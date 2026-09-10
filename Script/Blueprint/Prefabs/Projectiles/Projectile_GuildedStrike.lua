---@class Projectile_GuildedStrike_C:PESkillProjectileBase
---@field Capsule UCapsuleComponent
---@field ParticleSystem UParticleSystemComponent
---@field StaticMesh UStaticMeshComponent
--Edit Below--
local Projectile_GuildedStrike = {}
 
--[[
function Projectile_GuildedStrike:ReceiveBeginPlay()
    Projectile_GuildedStrike.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function Projectile_GuildedStrike:ReceiveTick(DeltaTime)
    Projectile_GuildedStrike.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function Projectile_GuildedStrike:ReceiveEndPlay()
    Projectile_GuildedStrike.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function Projectile_GuildedStrike:GetReplicatedProperties()
    return
end
--]]

--[[
function Projectile_GuildedStrike:GetAvailableServerRPCs()
    return
end
--]]

return Projectile_GuildedStrike