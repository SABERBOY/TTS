---@class PassiveSkill_SprtintDefense_C:PESkillPassiveSkillTemplate_C
--Edit Below--
local PassiveSkill_SprtintDefense = {}
 
function PassiveSkill_SprtintDefense:OnEnableSkill_BP()
    PassiveSkill_SprtintDefense.SuperClass.OnEnableSkill_BP(self)
end

function PassiveSkill_SprtintDefense:OnDisableSkill_BP()
    PassiveSkill_SprtintDefense.SuperClass.OnDisableSkill_BP(self)
end

function PassiveSkill_SprtintDefense:OnActivateSkill_BP()
    PassiveSkill_SprtintDefense.SuperClass.OnActivateSkill_BP(self)
end

function PassiveSkill_SprtintDefense:OnDeActivateSkill_BP()
    PassiveSkill_SprtintDefense.SuperClass.OnDeActivateSkill_BP(self)
end

function PassiveSkill_SprtintDefense:CanActivateSkill_BP()
    return PassiveSkill_SprtintDefense.SuperClass.CanActivateSkill_BP(self)
end

return PassiveSkill_SprtintDefense