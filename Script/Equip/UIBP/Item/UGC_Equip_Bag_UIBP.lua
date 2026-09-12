---@class UGC_Equip_Bag_UIBP_C:UAEUserWidget
---@field CanvasPanel_BagInfo UCanvasPanel
---@field Common_DragDrop_Item Common_DragDrop_Item_C
---@field Image_bg UImage
---@field Image_HighLight_Bag UImage
---@field Image_Select UImage
---@field NewButton_Expansion UNewButton
---@field NewButton_mask UNewButton
---@field ReuseList_Bag ReuseList2_C
---@field TextBlock_Sorting UTextBlock
--Edit Below--
-- 引擎 Prefab /Game/UGC/UITemplate/.../UGC_Equip_Bag_UIBP 无项目 Lua 绑定。
-- New(bagWidget, owner) 返回包装实例；冒号方法处理列表。
local EquipSlotSystem = require('Script.Common.EquipSlotSystem')
local EquipIconItem = require('Script.Equip.UIBP.Item.UGC_Equip_Icon_Item_UIBP')

local UGC_Equip_Bag_UIBP = {}

local ControllerCache = setmetatable({}, { __mode = 'k' })

local function ResolveBag(Controller)
    local Weak = Controller and Controller.__bag
    if not Weak then
        return nil
    end
    local OK, Bag = pcall(function()
        if not Weak:IsValid() then
            return nil
        end
        local W = Weak:Get()
        if not W or not UE.IsValid(W) then
            return nil
        end
        return W
    end)
    if OK then
        return Bag
    end
    return nil
end

local function ResolveOwner(Controller)
    local Weak = Controller and Controller.__owner
    if not Weak then
        return nil
    end
    local OK, Owner = pcall(function()
        if not Weak:IsValid() then
            return nil
        end
        return Weak:Get()
    end)
    if OK then
        return Owner
    end
    return nil
end

local META = {
    __index = function(Controller, Key)
        local Method = UGC_Equip_Bag_UIBP[Key]
        if Method ~= nil then
            return Method
        end
        local Bag = ResolveBag(Controller)
        if not Bag then
            return nil
        end
        local OK, Value = pcall(function()
            return Bag[Key]
        end)
        if OK then
            return Value
        end
        return nil
    end,
    __newindex = function(Controller, Key, Value)
        rawset(Controller, Key, Value)
    end,
}

function UGC_Equip_Bag_UIBP.New(BagWidget, Owner)
    if not BagWidget then
        print('[EquipBag] New 失败：背包子面板为空')
        return nil
    end
    local Cached = ControllerCache[BagWidget]
    if Cached then
        Cached.__owner = WeakObjectPtr(Owner)
        return Cached
    end
    local Controller = {
        __bag = WeakObjectPtr(BagWidget),
        __owner = WeakObjectPtr(Owner),
        bListBound = false,
        bItemClassRequested = false,
        BagItems = {},
        BagClickData = {},
        BagClickBound = {},
    }
    setmetatable(Controller, META)
    ControllerCache[BagWidget] = Controller
    return Controller
end

function UGC_Equip_Bag_UIBP:GetWidget()
    return ResolveBag(self)
end

function UGC_Equip_Bag_UIBP:GetList()
    local Bag = ResolveBag(self)
    if not Bag then
        return nil
    end
    return Bag.ReuseList_Bag
end

function UGC_Equip_Bag_UIBP:SetSortingText(Text)
    local Bag = ResolveBag(self)
    if Bag and CheckObjectContainsField(Bag, 'TextBlock_Sorting', true) and Bag.TextBlock_Sorting then
        Bag.TextBlock_Sorting:SetText(Text or '')
    end
end

function UGC_Equip_Bag_UIBP:EnsureListBound()
    if self.bListBound then
        return true
    end
    local List = self:GetList()
    if not List then
        return false
    end
    local OK, Err = pcall(function()
        List.OnUpdateItem:Add(self.OnUpdateItem, self)
    end)
    if not OK then
        print('[EquipBag] list bind failed ' .. tostring(Err))
        return false
    end
    self.bListBound = true
    print('[EquipBag] ReuseList_Bag bound')
    self:EnsureItemClass()
    return true
end

function UGC_Equip_Bag_UIBP:UnbindList()
    local List = self:GetList()
    if List and self.bListBound then
        pcall(function()
            List.OnUpdateItem:Remove(self.OnUpdateItem, self)
        end)
    end
    self.bListBound = false
end

function UGC_Equip_Bag_UIBP:EnsureItemClass()
    if self.bItemClassRequested then
        return
    end
    local List = self:GetList()
    if not List or List.ItemClass then
        return
    end
    local ClassPath = EquipIconItem.CLASS_PATH
    if not ClassPath or ClassPath == '' then
        return
    end
    local Bag = ResolveBag(self)
    if not Bag then
        return
    end
    self.bItemClassRequested = true
    local WeakBag = WeakObjectPtr(Bag)
    local Owner = ResolveOwner(self)
    local WeakOwner = Owner and WeakObjectPtr(Owner)
    print('[EquipBag] ItemClass 未加载，异步兜底 ' .. tostring(ClassPath))
    UGCObjectUtility.AsyncLoadClass(ClassPath, function(LoadedClass)
        if not WeakBag:IsValid() then
            return
        end
        local BagRef = WeakBag:Get()
        local CtrlRef = BagRef and ControllerCache[BagRef]
        if not CtrlRef then
            return
        end
        local CurList = CtrlRef:GetList()
        if not CurList or not LoadedClass then
            print('[EquipBag] ItemClass 兜底加载失败')
            return
        end
        pcall(function()
            CurList:SetItemClass(LoadedClass)
        end)
        print('[EquipBag] ItemClass 兜底加载完成')
        if WeakOwner and WeakOwner:IsValid() then
            local OwnerRef = WeakOwner:Get()
            if OwnerRef and OwnerRef.RefreshBagList then
                OwnerRef:RefreshBagList()
            end
        end
    end)
