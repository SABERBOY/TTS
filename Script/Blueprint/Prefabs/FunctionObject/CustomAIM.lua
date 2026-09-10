---@class CustomAIM_C:BP_WFM_UGC_HUD_C
--Edit Below--
local CustomAIM = {}
 
--[[
function CustomAIM:ReceiveBeginPlay()
    CustomAIM.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function CustomAIM:ReceiveTick(DeltaTime)
    CustomAIM.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function CustomAIM:ReceiveEndPlay()
    CustomAIM.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function CustomAIM:GetReplicatedProperties()
    return
end
--]]

--[[
function CustomAIM:GetAvailableServerRPCs()
    return
end
--]]

return CustomAIM