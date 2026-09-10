---@class PassiveSkill_ThorM416_C:PESkillPassiveSkillTemplate_C
---@field RemovedBuffWhenDisableSkill UClass
--Edit Below--
local PassiveSkill_ThorM416 = {
    TargetWeapon = nil,
    BulletHitDelegate = nil
}

function PassiveSkill_ThorM416:OnEnableSkill_BP()
    PassiveSkill_ThorM416.SuperClass.OnEnableSkill_BP(self)
    self.BulletHitDelegate = self:GetNetOwnerActor().OnBulletHitDelegate:Add(self.SkillActive, self)
end

function PassiveSkill_ThorM416:OnApply_BP(OwnerActor)
	print("PassiveSkill_ThorM416:OnApply_BP")
	local Weapon = UGCWeaponManagerSystem.GetCurrentWeapon(OwnerActor)
	if Weapon ~= nil and UE.IsValid(Weapon) then
		self.TargetWeapon = Weapon
	end
end

function PassiveSkill_ThorM416:OnUnApply_BP(OwnerActor, Reason)
	print("PassiveSkill_ThorM416:OnUnApply_BP")

    if self.BulletHitDelegate then
        local owner = self:GetNetOwnerActor()
        if owner then
            owner.OnBulletHitDelegate:Remove(self.SkillActive, self)
        end

        self.BulletHitDelegate = nil
    end
end

function PassiveSkill_ThorM416:SkillActive()
    -- 添加buff
    UGCPersistEffectSystem.AddBuffByClass(self:GetNetOwnerActor(),self.RemovedBuffWhenDisableSkill)
end

function PassiveSkill_ThorM416:OnDisableSkill_BP()
    ugcprint("PassiveSkill_ThorM416:OnDisableSkill_BP()")
    PassiveSkill_ThorM416.SuperClass.OnDisableSkill_BP(self)
    -- 移除Buff
    UGCPersistEffectSystem.RemoveBuffByClass(self:GetNetOwnerActor(), self.RemovedBuffWhenDisableSkill, 6, nil)
end

return PassiveSkill_ThorM416