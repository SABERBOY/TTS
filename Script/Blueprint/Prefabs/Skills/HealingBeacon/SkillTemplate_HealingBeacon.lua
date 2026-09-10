---@class SkillTemplate_HealingBeacon_C:PESkillTemplate_Base_C
--Edit Below--
local SkillTemplate_HealingBeacon = {}
 
function SkillTemplate_HealingBeacon:OnEnableSkill_BP()
    SkillTemplate_HealingBeacon.SuperClass.OnEnableSkill_BP(self)
end

function SkillTemplate_HealingBeacon:OnDisableSkill_BP()
    SkillTemplate_HealingBeacon.SuperClass.OnDisableSkill_BP(self)
end

function SkillTemplate_HealingBeacon:OnActivateSkill_BP()
    SkillTemplate_HealingBeacon.SuperClass.OnActivateSkill_BP(self)
end

function SkillTemplate_HealingBeacon:OnDeActivateSkill_BP()
    SkillTemplate_HealingBeacon.SuperClass.OnDeActivateSkill_BP(self)
end

function SkillTemplate_HealingBeacon:CanActivateSkill_BP()
    return SkillTemplate_HealingBeacon.SuperClass.CanActivateSkill_BP(self)
end

return SkillTemplate_HealingBeacon