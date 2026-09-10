---@class Buff_ImproveAttackSpeed_C:PersistEffectBuff
---@field IncreasePercentagePerShoot float
--Edit Below--
---@class Buff_ImproveAttackSpeed_C:PersistEffectBuff
---@field IncreasePercentagePerShoot float 每次射击提升的攻击速度百分比
---@field TargetWeapon object 目标武器引用
---@field CurrentBonus float 当前累积的攻击速度加成

local Buff_ImproveAttackSpeed = {
	TargetWeapon = nil,  -- 当前武器引用
	CurrentBonus = 0.0,   -- 当前累积的攻击速度加成值
	StackValue = 0.0,
}

local Skill_Utils = UGCGameSystem.UGCRequire('Script.Blueprint.Prefabs.Skills.Skill_Utils')
 
---Buff应用时调用，获取并保存当前武器引用
---@param OwnerActor object 拥有者Actor
function Buff_ImproveAttackSpeed:OnApply_BP(OwnerActor)
	if not UGCGameSystem.IsServer() then
		return
	end

	if not OwnerActor then
		Skill_Utils:LogError("ImproveAttackSpeed", "OnApply_BP: OwnerActor is nil")
		return
	end	
	Skill_Utils:LogInfo("ImproveAttackSpeed", "Buff applied to actor")
	
	-- 获取当前武器
	local weapon = UGCWeaponManagerSystem.GetCurrentWeapon(OwnerActor)
	if weapon and UE.IsValid(weapon) then
		self.TargetWeapon = weapon
		self.CurrentBonus = 0.0  -- 重置攻击速度加成
		Skill_Utils:LogInfo("ImproveAttackSpeed", "Target weapon set")
	else
		Skill_Utils:LogWarning("ImproveAttackSpeed", "No valid weapon found")
	end
	self.StackValue = UGCAttributeSystem.GetGameAttributeValue(self.TargetWeapon, 'AutoShootIntervalWrapper')*self.IncreasePercentagePerShoot/100
end

---Buff移除时调用，清除武器攻击速度加成
---@param OwnerActor object 拥有者Actor
---@param Reason string 移除原因
function Buff_ImproveAttackSpeed:OnUnApply_BP(OwnerActor, Reason)
	-- 仅在服务端执行
	if not UGCGameSystem.IsServer() then
		return
	end
	
	-- 移除武器攻击速度加成
	if self.TargetWeapon and UE.IsValid(self.TargetWeapon) and self.CurrentBonus ~= 0 then
		UGCAttributeSystem.AddGameAttributeValue(self.TargetWeapon, 'AutoShootIntervalWrapper', self.StackValue*(self:GetStackNum()))
		Skill_Utils:LogInfo("ImproveAttackSpeed", "Removed attack speed bonus", self.CurrentBonus)
	end
	
	-- 重置状态
	self.TargetWeapon = nil
	self.CurrentBonus = 0.0
end

---Buff堆叠层数变化时调用，更新武器攻击速度加成
---@param PreNum number 变化前的堆叠层数
---@param CurNum number 变化后的堆叠层数
function Buff_ImproveAttackSpeed:OnStackChange_BP(PreNum, CurNum)
	if not UGCGameSystem.IsServer() then
		return
	end

	if not self.TargetWeapon or not UE.IsValid(self.TargetWeapon) then
		return
	end
	
	-- 更新武器属性
	if CurNum == PreNum then
		return
	end
		UGCAttributeSystem.AddGameAttributeValue(self.TargetWeapon, 'AutoShootIntervalWrapper',  -self.StackValue*(CurNum - PreNum))
		Skill_Utils:LogInfo("ImproveAttackSpeed", "Stack changed", PreNum, "->", CurNum, "Bonus:", self.CurrentBonus)
end

return Buff_ImproveAttackSpeed
