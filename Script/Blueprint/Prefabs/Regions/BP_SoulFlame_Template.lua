---@class BP_SoulFlame_C:AActor
---@field ParticleSystem UParticleSystemComponent
---@field DefaultSceneRoot USceneComponent
---@field AttractionRadius int32
---@field DamageValue int32
---@field LifeTime float
---@field AttractionStrength int32

local BP_SoulFlame = {
    pawnClass = nil,
    damageTimer = 0,
}
 
function BP_SoulFlame:ReceiveBeginPlay()
    if not self:HasAuthority() then
        -- 播放音效
        local audioPath = '/Game/UGC/UGCGame/Skill/Audio/WwiseEvent/UGC_PasssiveSkill/Play_UGC_PasssiveSkill_SoulBurn.Play_UGC_PasssiveSkill_SoulBurn'
        local audioAkEvent = UE.LoadObject(audioPath)
        if audioAkEvent then
            local actorLocation = self:K2_GetActorLocation()
            UGCSoundManagerSystem.PlaySoundAtLocation(audioAkEvent, actorLocation, {0, 0, 0})
        end
        
        -- 客户端播放特效
        if self.ParentComponent then
            self.ParentComponent:SetActive(true)
        end
    end
end

function BP_SoulFlame:ReceiveTick(deltaTime)
    self:AttractEnemies(deltaTime)
    self:AttackEnemies(deltaTime)

    -- 生命周期管理
    if self.LifeTime > 0 then
        self.LifeTime = self.LifeTime - deltaTime
    else
        self:K2_DestroyActor()
    end
end

function BP_SoulFlame:GetEnemiesInRadius()
    print("BP_SoulFlame:GetEnemiesInRadius")
    local actorLocation = self:K2_GetActorLocation()
    local objectTypes = {EObjectTypeQuery.ObjectTypeQuery3}
    local hasResult, outActors = KismetSystemLibrary.SphereOverlapActors(
        self, 
        actorLocation, 
        self.AttractionRadius, 
        objectTypes, 
        nil, 
        nil
    )

    --阵营过滤 
    local SoulFlameInstigator = self:GetInstigator()
    if SoulFlameInstigator == nil then
        --获取不到技能施法者时 技能失效
        print("BP_SoulFlame:GetEnemiesInRadius 检测不到技能施法者 返回空")
        return {}
    end 
    local enemies = {}
    local InstigatorCampID = SoulFlameInstigator:GetGeneralCampID()
    for k, v in pairs(outActors) do
        local OverlappingActor = v
        local CampRelation = OverlappingActor:GetGeneralCampRelationWithCampID(InstigatorCampID) 
       
        -- 非自己或者友军
        if not (CampRelation == ECampRelation.Same or OverlappingActor == SoulFlameInstigator) then
           table.insert(enemies,OverlappingActor)
        end
    end

    return hasResult and enemies or {}
end

function BP_SoulFlame:AttractEnemies(deltaTime)
    local enemies = self:GetEnemiesInRadius()
    local flameLocation = self:K2_GetActorLocation()
    
    for _, enemy in ipairs(enemies) do
        local pawnLocation = enemy:K2_GetActorLocation()
        
        -- 计算吸引方向和力度
        local directionX = flameLocation.X - pawnLocation.X
        local directionY = flameLocation.Y - pawnLocation.Y
        local normalizedDirection = UGCMathUtility.Normal(Vector.New(directionX, directionY, 0))
        
        -- 计算新位置
        local forceX = normalizedDirection.X * self.AttractionStrength * deltaTime
        local forceY = normalizedDirection.Y * self.AttractionStrength * deltaTime
        local newLocation = Vector.New(
            pawnLocation.X + forceX, 
            pawnLocation.Y + forceY, 
            pawnLocation.Z
        )
        
        enemy:K2_SetActorLocation(newLocation)
    end
end

function BP_SoulFlame:AttackEnemies(deltaTime)
    -- 每秒造成一次伤害
    self.damageTimer = self.damageTimer + deltaTime
    if self.damageTimer < 1 then
        return
    end
    
    self.damageTimer = 0
    local enemies = self:GetEnemiesInRadius()
    if #enemies == 0 then
        return
    end
    
    local eventInstigator = self:GetInstigator() and UGCGameSystem.GetControllerByPawn(self:GetInstigator()) or nil
    
    for _, enemy in ipairs(enemies) do
        UGCGameSystem.ApplyDamage(enemy, self.DamageValue, eventInstigator, self, nil)
    end
end

return BP_SoulFlame