---@class SkillTemplate_AutoAim_C:PESkillTemplate_Base_C
--Edit Below--
local SkillTemplate_AutoAim = {}
 
function SkillTemplate_AutoAim:OnEnableSkill_BP()
    SkillTemplate_AutoAim.SuperClass.OnEnableSkill_BP(self)
end

function SkillTemplate_AutoAim:OnDisableSkill_BP()
    SkillTemplate_AutoAim.SuperClass.OnDisableSkill_BP(self)
end

function SkillTemplate_AutoAim:OnActivateSkill_BP()
    SkillTemplate_AutoAim.SuperClass.OnActivateSkill_BP(self)
end

function SkillTemplate_AutoAim:OnDeActivateSkill_BP()
    SkillTemplate_AutoAim.SuperClass.OnDeActivateSkill_BP(self)
end

function SkillTemplate_AutoAim:CanActivateSkill_BP()
    return SkillTemplate_AutoAim.SuperClass.CanActivateSkill_BP(self)
end

return SkillTemplate_AutoAim