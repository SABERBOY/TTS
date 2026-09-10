---@class BP_HealingOrbProj_C:AActor
---@field DetectAttach USphereComponent
---@field Sphere USphereComponent
---@field ParticleSystem UParticleSystemComponent
---@field DetectPickup USphereComponent
---@field Buff UClass
---@field LifeTime float
---@field OrbTrackSpeed float
---@field TriggerSound UAkAudioEvent
--Edit Below--
---@class BP_HealingOrbProj_C:AActor
---@field DetectAttach USphereComponent
---@field Sphere USphereComponent
---@field ParticleSystem UParticleSystemComponent
---@field DetectPickup USphereComponent
---@field Buff UClass
---@field LifeTime float
---@field OrbTrackSpeed float
---@field TriggerSound UAkAudioEvent
local BP_HealingOrbProj = {
    pickUpPawn = nil,
    destroyTimerHandle = nil,
    destroyTimerDelegate = nil,
    trackTimerHandle = nil,
    trackTimerDelegate = nil
}

function BP_HealingOrbProj:ReceiveBeginPlay()
    BP_HealingOrbProj.SuperClass.ReceiveBeginPlay(self)
    self:LuaInit()

    -- 设置生命周期定时器
    self.destroyTimerHandle, self.destroyTimerDelegate = UGCGameSystem.SetTimer(self, function()
        self:K2_DestroyActor()
    end, self.LifeTime, false)

    -- 设置追踪定时器
    self.trackTimerHandle, self.trackTimerDelegate = UGCGameSystem.SetTimer(self, function()
        self:UpdateTrackMovement()
    end, 0.02, true)
end

function BP_HealingOrbProj:ReceiveEndPlay()
    if BP_HealingOrbProj.SuperClass.ReceiveEndPlay then
        BP_HealingOrbProj.SuperClass.ReceiveEndPlay(self)
    end

    -- 清理定时器
    if self.destroyTimerHandle then
        UGCGameSystem.ClearTimer(self, self.destroyTimerHandle)
        self.destroyTimerHandle = nil
    end

    if self.trackTimerHandle then
        UGCGameSystem.ClearTimer(self, self.trackTimerHandle)
        self.trackTimerHandle = nil
    end
end

function BP_HealingOrbProj:UpdateTrackMovement()
    -- 如果有拾取者，法球追踪拾取者
    if not self.pickUpPawn then
        return
    end
   
    local pawnLocation = self.pickUpPawn:K2_GetActorLocation()
    local selfLocation = self:K2_GetActorLocation()

    -- 计算平面方向向量
    local normalizedDirection = UGCMathUtility.Normal(Vector.New(pawnLocation.X - selfLocation.X,
        pawnLocation.Y - selfLocation.Y, 0))

    -- 计算新位置
    local deltaTime = GameplayStatics.GetWorldDeltaSeconds(self)
    local newLocation = Vector.New(selfLocation.X + normalizedDirection.X * self.OrbTrackSpeed * deltaTime,
        selfLocation.Y + normalizedDirection.Y * self.OrbTrackSpeed * deltaTime, selfLocation.Z)

    -- 更新位置
    self:K2_SetActorLocation(newLocation)
end

function BP_HealingOrbProj:ReceiveTick(DeltaTime)
    BP_HealingOrbProj.SuperClass.ReceiveTick(self, DeltaTime)
    -- 移除了原来的计时和追踪逻辑，改为使用定时器实现
end

function BP_HealingOrbProj:OnOrbPickUp(pickUpPawn)
    -- 有权限时添加buff
    if self:HasAuthority() then
        UGCPersistEffectSystem.AddBuffByClass(pickUpPawn, self.Buff)
    else
        -- 播放音效
        local audioAkEvent = UE.LoadObject('/Game/UGC/UGCGame/Skill/Audio/WwiseEvent/UGC_PasssiveSkill/Play_UGC_PasssiveSkill_MagicCure.Play_UGC_PasssiveSkill_MagicCure')
        if UE.IsValid(audioAkEvent) then
            AkGameplayStatics.PostEventAtLocation(audioAkEvent, self:K2_GetActorLocation(), {0, 0, 0}, "", GameFrontendHUD)
        end
    end

    self:K2_DestroyActor()
end

function BP_HealingOrbProj:LuaInit()
    if self.bInitDoOnce then
        return
    end
    self.bInitDoOnce = true

    -- 绑定重叠事件
    self.DetectPickup.OnComponentBeginOverlap:Add(self.DetectPickup_OnComponentBeginOverlap, self)
    self.DetectAttach.OnComponentBeginOverlap:Add(self.DetectAttach_OnComponentBeginOverlap, self)
end

function BP_HealingOrbProj:DetectPickup_OnComponentBeginOverlap(overlappedComponent, otherActor, otherComp,
    otherBodyIndex, bFromSweep, sweepResult)
    if self:GetInstigator() == otherActor then
        self:OnOrbPickUp(otherActor)
    end
    return nil
end

function BP_HealingOrbProj:DetectAttach_OnComponentBeginOverlap(overlappedComponent, otherActor, otherComp,
    otherBodyIndex, bFromSweep, sweepResult)
    if self:GetInstigator() == otherActor then
        self.pickUpPawn = otherActor
    end
    return nil
end

return BP_HealingOrbProj
