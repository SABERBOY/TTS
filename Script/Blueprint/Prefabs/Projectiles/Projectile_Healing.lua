---@class Projectile_Healing_C:PESkillProjectileBase
---@field SkeletalMesh USkeletalMeshComponent
---@field Box UBoxComponent
--Edit Below--
local Projectile_Healing = {}
 
--[[
function Projectile_Healing:ReceiveBeginPlay()
    Projectile_Healing.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function Projectile_Healing:ReceiveTick(DeltaTime)
    Projectile_Healing.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function Projectile_Healing:ReceiveEndPlay()
    Projectile_Healing.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function Projectile_Healing:GetReplicatedProperties()
    return
end
--]]

--[[
function Projectile_Healing:GetAvailableServerRPCs()
    return
end
--]]

return Projectile_Healing