---@class Game_Equip_Grade_Item_UIBP_C:UAEUserWidget
---@field Image_Bg UImage
---@field CanvasPanel_Icon UCanvasPanel
---@field Equip_Icon_Item Game_Equip_Icon_Item_UIBP_C
---@field TextBlock_IconName UTextBlock
---@field TextBlock_Num UTextBlock
---@field TextBlock_Part UTextBlock
---@field TextBlock_Profession UTextBlock
---@field TextBlock_Value UTextBlock
---@field WidgetSwitcher_Lock UWidgetSwitcher
---@field Image_Lock UImage
---@field Image_UnLock UImage
--Edit Below--
---强化页顶部装备卡片（项目副本 Game_Equip_Grade_Item_UIBP）：
---  自己负责标题/等级/属性类型/品质品阶文案/属性增量的显示，以及内嵌图标的刷新；
---  调用方只准备数据表，不再逐字段操作。
local Game_Equip_Grade_Item_UIBP = {
    bInitDoOnce = false,
}

--构造函数，UI创建时自动调用
function Game_Equip_Grade_Item_UIBP:Construct()
    self:LuaInit()
end

function Game_Equip_Grade_Item_UIBP:LuaInit()
    if self.bInitDoOnce then
        return
    end
    self.bInitDoOnce = true
end

function Game_Equip_Grade_Item_UIBP:InitData(InParams)
    self.InParams = InParams or {}
end

---取内嵌图标单元（Game_Equip_Icon_Item_UIBP）
function Game_Equip_Grade_Item_UIBP:GetIcon()
    return self.Equip_Icon_Item
end

---@param Info table {
---  Title: string 标题（装备名或槽位名）,
---  Level: number 槽位等级,
---  Part: string 属性类型（攻击/生命值上限）,
---  Profession: string 品质·品阶上限文案,
---  Value: string 属性增量文案（+A → +B）,
---  ItemID/DefineID/IconLevel/EmptyName/bEquipped: 透传给内嵌图标
---}
function Game_Equip_Grade_Item_UIBP:ApplyData(Info)
    Info = Info or {}
    if self.TextBlock_IconName and Info.Title then
        self.TextBlock_IconName:SetText(Info.Title)
    end
    if self.TextBlock_Num then
        self.TextBlock_Num:SetText('Lv.' .. tostring(Info.Level or 0))
    end
    if self.TextBlock_Part and Info.Part then
        self.TextBlock_Part:SetText(Info.Part)
    end
    if self.TextBlock_Profession and Info.Profession then
        self.TextBlock_Profession:SetText(Info.Profession)
    end
    if self.TextBlock_Value and Info.Value then
        self.TextBlock_Value:SetText(Info.Value)
    end
    local Icon = self.Equip_Icon_Item
    if Icon and Icon.ApplyData then
        Icon:ApplyData(Info.ItemID, Info.IconLevel or Info.Level or 0,
            Info.EmptyName or '', Info.bEquipped == true, Info.DefineID)
    end
    self.Data = Info
end

--析构函数，UI销毁时自动调用
function Game_Equip_Grade_Item_UIBP:Destruct()
    self.Data = nil
    self.InParams = nil
    self.bInitDoOnce = false
end

return Game_Equip_Grade_Item_UIBP
