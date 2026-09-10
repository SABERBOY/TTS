---@class SkillTemplate_VehicleSummon_C:PESkillTemplate_Base_C
--Edit Below--
local SkillTemplate_VehicleSummon = {}
 
function SkillTemplate_VehicleSummon:OnEnableSkill_BP()
    SkillTemplate_VehicleSummon.SuperClass.OnEnableSkill_BP(self)
end

function SkillTemplate_VehicleSummon:OnDisableSkill_BP()
    SkillTemplate_VehicleSummon.SuperClass.OnDisableSkill_BP(self)
end

function SkillTemplate_VehicleSummon:OnActivateSkill_BP()
    SkillTemplate_VehicleSummon.SuperClass.OnActivateSkill_BP(self)
end

function SkillTemplate_VehicleSummon:OnDeActivateSkill_BP()
    SkillTemplate_VehicleSummon.SuperClass.OnDeActivateSkill_BP(self)
end

function SkillTemplate_VehicleSummon:CanActivateSkill_BP()
    return SkillTemplate_VehicleSummon.SuperClass.CanActivateSkill_BP(self)
end

return SkillTemplate_VehicleSummon