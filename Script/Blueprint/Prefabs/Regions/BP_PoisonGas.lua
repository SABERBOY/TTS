---@class BP_PoisonGas_C:AActor
---@field ParticleSystem UParticleSystemComponent
---@field Box UBoxComponent
---@field DefaultSceneRoot USceneComponent
---@field Interval float
---@field DamageValue float
---@field Pawn UClass
---@field BoxScale FVector
---@field Orientation FRotator
--Edit Below--
local BP_PoisonGas = {
    timeDelegate = nil,
    timeHandle = nil,
    CameraShakePawnList = {}
}

function BP_PoisonGas:ReceiveBeginPlay()
    BP_PoisonGas.SuperClass.ReceiveBeginPlay(self)
   
    if not self:HasAuthority() then
        return
    end
    
    local hitLocation = self:K2_GetActorLocation()
    
    self.timeHandle, self.timeDelegate = UGCGameSystem.SetTimer(
        self,
        function()
            self:CheckAndDamageOverlappingActors(hitLocation)
        end,
        self.Interval,
        true
    )
end

function BP_PoisonGas:CheckAndDamageOverlappingActors(hitLocation)
    local outHits = {}
    local bHit = UGCSceneQueryUtility.QueryByBoxMultiForObjects(
        self,
        hitLocation,
        hitLocation,
        self.BoxScale,
        self.Orientation,
        {EObjectTypeQuery.ObjectTypeQuery3},
        false,
        {},
        EDrawDebugTrace.None,
        outHits,
        true
    )
    
    if not bHit then
        return
    end
    
    local instigator = self:GetInstigator()
    local instigatorController = instigator and instigator:IsValid() and instigator:GetPlayerControllerSafety() or nil
    
    for _, hitResult in pairs(outHits) do
        local actor = hitResult.Actor
        
        if actor:IsValid() then
            local overlappingActor = actor:Get()
            
            if UE.IsA(overlappingActor, self.Pawn) then
                if not (instigator and overlappingActor == instigator) then
                    UGCGameSystem.ApplyDamage(overlappingActor, self.DamageValue, instigatorController, self, nil)
                end
            end
        end
    end
end


function BP_PoisonGas:ReceiveEndPlay()
    if BP_PoisonGas.SuperClass.ReceiveEndPlay then
        BP_PoisonGas.SuperClass.ReceiveEndPlay(self)
    end
    
    if self.timeHandle then
        UGCGameSystem.ClearTimer(self, self.timeHandle)
        self.timeHandle = nil
    end
end



return BP_PoisonGas