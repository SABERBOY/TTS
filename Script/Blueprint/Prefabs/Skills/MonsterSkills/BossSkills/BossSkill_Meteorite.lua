---@class BossSkill_Meteorite_C:PESkillTemplate_Base_C
--Edit Below--
local BossSkill_Meteorite = {}
 
function BossSkill_Meteorite:OnEnableSkill_BP()
    BossSkill_Meteorite.SuperClass.OnEnableSkill_BP(self)
end

function BossSkill_Meteorite:OnDisableSkill_BP()
    BossSkill_Meteorite.SuperClass.OnDisableSkill_BP(self)
end

function BossSkill_Meteorite:OnActivateSkill_BP()
    BossSkill_Meteorite.SuperClass.OnActivateSkill_BP(self)
end

function BossSkill_Meteorite:OnDeActivateSkill_BP()
    BossSkill_Meteorite.SuperClass.OnDeActivateSkill_BP(self)
end

function BossSkill_Meteorite:CanActivateSkill_BP()
    return BossSkill_Meteorite.SuperClass.CanActivateSkill_BP(self)
end

function BossSkill_Meteorite:GetShootSpeed()
    
end

return BossSkill_Meteorite