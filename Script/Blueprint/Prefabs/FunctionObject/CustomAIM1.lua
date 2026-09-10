---@class CustomAIM1_C:BP_WFM_UGC_HUD_C
--Edit Below--
local CustomAIM1 = {}
 
--[[
function CustomAIM1:ReceiveBeginPlay()
    CustomAIM1.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function CustomAIM1:ReceiveTick(DeltaTime)
    CustomAIM1.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function CustomAIM1:ReceiveEndPlay()
    CustomAIM1.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function CustomAIM1:GetReplicatedProperties()
    return
end
--]]

--[[
function CustomAIM1:GetAvailableServerRPCs()
    return
end
--]]

return CustomAIM1