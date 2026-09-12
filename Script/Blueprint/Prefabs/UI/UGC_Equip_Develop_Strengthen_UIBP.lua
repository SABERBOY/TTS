---@class UGC_Equip_Develop_Strengthen_UIBP_C:UAEUserWidget
---@field Common_Currency Common_Currency_UIBP_C
---@field Equip_Basic_GroupItem UGC_Equip_Basic_GroupItem_UIBP_C
---@field Equip_Grade_Item UGC_Equip_Grade_Item_UIBP_C
---@field Equip_Materials_GroupItem UGC_Equip_Materials_GroupItem_UIBP_C
---@field Image_Expand UImage
---@field NewButton_Insufficient UNewButton
---@field NewButton_Limit UNewButton
---@field NewButton_Submit UNewButton
---@field ProgressBar_Material UProgressBar
---@field ReuseList2_Bag ReuseList2_C
---@field TextBlock_Limit UTextBlock
---@field TextBlock_NotEnough UTextBlock
---@field TextBlock_Num1 UTextBlock
---@field TextBlock_Submit UTextBlock
---@field TextBlock_Times UTextBlock
---@field TextBlock_Total UTextBlock
---@field WidgetSwitcher_Btn UWidgetSwitcher
--Edit Below--
---装备强化面板（装备系统 第4节"永久槽位强化"）：
---  强化对象是"槽位（装备框）"，不是装备本体；等级 1-180，账号内四职业共享，换装不重置。
---  成功率 100%；从 L-1 升到 L：金币 = 30+3*L，装备零件 = 1+floor((L-1)/15)。
---  执行前预览目标等级、属性增量与完整消耗；请求处理中禁止重复点击（事务幂等由服务端保证）。
---  挂在 UGC_Equip_Main_UIBP 左侧，由养成/强化页签或槽位点击 InitData{SlotIdx, CloseCallback} 切入。
local EquipSlotSystem = require('Script.Common.EquipSlotSystem')
local EquipIconItem = require('Script.Equip.UIBP.Item.UGC_Equip_Icon_Item_UIBP')

local UGC_Equip_Develop_Strengthen_UIBP = {
    bInitDoOnce = false,
    bButtonsBound = false, -- 按钮委托是否已绑定（必须延迟到 InitData 时机，Construct 期绑定会原生崩溃）
    InParams = nil,
    SlotIdx = nil,
    CloseCallback = nil,

    -- 请求锁与属性变化刷新（RPC 单向，等级变化由属性复制驱动，无需 Tick）
    bRequesting = false,
    SlotLevelAttrHandle = nil, -- 当前绑定的 EquipSlotLv_* 属性变化委托
    bBagListBound = false,
    BagItems = {},
    BagClickData = {},
    bMaterialListBound = false,
    bBasicListBound = false,
    MaterialItems = {},
}

local function TryGetWidget(Owner, Name)
    if not Owner or not Name then
        return nil
    end
    if CheckObjectContainsField(Owner, Name, true) then
        return Owner[Name]
    end
    return nil
end

--安全执行：捕获 Lua 错误并记录（原生崩溃无法捕获，但阶段 print 可定位）
local function SafeCall(Desc, Fn)
    local OK, Err = pcall(Fn)
    if not OK then
        print('[EquipStrengthen] ' .. Desc .. ' ERR: ' .. tostring(Err))
    end
    return OK
end

--构造函数，UI创建时自动调用
function UGC_Equip_Develop_Strengthen_UIBP:Construct()
    print('[EquipStrengthen] Construct')
    self:LuaInit()
end

--Lua初始化函数
function UGC_Equip_Develop_Strengthen_UIBP:LuaInit()
    if self.bInitDoOnce then
        return
    end
    self.bInitDoOnce = true
    print('[EquipStrengthen] LuaInit begin')

    -- 注意：按钮委托绑定不在此处做！Construct 期 NewButton 的内核委托尚未初始化，
    -- 索引 .OnClicked 并 :Add 会触发客户端原生崩溃（已实测）。绑定延迟到 InitData 的 EnsureButtonsBound。

    SafeCall('SetTexts', function()
        if self.TextBlock_Submit then self.TextBlock_Submit:SetText('强化') end
        if self.TextBlock_NotEnough then self.TextBlock_NotEnough:SetText('材料不足') end
        if self.TextBlock_Limit then self.TextBlock_Limit:SetText('已达上限') end
    end)
    print('[EquipStrengthen] LuaInit end')