end

function UGC_Equip_Bag_UIBP:SetBagClickData(Widget, Data)
    if not Widget then
        return
    end
    self.BagClickData = self.BagClickData or {}
    self.BagClickData[tostring(Widget)] = Data
end

function UGC_Equip_Bag_UIBP:BindItemClick(Widget, Data)
    if not Widget or not Data then
        return
    end
    local Key = tostring(Widget)
    self.BagClickBound = self.BagClickBound or {}
    self:SetBagClickData(Widget, Data)
    if self.BagClickBound[Key] then
        return
    end
    local DragDrop = Widget.Common_DragDrop_Item
    if not DragDrop then
        return
    end
    local Bag = ResolveBag(self)
    local WeakBag = Bag and WeakObjectPtr(Bag)
    local WeakWidget = WeakObjectPtr(Widget)
    local Owner = ResolveOwner(self)
    local WeakOwner = Owner and WeakObjectPtr(Owner)
    local OK = pcall(function()
        DragDrop.OnDragClicked:Add(function()
            if not WeakBag or not WeakBag:IsValid() or not WeakWidget:IsValid() then
                return
            end
            local BagRef = WeakBag:Get()
            local CtrlRef = BagRef and ControllerCache[BagRef]
            local ItemWidget = WeakWidget:Get()
            local OwnerRef = WeakOwner and WeakOwner:IsValid() and WeakOwner:Get() or nil
            local ClickData = CtrlRef and CtrlRef.BagClickData and CtrlRef.BagClickData[tostring(ItemWidget)]
            if not OwnerRef or not ClickData or not ClickData.SlotIdx then
                print('[EquipBag] bag item 无法映射到六槽，忽略')
                return
            end
            print(string.format('[EquipBag] bag click ItemID=%s SlotIdx=%s equipped=%s',
                tostring(ClickData.ItemID), tostring(ClickData.SlotIdx), tostring(ClickData.bEquipped)))
            if OwnerRef.OpenStrengthenPanel then
                OwnerRef:OpenStrengthenPanel(ClickData.SlotIdx)
            end
        end)
    end)
    if OK then
        self.BagClickBound[Key] = true
    end
end

function UGC_Equip_Bag_UIBP:OnUpdateItem(Widget, Index)
    if not Widget then
        return
    end
    local Data = self.BagItems and self.BagItems[Index + 1]
    if not Data then
        self:SetBagClickData(Widget, nil)
        return
    end
    local Owner = ResolveOwner(self)
    local SlotIdx = Data.SlotIdx
    local Level = 0
    if SlotIdx and Owner then
        local PlayerState = Owner.GetLocalPlayerState and Owner:GetLocalPlayerState()
        local PlayerPawn = Owner.GetLocalPlayerPawn and Owner:GetLocalPlayerPawn()
        Level = EquipSlotSystem.GetSlotLevel(PlayerState, SlotIdx, PlayerPawn)
    end
    local SlotDef = SlotIdx and EquipSlotSystem.GetSlotDef(SlotIdx) or nil
    local Cell = EquipIconItem.New(Widget)
    if Cell then
        Cell:ApplyData(Data.ItemID, Level, SlotDef and SlotDef.Name or '', Data.bEquipped, Data.DefineID)
    end
    self:BindItemClick(Widget, Data)
end

function UGC_Equip_Bag_UIBP:ReloadItems(BagItems)
    local Bag = ResolveBag(self)
    if not Bag then
        return false
    end
    self:EnsureListBound()
    self:EnsureItemClass()
    self:SetSortingText('装备')

    self.BagItems = BagItems or {}
    local List = self:GetList()
    if not List then
        if CheckObjectContainsField(Bag, 'RefreshBagData', true) then
            Bag:RefreshBagData()
        elseif CheckObjectContainsField(Bag, 'Refresh', true) then
            Bag:Refresh()
        end
        return false
    end

    local Count = #self.BagItems
    local OK, Err = pcall(function()
        List:Reload(Count)
    end)
    if not OK then
        print('[EquipBag] Reload failed ' .. tostring(Err))
        return false
    end
    pcall(function()
        List:Refresh()
    end)
    print('[EquipBag] Reload count=' .. tostring(Count))
    return true
end

function UGC_Equip_Bag_UIBP:Clear()
    self:UnbindList()
    local List = self:GetList()
    if List then
        pcall(function()
            List:Reload(0)
        end)
    end
    self.bItemClassRequested = false
    self.BagItems = {}
    self.BagClickData = {}
    self.BagClickBound = {}
end

return UGC_Equip_Bag_UIBP
