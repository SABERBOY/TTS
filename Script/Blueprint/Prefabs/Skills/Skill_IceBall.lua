---@class Skill_IceBall_C:PESkillTemplate_Base_C
--Edit Below--
local Skill_IceBall = {}
 
function Skill_IceBall:OnEnableSkill_BP()
    Skill_IceBall.SuperClass.OnEnableSkill_BP(self)
end

function Skill_IceBall:OnDisableSkill_BP()
    Skill_IceBall.SuperClass.OnDisableSkill_BP(self)
end

function Skill_IceBall:OnActivateSkill_BP()
    Skill_IceBall.SuperClass.OnActivateSkill_BP(self)
end

function Skill_IceBall:OnDeActivateSkill_BP()
    Skill_IceBall.SuperClass.OnDeActivateSkill_BP(self)
end

function Skill_IceBall:CanActivateSkill_BP()
    return Skill_IceBall.SuperClass.CanActivateSkill_BP(self)
end

return Skill_IceBall