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
---  挂在 UGC_Equip_Main_UIBP 左侧；不再作为独立页面打开。
---  左侧 = 玩家当前已装备的六槽位（头盔/衣服/首饰/手套/腰带/鞋子），显示各槽位永久强化等级；
---  右侧 = 背包装备列表（内核子面板 UGC_Equip_Bag_UIBP 承载）。
---  点击装备槽切到主页面强化页签，强化的是槽位而非装备本体。
local EquipSlotSystem = require('Script.Common.EquipSlotSystem')
local EquipPanelManager = require('Script.Common.EquipPanelManager')
local EquipIconItem = require('Script.Equip.UIBP.Item.UGC_Equip_Icon_Item_UIBP')
local EquipBag = require('Script.Equip.UIBP.Item.UGC_Equip_Bag_UIBP')

local UGC_Equip_Basics_Main_UIBP = {
    bInitDoOnce = false,
    bClickBound = false,
    InParams = nil,
    StrengthenWidget = nil,
    SlotLevelAttrHandles = {},
    SlotCtrls = {},
    BagCtrl = nil,
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

function UGC_Equip_Basics_Main_UIBP:Construct()
    self:LuaInit()
end

function UGC_Equip_Basics_Main_UIBP:LuaInit()
    if self.bInitDoOnce then
        return
    end
    self.bInitDoOnce = true

    for _, WidgetName in ipairs(SPARE_SLOT_WIDGETS) do
        if self[WidgetName] then
            self[WidgetName]:SetVisibility(ESlateVisibility.Collapsed)
        end
    end

    self.SlotCtrls = {}
    self:EnsureSlotCtrls()
    self.BagCtrl = EquipBag.New(self.UGC_Equip_Bag_UIBP, self)

    self:Refresh()
end

---六槽代理：嵌套在 UGC_Equip_Main_UIBP 里时，Construct 期拿到的子控件对象随后会失效
---（实测 Ctrl:GetWidget() 变 nil），每次 Refresh 前重新校验并按需重建，重建后点击要重新绑定。
function UGC_Equip_Basics_Main_UIBP:EnsureSlotCtrls()
    self.SlotCtrls = self.SlotCtrls or {}
    local Rebuilt = false
    for WidgetName, _ in pairs(SLOT_WIDGET_MAP) do
        local W = self[WidgetName]
        if W then
            W:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
        end
        local Ctrl = self.SlotCtrls[WidgetName]
        if (not Ctrl or not Ctrl:IsValid()) and W then
            self.SlotCtrls[WidgetName] = EquipIconItem.New(W)
            Rebuilt = true
        end
    end
    if Rebuilt then
        self.bClickBound = false
    end
end

function UGC_Equip_Basics_Main_UIBP:EnsureSlotClickBound()
    if self.bClickBound then
        return
    end
    local AllBound = true
    local WeakSelf = WeakObjectPtr(self)
    for WidgetName, SlotIdx in pairs(SLOT_WIDGET_MAP) do
        local Ctrl = self.SlotCtrls and self.SlotCtrls[WidgetName]
        if Ctrl then
            local OK = Ctrl:BindClick(function()
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
                print('[EquipBasics] 槽位点击绑定失败 SlotIdx=' .. tostring(SlotIdx))
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

function UGC_Equip_Basics_Main_UIBP:OnSlotClicked(SlotIdx)
    local DefineID, ItemID = EquipSlotSystem.GetEquippedOnSlot(SlotIdx)
    print(string.format('[EquipBasics] OnSlotClicked SlotIdx=%s ItemID=%s', tostring(SlotIdx), tostring(ItemID)))
    if not ItemID then
        print('[EquipBasics] 该槽位当前没有装备，仍打开强化面板（强化对象是槽位）')
    end
    self:OpenStrengthenPanel(SlotIdx)
end

function UGC_Equip_Basics_Main_UIBP:OpenStrengthenPanel(SlotIdx)
    EquipPanelManager.OpenStrengthen(SlotIdx)
end

function UGC_Equip_Basics_Main_UIBP:Refresh()
    self:EnsureSlotCtrls()
    self:EnsureSlotClickBound()
    self:BindSlotLevelAttrs()
    EquipSlotSystem.BindAttachChange(self, function(SelfRef)
        print('[EquipBasics] attach changed, Refresh')
        SelfRef:Refresh()
    end)
    local PlayerState = self:GetLocalPlayerState()
    local PlayerPawn = self:GetLocalPlayerPawn()

    for WidgetName, SlotIdx in pairs(SLOT_WIDGET_MAP) do
        local Ctrl = self.SlotCtrls and self.SlotCtrls[WidgetName]
        if Ctrl then
            local SlotDef = EquipSlotSystem.GetSlotDef(SlotIdx)
            local Level = EquipSlotSystem.GetSlotLevel(PlayerState, SlotIdx, PlayerPawn)
            local DefineID, ItemID = EquipSlotSystem.GetEquippedOnSlot(SlotIdx)
            Ctrl:ApplyData(ItemID, Level, SlotDef and SlotDef.Name or '', ItemID ~= nil, DefineID)
        end
    end

    self:RefreshBagList()
end

function UGC_Equip_Basics_Main_UIBP:RefreshBagList()
    if not self.BagCtrl then
        return
    end
    local PC = UGCGameSystem.GetLocalPlayerController()
    local BagItems = EquipSlotSystem.CollectBagEquipItems(PC)
    self.BagCtrl:ReloadItems(BagItems)
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

function UGC_Equip_Basics_Main_UIBP:InitData(InParams)
    self.InParams = InParams or {}
    self:Refresh()
end

function UGC_Equip_Basics_Main_UIBP:Destruct()
    self:UnbindSlotLevelAttrs()
    if self.BagCtrl then
        self.BagCtrl:Clear()
    end
    self.InParams = nil
    self.StrengthenWidget = nil
    self.bClickBound = false
    self.SlotCtrls = {}
    self.BagCtrl = nil
    self.bInitDoOnce = false
end

return UGC_Equip_Basics_Main_UIBP
