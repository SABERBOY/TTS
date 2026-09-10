---@class BossSkill_Summon_C:PESkillTemplate_Base_C
--Edit Below--
local BossSkill_Summon = {}
 
function BossSkill_Summon:OnEnableSkill_BP()
    BossSkill_Summon.SuperClass.OnEnableSkill_BP(self)
end

function BossSkill_Summon:OnDisableSkill_BP()
    BossSkill_Summon.SuperClass.OnDisableSkill_BP(self)
end

function BossSkill_Summon:OnActivateSkill_BP()
    BossSkill_Summon.SuperClass.OnActivateSkill_BP(self)
end

function BossSkill_Summon:OnDeActivateSkill_BP()
    BossSkill_Summon.SuperClass.OnDeActivateSkill_BP(self)
end

function BossSkill_Summon:CanActivateSkill_BP()
    return BossSkill_Summon.SuperClass.CanActivateSkill_BP(self)
end

return BossSkill_Summon