end

---按钮点击绑定（须在控件构造完成后调用，即 InitData 时机）：
---NewButton.OnClicked 为 LuaMulticastDelegate，运行时 Add 已实测安全（Broadcast 可触发回调）。
function UGC_Equip_Develop_Strengthen_UIBP:EnsureButtonsBound()
    if self.bButtonsBound then
        return
    end
    local Binds = {
        { Field = 'NewButton_Submit', Handler = self.OnSubmitClicked },
        { Field = 'NewButton_Insufficient', Handler = self.OnInsufficientClicked },
        { Field = 'NewButton_Limit', Handler = self.OnLimitClicked },
    }
    local AllBound = true
    for _, B in ipairs(Binds) do
        local Btn = self[B.Field]
        if Btn then
            local OK, Err = pcall(function()
                Btn.OnClicked:Add(B.Handler, self)
            end)
            if not OK then
                AllBound = false
                print('[EquipStrengthen] 按钮绑定失败 ' .. B.Field .. ' err=' .. tostring(Err))
            end
        else
            AllBound = false
            print('[EquipStrengthen] 按钮控件缺失 ' .. B.Field)
        end
    end
    if AllBound then
        self.bButtonsBound = true
        print('[EquipStrengthen] 三个按钮点击已绑定')
    end
end

---开放化接口：InitData
---@param InParams table {SlotIdx: number 槽位1-6, CloseCallback: function|nil 关闭回调}
function UGC_Equip_Develop_Strengthen_UIBP:InitData(InParams)
    InParams = InParams or {}
    self.InParams = InParams
    self.SlotIdx = InParams.SlotIdx or 1
    self.CloseCallback = InParams.CloseCallback
    self.bRequesting = false
    print('[EquipStrengthen] InitData slot=' .. tostring(self.SlotIdx))
    self:EnsureButtonsBound()
    self:BindSlotLevelAttr()
    self:Refresh()
end

