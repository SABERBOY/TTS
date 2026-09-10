---@class MagicMonster_C:BP_UGC_GenericMobPawn_Base_C
---@field HitBox UCapsuleComponent
---@field Weapon UStaticMeshComponent
---@field StageOneEvent UAkAudioEvent
---@field StageTwoEvent UAkAudioEvent
---@field StopEvent UAkAudioEvent
---@field CharactersHit ULuaArrayHelper<ASTExtraPlayerCharacter>
---@field HatredDistance float
---@field LocalCharacter ASTExtraCharacter
---@field CurrentStage int32
---@field CurrentEvent UAkAudioEvent
---@field AKBank UObject
--Edit Below--
local MagicMonster = {}

function MagicMonster:ReceiveBeginPlay()
    if not self:HasAuthority() then
        -- 客户端中，怪物所在客户端的本地玩家
        self.LocalCharacter = GameplayStatics.GetPlayerCharacter(self, 0)
    end
    MagicMonster.SuperClass.ReceiveBeginPlay(self)
end


--[[
function MagicMonster:ReceiveTick(DeltaTime)
    MagicMonster.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]


function MagicMonster:ReceiveEndPlay()
    MagicMonster.SuperClass.ReceiveEndPlay(self) 
    if not self:HasAuthority() then
        self:PlayStopSound()
    end
end


--[[
function MagicMonster:GetReplicatedProperties()
    return
end
--]]


---受击前置事件
---生效范围：服务器
---@param Damage float 伤害值
---@param EventInstigator AController 伤害来源的Controller
---@param DamageCauser AActor 伤害来源
---@param DamageContext FGameMagnitudeContext  伤害上下文
function MagicMonster:PreTakeDamageEvent(Damage, EventInstigator, DamageCauser, DamageContext)
    local pc = UGCPlayerControllerSystem.GetPlayerCharacter(EventInstigator)
    self:AddHitCharacter(pc)
    
    -- 广播
    UnrealNetwork.CallUnrealRPC_Multicast(self, "PlaySound", self.CurrentStage, pc)
end

function MagicMonster:AddHitCharacter(character)
    if self.CharactersHit:Contains(character) then
        return 
    end
    -- 怪物之前没有收到过来自pc的伤害，添加到列表中
    self.CharactersHit:Add(character)   
end

---受击后置事件
---生效范围：服务器
---@param Damage float 伤害值
---@param EventInstigator AController 伤害来源的Controller
---@param DamageCauser AActor 伤害来源
---@param DamageContext FGameMagnitudeContext  伤害上下文
function MagicMonster:PostTakeDamageEvent(Damage, EventInstigator, DamageCauser, DamageContext)

end

---受击前置伤害修改
---生效范围：服务器
---@param Damage float 伤害值
---@param DamageType int32 伤害类型
---@param EventInstigator AController 伤害来源的Controller
---@param DamageCauser AActor 伤害来源
---@param HitF HitResult 伤害上下文
---@return float 修改后的伤害值
function MagicMonster:PreOverrideDamageValue(Damage, DamageType, EventInstigator, DamageCauser, Hit)
    return Damage
end

---受击后置伤害修改
---生效范围：服务器
---@param Damage float 伤害值
---@param DamageType int32 伤害类型
---@param EventInstigator AController 伤害来源的Controller
---@param DamageCauser AActor 伤害来源
---@param HitF HitResult 伤害上下文
---@return float 修改后的伤害值
function MagicMonster:PostOverrideDamageValue(Damage, DamageType, EventInstigator, DamageCauser, Hit)
    return Damage
end

---角色死亡事件
---生效范围：服务器&客户端
---@param Damage float 伤害值
---@param EventInstigator AController 伤害来源的Controller
---@param DamageCauser AActor 伤害来源
---@param FDamageEvent DamageEvent 伤害事件
---@param DamageTypeID int32 伤害类型
function MagicMonster:BPDie(KillingDamage, EventInstigator, DamageCauser, DamageEvent, DamageTypeID)
    self.UGCPresetCommonDropItemComponent:StartDrop(self, EventInstigator, {})
    if not self:HasAuthority() then
        ugcprint('Client Die')
        if self.CharactersHit:Contains(self.LocalCharacter) then
            self:PlayDieSound()
        end    
    end
    -- for _, v in pairs(self.CharactersHit) do
    --     -- 广播死亡音效
    --     if v then 
    --         UnrealNetwork.CallUnrealRPC_Multicast(self, "PlaySound", 4, v)
    --     end
    -- end
end


function MagicMonster:OnRep_CharactersHit()
    if self:HasAuthority() then
        return
    end
    -- 客户端收到变化通知
    for _, v in pairs(self.CharactersHit) do
        if v and v == self.LocalCharacter then
           
        end
    end
end

function MagicMonster:OnRep_CurrentStage()
    if self:HasAuthority() then
        return
    end

end

-- 客户端播放声音
function MagicMonster:PlaySound(index, character)
    if self:HasAuthority() then
        return
    end
    if character ~= self.LocalCharacter then
        return
    end

    if index == 1 then
        if self.CurrentEvent == self.StageOneEvent then return end
        self:PlayStageOneSound()
    elseif index == 2 then
        if self.CurrentEvent == self.StageTwoEvent then return end
        self:PlayStageTwoSound()
    elseif index == 3 then
        if self.CurrentEvent == self.DieEvent then return end
        -- self:PlayDieSound()
    elseif index == 4 then
        if self.CurrentEvent == self.StopEvent then return end
        self:PlayStopSound()
    end


end

function MagicMonster:GetCurrentTarget()
    return UGCGenericCharacterSystem.GetTargetEnemy(self)
end

---状态进入事件
---生效范围：服务器&客户端
---@param DynamicState FGameplayTag 进入的状态
function MagicMonster:OnEnterTagState_BP(DynamicState)
    local tag = BlueprintGameplayTagLibrary.GetTagName(DynamicState)
    ugcprint('OnEnterTagState_BP' .. tag)
    if not self:HasAuthority() then
        return
    end
    if tag == 'PawnState.Action.Battle' then
        self:AddHitCharacter(self:GetCurrentTarget())
        -- 广播
        UnrealNetwork.CallUnrealRPC_Multicast(self, "PlaySound", self.CurrentStage, self:GetCurrentTarget())
    end
end

---状态退出事件
---生效范围：服务器&客户端
---@param DynamicState FGameplayTag 退出的状态
function MagicMonster:OnLeaveTagState_BP(DynamicState)
    local tag = BlueprintGameplayTagLibrary.GetTagName(DynamicState)
    ugcprint('OnLeaveTagState_BP' .. tag)
    if tag == 'PawnState.Action.Battle' then
        if not self:HasAuthority() then
            self:StopSound()
        end
    end
end

-- ---状态打断事件
-- ---生效范围：服务器&客户端
-- ---@param DynamicState FGameplayTag 打断的状态
-- function @ActorName:OnInterruptTagState_BP(DynamicState)
--     local Tag = BlueprintGameplayTagLibrary.GetTagName(DynamicState)
--     ugcprint('OnInterruptTagState_BP' .. Tag)
-- end



function MagicMonster:OnBehaviorNotify_BP(NotifyMsg)
    ugcprint('OnBehaviorNotify_BP' .. NotifyMsg)
    if NotifyMsg == 'ChangeStage' then
        -- 转阶段
        self.CurrentStage = 2
        for k, v in pairs(self.CharactersHit) do
            UnrealNetwork.CallUnrealRPC_Multicast(self, "PlaySound", self.CurrentStage, v)
        end
    elseif NotifyMsg == 'Battle' then
        -- 战斗中
        
    end
        
end

function MagicMonster:PlayStageOneSound()
    UGCSoundManagerSystem.PlaySoundAttachActor(self.StageOneEvent,self,true)
    self.CurrentEvent = self.StageOneEvent
end

function MagicMonster:PlayStageTwoSound()
    self:PlayStopSound()
    UGCSoundManagerSystem.PlaySoundAttachActor(self.StageTwoEvent,self,true)
    self.CurrentEvent = self.StageTwoEvent
end

function MagicMonster:PlayStopSound()
    UGCSoundManagerSystem.PlaySoundAttachActor(self.StopEvent,self,true)
    self.CurrentEvent = self.StopEvent
end

return MagicMonster