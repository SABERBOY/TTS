---@class Projectile_FireBall_C:PESkillProjectileBase
---@field Capsule UCapsuleComponent
---@field ParticleSystem UParticleSystemComponent
---@field StaticMesh UStaticMeshComponent
--Edit Below--
local Projectile_FireBall = {}
 
--[[
function Projectile_FireBall:ReceiveBeginPlay()
    Projectile_FireBall.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function Projectile_FireBall:ReceiveTick(DeltaTime)
    Projectile_FireBall.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function Projectile_FireBall:ReceiveEndPlay()
    Projectile_FireBall.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function Projectile_FireBall:GetReplicatedProperties()
    return
end
--]]

--[[
function Projectile_FireBall:GetAvailableServerRPCs()
    return
end
--]]

return Projectile_FireBall