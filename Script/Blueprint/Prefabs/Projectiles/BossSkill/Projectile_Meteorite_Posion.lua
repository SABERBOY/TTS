---@class Projectile_Meteorite_Posion_C:PESkillProjectileBase
---@field Capsule UCapsuleComponent
---@field ParticleSystem UParticleSystemComponent
--Edit Below--
local Projectile_Meteorite_Posion = {}
 
--[[
function Projectile_Meteorite_Posion:ReceiveBeginPlay()
    Projectile_Meteorite_Posion.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function Projectile_Meteorite_Posion:ReceiveTick(DeltaTime)
    Projectile_Meteorite_Posion.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function Projectile_Meteorite_Posion:ReceiveEndPlay()
    Projectile_Meteorite_Posion.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function Projectile_Meteorite_Posion:GetReplicatedProperties()
    return
end
--]]

--[[
function Projectile_Meteorite_Posion:GetAvailableServerRPCs()
    return
end
--]]

return Projectile_Meteorite_Posion