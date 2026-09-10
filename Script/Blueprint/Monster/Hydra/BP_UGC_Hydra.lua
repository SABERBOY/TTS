---@class BP_UGC_Hydra_C:BP_UGC_MobPawn_Normal_Far_C
---@field SpawnParticle UParticleSystem
--Edit Below--
local BP_UGC_Hydra = {
    SpawnParticleEffect = nil,
    SpawnParticleTimer = nil,
    TimeHandle = nil
}
 

function BP_UGC_Hydra:ReceiveBeginPlay()
    BP_UGC_Hydra.SuperClass.ReceiveBeginPlay(self)
    if not UGCGameSystem.IsServer() then
        print("BP_UGC_Hydra:ReceiveBeginPlay")
        self:GetMeshComponent():SetVisibility(false,false,false)
        self.SpawnParticleEffect = GameplayStatics.SpawnEmitterAtLocation(self,self.SpawnParticle,self:K2_GetActorLocation() , {}, { X = 1, Y = 1, Z = 1 }, EAttachLocation.KeepRelativeOffset, true)
        UGCGameSystem.SetTimer(self, self.SpawnParticleDestroy, 1, true)
    end
end
function BP_UGC_Hydra:SpawnParticleDestroy()
    print("BP_UGC_Hydra:SpawnParticleDestroy")
    self:GetMeshComponent():SetVisibility(true,false,false)
    self.SpawnParticleEffect:K2_DestroyComponent()
    UGCGameSystem.ClearTimer(self,self.TimeHandle)
    self.TimeHandle = nil
end
--]]

--[[
function BP_UGC_Hydra:ReceiveTick(DeltaTime)
    BP_UGC_Hydra.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function BP_UGC_Hydra:ReceiveEndPlay()
    BP_UGC_Hydra.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function BP_UGC_Hydra:GetReplicatedProperties()
    return
end
--]]

--[[
function BP_UGC_Hydra:GetAvailableServerRPCs()
    return
end
--]]

--[[
function BP_UGC_Hydra:PreTakeDamageEvent(DamageCauser, EventInstigator, Damage, DamageContext)
     
end
--]]

--[[
function BP_UGC_Hydra:PostTakeDamageEvent(DamageCauser, EventInstigator, Damage, DamageContext)
    
end
--]]

--[[
function BP_UGC_Hydra:PreOverrideDamageValue(Damage, DamageType, EventInstigator, DamageCauser, Hit)
    return Damage
end
--]]

--[[
function BP_UGC_Hydra:PostOverrideDamageValue(Damage, DamageType, EventInstigator, DamageCauser, Hit)
    return Damage
end
--]]

--[[
function BP_UGC_Hydra:MobPawnDeadEvent(Killer, DamageCauser, KillingHitDamageType)
    
end
--]]

--[[
function BP_UGC_Hydra:StateChangeEvent(OldState, NewState)
    
end
--]]




return BP_UGC_Hydra