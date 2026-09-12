---@class Game_Equip_Bag_UIBP_C:UAEUserWidget
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
---背包装备列表子面板（项目副本 Game_Equip_Bag_UIBP）：
---  引擎按资产路径自动绑定本 Lua 类，self 就是控件本身；
---  列表刷新/格子复用/点击全部由本类的冒号实例方法处理。
---  Owner（装备主面板，用于取槽位等级与打开强化页）通过 InitData({Owner = ...}) 注入。
local EquipSlotSystem = require('Script.Common.EquipSlotSystem')

local Game_Equip_Bag_UIBP = {
    bInitDoOnce = false,
    bListBound = false,
    Owner = nil,
    BagItems = {},
    BagClickData = {},
    BagClickBound = {},
}

--构造函数，UI创建时自动调用
function Game_Equip_Bag_UIBP:Construct()
    self:LuaInit()
end

function Game_Equip_Bag_UIBP:LuaInit()
    if self.bInitDoOnce then
        return
    end
    self.bInitDoOnce = true
end

---@param InParams table {Owner: 装备主面板控件}
function Game_Equip_Bag_UIBP:InitData(InParams)
    InParams = InParams or {}
    self.Owner = InParams.Owner
    self:EnsureListBound()
end

function Game_Equip_Bag_UIBP:GetOwner()
    local Owner = self.Owner
    if Owner and UE.IsValid(Owner) then
        return Owner
    end
    return nil
end

function Game_Equip_Bag_UIBP:GetList()
    return self.ReuseList_Bag
end

function Game_Equip_Bag_UIBP:SetSortingText(Text)
    if self.TextBlock_Sorting then
        self.TextBlock_Sorting:SetText(Text or '')
    end
end

function Game_Equip_Bag_UIBP:EnsureListBound()
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

function Game_Equip_Bag_UIBP:UnbindList()
    local List = self:GetList()
    if List and self.bListBound then
        pcall(function()
            List.OnUpdateItem:Remove(self.OnUpdateItem, self)
        end)
    end
    self.bListBound = false
end

---列表格子类由预制体属性 ReuseList_Bag.ItemClass 指定，必须是 Game_Equip_Icon_Item_UIBP；
---这里只做体检提示，不再做异步兜底（副本资产在编辑器里直接改属性更可靠）。
function Game_Equip_Bag_UIBP:EnsureItemClass()
    local List = self:GetList()
    if not List then
        return
    end
    local ItemClass = nil
    pcall(function()
        ItemClass = List.ItemClass
    end)
    if not ItemClass then
        print('[EquipBag] 警告：ReuseList_Bag.ItemClass 为空，请在编辑器里指定 Game_Equip_Icon_Item_UIBP')
    end
end

function Game_Equip_Bag_UIBP:SetBagClickData(Widget, Data)
    if not Widget then
        return
    end
    self.BagClickData = self.BagClickData or {}
    self.BagClickData[tostring(Widget)] = Data
end

---背包格子点击：定位到对应槽位并打开强化页（强化对象是槽位）
function Game_Equip_Bag_UIBP:BindItemClick(Widget, Data)
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
    local WeakSelf = WeakObjectPtr(self)
    local WeakWidget = WeakObjectPtr(Widget)
    local OK = pcall(function()
        DragDrop.OnDragClicked:Add(function()
            if not WeakSelf:IsValid() or not WeakWidget:IsValid() then
                return
            end
            local SelfRef = WeakSelf:Get()
            local ItemWidget = WeakWidget:Get()
            local ClickData = SelfRef.BagClickData and SelfRef.BagClickData[tostring(ItemWidget)]
            if not ClickData or not ClickData.SlotIdx then
                print('[EquipBag] bag item 无法映射到六槽，忽略')
                return
            end
            print(string.format('[EquipBag] bag click ItemID=%s SlotIdx=%s equipped=%s',
                tostring(ClickData.ItemID), tostring(ClickData.SlotIdx), tostring(ClickData.bEquipped)))
            local Owner = SelfRef:GetOwner()
            if Owner and Owner.OpenStrengthenPanel then
                Owner:OpenStrengthenPanel(ClickData.SlotIdx)
            end
        end)
    end)
    if OK then
        self.BagClickBound[Key] = true
    end
end

---ReuseList 回调：Idx 从 0 开始
function Game_Equip_Bag_UIBP:OnUpdateItem(Widget, Index)
    if not Widget then
        return
    end
    local Data = self.BagItems and self.BagItems[Index + 1]
    if not Data then
        self:SetBagClickData(Widget, nil)
        return
    end
    local Owner = self:GetOwner()
    local SlotIdx = Data.SlotIdx
    local Level = 0
    if SlotIdx and Owner then
        local PlayerState = Owner.GetLocalPlayerState and Owner:GetLocalPlayerState()
        local PlayerPawn = Owner.GetLocalPlayerPawn and Owner:GetLocalPlayerPawn()
        Level = EquipSlotSystem.GetSlotLevel(PlayerState, SlotIdx, PlayerPawn)
    end
    local SlotDef = SlotIdx and EquipSlotSystem.GetSlotDef(SlotIdx) or nil
    -- 列表格子由 ItemClass（Game_Equip_Icon_Item_UIBP）实例化，直接走它的实例方法
    if Widget.ApplyData then
        Widget:ApplyData(Data.ItemID, Level, SlotDef and SlotDef.Name or '', Data.bEquipped, Data.DefineID)
    end
    self:BindItemClick(Widget, Data)
end

---@param BagItems table[] {ItemID, DefineID, SlotIdx, bEquipped}
function Game_Equip_Bag_UIBP:ReloadItems(BagItems)
    local List = self:GetList()
    if not List then
        return false
    end
    self:EnsureListBound()
    self:SetSortingText('装备')

    self.BagItems = BagItems or {}
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

function Game_Equip_Bag_UIBP:Clear()
    self:UnbindList()
    local List = self:GetList()
    if List then
        pcall(function()
            List:Reload(0)
        end)
    end
    self.BagItems = {}
    self.BagClickData = {}
    self.BagClickBound = {}
end

--析构函数，UI销毁时自动调用
function Game_Equip_Bag_UIBP:Destruct()
    self:Clear()
    self.Owner = nil
    self.bInitDoOnce = false
end

return Game_Equip_Bag_UIBP
