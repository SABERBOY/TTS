---@class PassiveSkill_LifeSurge_C:PESkillPassiveSkillTemplate_C
--Edit Below--
local PassiveSkill_LifeSurge = {}
 
function PassiveSkill_LifeSurge:OnEnableSkill_BP()
    PassiveSkill_LifeSurge.SuperClass.OnEnableSkill_BP(self)
end

function PassiveSkill_LifeSurge:OnDisableSkill_BP()
    PassiveSkill_LifeSurge.SuperClass.OnDisableSkill_BP(self)
end

function PassiveSkill_LifeSurge:OnActivateSkill_BP()
    PassiveSkill_LifeSurge.SuperClass.OnActivateSkill_BP(self)
end

function PassiveSkill_LifeSurge:OnDeActivateSkill_BP()
    PassiveSkill_LifeSurge.SuperClass.OnDeActivateSkill_BP(self)
end

function PassiveSkill_LifeSurge:CanActivateSkill_BP()
    return PassiveSkill_LifeSurge.SuperClass.CanActivateSkill_BP(self)
end

return PassiveSkill_LifeSurge