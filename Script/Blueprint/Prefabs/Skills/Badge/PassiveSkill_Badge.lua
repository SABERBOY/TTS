---@class PassiveSkill_Badge_C:PESkillPassiveSkillTemplate_C
--Edit Below--
local PassiveSkill_Badge = {}
 
function PassiveSkill_Badge:OnEnableSkill_BP()
    print("PassiveSkill_Badge:OnEnableSkill_BP")
    PassiveSkill_Badge.SuperClass.OnEnableSkill_BP(self)
end

function PassiveSkill_Badge:OnDisableSkill_BP()
    print("PassiveSkill_Badge:OnDisableSkill_BP")
    PassiveSkill_Badge.SuperClass.OnDisableSkill_BP(self)
end

function PassiveSkill_Badge:OnActivateSkill_BP()
    print("PassiveSkill_Badge:OnActivateSkill_BP")
    PassiveSkill_Badge.SuperClass.OnActivateSkill_BP(self)
end

function PassiveSkill_Badge:OnDeActivateSkill_BP()
    print("PassiveSkill_Badge:OnDeActivateSkill_BP")
    PassiveSkill_Badge.SuperClass.OnDeActivateSkill_BP(self)
end

function PassiveSkill_Badge:CanActivateSkill_BP()
    print("PassiveSkill_Badge:CanActivateSkill_BP")
    return PassiveSkill_Badge.SuperClass.CanActivateSkill_BP(self)
end

return PassiveSkill_Badge