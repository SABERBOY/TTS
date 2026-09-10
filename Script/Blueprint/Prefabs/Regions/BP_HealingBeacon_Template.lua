---@class BP_HealingBeacon_Template_C:AActor
---@field Sphere USphereComponent
---@field P_DMM_Detect_01 UParticleSystemComponent
---@field DefaultSceneRoot USceneComponent
---@field HealingInterval int32
---@field HealingPercentage float
---@field DestoryTime bool
---@field PlayerPawn UClass
--Edit Below--
local BP_HealingBeacon = {
    InstigatorCampID = nil,
    TimeDelegate = nil,
    TimeHandle = nil
}
 
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
    if self:HasAuthority() then
        if self.InstigatorCampID == nil then
            print("BP_HealingBeacon:ReceiveBeginPlay 技能施法者ID未查询到技能失效")         
            return
        end   

        self.TimeHandle, self.TimerDelegate =  UGCGameSystem.SetTimer(self,
        function ()
            local HitLocation = self:K2_GetActorLocation();
            local SphereRadius = self.Sphere:GetScaledSphereRadius();
            local  DrawDebugTrace = EDrawDebugTrace.ForDuration
            local bHit, Results = KismetSystemLibrary.SphereTraceMultiForObjects(self,  HitLocation,  HitLocation, SphereRadius, {EObjectTypeQuery.ObjectTypeQuery3}, false, {}, DrawDebugTrace, {}, true, {R=1, G=0, B=0, A=1}, {R=0, G=1, B=0, A=1}, 3)
           
            if not bHit then
                print("BP_HealingBeacon:ReceiveBeginPlay 范围内无命中目标")
                return
            end

            for k, v in pairs(Results) do
                if  v.Actor:IsValid() then
                    local OverlappingActor = v.Actor:Get()
                    print("BP_HealingBeacon:ReceiveBeginPlay 检测对象是否为友军:"..tostring(KismetSystemLibrary.GetDisplayName(self.OverlappingActor)))
                    local CampRelation = OverlappingActor:GetGeneralCampRelationWithCampID(self.InstigatorCampID) 
                    -- 给自己或者友军回血
                    if CampRelation == ECampRelation.Same or OverlappingActor == HealingInstigator then
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