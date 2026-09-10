---@class Projectile_GuidedStrike_LowPower_C:PESkillProjectileBase
---@field Capsule UCapsuleComponent
---@field ParticleSystem UParticleSystemComponent
---@field StaticMesh UStaticMeshComponent
--Edit Below--
local Projectile_GuidedStrike_LowPower = {}
 
--[[
function Projectile_GuidedStrike_LowPower:ReceiveBeginPlay()
    Projectile_GuidedStrike_LowPower.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function Projectile_GuidedStrike_LowPower:ReceiveTick(DeltaTime)
    Projectile_GuidedStrike_LowPower.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function Projectile_GuidedStrike_LowPower:ReceiveEndPlay()
    Projectile_GuidedStrike_LowPower.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function Projectile_GuidedStrike_LowPower:GetReplicatedProperties()
    return
end
--]]

--[[
function Projectile_GuidedStrike_LowPower:GetAvailableServerRPCs()
    return
end
--]]

return Projectile_GuidedStrike_LowPower