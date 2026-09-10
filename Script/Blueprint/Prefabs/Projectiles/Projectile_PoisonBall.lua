---@class Projectile_PoisonBall_C:PESkillProjectileBase
---@field ParticleSystem UParticleSystemComponent
---@field Sphere USphereComponent
--Edit Below--
local Projectile_PoisonBall = {}
 
--[[
function Projectile_PoisonBall:ReceiveBeginPlay()
    Projectile_PoisonBall.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function Projectile_PoisonBall:ReceiveTick(DeltaTime)
    Projectile_PoisonBall.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function Projectile_PoisonBall:ReceiveEndPlay()
    Projectile_PoisonBall.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function Projectile_PoisonBall:GetReplicatedProperties()
    return
end
--]]

--[[
function Projectile_PoisonBall:GetAvailableServerRPCs()
    return
end
--]]

return Projectile_PoisonBall