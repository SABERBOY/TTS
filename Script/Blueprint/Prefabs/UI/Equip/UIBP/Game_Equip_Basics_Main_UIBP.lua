---@class Game_Equip_Basics_Main_UIBP_C:UAEUserWidget
---@field Common_DragDrop_Armor Common_DragDrop_Item_C
---@field Common_DragDrop_Common Common_DragDrop_Item_C
---@field Equipment_Slot_0 Game_Equip_Icon_Item_UIBP_C
---@field Equipment_Slot_1 Game_Equip_Icon_Item_UIBP_C
---@field Equipment_Slot_2 Game_Equip_Icon_Item_UIBP_C
---@field Equipment_Slot_3 Game_Equip_Icon_Item_UIBP_C
---@field Equipment_Slot_4 Game_Equip_Icon_Item_UIBP_C
---@field Equipment_Slot_5 Game_Equip_Icon_Item_UIBP_C
---@field Equipment_Slot_6 Game_Equip_Icon_Item_UIBP_C
---@field Equipment_Slot_7 Game_Equip_Icon_Item_UIBP_C
---@field Equipment_Slot_8 Game_Equip_Item_UIBP_C
---@field Equipment_Slot_9 Game_Equip_Item_UIBP_C
---@field Image_HighLight_ArmorPart UImage
---@field UGC_Equip_Bag_UIBP Game_Equip_Bag_UIBP_C
--Edit Below--
---装备显示面板（装备系统）：
---  挂在 Game_Equip_Main_UIBP 左侧；不再作为独立页面打开。
---  左侧 = 玩家当前已装备的六槽位（头盔/衣服/首饰/手套/腰带/鞋子），显示各槽位永久强化等级；
---  右侧 = 背包装备列表（子面板 Game_Equip_Bag_UIBP 承载）。
---  点击"已有装备"的槽位：切到主页面强化页签并强化该插槽（强化对象是槽位而非装备本体）；
---  点击空槽：不跳转，留在装备页只打一条提示日志。右侧页签进入强化页仍沿用上次槽位（首次=头盔）。
---  子控件都已是项目资产（Game_Equip_*），各自带 Lua 类：本面板只做编排，
---  槽位/背包的显示与点击由对应子控件自己的实例方法负责，不再有 New(Widget) 代理。
local EquipSlotSystem = require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotSystem')
local EquipPanelManager = require('Script.Blueprint.Prefabs.UI.Equip.EquipPanelManager')
local Game_Equip_Basics_Main_UIBP = {
    bInitDoOnce = false,
    bSlotWidgetsReady = false,
    bSlotWarned = false,
    InParams = nil,
    StrengthenWidget = nil,
    SlotLevelAttrHandles = {},
}
local SLOT_WIDGET_MAP = {
    -- 左边的三个槽位：头盔、衣服、首饰
    Equipment_Slot_1 = 1, -- 头盔
    Equipment_Slot_2 = 2, -- 衣服
    Equipment_Slot_4 = 3, -- 首饰
    -- 右边的三个槽位：手套、腰带、鞋子
    Equipment_Slot_5 = 4, -- 手套
    Equipment_Slot_6 = 5, -- 腰带
    Equipment_Slot_7 = 6, -- 鞋子
}
-- 未映射到六槽的两个大格子（中间两个），隐藏；注意要与 SLOT_WIDGET_MAP 互补，别把已映射的槽藏掉
local SPARE_SLOT_WIDGETS = { 'Equipment_Slot_0', 'Equipment_Slot_3' }
function Game_Equip_Basics_Main_UIBP:Construct()
    self:LuaInit()
end
function Game_Equip_Basics_Main_UIBP:LuaInit()
    if self.bInitDoOnce then
        return
    end
    self.bInitDoOnce = true
    for _, WidgetName in ipairs(SPARE_SLOT_WIDGETS) do
        if self[WidgetName] then
            self[WidgetName]:SetVisibility(ESlateVisibility.Collapsed)
        end
    end
    -- 背包子面板是真实 Game_Equip_Bag_UIBP 实例：注入 Owner，列表刷新由它自己处理
    local Bag = self.UGC_Equip_Bag_UIBP
    if Bag and Bag.InitData then
        Bag:InitData({ Owner = self })
    else
        print('[EquipBasics] UGC_Equip_Bag_UIBP 缺少 Game_Equip_Bag_UIBP 的 Lua 方法，检查资产类绑定')
    end
    self:Refresh()
