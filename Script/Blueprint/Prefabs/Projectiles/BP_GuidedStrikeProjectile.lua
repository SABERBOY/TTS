---@class BP_GuidedStrikeProjectile_C:UniversalProjectileBase
---@field Tail UParticleSystemComponent
---@field Sphere UStaticMeshComponent
---@field SphereCollision USphereComponent
---@field PlayerPawn UClass
---@field CameraShakeRange float
---@field CameraShakeTime float
---@field CameraShakeScale float

local BP_GuidedStrikeProjectile = {}

function BP_GuidedStrikeProjectile:ReceiveOnImpact(HitResult)
    -- 缓存常用变量，提高性能
    local hitLocation = HitResult.ImpactPoint
    local shakeRange = self.CameraShakeRange
    
    -- 球形追踪检测
    local debugTrace = EDrawDebugTrace.ForDuration
    local objectTypes = {EObjectTypeQuery.ObjectTypeQuery3}
    local redColor = {R = 1, G = 0, B = 0, A = 1}
    local greenColor = {R = 0, G = 1, B = 0, A = 1}
    
    local bHit, results = KismetSystemLibrary.SphereTraceMultiForObjects(
        self, 
        hitLocation, 
        hitLocation,
        shakeRange, 
        objectTypes, 
        false, 
        {}, 
        debugTrace, 
        {}, 
        true, 
        redColor, 
        greenColor, 
        3
    )
    
    -- 如果没有命中，直接返回
    if not bHit then
        return
    end
    
    -- 处理命中结果
    for _, hitResult in pairs(results) do
        local actor = hitResult.Actor
        if actor:IsValid() and UE.IsA(actor:Get(), self.PlayerPawn) then
            local playerController = actor:Get():GetPlayerControllerSafety()
            UGCGameSystem.ClientPlayCameraShake(
                playerController, 
                EPESkillCameraShakeType.E_PESKILL_CameraShake_Random, 
                self.CameraShakeScale, 
                self.CameraShakeTime
            )
        end
    end
end

return BP_GuidedStrikeProjectile
