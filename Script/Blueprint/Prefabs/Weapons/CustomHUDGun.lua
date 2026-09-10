---@class CustomHUDGun_C:BP_UGC_Rifle_AKM_C
--Edit Below--
local CustomHUDGun = {}
 
--[[
function CustomHUDGun:ReceiveBeginPlay()
    CustomHUDGun.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function CustomHUDGun:ReceiveTick(DeltaTime)
    CustomHUDGun.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function CustomHUDGun:ReceiveEndPlay()
    CustomHUDGun.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function CustomHUDGun:GetReplicatedProperties()
    return
end
--]]

--[[
function CustomHUDGun:GetAvailableServerRPCs()
    return
end
--]]

return CustomHUDGun