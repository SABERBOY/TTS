---@class Buff_FireProhibited_C:PersistEffectBuff
---@field MuzzleSmoke UParticleSystem
--Edit Below--
local Buff_FireProhibited = {
    MuzzleEffect = nil,
}

local SkillUtils = UGCGameSystem.UGCRequire('Script.Blueprint.Prefabs.Skills.Skill_Utils')
 
-- buff开始
function Buff_FireProhibited:OnApply_BP(OwnerActor)
    print("Buff_FireProhibited:OnApply_BP(OwnerActor)")
    if not UGCGameSystem.IsServer() then
        -- 安全检查
        if not OwnerActor then
            SkillUtils:LogError("Buff_FireProhibited", "OnApply_BP: OwnerActor is nil")
            return
        end
        local TargetWeapon = UGCWeaponManagerSystem.GetCurrentWeapon(OwnerActor)
        if UE.IsValid(TargetWeapon) then
            local WeaponMeshComp = TargetWeapon:GetWeaponMeshComponent()
    
            if UE.IsValid(WeaponMeshComp) then
                self.MuzzleEffect = GameplayStatics.SpawnEmitterAttached(self.MuzzleSmoke, WeaponMeshComp, "Muzzle", {}, {}, { X = 1, Y = 1, Z = 1 }, EAttachLocation.KeepRelativeOffset, false)
            end
        end
        return
    end
    


    SkillUtils:LogInfo("Buff_FireProhibited", "OnApply_BP: MuzzleEffect", self.MuzzleEffect)
end

-- buff结束
function Buff_FireProhibited:OnUnApply_BP(OwnerActor, Reason)
    if not UGCGameSystem.IsServer() then
        if UE.IsValid(self.MuzzleEffect) then
            self.MuzzleEffect:K2_DestroyComponent(self.MuzzleEffect)
            self.MuzzleEffect = nil
    
            SkillUtils:LogInfo("Buff_FireProhibited", "OnUnApply_BP")
        end
        return
    end

end

return Buff_FireProhibited