---@class UGC_Equip_Basics_Main_UIBP_C:UAEUserWidget
---@field Common_DragDrop_Armor Common_DragDrop_Item_C
---@field Common_DragDrop_Common Common_DragDrop_Item_C
---@field Equipment_Slot_0 UGC_Equip_Icon_Item_UIBP_C
---@field Equipment_Slot_1 UGC_Equip_Icon_Item_UIBP_C
---@field Equipment_Slot_2 UGC_Equip_Icon_Item_UIBP_C
---@field Equipment_Slot_3 UGC_Equip_Icon_Item_UIBP_C
---@field Equipment_Slot_4 UGC_Equip_Icon_Item_UIBP_C
---@field Equipment_Slot_5 UGC_Equip_Icon_Item_UIBP_C
---@field Equipment_Slot_6 UGC_Equip_Icon_Item_UIBP_C
---@field Equipment_Slot_7 UGC_Equip_Icon_Item_UIBP_C
---@field Equipment_Slot_8 UGC_Equip_Item_UIBP_C
---@field Equipment_Slot_9 UGC_Equip_Item_UIBP_C
---@field Image_HighLight_ArmorPart UImage
---@field UGC_Equip_Bag_UIBP UGC_Equip_Bag_UIBP_C
--Edit Below--
---装备显示面板（装备系统）：
---  左侧 = 玩家当前已装备的六槽位（头盔/衣服/首饰/手套/腰带/鞋子），显示各槽位永久强化等级；
---  右侧 = 背包装备列表（内核子面板 UGC_Equip_Bag_UIBP 承载）。
---  点击装备槽（装备框）弹出装备强化面板 UGC_Equip_Develop_Strengthen_UIBP，强化的是槽位而非装备本体。
local EquipSlotSystem = require('Script.Common.EquipSlotSystem')

local UGC_Equip_Basics_Main_UIBP = {
    bInitDoOnce = false,
    bClickBound = false, -- 槽位点击是否已绑定（必须延迟到 InitData 时机，Construct 期绑定会原生崩溃）
    InParams = nil,
    StrengthenWidget = nil, -- 已打开的强化面板（WeakObjectPtr）
    SlotLevelAttrHandles = {}, -- 六槽位等级属性变化委托
}

-- 内核槽位控件 → 策划六槽位(SlotIdx) 映射
-- 布局依据：Slot_0/Slot_3 为中间大框(100x110)，左列 Slot_1/2/4、右列 Slot_5/6/7 为小框(72x72)
-- 策划仅六槽：中上=头盔、中下=衣服、左列=手套/腰带/鞋子、右上=首饰；Slot_6/7 备用隐藏
local SLOT_WIDGET_MAP = {
    Equipment_Slot_0 = 1, -- 头盔
    Equipment_Slot_3 = 2, -- 衣服
    Equipment_Slot_5 = 3, -- 首饰
    Equipment_Slot_1 = 4, -- 手套
    Equipment_Slot_2 = 5, -- 腰带
    Equipment_Slot_4 = 6, -- 鞋子
}
local SPARE_SLOT_WIDGETS = { 'Equipment_Slot_6', 'Equipment_Slot_7' }

--构造函数，UI创建时自动调用
function UGC_Equip_Basics_Main_UIBP:Construct()
    self:LuaInit()
end

--Lua初始化函数
function UGC_Equip_Basics_Main_UIBP:LuaInit()
    if self.bInitDoOnce then
        return
    end
    self.bInitDoOnce = true

    -- 注意：槽位点击绑定不在此处做！Construct 期子控件的内核委托尚未初始化，
    -- 索引/绑定会触发原生崩溃（已实测）。绑定延迟到 InitData/Refresh 的 EnsureSlotClickBound。

    -- 策划只有六槽，备用槽位隐藏（Slot_8/9 为内核横条控件，保持默认不动）
    for _, WidgetName in ipairs(SPARE_SLOT_WIDGETS) do
        if self[WidgetName] then
            self[WidgetName]:SetVisibility(ESlateVisibility.Collapsed)
        end
    end

    self:Refresh()
end

