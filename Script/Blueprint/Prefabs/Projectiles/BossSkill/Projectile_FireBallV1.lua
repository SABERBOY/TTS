---@class Projectile_FireBallV1_C:PESkillProjectileBase
---@field Capsule UCapsuleComponent
---@field ParticleSystem UParticleSystemComponent
---@field StaticMesh UStaticMeshComponent
--Edit Below--
local Projectile_FireBallV1 = {}
 
--[[
function Projectile_FireBallV1:ReceiveBeginPlay()
    Projectile_FireBallV1.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function Projectile_FireBallV1:ReceiveTick(DeltaTime)
    Projectile_FireBallV1.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function Projectile_FireBallV1:ReceiveEndPlay()
    Projectile_FireBallV1.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function Projectile_FireBallV1:GetReplicatedProperties()
    return
end
--]]

--[[
function Projectile_FireBallV1:GetAvailableServerRPCs()
    return
end
--]]

return Projectile_FireBallV1