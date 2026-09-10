---@class PassiveSkill_DamageAura_1_C:PESkillPassiveSkillTemplate_C
---@field Particle UParticleSystem
--Edit Below--
local PassiveSkill_DamageAura_1 = {
    SkillBaseClass = nil,
    ParticleSystemComponent = nil
}
 
function PassiveSkill_DamageAura_1:OnApply_BP()
    PassiveSkill_DamageAura_1.SuperClass.OnApply_BP(self)
    print("PassiveSkill_DamageAura_1:OnApply_BP")
    if not self:HasAuthority() then
        local Character = self:GetNetOwnerActor()
        self.ParticleSystemComponent = GameplayStatics.SpawnEmitterAttachedToActor(self.Particle, Character.Mesh, "root", Vector.New(0,0,10), Rotator.New(0, 0, 0), Vector.New(1, 1, 1), EAttachLocation.SnapToTarget, true)
    end
end

function PassiveSkill_DamageAura_1:OnDisableSkill_BP()
    PassiveSkill_DamageAura_1.SuperClass.OnDisableSkill_BP(self)

end

function PassiveSkill_DamageAura_1:OnUnApply_BP()
    PassiveSkill_DamageAura_1.SuperClass.OnUnApply_BP(self)
    print("PassiveSkill_DamageAura_1:OnUnApply_BP")
    if not self:HasAuthority() then
        if (self.ParticleSystemComponent) then
            self.ParticleSystemComponent:K2_DestroyComponent()
        end
    end
end

function PassiveSkill_DamageAura_1:OnActivateSkill_BP()
    PassiveSkill_DamageAura_1.SuperClass.OnActivateSkill_BP(self)
end

function PassiveSkill_DamageAura_1:OnDeActivateSkill_BP()
    PassiveSkill_DamageAura_1.SuperClass.OnDeActivateSkill_BP(self)
end

function PassiveSkill_DamageAura_1:CanActivateSkill_BP()
    return PassiveSkill_DamageAura_1.SuperClass.CanActivateSkill_BP(self)
end

return PassiveSkill_DamageAura_1