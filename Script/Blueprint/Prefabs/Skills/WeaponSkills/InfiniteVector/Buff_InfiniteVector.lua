---@class Buff_InfiniteVector_C:PersistEffectBuff
--Edit Below--
local Buff_InfiniteVector = {
    TargetWeapon = nil,
    CurrentBulletNumRemember = nil,
}

local Skill_Utils = UGCGameSystem.UGCRequire('Script.Blueprint.Prefabs.Skills.Skill_Utils')

-- buff开始
function Buff_InfiniteVector:OnApply_BP(OwnerActor)
    Skill_Utils:LogInfo("Buff_InfiniteVector", "OnApply_BP")

    if not UGCGameSystem.IsServer() then
        return
    end

    if not OwnerActor then
        Skill_Utils:LogError("Buff_InfiniteVector", "OnApply_BP: OwnerActor is nil")
        return
    end

    local Weapon = UGCWeaponManagerSystem.GetCurrentWeapon(OwnerActor)
    if Weapon ~= nil and UE.IsValid(Weapon) then
        self.TargetWeapon = Weapon;
        -- UGCGunSystem.ForceReloadAndEnableInfiniteBullets(self.TargetWeapon, true)
        self.CurrentBulletNumRemember = self.TargetWeapon:GetCurrentBulletNumInClip()
        if self.CurrentBulletNumRemember - 15 <= 0 then
            self.TargetWeapon:SetCurrentBulletNumInClipOnServerNew(50, true)
        end
        print("Buff_InfiniteVector:OnApply_BP(OwnerActor)--CurrentBulletNumRemember"..tostring(self.CurrentBulletNumRemember))
        -- self.TargetWeapon:ToNextClip()
        -- self.TargetWeapon:SetCurrentBulletNumInClipOnServerNew(self.CurrentBulletNumRemember, true)
        -- self.TargetWeapon:EnableInfiniteClipBullets(true);
        UGCGunSystem.EnableInfiniteBullets(self.TargetWeapon, true)
    end
end

-- buff结束
function Buff_InfiniteVector:OnUnApply_BP(OwnerActor, Reason)
    Skill_Utils:LogInfo("Buff_InfiniteVector", "OnUnApply_BP")

    if not UGCGameSystem.IsServer() then
        return
    end

    Skill_Utils:LogInfo("Buff_InfiniteVector", "EnableInfiniteClipBullets false")
    if self.TargetWeapon ~= nil and UE.IsValid(self.TargetWeapon) then
        if self.CurrentBulletNumRemember - 15 <= 0 then
            self.TargetWeapon:SetCurrentBulletNumInClipOnServerNew(0, true)
        end
        UGCGunSystem.EnableInfiniteBullets(self.TargetWeapon, false)
    end
end

return Buff_InfiniteVector