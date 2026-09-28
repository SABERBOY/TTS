---@class SuperMonster_C:BP_UGC_GenericMobPawn_Base_C
---@field HitBox UCapsuleComponent
---@field SK_CH_UGC_Titan_weapon UStaticMeshComponent
--Edit Below--
local SuperMonster = {}
local BossTypes = require('Script.AI.Boss.BossAI_Types')
local BossKeys = BossTypes.BBKeys
local BossTreePath = '/TTS/Asset/AI/BT/BT_Boss.BT_Boss'
local terminalBosses = setmetatable({}, { __mode = 'k' })

local function warn(message)
    if type(ugcprint) == 'function' then
        pcall(ugcprint, '[SuperMonster-Boss] ' .. message)
    end
end

local function safe(label, fn)
    local ok, value = pcall(fn)
    if not ok then warn(label .. ' failed: ' .. tostring(value)) end
    return ok, value
end

-- SuperMonster may be reused with another behavior tree. A previously started
-- Boss runtime also counts, because its tree setting can be gone during EndPlay.
local function behaviorTreePath(pawn)
    local pathOK, path = pcall(function()
        local setting = UGCGenericCharacterSystem.GetBehaviorTreeSetting(pawn)
        if not setting or not setting.BehaviorTreePath then return nil end
        return UGCObjectUtility.GetObjectPathName(setting.BehaviorTreePath)
    end)
    if not pathOK or not path then
        pathOK, path = pcall(function()
            local setting = pawn.BehaviorControlComp.BehaviorTreeSetting
            return UGCObjectUtility.GetObjectPathName(setting.BehaviorTreePath)
        end)
    end
    return pathOK and path or nil
end

local function bossModules(pawn)
    local isBossTree = behaviorTreePath(pawn) == BossTreePath
    local runtimeOK, Runtime = pcall(require, 'Script.AI.Boss.BossAI_SkillRuntime')
    local observedOK, Observed = pcall(require, 'Script.AI.Boss.BossAI_Observed')
    local hasRuntime, hasObservation = false, false
    if runtimeOK then
        local ok, existing = safe('runtime lookup', function() return Runtime.Get(pawn) end)
        hasRuntime = ok and existing ~= nil
    end
    if observedOK then
        local ok, existing = safe('observation lookup', function() return Observed.Get(pawn) end)
        hasObservation = ok and existing ~= nil
    end
    if not isBossTree and not hasRuntime and not hasObservation
        and not terminalBosses[pawn] then return false end
    if not runtimeOK then warn('runtime module unavailable: ' .. tostring(Runtime)) end
    if not observedOK then warn('observation module unavailable: ' .. tostring(Observed)) end
    return true, runtimeOK and Runtime or nil, observedOK and Observed or nil
end

local function clearBlackboard(pawn, terminal)
    local _, board = safe('Blackboard lookup', function()
        return pawn:GetBlackBoardComponent()
    end)
    if not board then return end
    if terminal then safe('IsDead', function() board:SetValueAsBool(BossKeys.IsDead, true) end) end
    local bools = { BossKeys.CombatActive, BossKeys.HasLineOfSight,
        BossKeys.PhaseTransitionReady, BossKeys.CanApplyHardStagger, BossKeys.MustReset }
    for _, key in ipairs(bools) do
        safe('Blackboard ' .. key, function() board:SetValueAsBool(key, false) end)
    end
    safe('SelectedSkill', function()
        board:SetValueAsInt(BossKeys.SelectedSkill, BossTypes.SkillID.None)
    end)
    safe('ActionKind', function()
        board:SetValueAsInt(BossKeys.ActionKind, BossTypes.ActionKind.None)
    end)
    safe('TargetActor', function() board:SetValueAsObject(BossKeys.TargetActor, nil) end)
end

