---装备 UI 共用：槽位图标、背包列表、客户端换装委托
local EquipSlotSystem = require('Script.Common.EquipSlotSystem')

local EquipUIHelper = {}

local ICON_ITEM_CLASS_PATH = '/Game/UGC/UITemplate/Asset/Equip/UIBP/Item/UGC_Equip_Icon_Item_UIBP.UGC_Equip_Icon_Item_UIBP_C'

function EquipUIHelper.GetLocalPC()
    return UGCGameSystem.GetLocalPlayerController()
end

local function SoftPathToString(Path)
    if not Path then
        return nil
    end
    if type(Path) == 'string' then
        return Path ~= '' and Path or nil
    end
    local OK, Converted = pcall(function()
        return UGCObjectUtility.GetPathBySoftObjectPath(Path)
    end)
    if OK and type(Converted) == 'string' and Converted ~= '' and Converted ~= 'None' then
        return Converted
    end
    return nil
end

---异步把物品图标刷到 UImage 上
function EquipUIHelper.ApplyItemIcon(ImageWidget, ItemID)
    if not ImageWidget or not ItemID or ItemID == 0 then
        return
    end
    local OK, Path = pcall(function()
        return UGCItemSystemV2.GetItemIconTextureV2(ItemID)
    end)
    local PathStr = SoftPathToString(OK and Path or nil)
    if not PathStr then
        return
    end
    local WeakImage = WeakObjectPtr(ImageWidget)
    pcall(function()
        UGCObjectUtility.AsyncLoadObject(PathStr, function(LoadedTexture)
            if not WeakImage:IsValid() or not LoadedTexture then
                return
            end
            local Image = WeakImage:Get()
            if Image then
                pcall(function()
                    Image:SetBrushFromTexture(LoadedTexture, false)
                end)
            end
        end)
    end)
end

---刷新 UGC_Equip_Icon_Item_UIBP：空槽显示部位名，有装备显示图标+等级
---@param SlotWidget UUserWidget
---@param ItemID number|nil
---@param Level number|nil 槽位永久强化等级
---@param EmptyName string|nil 空槽显示名（如「头盔」）
---@param bEquipped boolean|nil 是否当前穿戴
function EquipUIHelper.ApplyIconItem(SlotWidget, ItemID, Level, EmptyName, bEquipped)
    if not SlotWidget then
        return
    end
    local HasItem = ItemID ~= nil and ItemID ~= 0
    if SlotWidget.TextBlock_Level then
        SlotWidget.TextBlock_Level:SetText('Lv.' .. tostring(Level or 0))
    end
    if SlotWidget.TextBlock_FittingName then
        if HasItem then
            local Name = ''
            pcall(function()
                Name = UGCItemSystemV2.GetItemNameV2(ItemID) or ''
            end)
            SlotWidget.TextBlock_FittingName:SetText(Name)
        else
            SlotWidget.TextBlock_FittingName:SetText(EmptyName or '')
        end
    end
    if SlotWidget.TextBlock_Using then
        if bEquipped then
            SlotWidget.TextBlock_Using:SetText('穿戴中')
            SlotWidget.TextBlock_Using:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
        else
            SlotWidget.TextBlock_Using:SetVisibility(ESlateVisibility.Collapsed)
        end
    end
    if SlotWidget.CanvasPanel_NotWornState then
        SlotWidget.CanvasPanel_NotWornState:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
    end
    if HasItem then
        EquipUIHelper.ApplyItemIcon(SlotWidget.Image_DefaultIcon, ItemID)
        if SlotWidget.Image_QualityBarBg then
            EquipUIHelper.ApplyItemIcon(SlotWidget.Image_QualityBarBg, ItemID)
        end
    end
    if SlotWidget.WidgetSwitcher_Content then
        pcall(function()
            SlotWidget.WidgetSwitcher_Content:SetActiveWidgetIndex(0)
        end)
    end
end

---读当前玩家某策划槽上的已装备 DefineID / ItemID
function EquipUIHelper.GetEquippedOnSlot(SlotIdx)
    local PC = EquipUIHelper.GetLocalPC()
    local SlotName = EquipSlotSystem.GetKernelSlotName(SlotIdx)
    if not PC or not SlotName then
        return nil, nil, SlotName
    end
    local OK, DefineID = pcall(function()
        return UGCBackpackSystemV2.GetEquippedItemBySlotName(PC, SlotName)
    end)
    if not OK then
        return nil, nil, SlotName
    end
    return DefineID, EquipSlotSystem.GetDefineItemID(DefineID), SlotName
end

