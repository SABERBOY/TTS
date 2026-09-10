---@class BP_HealingBeacon_C:AActor
---@field Sphere USphereComponent
---@field P_DMM_Detect_01 UParticleSystemComponent
---@field StaticMesh UStaticMeshComponent
---@field DefaultSceneRoot USceneComponent
---@field HealingInterval int32
---@field HealingPercentage float
--Edit Below--
local BP_HealingBeacon = {
    InstigatorCampID = nil,
    TimeDelegate = nil,
    TimeHandle = nil
}
 

function BP_HealingBeacon:ReceiveBeginPlay()
    BP_HealingBeacon.SuperClass.ReceiveBeginPlay(self)

    local HealingInstigator = self:GetInstigator()
    if HealingInstigator ~= nil then
        -- 获取阵营ID
        self.InstigatorCampID = HealingInstigator:GetGeneralCampID()
        print("BP_HealingBeacon:ReceiveBeginPlay InstigatorCampID="..tostring(self.InstigatorCampID))
    else
        print("BP_HealingBeacon:ReceiveBeginPlay [HealingInstigator == nil]")
    end

    
    -- 信标周围5m内的友军每秒恢复5%生命值
    --[[
    if UGCGameSystem.IsServer() then
        
    end
    ]]
    
    --[[ 生成在玩家旁边时，如果玩家未移动那么 通过GetOverLlappingActors获取不到任何对象。采用其他方式
    if self:HasAuthority() then
        self.TimeHandle, self.TimerDelegate =  UGCGameSystem.SetTimer(self,
        function ()
            print("BP_HealingBeacon:ReceiveBeginPlay Timer")
            local OverlappingActors = {}
            self.Sphere:GetOverlappingActors(OverlappingActors)
            print("BP_HealingBeacon:ReceiveBeginPlay OverlappingActors Length :"..#OverlappingActors)
            for k, OverlappingActor in pairs(OverlappingActors) do
                if self.InstigatorCampID ~= nil then
                    print("BP_HealingBeacon:ReceiveBeginPlay CampRelation="..tostring(OverlappingActor))
                    local CampRelation = OverlappingActor:GetGeneralCampRelationWithCampID(self.InstigatorCampID) 
                    print("BP_HealingBeacon:ReceiveBeginPlay CampRelation="..tostring(CampRelation))
                    -- 友军或同盟时
                    if CampRelation == ECampRelation.Same or  CampRelation == ECampRelation.Ally then
                        -- 回血
                        local MaxHealth = UGCAttributeSystem.GetGameAttributeValue(OverlappingActor, "HealthMax")
                        UGCAttributeSystem.AddGameAttributeValue(OverlappingActor, "Health", MaxHealth*self.HealingPercentage)
                        print("BP_HealingBeacon:ReceiveBeginPlay:Healing"..tostring(OverlappingActor))
                    end
                end
            end
        end,
        self.HealingInterval,
        true)
    end
    ]]

    if self:HasAuthority() then
        self.TimeHandle, self.TimerDelegate =  UGCGameSystem.SetTimer(self,
        function ()
            print("BP_HealingBeacon:ReceiveBeginPlay Timer")
            local HitLocation = self:K2_GetActorLocation();
            local SphereRadius = self.Sphere:GetScaledSphereRadius();
            print("BP_HealingBeacon:ReceiveBeginPlay SphereRadius "..SphereRadius)
            local  DrawDebugTrace = EDrawDebugTrace.ForDuration
            local bHit, Results = KismetSystemLibrary.SphereTraceMultiForObjects(self,  HitLocation,  HitLocation, SphereRadius, {EObjectTypeQuery.ObjectTypeQuery3}, false, {}, DrawDebugTrace, {}, true, {R=1, G=0, B=0, A=1}, {R=0, G=1, B=0, A=1}, 3)
            if bHit then
                for k, v in pairs(Results) do
                    if v.Actor:IsValid() then
                        if UE.IsA(v.Actor:Get(),self.PlayerPawn) then
                            if self.InstigatorCampID ~= nil then
                                local OverlappingActor = v.Actor:Get()
                                print("BP_HealingBeacon:ReceiveBeginPlay CampRelation="..tostring(OverlappingActor))
                                local CampRelation = OverlappingActor:GetGeneralCampRelationWithCampID(self.InstigatorCampID) 
                                print("BP_HealingBeacon:ReceiveBeginPlay CampRelation="..tostring(CampRelation))
                                -- 友军或同盟时
                                if CampRelation == ECampRelation.Same or  CampRelation == ECampRelation.Ally then
                                    -- 回血
                                    local MaxHealth = UGCAttributeSystem.GetGameAttributeValue(OverlappingActor, "HealthMax")
                                    UGCAttributeSystem.AddGameAttributeValue(OverlappingActor, "Health", MaxHealth*self.HealingPercentage)
                                    print("BP_HealingBeacon:ReceiveBeginPlay:Healing"..tostring(OverlappingActor))
                                end
                            end
                        end
                    end
                end
            end
        end,
        self.HealingInterval,
        true)
    end
end


--[[
function BP_HealingBeacon:ReceiveTick(DeltaTime)
    BP_HealingBeacon.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]


function BP_HealingBeacon:ReceiveEndPlay()
    BP_HealingBeacon.SuperClass.ReceiveEndPlay(self) 
    UGCGameSystem.ClearTimer(self, self.TimeHandle);
end




--[[
function BP_HealingBeacon:GetReplicatedProperties()
    return
end
--]]

--[[
function BP_HealingBeacon:GetAvailableServerRPCs()
    return
end
--]]

return BP_HealingBeacon