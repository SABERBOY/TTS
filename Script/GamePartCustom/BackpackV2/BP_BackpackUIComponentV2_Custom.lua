---@class BP_BackpackUIComponentV2_Custom_C:BP_BackpackUIComponentV2_C
--Edit Below--
local BP_BackpackUIComponentV2_Custom = {}
local EquipSlotAttrApplier = require('Script.Common.EquipSlotAttrApplier')

local COMMON_PREFIX = "EquipmentSlot.Common."
local DETAIL_WIDGET_PATH = "Asset/Blueprint/Prefabs/UI/Equip/UIBP/Game_ItemDetail_UIBP.Game_ItemDetail_UIBP_C"
local EQUIP_PANEL_PATH = "/Game/UGC/UITemplate/Asset/Backpack/Arts_UI/UIBP/UGC_Backpack_OpenAPI/UGC_WeaponEquip_Open_UIBP.UGC_WeaponEquip_Open_UIBP_C"
local SLOT_WIDGET_PATHS = {
    "/Game/UGC/UITemplate/Asset/Backpack/Arts_UI/UIBP/UGC_Backpack_OpenAPI/UGC_BodyEquipSlot_Open_UIBP.UGC_BodyEquipSlot_Open_UIBP_C",
    "/Game/UGC/UITemplate/Asset/Backpack/Arts_UI/UIBP/Equip/Item/Depot_EquipType_02_UIBP.Depot_EquipType_02_UIBP_C",
}

