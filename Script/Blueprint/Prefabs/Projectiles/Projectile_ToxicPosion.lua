---@class Projectile_ToxicPosion_C:PESkillProjectileBase
---@field ParticleSystem UParticleSystemComponent
---@field StaticMesh UStaticMeshComponent
---@field Sphere USphereComponent
--Edit Below--
local Projectile_ToxicPosion = {}
 
--[[
function Projectile_ToxicPosion:ReceiveBeginPlay()
    Projectile_ToxicPosion.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function Projectile_ToxicPosion:ReceiveTick(DeltaTime)
    Projectile_ToxicPosion.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function Projectile_ToxicPosion:ReceiveEndPlay()
    Projectile_ToxicPosion.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function Projectile_ToxicPosion:GetReplicatedProperties()
    return
end
--]]

--[[
function Projectile_ToxicPosion:GetAvailableServerRPCs()
    return
end
--]]

return Projectile_ToxicPosion