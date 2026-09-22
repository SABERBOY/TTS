---@class SuperMonster_C:BP_UGC_GenericMobPawn_Base_C
---@field HitBox UCapsuleComponent
---@field SK_CH_UGC_Titan_weapon UStaticMeshComponent
--Edit Below--
local SuperMonster = {}

function SuperMonster:ReceiveBeginPlay()
    SuperMonster.SuperClass.ReceiveBeginPlay(self)
    ugcprint('[SuperMonster] 超级怪物·特性炸裂 已生成')
    -- 附加周期性被动技能 PassiveSkill_IceCubeWall:周围有玩家时周期性生成冰块阻挡其移动路线
    if UGCGameSystem.IsServer() then
        local IceSkillClass = UE.LoadClass('/TTS/Asset/Blueprint/Prefabs/Skills/PassiveSkill_IceCubeWall.PassiveSkill_IceCubeWall_C')
        if IceSkillClass then
            self.IceCubeWallSkillInstance = UGCPersistEffectSystem.AddSkillByClass(self, IceSkillClass)
            ugcprint('[SuperMonster] 已附加冰块墙被动技能 PassiveSkill_IceCubeWall')
        else
            ugcprint('[SuperMonster] 冰块墙被动技能类加载失败')
        end
    end
end

-- function SuperMonster:ReceiveTick(DeltaTime)
--     SuperMonster.SuperClass.ReceiveTick(self, DeltaTime)
-- end

-- function SuperMonster:ReceiveEndPlay()
--     SuperMonster.SuperClass.ReceiveEndPlay(self) 
-- end

-- function SuperMonster:GetReplicatedProperties()
--     return
-- end

-- ---受击前置事件
-- ---生效范围：服务器
-- ---@param Damage float 伤害值
-- ---@param EventInstigator AController 伤害来源的Controller
-- ---@param DamageCauser AActor 伤害来源
-- ---@param DamageContext FGameMagnitudeContext  伤害上下文
-- function SuperMonster:PreTakeDamageEvent(Damage, EventInstigator, DamageCauser, DamageContext)
     
-- end

-- ---受击后置事件
-- ---生效范围：服务器
-- ---@param Damage float 伤害值
-- ---@param EventInstigator AController 伤害来源的Controller
-- ---@param DamageCauser AActor 伤害来源
-- ---@param DamageContext FGameMagnitudeContext  伤害上下文
-- function SuperMonster:PostTakeDamageEvent(Damage, EventInstigator, DamageCauser, DamageContext)
    
-- end

-- ---受击前置伤害修改
-- ---生效范围：服务器
-- ---@param Damage float 伤害值
-- ---@param DamageType int32 伤害类型
-- ---@param EventInstigator AController 伤害来源的Controller
-- ---@param DamageCauser AActor 伤害来源
-- ---@param HitF HitResult 伤害上下文
-- ---@return float 修改后的伤害值
-- function SuperMonster:PreOverrideDamageValue(Damage, DamageType, EventInstigator, DamageCauser, Hit)
--     return Damage
-- end

-- ---受击后置伤害修改
-- ---生效范围：服务器
-- ---@param Damage float 伤害值
-- ---@param DamageType int32 伤害类型
-- ---@param EventInstigator AController 伤害来源的Controller
-- ---@param DamageCauser AActor 伤害来源
-- ---@param HitF HitResult 伤害上下文
-- ---@return float 修改后的伤害值
-- function SuperMonster:PostOverrideDamageValue(Damage, DamageType, EventInstigator, DamageCauser, Hit)
--     return Damage
-- end

---角色死亡事件
---生效范围：服务器&客户端
---@param Damage float 伤害值
---@param EventInstigator AController 伤害来源的Controller
---@param DamageCauser AActor 伤害来源
---@param FDamageEvent DamageEvent 伤害事件
---@param DamageTypeID int32 伤害类型
function SuperMonster:BPDie(KillingDamage, EventInstigator, DamageCauser, DamageEvent, DamageTypeID)
    if self:HasAuthority() then
        -- 只有服务端才可以掉落
        self.UGCPresetCommonDropItemComponent:StartDrop(self, EventInstigator, {})
    end
end

-- ---状态进入事件
-- ---生效范围：服务器&客户端
-- ---@param DynamicState FGameplayTag 进入的状态
-- function SuperMonster:OnEnterTagState_BP(DynamicState)
--     local Tag = BlueprintGameplayTagLibrary.GetTagName(DynamicState)
--     ugcprint('OnEnterTagState_BP: ' .. Tag)
-- end

-- ---状态退出事件
-- ---生效范围：服务器&客户端
-- ---@param DynamicState FGameplayTag 退出的状态
-- function SuperMonster:OnLeaveTagState_BP(DynamicState)
--     local Tag = BlueprintGameplayTagLibrary.GetTagName(DynamicState)
--     ugcprint('OnLeaveTagState_BP: ' .. Tag)
-- end

-- ---状态打断事件
-- ---生效范围：服务器&客户端
-- ---@param DynamicState FGameplayTag 打断的状态
-- function SuperMonster:OnInterruptTagState_BP(DynamicState)
--     local Tag = BlueprintGameplayTagLibrary.GetTagName(DynamicState)
--     ugcprint('OnInterruptTagState_BP' .. Tag)
-- end

-- ---行为树消息
-- ---生效范围：服务器
-- ---@param NotifyMsg string 消息
-- function SuperMonster:OnBehaviorNotify_BP(NotifyMsg)
--     ugcprint('OnBehaviorNotify_BP: ' .. NotifyMsg)
-- end

-- ---怪物的目标发生变化事件
-- ---生效范围：服务器&客户端
-- ---@param OldTarget AActor 旧目标
-- ---@param NewTarget AActor 新目标
-- function SuperMonster:OnTargetChange_BP(OldTarget, NewTarget)
    
-- end

return SuperMonster