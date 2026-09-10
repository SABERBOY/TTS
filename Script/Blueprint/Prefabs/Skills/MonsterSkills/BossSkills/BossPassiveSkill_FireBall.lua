---@class BossPassiveSkill_FireBall_C:PESkillPassiveSkillTemplate_C
--Edit Below--
local BossPassiveSkill_FireBall = {}
 
function BossPassiveSkill_FireBall:OnEnableSkill_BP()
    BossPassiveSkill_FireBall.SuperClass.OnEnableSkill_BP(self)
end

function BossPassiveSkill_FireBall:OnDisableSkill_BP()
    BossPassiveSkill_FireBall.SuperClass.OnDisableSkill_BP(self)
end

function BossPassiveSkill_FireBall:OnActivateSkill_BP()
    BossPassiveSkill_FireBall.SuperClass.OnActivateSkill_BP(self)
end

function BossPassiveSkill_FireBall:OnDeActivateSkill_BP()
    BossPassiveSkill_FireBall.SuperClass.OnDeActivateSkill_BP(self)
end

function BossPassiveSkill_FireBall:CanActivateSkill_BP()
    return BossPassiveSkill_FireBall.SuperClass.CanActivateSkill_BP(self)
end

return BossPassiveSkill_FireBall