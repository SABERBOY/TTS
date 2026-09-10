---@class Projectile_Meteorite_C:PESkillProjectileBase
---@field Capsule UCapsuleComponent
---@field ParticleSystem UParticleSystemComponent
--Edit Below--
local Projectile_Meteorite = {}
 
--[[
function Projectile_Meteorite:ReceiveBeginPlay()
    Projectile_Meteorite.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function Projectile_Meteorite:ReceiveTick(DeltaTime)
    Projectile_Meteorite.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function Projectile_Meteorite:ReceiveEndPlay()
    Projectile_Meteorite.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function Projectile_Meteorite:GetReplicatedProperties()
    return
end
--]]

--[[
function Projectile_Meteorite:GetAvailableServerRPCs()
    return
end
--]]

return Projectile_Meteorite