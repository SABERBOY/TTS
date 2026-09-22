---@class Skill_CastTrackBomb_C:PESkillTemplate_Base_C
--Edit Below--
local Skill_CastTrackBomb = {}
 
function Skill_CastTrackBomb:OnEnableSkill_BP()
    Skill_CastTrackBomb.SuperClass.OnEnableSkill_BP(self)
end

function Skill_CastTrackBomb:OnDisableSkill_BP()
    Skill_CastTrackBomb.SuperClass.OnDisableSkill_BP(self)
end

function Skill_CastTrackBomb:OnActivateSkill_BP()
    Skill_CastTrackBomb.SuperClass.OnActivateSkill_BP(self)
end

function Skill_CastTrackBomb:OnDeActivateSkill_BP()
    Skill_CastTrackBomb.SuperClass.OnDeActivateSkill_BP(self)
end

function Skill_CastTrackBomb:CanActivateSkill_BP()
    return Skill_CastTrackBomb.SuperClass.CanActivateSkill_BP(self)
end

return Skill_CastTrackBomb