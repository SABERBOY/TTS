---@class PassiveSkill_SoulBurning_C:PESkillPassiveSkillTemplate_C
--Edit Below--
local PassiveSkill_SoulBurning = {}
 
function PassiveSkill_SoulBurning:OnEnableSkill_BP()
    PassiveSkill_SoulBurning.SuperClass.OnEnableSkill_BP(self)
end

function PassiveSkill_SoulBurning:OnDisableSkill_BP()
    PassiveSkill_SoulBurning.SuperClass.OnDisableSkill_BP(self)
end

function PassiveSkill_SoulBurning:OnActivateSkill_BP()
    PassiveSkill_SoulBurning.SuperClass.OnActivateSkill_BP(self)
end

function PassiveSkill_SoulBurning:OnDeActivateSkill_BP()
    PassiveSkill_SoulBurning.SuperClass.OnDeActivateSkill_BP(self)
end

function PassiveSkill_SoulBurning:CanActivateSkill_BP()
    return PassiveSkill_SoulBurning.SuperClass.CanActivateSkill_BP(self)
end

return PassiveSkill_SoulBurning