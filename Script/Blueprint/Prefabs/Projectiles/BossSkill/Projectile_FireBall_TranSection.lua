---@class Projectile_FireBall_TranSection_C:PESkillProjectileBase
---@field Capsule UCapsuleComponent
---@field ParticleSystem UParticleSystemComponent
---@field StaticMesh UStaticMeshComponent
--Edit Below--
local Projectile_FireBall_TranSection = {}
 
--[[
function Projectile_FireBall_TranSection:ReceiveBeginPlay()
    Projectile_FireBall_TranSection.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function Projectile_FireBall_TranSection:ReceiveTick(DeltaTime)
    Projectile_FireBall_TranSection.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function Projectile_FireBall_TranSection:ReceiveEndPlay()
    Projectile_FireBall_TranSection.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function Projectile_FireBall_TranSection:GetReplicatedProperties()
    return
end
--]]

--[[
function Projectile_FireBall_TranSection:GetAvailableServerRPCs()
    return
end
--]]

return Projectile_FireBall_TranSection