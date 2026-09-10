local RangedMonsters = {}

--[[
function RangedMonsters:ReceiveBeginPlay()
    RangedMonsters.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function RangedMonsters:ReceiveTick(DeltaTime)
    RangedMonsters.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function RangedMonsters:ReceiveEndPlay()
    RangedMonsters.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function RangedMonsters:GetReplicatedProperties()
    return
end
--]]

--[[
-- 	 * 受击前置事件
--	 * 生效范围：服务器
--	 * @param float Damage 伤害值
--	 * @param AController EventInstigator 伤害来源的Controller
--	 * @param AActor DamageCauser 伤害来源
--	 * @param FGameMagnitudeContext DamageContext 伤害上下文
function RangedMonsters:PreTakeDamageEvent(Damage, EventInstigator, DamageCauser, DamageContext)
     
end
--]]

--[[
-- 	 * 受击后置事件
--	 * 生效范围：服务器
--	 * @param float Damage 伤害值
--	 * @param AController EventInstigator 伤害来源的Controller
--	 * @param AActor DamageCauser 伤害来源
--	 * @param FGameMagnitudeContext DamageContext 伤害上下文
function RangedMonsters:PostTakeDamageEvent(Damage, EventInstigator, DamageCauser, DamageContext)
    
end
--]]

--[[
-- 	 * 受击前置伤害修改
--	 * 生效范围：服务器
--	 * @param float Damage 伤害值
--	 * @param int32 DamageType 伤害类型
--	 * @param AController EventInstigator 伤害来源的Controller
--	 * @param AActor DamageCauser 伤害来源
--	 * @param FHitResult Hit 伤害上下文
--   * @return float 修改后的伤害值
function RangedMonsters:PreOverrideDamageValue(Damage, DamageType, EventInstigator, DamageCauser, Hit)
    return Damage
end
--]]

--[[
-- 	 * 受击后置伤害修改
--	 * 生效范围：服务器
--	 * @param float Damage 伤害值
--	 * @param int32 DamageType 伤害类型
--	 * @param AController EventInstigator 伤害来源的Controller
--	 * @param AActor DamageCauser 伤害来源
--	 * @param FHitResult Hit 伤害上下文
--   * @return float 修改后的伤害值
function RangedMonsters:PostOverrideDamageValue(Damage, DamageType, EventInstigator, DamageCauser, Hit)
    return Damage
end
--]]

-- 	 * 角色死亡事件
--	 * 生效范围：服务器
--	 * @param float Damage 伤害值
--	 * @param AController EventInstigator 伤害来源的Controller
--	 * @param AActor DamageCauser 伤害来源
--	 * @param DamageEvent FDamageEvent 伤害事件
--	 * @param int32 DamageTypeID 伤害类型
function RangedMonsters:BPDie(KillingDamage, EventInstigator, DamageCauser, DamageEvent, DamageTypeID)
    self.UGCPresetCommonDropItemComponent:StartDrop(self, EventInstigator, {})
end


--[[
-- 	 * 状态进入事件
--	 * 生效范围：服务器&客户端
--	 * @param DynamicState 进入状态
function RangedMonsters:OnEnterTagState_BP(DynamicState)

end
--]]

--[[
-- 	 * 状态退出事件
--	 * 生效范围：服务器&客户端
--	 * @param DynamicState 进入状态
function RangedMonsters:OnEnterTagState_BP(DynamicState)

end
--]]

--[[
-- 	 * 状态打断事件
--	 * 生效范围：服务器&客户端
--	 * @param DynamicState 进入状态
function RangedMonsters:OnEnterTagState_BP(DynamicState)

end
--]]

--[[
-- 	 * 行为树消息
--	 * 生效范围：服务器
--	 * @param NotifyMsg 消息
function RangedMonsters:OnEnterTagState_BP(DynamicState)

end
--]]

return RangedMonsters