---刷新面板：等级/进度/消耗预览/拥有量/按钮状态
function UGC_Equip_Develop_Strengthen_UIBP:Refresh()
    local SlotIdx = self.SlotIdx
    if not SlotIdx then
        return
    end
    local SlotDef = EquipSlotSystem.GetSlotDef(SlotIdx)
    if not SlotDef then
        return
    end
    print('[EquipStrengthen] Refresh begin slot=' .. tostring(SlotIdx))

    local PlayerState, PlayerPawn = self:GetPlayerStateAndPawn()
    -- 预览下一次 +1 强化的目标等级、属性增量与完整消耗（策划 4.3：执行前必须预览）
    local Preview = EquipSlotSystem.GetStrengthenPreview(PlayerState, PlayerPawn, SlotIdx, 1)
    local AttrName = SlotDef.AttrType == 'Atk' and '攻击' or '生命值上限'
    print(string.format('[EquipStrengthen] preview lv=%d gold=%d parts=%d have=%d maxed=%s afford=%s',
        Preview.Level, Preview.GoldCost, Preview.PartsCost, Preview.GoldHave,
        tostring(Preview.Maxed), tostring(Preview.Affordable)))

    -- 顶部信息区：当前装备名(或槽位名) / 等级 / 属性类型 / 品质·品阶上限 / 当前累计加成 → 下一级加成 + 当前装备图标
    SafeCall('GradeItem', function()
        local Grade = self.Equip_Grade_Item
        if Grade then
            local DefineID, ItemID = Preview.DefineID, Preview.ItemID
            local Title = SlotDef.Name .. '槽'
            if ItemID then
                local ItemName = EquipSlotSystem.GetItemName(DefineID, ItemID)
                if ItemName ~= '' then
                    Title = ItemName
                end
            end
            if Grade.TextBlock_IconName then Grade.TextBlock_IconName:SetText(Title) end
            if Grade.TextBlock_Num then Grade.TextBlock_Num:SetText('Lv.' .. tostring(Preview.Level)) end
            if Grade.TextBlock_Part then Grade.TextBlock_Part:SetText(AttrName) end
            if Grade.TextBlock_Profession then
                local Info = '未装备 · 全职业共享'
                if Preview.Rank then
                    Info = string.format('%s(%s) · 生效上限 Lv.%d',
                        EquipSlotSystem.GetQualityName(Preview.Quality), Preview.Rank.Name, Preview.Cap)
                end
                Grade.TextBlock_Profession:SetText(Info)
            end
            if Grade.TextBlock_Value then
                if Preview.Rank and Preview.CapReached then
                    -- 槽位等级已超过当前装备品阶上限：继续强化不会立刻生效，提示实际生效值
                    Grade.TextBlock_Value:SetText(string.format('+%d(生效+%d) → +%d',
                        Preview.CurBonus, Preview.EffectiveBonus, Preview.NextBonus))
                else
                    Grade.TextBlock_Value:SetText(string.format('+%d → +%d', Preview.CurBonus, Preview.NextBonus))
                end
            end
            if Grade.Equip_Icon_Item then
                local Icon = EquipIconItem.New(Grade.Equip_Icon_Item)
                if Icon then
                    Icon:ApplyData(ItemID, Preview.Level, SlotDef.Name, ItemID ~= nil, DefineID)
                end
            end
        end
    end)

    -- 等级数字与满级进度
    SafeCall('LevelTexts', function()
        if self.TextBlock_Num1 then self.TextBlock_Num1:SetText(tostring(Preview.Level)) end
        if self.ProgressBar_Material then
            self.ProgressBar_Material:SetPercent(Preview.Level / EquipSlotSystem.MAX_LEVEL)
        end
        if self.TextBlock_Times then self.TextBlock_Times:SetText(tostring(Preview.GoldCost)) end
        if self.TextBlock_Total then self.TextBlock_Total:SetText(tostring(Preview.PartsCost)) end
    end)

    -- 金币拥有量（Common_Currency 子控件金额文本）
    SafeCall('Currency', function()
        local Currency = self.Common_Currency
        if Currency and Currency.TextBlock_Currency_Amount then
            Currency.TextBlock_Currency_Amount:SetText(tostring(Preview.GoldHave))
        end
    end)

    -- 按钮状态切换：0=可强化(Submit) / 1=材料不足(Insufficient) / 2=已达上限(Limit)
    SafeCall('BtnSwitcher', function()
        local BtnState = 0
        if Preview.Maxed then
            BtnState = 2
        elseif not Preview.Affordable then
            BtnState = 1
        end
        if self.WidgetSwitcher_Btn then
            self.WidgetSwitcher_Btn:SetActiveWidgetIndex(BtnState)
        end
    end)

    -- 属性组/材料组
    SafeCall('GroupItems', function()
        self:RefreshBasicGroup(SlotIdx, SlotDef, Preview, AttrName)
        self:RefreshMaterialGroup(Preview)
    end)
    self:RefreshBagList()
    print('[EquipStrengthen] Refresh end')
end

function UGC_Equip_Develop_Strengthen_UIBP:EnsureBagListBound()
    if self.bBagListBound then
        return
    end
    local List = self.ReuseList2_Bag
    if not List then
        return
    end
    local OK, Err = pcall(function()
        List.OnUpdateItem:Add(self.OnUpdateBagItem, self)
    end)
    if OK then
        self.bBagListBound = true
        print('[EquipStrengthen] ReuseList2_Bag bound')
    else
        print('[EquipStrengthen] bag list bind failed ' .. tostring(Err))
    end
end