local function cleanBoss(pawn, reason, oldController, terminal)
    if not pawn:HasAuthority() or not UGCGameSystem.IsServer() then return end
    local isBoss, Runtime, Observed = bossModules(pawn)
    if not isBoss then return end
    if terminal then terminalBosses[pawn] = true end
    clearBlackboard(pawn, terminalBosses[pawn] == true)
    local _, now = safe('clock', function() return UGCGameSystem.GetTimeSeconds(pawn) end)
    if type(now) ~= 'number' or now ~= now or now == math.huge
        or now == -math.huge then now = 0 end
    if Runtime then
        local ok, clean = safe('runtime release', function()
            return Runtime.Release(pawn, now, reason)
        end)
        if ok and clean == false then warn('runtime cleanup is pending retry') end
    end
    if Observed then safe('observation clear', function() Observed.Clear(pawn) end) end

    local controller = oldController
    if not controller then
        _, controller = safe('controller lookup', function() return pawn:GetController() end)
    end
    if controller then
        local owned, controlledPawn = pcall(function()
            if controller.K2_GetPawn then return controller:K2_GetPawn() end
            if controller.GetPawn then return controller:GetPawn() end
            return nil
        end)
        if owned and (controlledPawn == nil or controlledPawn == pawn) then
            if controller.StopMovement then
                safe('controller movement stop', function() controller:StopMovement() end)
            end
            local _, brain = safe('brain lookup', function()
                return controller.BrainComponent
                    or (controller.GetBrainComponent and controller:GetBrainComponent())
            end)
            if brain and brain.StopLogic then
                safe('brain stop', function() brain:StopLogic('Boss' .. reason) end)
            end
        end
    end
    safe('pawn movement stop', function()
        local movement = pawn:GetMovementComponent()
        if movement then movement:StopMovementImmediately() end
    end)
    safe('behavior stop', function()
        UGCGenericCharacterSystem.StopBehavior(pawn,
            reason == 'death' and 'BossDead' or 'Boss' .. reason)
    end)
end

function SuperMonster:ReceiveBeginPlay()
    terminalBosses[self] = nil
    SuperMonster.SuperClass.ReceiveBeginPlay(self)
    ugcprint('[SuperMonster] 超级怪物·特性炸裂 已生成')
    -- 附加周期性被动技能 PassiveSkill_IceCubeWall:周围有玩家时周期性生成冰块阻挡其移动路线
    if UGCGameSystem.IsServer() then
        if behaviorTreePath(self) == BossTreePath then
            ugcprint('[SuperMonster] BT_Boss 跳过旧冰块墙被动技能 PassiveSkill_IceCubeWall')
        else
            local IceSkillClass = UE.LoadClass('/TTS/Asset/Blueprint/Prefabs/Skills/PassiveSkill_IceCubeWall.PassiveSkill_IceCubeWall_C')
            if IceSkillClass then
                self.IceCubeWallSkillInstance = UGCPersistEffectSystem.AddSkillByClass(self, IceSkillClass)
                ugcprint('[SuperMonster] 已附加冰块墙被动技能 PassiveSkill_IceCubeWall')
            else
                ugcprint('[SuperMonster] 冰块墙被动技能类加载失败')
            end
        end
    end
end

-- function SuperMonster:ReceiveTick(DeltaTime)
--     SuperMonster.SuperClass.ReceiveTick(self, DeltaTime)
-- end

function SuperMonster:ReceiveEndPlay(EndPlayReason)
    safe('EndPlay cleanup', function() cleanBoss(self, 'endplay', nil, true) end)
    SuperMonster.SuperClass.ReceiveEndPlay(self, EndPlayReason)
end

-- APawn's server-side Unpossessed event carries the previous controller.
function SuperMonster:ReceiveUnpossessed(OldController)
    safe('Unpossessed cleanup', function()
        cleanBoss(self, 'unpossess', OldController, false)
    end)
    local parent = SuperMonster.SuperClass.ReceiveUnpossessed
    if parent then parent(self, OldController) end
end

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
        safe('death cleanup', function() cleanBoss(self, 'death', nil, true) end)
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
