---@class Throw_Plaguescale_C:PESkillProjectileBase
---@field Capsule UCapsuleComponent
---@field ParticleSystem UParticleSystemComponent
---@field StaticMesh UStaticMeshComponent
--Edit Below--
local Throw_Fire = {}
 
--[[
function Throw_Fire:ReceiveBeginPlay()
    Throw_Fire.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function Throw_Fire:ReceiveTick(DeltaTime)
    Throw_Fire.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function Throw_Fire:ReceiveEndPlay()
    Throw_Fire.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function Throw_Fire:GetReplicatedProperties()
    return
end
--]]

--[[
function Throw_Fire:GetAvailableServerRPCs()
    return
end
--]]

return Throw_Fire