function UGC_Equip_Develop_Strengthen_UIBP:RefreshBagList()
    self:EnsureBagListBound()
    local PC = UGCGameSystem.GetLocalPlayerController()
    self.BagItems = EquipSlotSystem.CollectBagEquipItems(PC)
    if self.ReuseList2_Bag then
        pcall(function()
            self.ReuseList2_Bag:Reload(#self.BagItems)
        end)
        print('[EquipStrengthen] bag Reload count=' .. tostring(#self.BagItems))
    end
end

function UGC_Equip_Develop_Strengthen_UIBP:OnUpdateBagItem(Widget, Index)
    if not Widget then
        return
    end
    local Data = self.BagItems and (self.BagItems[Index + 1] or self.BagItems[Index])
    if not Data then
        return
    end
    local Level = 0
    if Data.SlotIdx then
        local PlayerState, PlayerPawn = self:GetPlayerStateAndPawn()
        Level = EquipSlotSystem.GetSlotLevel(PlayerState, Data.SlotIdx, PlayerPawn)
    end
    local SlotDef = Data.SlotIdx and EquipSlotSystem.GetSlotDef(Data.SlotIdx) or nil
    local Cell = EquipIconItem.New(Widget)
    if Cell then
        Cell:ApplyData(Data.ItemID, Level, SlotDef and SlotDef.Name or '', Data.bEquipped, Data.DefineID)
    end
    local Key = tostring(Widget)
    self.BagClickData = self.BagClickData or {}
    self.BagClickBound = self.BagClickBound or {}
    self.BagClickData[Key] = Data
    if self.BagClickBound[Key] or not Widget.Common_DragDrop_Item then
        return
    end
    local WeakSelf = WeakObjectPtr(self)
    local WeakWidget = WeakObjectPtr(Widget)
    local OK = pcall(function()
        Widget.Common_DragDrop_Item.OnDragClicked:Add(function()
            if not WeakSelf:IsValid() or not WeakWidget:IsValid() then
                return
            end
            local SelfRef = WeakSelf:Get()
            local ItemWidget = WeakWidget:Get()
            local ClickData = SelfRef and SelfRef.BagClickData and SelfRef.BagClickData[tostring(ItemWidget)]
            if not SelfRef or not ClickData or not ClickData.SlotIdx then
                return
            end
            print(string.format('[EquipStrengthen] bag click ItemID=%s SlotIdx=%s equipped=%s',
                tostring(ClickData.ItemID), tostring(ClickData.SlotIdx), tostring(ClickData.bEquipped)))
            SelfRef:InitData({
                SlotIdx = ClickData.SlotIdx,
                CloseCallback = SelfRef.CloseCallback,
            })
        end)
    end)
    if OK then
        self.BagClickBound[Key] = true
    end
end

function UGC_Equip_Develop_Strengthen_UIBP:RefreshBasicGroup(SlotIdx, SlotDef, Preview, AttrName)
    local Group = self.Equip_Basic_GroupItem
    if not Group then
        return
    end
    local Title = TryGetWidget(Group, 'TextBlock_0')
    if Title then
        Title:SetText('基础属性')
    end
    self.BasicItems = {
        {
            Name = AttrName,
            OldValue = '+' .. tostring(Preview.CurBonus),
            NewValue = '+' .. tostring(Preview.NextBonus),
        },
    }
    -- 有装备时补一行"生效等级"：min(槽位等级, 品阶上限)，让玩家看到品阶截断
    if Preview.Rank then
        local NextEffective = math.min(Preview.Target, Preview.Cap)
        self.BasicItems[#self.BasicItems + 1] = {
            Name = string.format('生效等级(%s上限%d)', Preview.Rank.Name, Preview.Cap),
            OldValue = 'Lv.' .. tostring(Preview.EffectiveLevel),
            NewValue = 'Lv.' .. tostring(NextEffective),
        }
    end
    local Box = TryGetWidget(Group, 'WrapGroupBox_property')
    if not Box then
        return
    end
    if not self.bBasicListBound then
        local OK = pcall(function()
            Box.OnUpdateItem:Add(self.OnUpdateBasicItem, self)
        end)
        if OK then
            self.bBasicListBound = true
        end
    end
    pcall(function()
        Box:Reload(#self.BasicItems)
    end)
end

function UGC_Equip_Develop_Strengthen_UIBP:OnUpdateBasicItem(Widget, Index)
    if not Widget then
        return
    end
    local Data = self.BasicItems and (self.BasicItems[Index + 1] or self.BasicItems[Index])
    if not Data then
        return
    end
    local NameText = TryGetWidget(Widget, 'TextBlock_AttributeName')
    if NameText then NameText:SetText(Data.Name) end
    local OldText = TryGetWidget(Widget, 'TextBlock_Old')
    if OldText then OldText:SetText(Data.OldValue) end
    local NewText = TryGetWidget(Widget, 'TextBlock_New')
    if NewText then NewText:SetText(Data.NewValue) end
end

function UGC_Equip_Develop_Strengthen_UIBP:RefreshMaterialGroup(Preview)
    local Group = self.Equip_Materials_GroupItem
    if not Group then
        return
    end
    local Title = TryGetWidget(Group, 'TextBlock_0')
    if Title then
        Title:SetText('升级材料')
    end
    self.MaterialItems = {
        { Have = Preview.GoldHave, Need = Preview.GoldCost },
        { Have = Preview.PartsHave or 0, Need = Preview.PartsCost },
    }
    local List = TryGetWidget(Group, 'ReuseList2')
    if not List then
        return
    end
    if not self.bMaterialListBound then
        local OK = pcall(function()
            List.OnUpdateItem:Add(self.OnUpdateMaterialItem, self)
        end)
        if OK then
            self.bMaterialListBound = true
        end
    end
    pcall(function()
        List:Reload(#self.MaterialItems)
    end)
end

function UGC_Equip_Develop_Strengthen_UIBP:OnUpdateMaterialItem(Widget, Index)
    if not Widget then
        return
    end
    local Data = self.MaterialItems and (self.MaterialItems[Index + 1] or self.MaterialItems[Index])
    if not Data then
        return
    end
    local Enough = (Data.Have or 0) >= (Data.Need or 0)
    local Switcher = TryGetWidget(Widget, 'WidgetSwitcher_Meterial')
    if Switcher then
        pcall(function()
            Switcher:SetActiveWidgetIndex(Enough and 0 or 1)
        end)
    end
    local function SetNamed(Name, Value)
        local Text = TryGetWidget(Widget, Name)
        if Text then Text:SetText(tostring(Value)) end
    end
    SetNamed('TextBlock_Hold', Data.Have or 0)
    SetNamed('TextBlock_Need', Data.Need or 0)
    SetNamed('TextBlock_Quantity', Data.Have or 0)
    SetNamed('TextBlock_Need_Quantity', Data.Need or 0)
end

---强化按钮：+1 级
---策划 4.3 还要求提供 +10 与"升至当前上限"：当前内核面板无对应按钮控件，
---数据层已支持批量（StrengthenBatch(10) / StrengthenToCap()），UI 扩展按钮后直接调用即可。
function UGC_Equip_Develop_Strengthen_UIBP:OnSubmitClicked()
    self:StrengthenBatch(1)
end

---批量强化请求（Count 级；服务端事务校验并扣除）
function UGC_Equip_Develop_Strengthen_UIBP:StrengthenBatch(Count)
    if self.bRequesting then
        return -- 策划 11：请求处理中禁止重复点击
    end
    local PlayerState, PlayerPawn = self:GetPlayerStateAndPawn()
    local Preview = EquipSlotSystem.GetStrengthenPreview(PlayerState, PlayerPawn, self.SlotIdx, Count)
    if Preview.Maxed then
        print('[EquipStrengthen] 已达上限 180 级')
        return
    end
    if not Preview.Affordable then
        print(string.format('[EquipStrengthen] 材料不足：金币 %d/%d 零件 %d/%d',
            Preview.GoldHave, Preview.GoldCost, Preview.PartsHave, Preview.PartsCost))
        self:Refresh()
        return
    end

    self.bRequesting = true
    self.RequestFromLevel = Preview.Level
    self.RequestElapsed = 0
    print(string.format('[EquipStrengthen] 发起强化请求 slot=%d count=%d from=%d', self.SlotIdx, Count, Preview.Level))
    EquipSlotSystem.ClientRequestStrengthen(self.SlotIdx, Count)
end

---升至系统上限（180 级）：预留接口，UI 扩展按钮后绑定
function UGC_Equip_Develop_Strengthen_UIBP:StrengthenToCap()
    self:StrengthenBatch(EquipSlotSystem.MAX_LEVEL)
end

function UGC_Equip_Develop_Strengthen_UIBP:OnInsufficientClicked()
    local PlayerState, PlayerPawn = self:GetPlayerStateAndPawn()
    local Preview = EquipSlotSystem.GetStrengthenPreview(PlayerState, PlayerPawn, self.SlotIdx, 1)
    print(string.format('[EquipStrengthen] 材料不足：金币 %d/%d 零件 %d/%d',
        Preview.GoldHave, Preview.GoldCost, Preview.PartsHave, Preview.PartsCost))
end

function UGC_Equip_Develop_Strengthen_UIBP:OnLimitClicked()
    print('[EquipStrengthen] 槽位已达 180 级上限')
    if self.CloseCallback then
        self.CloseCallback()
    end
end

---绑定槽位等级属性变化委托（客户端）：属性复制到达时刷新并解除请求锁
function UGC_Equip_Develop_Strengthen_UIBP:BindSlotLevelAttr()
    self:UnbindSlotLevelAttr()
    local PlayerState, PlayerPawn = self:GetPlayerStateAndPawn()
    if not PlayerPawn then
        return
    end
    local AttrName = EquipSlotSystem.GetSlotAttrName(self.SlotIdx)
    if not AttrName then
        return
    end
    local WeakSelf = WeakObjectPtr(self)
    local OK, Handle = pcall(function()
        return UGCAttributeSystem.AddGameAttributeChangedDelegate(PlayerPawn, AttrName, function()
            if not WeakSelf:IsValid() then return end
            local SelfRef = WeakSelf:Get()
            if not SelfRef then return end
            SelfRef.bRequesting = false
            SelfRef:Refresh()
        end)
    end)
    if OK then
        self.SlotLevelAttrHandle = Handle
        print('[EquipStrengthen] 绑定属性变化 ' .. AttrName)
    else
        print('[EquipStrengthen] 绑定属性变化失败 ' .. tostring(AttrName))
    end
end

function UGC_Equip_Develop_Strengthen_UIBP:UnbindSlotLevelAttr()
    if not self.SlotLevelAttrHandle then
        return
    end
    local PlayerState, PlayerPawn = self:GetPlayerStateAndPawn()
    local AttrName = EquipSlotSystem.GetSlotAttrName(self.SlotIdx)
    if PlayerPawn and AttrName then
        pcall(function()
            UGCAttributeSystem.RemoveGameAttributeChangedDelegate(PlayerPawn, AttrName, self.SlotLevelAttrHandle)
        end)
    end
    self.SlotLevelAttrHandle = nil
end

function UGC_Equip_Develop_Strengthen_UIBP:GetPlayerStateAndPawn()
    local PC = UGCGameSystem.GetLocalPlayerController()
    if not PC then
        return nil, nil
    end
    local PlayerState = CheckObjectContainsField(PC, 'GetCurPlayerState', true) and PC:GetCurPlayerState() or nil
    local PlayerPawn = CheckObjectContainsField(PC, 'GetPlayerCharacterSafety', true) and PC:GetPlayerCharacterSafety() or nil
    return PlayerState, PlayerPawn
end

--析构函数，UI销毁时自动调用
function UGC_Equip_Develop_Strengthen_UIBP:Destruct()
    SafeCall('UnbindButtons', function()
        if self.bButtonsBound then
            if self.NewButton_Submit then
                self.NewButton_Submit.OnClicked:Remove(self.OnSubmitClicked, self)
            end
            if self.NewButton_Insufficient then
                self.NewButton_Insufficient.OnClicked:Remove(self.OnInsufficientClicked, self)
            end
            if self.NewButton_Limit then
                self.NewButton_Limit.OnClicked:Remove(self.OnLimitClicked, self)
            end
        end
    end)
    self:UnbindSlotLevelAttr()
    self.InParams = nil
    self.SlotIdx = nil
    self.CloseCallback = nil
    self.bRequesting = false
    self.bButtonsBound = false
    self.bBagListBound = false
    self.BagItems = {}
    self.BagClickData = {}
    self.BagClickBound = {}
    self.bMaterialListBound = false
    self.bBasicListBound = false
    self.MaterialItems = {}
    self.BasicItems = {}
    self.bInitDoOnce = false
end

return UGC_Equip_Develop_Strengthen_UIBP
