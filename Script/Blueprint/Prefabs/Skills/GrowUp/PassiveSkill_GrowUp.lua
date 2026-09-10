local PassiveSkill_GrowUp = {}
 
function PassiveSkill_GrowUp:OnEnableSkill_BP()
    PassiveSkill_GrowUp.SuperClass.OnEnableSkill_BP(self)
end

function PassiveSkill_GrowUp:OnDisableSkill_BP()
    PassiveSkill_GrowUp.SuperClass.OnDisableSkill_BP(self)
end

function PassiveSkill_GrowUp:OnActivateSkill_BP()
    PassiveSkill_GrowUp.SuperClass.OnActivateSkill_BP(self)
end

function PassiveSkill_GrowUp:OnDeActivateSkill_BP()
    PassiveSkill_GrowUp.SuperClass.OnDeActivateSkill_BP(self)
end

function PassiveSkill_GrowUp:CanActivateSkill_BP()
    return PassiveSkill_GrowUp.SuperClass.CanActivateSkill_BP(self)
end

return PassiveSkill_GrowUp