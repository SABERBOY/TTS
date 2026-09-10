---@class SkillTemplate_ToxicGrende_C:PESkillTemplate_Active_C
--Edit Below--
local SkillTemplate_ToxicGrende = {}
 
function SkillTemplate_ToxicGrende:OnEnableSkill_BP()
    SkillTemplate_ToxicGrende.SuperClass.OnEnableSkill_BP(self)
end

function SkillTemplate_ToxicGrende:OnDisableSkill_BP()
    SkillTemplate_ToxicGrende.SuperClass.OnDisableSkill_BP(self)
end

function SkillTemplate_ToxicGrende:OnActivateSkill_BP()
    --UGCWeaponManagerSystem.CurrentWeaponAttachToBack(self.Owner.Owner)
    SkillTemplate_ToxicGrende.SuperClass.OnActivateSkill_BP(self)
end

function SkillTemplate_ToxicGrende:OnDeActivateSkill_BP()
    SkillTemplate_ToxicGrende.SuperClass.OnDeActivateSkill_BP(self)
end

function SkillTemplate_ToxicGrende:CanActivateSkill_BP()
    return SkillTemplate_ToxicGrende.SuperClass.CanActivateSkill_BP(self)
end

return SkillTemplate_ToxicGrende