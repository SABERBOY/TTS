---@class Skill_ChargedBeam_C:PESkillTemplate_Base_C
---@field DamageValue float
--Edit Below--
local Skill_ChargedBeam = {}
 
function Skill_ChargedBeam:OnEnableSkill_BP()
    Skill_ChargedBeam.SuperClass.OnEnableSkill_BP(self)
end

function Skill_ChargedBeam:OnDisableSkill_BP()
    Skill_ChargedBeam.SuperClass.OnDisableSkill_BP(self)
end

function Skill_ChargedBeam:OnActivateSkill_BP()
    Skill_ChargedBeam.SuperClass.OnActivateSkill_BP(self)
end

function Skill_ChargedBeam:OnDeActivateSkill_BP()
    Skill_ChargedBeam.SuperClass.OnDeActivateSkill_BP(self)
end

function Skill_ChargedBeam:CanActivateSkill_BP()
    return Skill_ChargedBeam.SuperClass.CanActivateSkill_BP(self)
end

return Skill_ChargedBeam