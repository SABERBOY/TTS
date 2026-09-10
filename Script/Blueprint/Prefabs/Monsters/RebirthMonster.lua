---@class RebirthMonster_C:BP_UGC_GenericMobPawn_Base_C
---@field HitBox UCapsuleComponent
--Edit Below--
local RebirthMonster = {}

--[[
function RebirthMonster:ReceiveBeginPlay()
    RebirthMonster.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function RebirthMonster:ReceiveTick(DeltaTime)
    RebirthMonster.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function RebirthMonster:ReceiveEndPlay()
    RebirthMonster.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function RebirthMonster:GetReplicatedProperties()
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
function RebirthMonster:PreTakeDamageEvent(Damage, EventInstigator, DamageCauser, DamageContext)
     
end
--]]

--[[
-- 	 * 受击后置事件
--	 * 生效范围：服务器
--	 * @param float Damage 伤害值
--	 * @param AController EventInstigator 伤害来源的Controller
--	 * @param AActor DamageCauser 伤害来源
--	 * @param FGameMagnitudeContext DamageContext 伤害上下文
function RebirthMonster:PostTakeDamageEvent(Damage, EventInstigator, DamageCauser, DamageContext)
    
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
function RebirthMonster:PreOverrideDamageValue(Damage, DamageType, EventInstigator, DamageCauser, Hit)
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
function RebirthMonster:PostOverrideDamageValue(Damage, DamageType, EventInstigator, DamageCauser, Hit)
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
function RebirthMonster:BPDie(KillingDamage, EventInstigator, DamageCauser, DamageEvent, DamageTypeID)
    self.UGCPresetCommonDropItemComponent:StartDrop(self, EventInstigator, {})
end


--[[
-- 	 * 状态进入事件
--	 * 生效范围：服务器&客户端
--	 * @param DynamicState 进入状态
function RebirthMonster:OnEnterTagState_BP(DynamicState)

end
--]]

--[[
-- 	 * 状态退出事件
--	 * 生效范围：服务器&客户端
--	 * @param DynamicState 进入状态
function RebirthMonster:OnEnterTagState_BP(DynamicState)

end
--]]

--[[
-- 	 * 状态打断事件
--	 * 生效范围：服务器&客户端
--	 * @param DynamicState 进入状态
function RebirthMonster:OnEnterTagState_BP(DynamicState)

end
--]]

--[[
-- 	 * 行为树消息
--	 * 生效范围：服务器
--	 * @param NotifyMsg 消息
function RebirthMonster:OnEnterTagState_BP(DynamicState)

end
--]]

return RebirthMonster