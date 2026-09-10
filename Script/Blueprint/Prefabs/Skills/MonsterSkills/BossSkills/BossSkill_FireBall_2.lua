---@class BossSkill_FireBall_2_C:PESkillTemplate_Base_C
--Edit Below--
local BossSkill_FireBall_2 = {}
 
function BossSkill_FireBall_2:OnEnableSkill_BP()
    BossSkill_FireBall_2.SuperClass.OnEnableSkill_BP(self)
end

function BossSkill_FireBall_2:OnDisableSkill_BP()
    BossSkill_FireBall_2.SuperClass.OnDisableSkill_BP(self)
end

function BossSkill_FireBall_2:OnActivateSkill_BP()
    BossSkill_FireBall_2.SuperClass.OnActivateSkill_BP(self)
end

function BossSkill_FireBall_2:OnDeActivateSkill_BP()
    BossSkill_FireBall_2.SuperClass.OnDeActivateSkill_BP(self)
end

function BossSkill_FireBall_2:CanActivateSkill_BP()
    return BossSkill_FireBall_2.SuperClass.CanActivateSkill_BP(self)
end

return BossSkill_FireBall_2