---槽位点击绑定（须在控件构造完成后调用，即 InitData/Refresh 时机）：
---内核槽位的点击流经过 Common_DragDrop_Item.OnDragClicked（LuaMulticastDelegate），
---运行时 Add 已实测安全；实例级包装内核 lua 函数（slot.OnClicked=fn）不生效，勿用。
function UGC_Equip_Basics_Main_UIBP:EnsureSlotClickBound()
    if self.bClickBound then
        return
    end
    local AllBound = true
    for WidgetName, SlotIdx in pairs(SLOT_WIDGET_MAP) do
        local SlotWidget = self[WidgetName]
        local DragDrop = SlotWidget and SlotWidget.Common_DragDrop_Item
        if DragDrop then
            local WeakSelf = WeakObjectPtr(self)
            local OK, Err = pcall(function()
                DragDrop.OnDragClicked:Add(function()
                    if not WeakSelf:IsValid() then return end
                    local SelfRef = WeakSelf:Get()
                    if SelfRef then
                        SelfRef:OnSlotClicked(SlotIdx)
                    end
                end)
            end)
            if not OK then
                AllBound = false
                print('[EquipBasics] 槽位点击绑定失败 SlotIdx=' .. tostring(SlotIdx) .. ' err=' .. tostring(Err))
            end
        else
            AllBound = false
        end
    end
    if AllBound then
        self.bClickBound = true
        print('[EquipBasics] 六槽位点击已绑定')
    end
end

---点击装备槽：弹出装备强化面板（强化槽位/装备框，不是强化装备）
function UGC_Equip_Basics_Main_UIBP:OnSlotClicked(SlotIdx)
    ugcprint('[EquipBasics] OnSlotClicked SlotIdx=' .. tostring(SlotIdx))
    self:OpenStrengthenPanel(SlotIdx)
end

---打开强化面板（复用已创建实例；不存在则异步创建项目版 UGC_Equip_Develop_Strengthen_UIBP）
function UGC_Equip_Basics_Main_UIBP:OpenStrengthenPanel(SlotIdx)
    local Cached = self.StrengthenWidget
    if Cached and Cached:IsValid() then
        local Widget = Cached:Get()
        if Widget then
            UGCWidgetUtility.ShowWidget(Widget)
            if CheckObjectContainsField(Widget, 'InitData', true) then
                Widget:InitData({
                    SlotIdx = SlotIdx,
                    CloseCallback = function() UGCWidgetUtility.HideWidget(Widget) end,
                })
            end
            return
        end
    end

    local Path = UGCGameSystem.GetUGCResourcesFullPath(
        'Asset/Blueprint/Prefabs/UI/UGC_Equip_Develop_Strengthen_UIBP.UGC_Equip_Develop_Strengthen_UIBP_C')
    local WeakSelf = WeakObjectPtr(self)
    UGCWidgetUtility.CreateWidgetAsync(Path, function(Widget)
        if not Widget or not UE.IsValid(Widget) then return end
        if not WeakSelf:IsValid() then return end
        local SelfRef = WeakSelf:Get()
        if not SelfRef then return end

        SelfRef.StrengthenWidget = WeakObjectPtr(Widget)
        print('[EquipBasics] Strengthen created')
        if not UGCWidgetUtility.IsWidgetAddedToSlot(Widget) then
            UGCWidgetUtility.AddToSlot(Widget, 'UI.UISlot.MainUISlot_High', 200)
        end
        print('[EquipBasics] Strengthen AddToSlot done')
        UGCWidgetUtility.ShowWidget(Widget)
        print('[EquipBasics] Strengthen ShowWidget done')
        if CheckObjectContainsField(Widget, 'InitData', true) then
            Widget:InitData({
                SlotIdx = SlotIdx,
                CloseCallback = function() UGCWidgetUtility.HideWidget(Widget) end,
            })
        end
        print('[EquipBasics] Strengthen InitData done')
    end)
end

