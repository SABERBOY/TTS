---@class Game_Equip_Item_UIBP_C:UAEUserWidget
---@field Common_DragDrop_Item_Drag Common_DragDrop_Item_C
---@field Common_DragDrop_Item_Drop Common_DragDrop_Item_C
---@field HorizontalBox_Bullet UHorizontalBox
---@field Image_HighLight UImage
---@field Image_QualityBar UImage
---@field Image_Select UImage
---@field Image_Weaponcucoloris UImage
---@field TextBlock_Grade UTextBlock
---@field TextBlock_Num UTextBlock
---@field TextBlock_TypeName UTextBlock
---@field UGC_Equip_AffixsBar_Item_UIBP Game_Equip_AffixsBar_Item_UIBP_C
--Edit Below--
---武器/大件装备格子（项目副本 Game_Equip_Item_UIBP）：最小骨架。
---目前 Basics 的 Equipment_Slot_8/9 只用它显示，无额外逻辑；后续要在这里补 UI 行为。
local Game_Equip_Item_UIBP = {
    bInitDoOnce = false,
}

--构造函数，UI创建时自动调用
function Game_Equip_Item_UIBP:Construct()
    self:LuaInit()
end

function Game_Equip_Item_UIBP:LuaInit()
    if self.bInitDoOnce then
        return
    end
    self.bInitDoOnce = true
end

function Game_Equip_Item_UIBP:InitData(InParams)
    self.InParams = InParams or {}
end

--析构函数，UI销毁时自动调用
function Game_Equip_Item_UIBP:Destruct()
    self.InParams = nil
    self.bInitDoOnce = false
end

return Game_Equip_Item_UIBP
