---@class Projectile_Hydra_C:PESkillProjectileBase
---@field Capsule UCapsuleComponent
---@field ParticleSystem UParticleSystemComponent
---@field StaticMesh UStaticMeshComponent
--Edit Below--
local Projectile_Hydra = {}
 
--[[
function Projectile_Hydra:ReceiveBeginPlay()
    Projectile_Hydra.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function Projectile_Hydra:ReceiveTick(DeltaTime)
    Projectile_Hydra.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function Projectile_Hydra:ReceiveEndPlay()
    Projectile_Hydra.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function Projectile_Hydra:GetReplicatedProperties()
    return
end
--]]

--[[
function Projectile_Hydra:GetAvailableServerRPCs()
    return
end
--]]

return Projectile_Hydra