local function CollectDefineIDs(IDs, Push)
    if type(IDs) == 'table' then
        for _, DefineID in pairs(IDs) do
            Push(DefineID)
        end
        return
    end
    if type(IDs) ~= 'userdata' then
        return
    end
    local Len = 0
    pcall(function() Len = #IDs end)
    if Len > 0 then
        for i = 1, Len do
            Push(IDs[i])
        end
        return
    end
    pcall(function()
        for _, DefineID in pairs(IDs) do
            Push(DefineID)
        end
    end)
end

---收集背包里可作为装备的物品（含已穿戴；已装备物品可能不占格子，需从槽位补入）
function EquipUIHelper.CollectBagEquipItems(PC)
    local Result = {}
    PC = PC or EquipUIHelper.GetLocalPC()
    if not PC then
        return Result
    end
    local Seen = {}
    local function KeyOf(DefineID, ItemID)
        local InstanceID = 0
        pcall(function() InstanceID = DefineID.InstanceID or 0 end)
        return tostring(ItemID) .. '_' .. tostring(InstanceID)
    end
    local function Push(DefineID, ForcedSlotName)
        local ItemID = EquipSlotSystem.GetDefineItemID(DefineID)
        if not ItemID then
            return
        end
        local Key = KeyOf(DefineID, ItemID)
        if Seen[Key] then
            return
        end
        -- IsItemEquipTarget 表示“物品自己是否带配件槽”，不能用来判断能否穿在身上
        local CanWear = ForcedSlotName ~= nil and ForcedSlotName ~= ''
        if not CanWear then
            pcall(function()
                CanWear = UGCBackpackSystemV2.CheckCanEquipItemToAnySlotV2(PC, ItemID) == true
            end)
        end
        if not CanWear then
            for _, KernelName in pairs(EquipSlotSystem.KernelSlotNames) do
                if KernelName then
                    local OKSlot = false
                    pcall(function()
                        OKSlot = UGCBackpackSystemV2.ItemCanEquipToSlot(PC, ItemID, KernelName) == true
                    end)
                    if OKSlot then
                        CanWear = true
                        break
                    end
                end
            end
        end
        if not CanWear then
            return
        end
        local SlotName = ForcedSlotName or ''
        if SlotName == '' then
            pcall(function()
                SlotName = UGCBackpackSystemV2.GetItemEquippingSlot(PC, DefineID) or ''
            end)
        end
        local SlotIdx = EquipSlotSystem.GetSlotIdxByKernelName(SlotName)
        if not SlotIdx then
            local TargetSlots
            pcall(function()
                TargetSlots = UGCItemSystemV2.GetEquipTargetSlots(ItemID)
            end)
            CollectDefineIDs(TargetSlots, function(Name)
                if not SlotIdx then
                    SlotIdx = EquipSlotSystem.GetSlotIdxByKernelName(Name)
                end
            end)
        end
        Seen[Key] = true
        Result[#Result + 1] = {
            DefineID = DefineID,
            ItemID = ItemID,
            SlotName = SlotName,
            SlotIdx = SlotIdx,
            bEquipped = SlotName ~= nil and SlotName ~= '',
        }
    end
    local OK, IDs = pcall(function()
        return UGCBackpackSystemV2.GetAllItemDefineIDsV2(PC)
    end)
    if OK then
        CollectDefineIDs(IDs, Push)
    end
    -- 已装备物品可能不在格子列表里，从内核槽补一份，保证右侧能点到头盔
    for SlotIdx, SlotName in pairs(EquipSlotSystem.KernelSlotNames) do
        if SlotName then
            local DefineID
            pcall(function()
                DefineID = UGCBackpackSystemV2.GetEquippedItemBySlotName(PC, SlotName)
            end)
            Push(DefineID, SlotName)
        end
    end
    return Result
end

---绑定客户端装备变化委托（DS 不广播，仅客户端 UI 用）
function EquipUIHelper.BindAttachChange(OwnerWidget, Callback)
    if not OwnerWidget or OwnerWidget.__EquipUIAttachBound then
        return
    end
    local PC = EquipUIHelper.GetLocalPC()
    if not PC then
        return
    end
    local Comp = UGCBackpackSystemV2.GetBackpackComponentV2(PC)
    if not Comp or not CheckObjectContainsField(Comp, 'GetItemAttachParentChangeDelegateV2', true) then
        return
    end
    local OK, Delegate = pcall(function()
        return Comp:GetItemAttachParentChangeDelegateV2()
    end)
    if not OK or not Delegate or not Delegate.Add then
        return
    end
    local WeakOwner = WeakObjectPtr(OwnerWidget)
    Delegate:Add(function(...)
        if not WeakOwner:IsValid() then
            return
        end
        local SelfRef = WeakOwner:Get()
        if SelfRef and Callback then
            Callback(SelfRef, ...)
        end
    end)
    OwnerWidget.__EquipUIAttachBound = true
    print('[EquipUI] bound ItemAttachParentChangeDelegateV2')
end

function EquipUIHelper.TryGetWidget(Owner, Name)
    if not Owner or not Name then
        return nil
    end
    if CheckObjectContainsField(Owner, Name, true) then
        return Owner[Name]
    end
    return nil
end

function EquipUIHelper.GetIconItemClassPath()
    return ICON_ITEM_CLASS_PATH
end

return EquipUIHelper
