---@class Projectile_FireBallV2_C:PESkillProjectileBase
---@field Capsule UCapsuleComponent
---@field ParticleSystem UParticleSystemComponent
---@field StaticMesh UStaticMeshComponent
--Edit Below--
local Projectile_FireBallV2 = {}
 
--[[
function Projectile_FireBallV2:ReceiveBeginPlay()
    Projectile_FireBallV2.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function Projectile_FireBallV2:ReceiveTick(DeltaTime)
    Projectile_FireBallV2.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function Projectile_FireBallV2:ReceiveEndPlay()
    Projectile_FireBallV2.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function Projectile_FireBallV2:GetReplicatedProperties()
    return
end
--]]

--[[
function Projectile_FireBallV2:GetAvailableServerRPCs()
    return
end
--]]

return Projectile_FireBallV2