end
---六槽控件是真实 Game_Equip_Icon_Item_UIBP 实例：只负责显示槽位与绑定点击。
---绑定是幂等的（子控件的 BindClick 自己防重复）；未绑定成功时下次 Refresh 会重试。
function Game_Equip_Basics_Main_UIBP:EnsureSlotWidgets()
    if self.bSlotWidgetsReady then
        return
    end
    local AllBound = true
    local WeakSelf = WeakObjectPtr(self)
    for WidgetName, SlotIdx in pairs(SLOT_WIDGET_MAP) do
        local W = self[WidgetName]
        if not W then
            AllBound = false
        else
            W:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
            if not W.BindClick then
                AllBound = false
                if not self.bSlotWarned then
                    self.bSlotWarned = true
                    print('[EquipBasics] ' .. WidgetName .. ' 没有 Game_Equip_Icon_Item_UIBP 的 Lua 方法，检查资产类绑定')
                end
            else
                local OK = W:BindClick(function()
                    if not WeakSelf:IsValid() then
                        return
                    end
                    local SelfRef = WeakSelf:Get()
                    if SelfRef then
                        SelfRef:OnSlotClicked(SlotIdx)
                    end
                end)
                if not OK then
                    AllBound = false
                end
            end
        end
    end
    if AllBound then
        self.bSlotWidgetsReady = true
        print('[EquipBasics] 六槽位点击已绑定')
    end
end
function Game_Equip_Basics_Main_UIBP:OnSlotClicked(SlotIdx)
    local DefineID, ItemID = EquipSlotSystem.GetEquippedOnSlot(SlotIdx)
    print(string.format('[EquipBasics] OnSlotClicked SlotIdx=%s ItemID=%s', tostring(SlotIdx), tostring(ItemID)))
    if not ItemID then
        -- 空槽不跳转：留在装备页，只提示。
        -- 手套(4)/腰带(5)没有内核槽位（EquipSlotSystem.KernelSlotNames 为 nil），
        -- GetEquippedOnSlot 永远返回 nil，因此这两槽按规则永不跳转强化页。
        local SlotDef = EquipSlotSystem.GetSlotDef(SlotIdx)
        print(string.format('[EquipBasics] %s槽 未装备，取消跳转强化面板',
            tostring(SlotDef and SlotDef.Name or SlotIdx)))
        return
    end
    -- 有装备：带着点击的 SlotIdx 跳到强化页，强化对象就是该插槽
    self:OpenStrengthenPanel(SlotIdx)
end
function Game_Equip_Basics_Main_UIBP:OpenStrengthenPanel(SlotIdx)
    EquipPanelManager.OpenStrengthen(SlotIdx)
end
function Game_Equip_Basics_Main_UIBP:Refresh()
    self:EnsureSlotWidgets()
    self:BindSlotLevelAttrs()
    EquipSlotSystem.BindAttachChange(self, function(SelfRef)
        print('[EquipBasics] attach changed, Refresh')
        SelfRef:Refresh()
    end)
    local PlayerState = self:GetLocalPlayerState()
    local PlayerPawn = self:GetLocalPlayerPawn()
    for WidgetName, SlotIdx in pairs(SLOT_WIDGET_MAP) do
        local W = self[WidgetName]
        if W and W.ApplyData then
            local SlotDef = EquipSlotSystem.GetSlotDef(SlotIdx)
            local Level = EquipSlotSystem.GetSlotLevel(PlayerState, SlotIdx, PlayerPawn)
            local DefineID, ItemID = EquipSlotSystem.GetEquippedOnSlot(SlotIdx)
            W:ApplyData(ItemID, Level, SlotDef and SlotDef.Name or '', ItemID ~= nil, DefineID)
        end
    end
    self:RefreshBagList()
end
function Game_Equip_Basics_Main_UIBP:RefreshBagList()
    local Bag = self.UGC_Equip_Bag_UIBP
    if not Bag or not Bag.ReloadItems then
        return
    end
    local PC = UGCGameSystem.GetLocalPlayerController()
    Bag:ReloadItems(EquipSlotSystem.CollectBagEquipItems(PC))
end
function Game_Equip_Basics_Main_UIBP:GetLocalPlayerState()
    local PC = UGCGameSystem.GetLocalPlayerController()
    if PC and CheckObjectContainsField(PC, 'GetCurPlayerState', true) then
        return PC:GetCurPlayerState()
    end
    return nil
end
function Game_Equip_Basics_Main_UIBP:GetLocalPlayerPawn()
    local PC = UGCGameSystem.GetLocalPlayerController()
    if PC and CheckObjectContainsField(PC, 'GetPlayerCharacterSafety', true) then
        return PC:GetPlayerCharacterSafety()
    end
    return nil
end
function Game_Equip_Basics_Main_UIBP:BindSlotLevelAttrs()
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
function Game_Equip_Basics_Main_UIBP:UnbindSlotLevelAttrs()
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
function Game_Equip_Basics_Main_UIBP:InitData(InParams)
    self.InParams = InParams or {}
    self:Refresh()
end
function Game_Equip_Basics_Main_UIBP:Destruct()
    self:UnbindSlotLevelAttrs()
    -- 背包子面板 / 六槽控件会收到自己的 Destruct，这里只清本面板状态
    self.InParams = nil
    self.StrengthenWidget = nil
    self.bSlotWidgetsReady = false
    self.bSlotWarned = false
    self.bInitDoOnce = false
end
return Game_Equip_Basics_Main_UIBP