---@class Game_Equip_AffixsBar_Item_UIBP_C:UAEUserWidget
---@field ReuseList2_Star ReuseList2_C
---@field FittingName FText
--Edit Below--
---词缀条单元（项目副本 Game_Equip_AffixsBar_Item_UIBP）：最小骨架。
---说明：引擎原资产 UGC_Equip_AffixsBar_Item_UIBP 会被引擎按类名自动绑定 LostTombAffixsBar
---（报 ReuseList2 nil）；副本换了项目类名，不再命中那次误绑定。
local Game_Equip_AffixsBar_Item_UIBP = {
    bInitDoOnce = false,
}

--构造函数，UI创建时自动调用
function Game_Equip_AffixsBar_Item_UIBP:Construct()
    self:LuaInit()
end

function Game_Equip_AffixsBar_Item_UIBP:LuaInit()
    if self.bInitDoOnce then
        return
    end
    self.bInitDoOnce = true
end

function Game_Equip_AffixsBar_Item_UIBP:InitData(InParams)
    self.InParams = InParams or {}
end

--析构函数，UI销毁时自动调用
function Game_Equip_AffixsBar_Item_UIBP:Destruct()
    self.InParams = nil
    self.bInitDoOnce = false
end

return Game_Equip_AffixsBar_Item_UIBP
