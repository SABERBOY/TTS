---@class PassiveSkill_HealingOrb_C:PESkillPassiveSkillTemplate_C
--Edit Below--
local PassiveSkill_HealingOrb = {}
 
function PassiveSkill_HealingOrb:OnEnableSkill_BP()
    PassiveSkill_HealingOrb.SuperClass.OnEnableSkill_BP(self)
end

function PassiveSkill_HealingOrb:OnDisableSkill_BP()
    PassiveSkill_HealingOrb.SuperClass.OnDisableSkill_BP(self)
end

function PassiveSkill_HealingOrb:OnActivateSkill_BP()
    PassiveSkill_HealingOrb.SuperClass.OnActivateSkill_BP(self)
end

function PassiveSkill_HealingOrb:OnDeActivateSkill_BP()
    PassiveSkill_HealingOrb.SuperClass.OnDeActivateSkill_BP(self)
end

function PassiveSkill_HealingOrb:CanActivateSkill_BP()
    return PassiveSkill_HealingOrb.SuperClass.CanActivateSkill_BP(self)
end

return PassiveSkill_HealingOrb