local function IsCommonEquipSlot(SlotName)
    return type(SlotName) == "string" and string.sub(SlotName, 1, #COMMON_PREFIX) == COMMON_PREFIX
end

local function GetDefineItemID(ItemDefineID)
    if ItemDefineID == nil then
        return nil
    end
    if type(ItemDefineID) == "number" and ItemDefineID ~= 0 then
        return ItemDefineID
    end
    local Ok, Value = pcall(function()
        return ItemDefineID.TypeSpecificID
    end)
    if Ok and type(Value) == "number" and Value ~= 0 then
        return Value
    end
    return nil
end

local function IsValidDefineID(ItemDefineID)
    return GetDefineItemID(ItemDefineID) ~= nil
end

local function ExtractSlotInfo(Widget, ...)
    local SlotName, ItemDefineID, ItemID
    if Widget then
        local Ok, Value = pcall(function() return Widget.SlotName end)
        if Ok and type(Value) == "string" then
            SlotName = Value
        end
        Ok, Value = pcall(function() return Widget.ItemDefineID end)
        if Ok and Value ~= nil then
            ItemDefineID = Value
        end
        Ok, Value = pcall(function() return Widget.ItemID end)
        if Ok and type(Value) == "number" and Value ~= 0 then
            ItemID = Value
        end
        local Data = nil
        Ok, Data = pcall(function() return Widget.data end)
        if Ok and type(Data) == "table" then
            SlotName = SlotName or Data.SlotName
            ItemDefineID = ItemDefineID or Data.ItemDefineID or Data.DefineID
            if type(Data.ItemID) == "number" and Data.ItemID ~= 0 then
                ItemID = ItemID or Data.ItemID
            end
        end
    end
    local Count = select("#", ...)
    for i = 1, Count do
        local Arg = select(i, ...)
        if type(Arg) == "string" and string.find(Arg, "EquipmentSlot", 1, true) then
            SlotName = Arg
        elseif type(Arg) == "number" and Arg ~= 0 then
            ItemID = ItemID or Arg
        elseif type(Arg) == "table" then
            SlotName = SlotName or Arg.SlotName
            ItemDefineID = ItemDefineID or Arg.ItemDefineID or Arg.DefineID
            if type(Arg.ItemID) == "number" and Arg.ItemID ~= 0 then
                ItemID = ItemID or Arg.ItemID
            end
        end
    end
    ItemID = ItemID or GetDefineItemID(ItemDefineID)
    return SlotName, ItemDefineID, ItemID
end

local function SlotNameToString(SlotName)
    if type(SlotName) == "string" then
        return SlotName
    end
    local Ok, Name = pcall(function()
        return SlotName.TagName
    end)
    if Ok and type(Name) == "string" and Name ~= "" then
        return Name
    end
    return nil
end

function BP_BackpackUIComponentV2_Custom:BindEquipChangeDelegates()
    if self.__TTYEquipChangeBound then
        return
    end
    local PC = UGCGameSystem.GetLocalPlayerController()
    if not PC then
        return
    end
    local Comp = UGCBackpackSystemV2.GetBackpackComponentV2(PC)
    if not Comp then
        return
    end
    local Owner = self
    local Ok, Delegate = pcall(function()
        return Comp:GetItemAttachParentChangeDelegateV2()
    end)
    if Ok and Delegate and Delegate.Add then
        Delegate:Add(function(...)
            local SlotName
            local Count = select("#", ...)
            for i = 1, Count do
                local Arg = select(i, ...)
                if type(Arg) == "string" and string.find(Arg, "EquipmentSlot", 1, true) then
                    SlotName = Arg
                    break
                end
                SlotName = SlotName or SlotNameToString(Arg)
            end
            print(string.format("[EquipRefresh] AttachParent argc=%d SlotName=%s", Count, tostring(SlotName)))
            Owner:OnEquipSlotChanged(SlotName)

            -- 服务端：装备槽位变化后重算槽位强化属性加成
            if UGCGameSystem.IsServer() then
                local Pawn = PC and PC:GetPlayerCharacterSafety() or nil
                if Pawn then
                    EquipSlotAttrApplier.OnEquipChanged(Pawn, SlotName)
                end
            end
        end, self)
        self.__TTYEquipChangeBound = true
        print("[EquipRefresh] bound ItemAttachParentChangeDelegateV2")
    else
        print("[EquipRefresh] GetItemAttachParentChangeDelegateV2 failed")
    end
end

function BP_BackpackUIComponentV2_Custom:ApplyItemDetail(Widget, ItemDefineID, ItemID)
    if not Widget then
        return
    end
    local Owner = self
    local ResolvedItemID = ItemID or GetDefineItemID(ItemDefineID)
    if not UGCWidgetUtility.IsWidgetAddedToSlot(Widget) then
        UGCWidgetUtility.AddToSlot(Widget, "UI.UISlot.MainUISlot_High", 200)
    end
    UGCWidgetUtility.ShowWidget(Widget)
    local Ok, Err = pcall(function()
        Widget:InitData({
            ItemData = {
                ItemDefineID = ItemDefineID,
                ItemID = ResolvedItemID,
                ItemCount = 1,
            },
            CloseCallback = function()
                Owner:HideCommonEquipDetail()
            end,
        })
    end)
    if not Ok then
        print("[EquipClick] UGC_ItemDetail InitData error=" .. tostring(Err))
        return
    end
    print(string.format("[EquipClick] UGC_ItemDetail InitData ok ItemID=%s", tostring(ResolvedItemID)))
end

function BP_BackpackUIComponentV2_Custom:ShowCommonEquipDetail(SlotName, ItemDefineID, ItemID)
    self.CurrentDetailSlotName = SlotName
    if self.EquipDetailWidget then
        self:ApplyItemDetail(self.EquipDetailWidget, ItemDefineID, ItemID)
        return
    end
    local Path = UGCGameSystem.GetUGCResourcesFullPath(DETAIL_WIDGET_PATH)
    local Owner = self
    UGCWidgetUtility.CreateWidgetAsync(Path, function(Widget)
        if not Widget then
            print("[EquipClick] failed to create Game_ItemDetail_UIBP")
            return
        end
        Owner.EquipDetailWidget = Widget
        Owner:ApplyItemDetail(Widget, ItemDefineID, ItemID)
    end)
end

function BP_BackpackUIComponentV2_Custom:HideCommonEquipDetail()
    self.CurrentDetailSlotName = nil
    if self.EquipDetailWidget then
        UGCWidgetUtility.HideWidget(self.EquipDetailWidget)
    end
end

function BP_BackpackUIComponentV2_Custom:RefreshEquipPanelData()
    local WidgetClass = UE.LoadClass(EQUIP_PANEL_PATH)
    if not WidgetClass then
        print("[EquipRefresh] LoadClass Open panel failed")
        return
    end
    local Widgets = UGCWidgetUtility.GetAllWidgetsOfClass(WidgetClass, false) or {}
    print("[EquipRefresh] RefreshEquipData count=" .. tostring(#Widgets))
    for _, Widget in ipairs(Widgets) do
        local Ok, Err = pcall(function()
            Widget:RefreshEquipData()
        end)
        if not Ok then
            print("[EquipRefresh] RefreshEquipData error=" .. tostring(Err))
        end
    end
end

function BP_BackpackUIComponentV2_Custom:RefreshCommonEquipDetail(SlotName)
    if not self.EquipDetailWidget or not self.CurrentDetailSlotName then
        return
    end
    if SlotName and self.CurrentDetailSlotName ~= SlotName then
        return
    end
    local PC = UGCGameSystem.GetLocalPlayerController()
    local DefineID = nil
    if PC then
        DefineID = UGCBackpackSystemV2.GetEquippedItemBySlotName(PC, self.CurrentDetailSlotName)
    end
    if IsValidDefineID(DefineID) then
        self:ApplyItemDetail(self.EquipDetailWidget, DefineID, GetDefineItemID(DefineID))
    else
        self:HideCommonEquipDetail()
    end
end

function BP_BackpackUIComponentV2_Custom:FlushEquipSlotRefresh()
    self.EquipRefreshTimer = nil
    local SlotName = self.PendingEquipRefreshSlot
    self.PendingEquipRefreshSlot = nil
    print("[EquipRefresh] flush SlotName=" .. tostring(SlotName))
    self:RefreshEquipPanelData()
    self:HookCommonEquipSlotClicks()
    self:RefreshCommonEquipDetail(SlotName)
end

function BP_BackpackUIComponentV2_Custom:OnEquipSlotChanged(SlotName)
    self.PendingEquipRefreshSlot = SlotName or self.PendingEquipRefreshSlot
    if self.EquipRefreshTimer then
        UGCGameSystem.ClearTimer(self, self.EquipRefreshTimer)
        self.EquipRefreshTimer = nil
    end
    self.EquipRefreshTimer = UGCGameSystem.SetTimer(self, function()
        self:FlushEquipSlotRefresh()
    end, 0.05, false)
end

function BP_BackpackUIComponentV2_Custom:WrapCommonEquipClick(Widget)
    if not Widget or Widget.__TTYEquipClickWrapped then
        return
    end
    Widget.__TTYEquipClickWrapped = true
    local Owner = self
    local function HandleClick(...)
        local SlotName, ItemDefineID, ItemID = ExtractSlotInfo(Widget, ...)
        print(string.format("[EquipClick] SlotName=%s HasDefineID=%s ItemID=%s", tostring(SlotName), tostring(ItemDefineID ~= nil), tostring(ItemID)))
        if not IsCommonEquipSlot(SlotName) then
            return false
        end
        local DefineID = ItemDefineID
        if not IsValidDefineID(DefineID) then
            local PC = UGCGameSystem.GetLocalPlayerController()
            if PC then
                DefineID = UGCBackpackSystemV2.GetEquippedItemBySlotName(PC, SlotName)
            end
        end
        ItemID = ItemID or GetDefineItemID(DefineID)
        if IsValidDefineID(DefineID) or ItemID then
            Owner:ShowCommonEquipDetail(SlotName, DefineID, ItemID)
        else
            print("[EquipClick] common slot empty, skip panel")
        end
        return true
    end

    local function WrapCallback(Old)
        return function(...)
            if HandleClick(...) then
                return
            end
            if Old then
                return Old(...)
            end
        end
    end

    local Ok, Data = pcall(function() return Widget.data end)
    if Ok and type(Data) == "table" then
        Data.OnClickCallback = WrapCallback(Data.OnClickCallback)
        if not Widget.__TTYEquipDragWrapped then
            Widget.__TTYEquipDragWrapped = true
            local OldDragCancel = Data.OnDragCanceledCallback
            Data.OnDragCanceledCallback = function(...)
                if OldDragCancel then
                    OldDragCancel(...)
                end
                Owner:OnEquipSlotChanged(ExtractSlotInfo(Widget, ...))
            end
        end
    end
    Ok, Data = pcall(function() return Widget.OnClickCallback end)
    if Ok then
        pcall(function()
            Widget.OnClickCallback = WrapCallback(Data)
        end)
    end

    local OldInit = Widget.InitData
    if type(OldInit) == "function" then
        Widget.InitData = function(W, InData, ...)
            if type(InData) == "table" then
                InData.OnClickCallback = WrapCallback(InData.OnClickCallback)
                local OldDragCancel = InData.OnDragCanceledCallback
                InData.OnDragCanceledCallback = function(...)
                    if OldDragCancel then
                        OldDragCancel(...)
                    end
                    Owner:OnEquipSlotChanged(ExtractSlotInfo(W, ...))
                end
            end
            return OldInit(W, InData, ...)
        end
    end
end

function BP_BackpackUIComponentV2_Custom:HookCommonEquipSlotClicks()
    self:BindEquipChangeDelegates()
    for _, Path in ipairs(SLOT_WIDGET_PATHS) do
        local WidgetClass = UE.LoadClass(Path)
        if WidgetClass then
            local Widgets = UGCWidgetUtility.GetAllWidgetsOfClass(WidgetClass, false) or {}
            print(string.format("[EquipClick] wrap class=%s count=%s", Path, tostring(#Widgets)))
            for _, Widget in ipairs(Widgets) do
                self:WrapCommonEquipClick(Widget)
            end
        else
            print("[EquipClick] LoadClass failed: " .. Path)
        end
    end
end

---开始运行时执行
function BP_BackpackUIComponentV2_Custom:ReceiveBeginPlay()
    BP_BackpackUIComponentV2_Custom.SuperClass.ReceiveBeginPlay(self)
    self:BindEquipChangeDelegates()
    -- 服务端：玩家进入后绑定槽位强化属性应用
    if UGCGameSystem.IsServer() then
        local PC = UGCGameSystem.GetLocalPlayerController()
        local Pawn = PC and PC:GetPlayerCharacterSafety() or nil
        if Pawn then
            EquipSlotAttrApplier.BindPlayer(Pawn)
        end
    end
end

---结束运行时执行
function BP_BackpackUIComponentV2_Custom:ReceiveEndPlay()
    self.bBackpackOpen = false
    if self.EquipRefreshTimer then
        UGCGameSystem.ClearTimer(self, self.EquipRefreshTimer)
        self.EquipRefreshTimer = nil
    end
    self:HideCommonEquipDetail()
    if UGCGameSystem.IsServer() then
        local PC = UGCGameSystem.GetLocalPlayerController()
        local Pawn = PC and PC:GetPlayerCharacterSafety() or nil
        if Pawn then
            EquipSlotAttrApplier.UnbindPlayer(Pawn)
        end
    end
    BP_BackpackUIComponentV2_Custom.SuperClass.ReceiveEndPlay(self)
end

---点击上锁格子后回调(ClickLockBackpackItem重写后不执行)
---@param Panel UUserWidget @弹窗面板，取自ClickLockBackpackItem返回值，可能为nil
-- function BP_BackpackUIComponentV2_Custom:OnClickLockBackpackItem(Panel)
-- end

---是否显示丢弃区域
---生效范围：客户端
---@return boolean @是否显示丢弃区域
-- function BP_BackpackUIComponentV2_Custom:IsDiscardAreaVisible()
-- end

---获取RPC列表 (注意不要使用GetAvailableServerRPCs)
---@return table @RPC函数名列表
-- function BP_BackpackUIComponentV2_Custom:GetUGCAvailableServerRPCs()
--     return {}
-- end

---默认排序函数, 组件上配置
---生效范围: 客户端
---@param Data1 table @物品数据1 {DefineID:物品DefineID, Idx:格子索引}
---@param Data2 table @物品数据2 {DefineID:物品DefineID, Idx:格子索引}
---@return boolean @true:物品1在前, false:物品2在前
-- function BP_BackpackUIComponentV2_Custom.CompareQuality(Data1,Data2)
-- end

---获取背包拖拽控件类
---生效范围：客户端
---@return FSoftClassPath|nil @拖拽控件类，未配置则返回nil
-- function BP_BackpackUIComponentV2_Custom:GetBackpackDragDropWidget()
-- end

---背包UI打开后执行
---@param Panel UUserWidget @背包主界面控件
function BP_BackpackUIComponentV2_Custom:OnOpenBattleMainPanel(Panel)
    self.bBackpackOpen = true
    self:HookCommonEquipSlotClicks()
end

---背包UI关闭后执行
---@param Panel UUserWidget @背包主界面控件
function BP_BackpackUIComponentV2_Custom:OnCloseBattleMainPanel(Panel)
    self.bBackpackOpen = false
    if self.EquipRefreshTimer then
        UGCGameSystem.ClearTimer(self, self.EquipRefreshTimer)
        self.EquipRefreshTimer = nil
    end
    self:HideCommonEquipDetail()
end

---打开大厅背包界面(已废弃)
---生效范围：客户端
---@param Mode number @1:背包+装备栏 2:背包+仓库 3:背包+装备栏+仓库
-- function BP_BackpackUIComponentV2_Custom:OpenLobbyBackpackMainUI(Mode)
-- end

---关闭大厅背包界面(已废弃)
---生效范围：客户端
-- function BP_BackpackUIComponentV2_Custom:CloseLobbyPanel()
-- end

---当打开删除弹窗时调用
---@param Panel UUserWidget @面板控件
-- function BP_BackpackUIComponentV2_Custom:OnOpenDeletePanel(Panel)
-- end

---当打开存入取出代币时调用
---@param Panel UUserWidget @面板控件
-- function BP_BackpackUIComponentV2_Custom:OnOpenSaveOrWithDrawPanel(Panel)
-- end

---当打开丢弃物品弹窗时调用
---@param Panel UUserWidget @面板控件
-- function BP_BackpackUIComponentV2_Custom:OnOpenDropItemPanel(Panel)
-- end

return BP_BackpackUIComponentV2_Custom