---刷新面板：左侧六槽位显示永久强化等级，右侧背包列表防御性刷新
function UGC_Equip_Basics_Main_UIBP:Refresh()
    self:EnsureSlotClickBound()
    self:BindSlotLevelAttrs()
    local PlayerState = self:GetLocalPlayerState()
    local PlayerPawn = self:GetLocalPlayerPawn()

    for WidgetName, SlotIdx in pairs(SLOT_WIDGET_MAP) do
        local SlotWidget = self[WidgetName]
        if SlotWidget then
            local Level = EquipSlotSystem.GetSlotLevel(PlayerState, SlotIdx, PlayerPawn)
            -- 槽位（装备框）永久强化等级：Icon_Item 自带 TextBlock_Level
            -- 注：策划装备物品入库后，此文本如与内核装备等级显示冲突，改为叠加显示
            if SlotWidget.TextBlock_Level then
                SlotWidget.TextBlock_Level:SetText('Lv.' .. tostring(Level))
            end
        end
    end

    -- 右侧背包装备列表：内核子面板自管数据，防御性调用其刷新接口
    local Bag = self.UGC_Equip_Bag_UIBP
    if Bag then
        if CheckObjectContainsField(Bag, 'RefreshBagData', true) then
            Bag:RefreshBagData()
        elseif CheckObjectContainsField(Bag, 'Refresh', true) then
            Bag:Refresh()
        end
    end
end

function UGC_Equip_Basics_Main_UIBP:GetLocalPlayerState()
    local PC = UGCGameSystem.GetLocalPlayerController()
    if PC and CheckObjectContainsField(PC, 'GetCurPlayerState', true) then
        return PC:GetCurPlayerState()
    end
    return nil
end

function UGC_Equip_Basics_Main_UIBP:GetLocalPlayerPawn()
    local PC = UGCGameSystem.GetLocalPlayerController()
    if PC and CheckObjectContainsField(PC, 'GetPlayerCharacterSafety', true) then
        return PC:GetPlayerCharacterSafety()
    end
    return nil
end

---绑定六槽位等级属性变化，实时刷新左侧等级显示
function UGC_Equip_Basics_Main_UIBP:BindSlotLevelAttrs()
    self:UnbindSlotLevelAttrs()
    local PlayerPawn = self:GetLocalPlayerPawn()
    if not PlayerPawn then
        return
    end
    local WeakSelf = WeakObjectPtr(self)
    for _, SlotIdx in pairs(SLOT_WIDGET_MAP) do
        local AttrName = EquipSlotSystem.GetSlotAttrName(SlotIdx)
        if AttrName and not self.SlotLevelAttrHandles[SlotIdx] then
            local OK, Handle = pcall(function()
                return UGCAttributeSystem.AddGameAttributeChangedDelegate(PlayerPawn, AttrName, function()
                    if not WeakSelf:IsValid() then return end
                    local SelfRef = WeakSelf:Get()
                    if SelfRef then
                        SelfRef:Refresh()
                    end
                end)
            end)
            if OK then
                self.SlotLevelAttrHandles[SlotIdx] = Handle
            end
        end
    end
end

function UGC_Equip_Basics_Main_UIBP:UnbindSlotLevelAttrs()
    local PlayerPawn = self:GetLocalPlayerPawn()
    if not PlayerPawn then
        self.SlotLevelAttrHandles = {}
        return
    end
    for SlotIdx, Handle in pairs(self.SlotLevelAttrHandles) do
        local AttrName = EquipSlotSystem.GetSlotAttrName(SlotIdx)
        if AttrName then
            pcall(function()
                UGCAttributeSystem.RemoveGameAttributeChangedDelegate(PlayerPawn, AttrName, Handle)
            end)
        end
    end
    self.SlotLevelAttrHandles = {}
end

---开放化接口：InitData（外部容器打开面板时调用）
function UGC_Equip_Basics_Main_UIBP:InitData(InParams)
    self.InParams = InParams or {}
    self:Refresh()
end

--析构函数，UI销毁时自动调用
function UGC_Equip_Basics_Main_UIBP:Destruct()
    self:UnbindSlotLevelAttrs()
    self.InParams = nil
    self.StrengthenWidget = nil
    self.bClickBound = false
    self.bInitDoOnce = false
end

return UGC_Equip_Basics_Main_UIBP
