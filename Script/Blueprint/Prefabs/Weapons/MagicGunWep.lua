---@class MagicGunWep_C:BP_UGC_MachineGun_PP19_C
--Edit Below--
local MagicGunWep = {}
 
--[[
function MagicGunWep:ReceiveBeginPlay()
    MagicGunWep.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function MagicGunWep:ReceiveTick(DeltaTime)
    MagicGunWep.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function MagicGunWep:ReceiveEndPlay()
    MagicGunWep.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function MagicGunWep:GetReplicatedProperties()
    return
end
--]]

--[[
function MagicGunWep:GetAvailableServerRPCs()
    return
end
--]]

return MagicGunWep