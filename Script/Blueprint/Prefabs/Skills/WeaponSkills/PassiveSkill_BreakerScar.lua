---@class PassiveSkill_BreakerScar_C:PESkillPassiveSkillTemplate_C
---@field ShotEnhanceInterval int32
---@field BulletDamageEnhance FString
---@field AddDamageAKEvent UAkAudioEvent
--Edit Below--
---@class PassiveSkill_BreakerScar_C:PESkillPassiveSkillTemplate_C
---@field ShotEnhanceInterval int32
---@field BulletDamageEnhance FString
-- Edit Below--
local PassiveSkill_BreakerScar = {
    FiredShotsCount = 0,
    TargetWeapon = nil,
    BulletDamagetRemember = nil,
}


function PassiveSkill_BreakerScar:OnActivateSkill_BP()
    ugcprint("PassiveSkill_BreakerScar:OnActivateSkill_BP()")
    PassiveSkill_BreakerScar.SuperClass.OnActivateSkill_BP(self)

    if UGCGameSystem.IsServer() then
        if self.TargetWeapon == nil then
            self.TargetWeapon = UGCWeaponManagerSystem.GetCurrentWeapon(self.Owner.Owner)
        end

        if not self.TargetWeapon then
            return
        end

        self.FiredShotsCount = self.FiredShotsCount + 1

        if self.FiredShotsCount == self.ShotEnhanceInterval then
            -- 子弹伤害加成
            UGCAttributeSystem.AddGameAttributeValue(self:GetNetOwnerActor():GetCurrentWeapon(), 'BaseImpactDamageWrapper', self.BulletDamagetRemember)
            UnrealNetwork.CallUnrealRPC_Multicast(self, "AddDamageSound")
        elseif self.FiredShotsCount == self.ShotEnhanceInterval + 1 then
            -- 恢复子弹伤害加成
            self.FiredShotsCount = 1
            UGCAttributeSystem.AddGameAttributeValue(self:GetNetOwnerActor():GetCurrentWeapon(), 'BaseImpactDamageWrapper', -self.BulletDamagetRemember)
        end
       
    end
end

function PassiveSkill_BreakerScar:OnEnableSkill_BP()
    PassiveSkill_BreakerScar.SuperClass.OnEnableSkill_BP(self)
    print("PassiveSkill_BreakerScar:OnEnableSkill_BP ")
    self.BulletDamagetRemember = UGCAttributeSystem.GetGameAttributeValue(self:GetNetOwnerActor():GetCurrentWeapon(),'BaseImpactDamageWrapper')*self.BulletDamageEnhance
end

function PassiveSkill_BreakerScar:OnDisableSkill_BP()
    ugcprint("PassiveSkill_BreakerScar:OnDisableSkill_BP()")
    PassiveSkill_BreakerScar.SuperClass.OnDisableSkill_BP(self)
    if self.FiredShotsCount == self.ShotEnhanceInterval then
        UGCAttributeSystem.AddGameAttributeValue(self:GetNetOwnerActor():GetCurrentWeapon(), 'BaseImpactDamageWrapper', -self.BulletDamagetRemember)
    end
end


function PassiveSkill_BreakerScar:AddDamageSound()
    AkGameplayStatics.PostEvent(self.AddDamageAKEvent,self:GetNetOwnerActor(),false,"")
end

return PassiveSkill_BreakerScar
