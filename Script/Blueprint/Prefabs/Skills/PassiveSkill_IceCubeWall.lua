---@class PassiveSkill_IceCubeWall_C:PESkillPassiveSkillTemplate_C
--Edit Below--
local PassiveSkill_IceCubeWall = {}
 
function PassiveSkill_IceCubeWall:OnEnableSkill_BP()
    PassiveSkill_IceCubeWall.SuperClass.OnEnableSkill_BP(self)
end

function PassiveSkill_IceCubeWall:OnDisableSkill_BP()
    PassiveSkill_IceCubeWall.SuperClass.OnDisableSkill_BP(self)
end

function PassiveSkill_IceCubeWall:OnActivateSkill_BP()
    PassiveSkill_IceCubeWall.SuperClass.OnActivateSkill_BP(self)
end

function PassiveSkill_IceCubeWall:OnDeActivateSkill_BP()
    PassiveSkill_IceCubeWall.SuperClass.OnDeActivateSkill_BP(self)
end

function PassiveSkill_IceCubeWall:CanActivateSkill_BP()
    return PassiveSkill_IceCubeWall.SuperClass.CanActivateSkill_BP(self)
end

return PassiveSkill_IceCubeWall