---@class BossSkill_FireBall_C:PESkillTemplate_Base_C
--Edit Below--
local BossSkill_FireBall = {}
 
function BossSkill_FireBall:OnEnableSkill_BP()
    BossSkill_FireBall.SuperClass.OnEnableSkill_BP(self)
end

function BossSkill_FireBall:OnDisableSkill_BP()
    BossSkill_FireBall.SuperClass.OnDisableSkill_BP(self)
end

function BossSkill_FireBall:OnActivateSkill_BP()
    BossSkill_FireBall.SuperClass.OnActivateSkill_BP(self)
end

function BossSkill_FireBall:OnDeActivateSkill_BP()
    BossSkill_FireBall.SuperClass.OnDeActivateSkill_BP(self)
end

function BossSkill_FireBall:CanActivateSkill_BP()
    return BossSkill_FireBall.SuperClass.CanActivateSkill_BP(self)
end

return BossSkill_FireBall