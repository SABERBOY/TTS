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
---  由 UGC_Equip_Basics_Main_UIBP 点击装备槽后 InitData{SlotIdx, CloseCallback} 打开。
local EquipSlotSystem = require('Script.Common.EquipSlotSystem')

local UGC_Equip_Develop_Strengthen_UIBP = {
    bInitDoOnce = false,
    bButtonsBound = false, -- 按钮委托是否已绑定（必须延迟到 InitData 时机，Construct 期绑定会原生崩溃）
    InParams = nil,
    SlotIdx = nil,
    CloseCallback = nil,

    -- 请求锁与属性变化刷新（RPC 单向，等级变化由属性复制驱动，无需 Tick）
    bRequesting = false,
    SlotLevelAttrHandle = nil, -- 当前绑定的 EquipSlotLv_* 属性变化委托
}

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

    -- 顶部信息区：槽位名 / 等级 / 属性类型 / 当前累计加成 → 下一级加成
    SafeCall('GradeItem', function()
        local Grade = self.Equip_Grade_Item
        if Grade then
            if Grade.TextBlock_IconName then Grade.TextBlock_IconName:SetText(SlotDef.Name .. '槽') end
            if Grade.TextBlock_Num then Grade.TextBlock_Num:SetText('Lv.' .. tostring(Preview.Level)) end
            if Grade.TextBlock_Part then Grade.TextBlock_Part:SetText(AttrName) end
            if Grade.TextBlock_Value then
                Grade.TextBlock_Value:SetText(string.format('+%d → +%d', Preview.CurBonus, Preview.NextBonus))
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

    -- 属性组/材料组子控件：内核 lua 接口未知，防御性传入预览数据
    SafeCall('GroupItems', function()
        if self.Equip_Basic_GroupItem and CheckObjectContainsField(self.Equip_Basic_GroupItem, 'InitData', true) then
            self.Equip_Basic_GroupItem:InitData({
                SlotIdx = SlotIdx,
                Level = Preview.Level,
                AttrType = SlotDef.AttrType,
                AttrName = AttrName,
                CurBonus = Preview.CurBonus,
                NextBonus = Preview.NextBonus,
            })
        end
        if self.Equip_Materials_GroupItem and CheckObjectContainsField(self.Equip_Materials_GroupItem, 'InitData', true) then
            self.Equip_Materials_GroupItem:InitData({
                GoldCost = Preview.GoldCost,
                PartsCost = Preview.PartsCost,
                GoldHave = Preview.GoldHave,
                PartsHave = Preview.PartsHave,
            })
        end
    end)
    print('[EquipStrengthen] Refresh end')
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
    self.bInitDoOnce = false
end

return UGC_Equip_Develop_Strengthen_UIBP
