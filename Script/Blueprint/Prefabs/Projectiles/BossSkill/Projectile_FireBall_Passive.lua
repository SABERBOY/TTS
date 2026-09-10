---@class Projectile_FireBall_Passive_C:PESkillProjectileBase
---@field Capsule UCapsuleComponent
---@field ParticleSystem UParticleSystemComponent
---@field StaticMesh UStaticMeshComponent
--Edit Below--
local Projectile_FireBall_Passive = {}
 
--[[
function Projectile_FireBall_Passive:ReceiveBeginPlay()
    Projectile_FireBall_Passive.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function Projectile_FireBall_Passive:ReceiveTick(DeltaTime)
    Projectile_FireBall_Passive.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function Projectile_FireBall_Passive:ReceiveEndPlay()
    Projectile_FireBall_Passive.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function Projectile_FireBall_Passive:GetReplicatedProperties()
    return
end
--]]

--[[
function Projectile_FireBall_Passive:GetAvailableServerRPCs()
    return
end
--]]

return Projectile_FireBall_Passive