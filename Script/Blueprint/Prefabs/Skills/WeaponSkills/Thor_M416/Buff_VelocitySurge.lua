---@class Buff_VelocitySurge_C:PersistEffectBuff
---@field FireRateBonus float
---@field AssociatedSkill UClass
---@field ImproveAttackSpeedParticleRes UParticleSystem
--Edit Below--
---@class Buff_VelocitySurge_C:PersistEffectBuff
---@field FireRateBonus float
---@field AssociatedSkill UClass

local Buff_VelocitySurge = {
	DamageBonus = 50.0,
    ReloadSpeedBonus = 100.0,
    TargetWeapon = nil,
    bIsActive = false,
    BaseReloadTimeFactor = 0.0,
	SkillInatance = nil,
	StackValue = 0.0,
}

-- buff开始
function Buff_VelocitySurge:OnApply_BP(OwnerActor)
	self.TargetWeapon = UGCWeaponManagerSystem.GetCurrentWeapon(OwnerActor)
	self.StackValue = UGCAttributeSystem.GetGameAttributeValue(self.TargetWeapon, 'AutoShootIntervalWrapper')*self.FireRateBonus/100
end


-- buff结束
function Buff_VelocitySurge:OnUnApply_BP(OwnerActor, Reason)
	ugcprint("Buff_VelocitySurge:OnUnApply_BP(OwnerActor, Reason)")

	-- 移除所有加成
	if UGCGameSystem.IsServer() and self.TargetWeapon ~= nil and UE.IsValid(self.TargetWeapon) then
		UGCAttributeSystem.AddGameAttributeValue(self.TargetWeapon, 'AutoShootIntervalWrapper',  self.StackValue*(self:GetStackNum()))
	end
end

-- buff合并，A为当前身上已有buff，B为外来buff，调用A.OnMerge(B)
function Buff_VelocitySurge:OnMerge_BP(PersistEffect)
	self:RefreshBuff()
end

-- buff堆叠层数变化
function Buff_VelocitySurge:OnStackChange_BP(PreNum, CurNum)
	ugcprint(string.format("Buff_VelocitySurge:OnStackChange_BP(PreNum, CurNum) PreNum:%d,CurNum:%d",PreNum,CurNum))
	
	if UGCGameSystem.IsServer() and self.TargetWeapon ~= nil and UE.IsValid(self.TargetWeapon) then
		UGCAttributeSystem.AddGameAttributeValue(self.TargetWeapon, 'AutoShootIntervalWrapper', -self.StackValue*(CurNum-PreNum))
	end
end

return Buff_VelocitySurge