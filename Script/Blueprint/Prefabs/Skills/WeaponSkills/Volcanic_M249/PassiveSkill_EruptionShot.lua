---@class PassiveSkill_EruptionShot_C:PESkillPassiveSkillTemplate_C
local PassiveSkill_EruptionShot = {
    Weapon = nil
}

function PassiveSkill_EruptionShot:OnEnableSkill_BP()
    PassiveSkill_EruptionShot.SuperClass.OnEnableSkill_BP(self)
    if self.Weapon == nil then
        self.Weapon = UGCWeaponManagerSystem.GetCurrentWeapon(self.Owner.Owner)
    end
end

function PassiveSkill_EruptionShot:OnActivateSkill_BP()
    PassiveSkill_EruptionShot.SuperClass.OnActivateSkill_BP(self)

    ugcprint("PassiveSkill_EruptionShot:InitWeapon() Weapon=" .. tostring(self.Weapon))

    if not self.Weapon then
        return
    end

    local MuzzleTransform = self.Weapon:GetMuzzleTransform()
    local MuzzleLocation, MuzzleRotation, MuzzleScale = UGCMathUtility.BreakTransform(MuzzleTransform)

    local LaunchDir = UGCMathUtility.Normal(UGCMathUtility.GetForwardVector(MuzzleRotation))

    self:SetSelectDirection(LaunchDir)
    self:SetSelectTransform(MuzzleTransform)
end

return PassiveSkill_EruptionShot
