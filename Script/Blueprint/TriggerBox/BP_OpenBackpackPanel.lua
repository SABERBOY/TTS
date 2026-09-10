---@class BP_OpenBackpackPanel_C:BP_ExampleBase_C
---@field Widget1 UWidgetComponent
--Edit Below--
local BP_OpenBackpackPanel = {}
 
function BP_OpenBackpackPanel:CheckCanActive()
    print("BP_OpenBackpackPanel:CheckCanActive()")
    return true
end

function BP_OpenBackpackPanel:OnActive()
    print("BP_OpenBackpackPanel:OnActive()")
    UGCBackpackSystemV2.OpenBackpackPanelStyle(nil,2)
end


function BP_OpenBackpackPanel:ReceiveBeginPlay()
    BP_OpenBackpackPanel.SuperClass.ReceiveBeginPlay(self)
    if UGCGameSystem.IsServer() then
        return
    end
    self.Widget1.Widget.TextBlock_Title:SetText("仓库")
end
--]]

--[[
function BP_OpenBackpackPanel:ReceiveTick(DeltaTime)
    BP_OpenBackpackPanel.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function BP_OpenBackpackPanel:ReceiveEndPlay()
    BP_OpenBackpackPanel.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function BP_OpenBackpackPanel:GetReplicatedProperties()
    return
end
--]]

--[[
function BP_OpenBackpackPanel:GetAvailableServerRPCs()
    return
end
--]]

return BP_OpenBackpackPanel