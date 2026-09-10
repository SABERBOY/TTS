---@class BP_TransferNode_C:AActor
---@field Widget UWidgetComponent
---@field StaticMesh UStaticMeshComponent
---@field DefaultSceneRoot USceneComponent
---@field CategoryName FString
---@field OrientCharacter bool
--Edit Below--
---@field Widget UWidgetComponent
local BP_TransferNode = {}
 
function BP_TransferNode:ReceiveBeginPlay()
    BP_TransferNode.SuperClass.ReceiveBeginPlay(self)
    self.Widget.Widget.TextBlock_Title:SetText(self.CategoryName)
end


function BP_TransferNode:ReceiveTick(DeltaTime)
    BP_TransferNode.SuperClass.ReceiveTick(self, DeltaTime)
    if self.OrientCharacter and not self:HasAuthority() then
        self:OrientToCharacter()
    end
end

function BP_TransferNode:OrientToCharacter()
    local Player = GameplayStatics.GetPlayerCharacter(self, 0)
    if Player then
        local PlayerLocation = Player:K2_GetActorLocation()
        local Location = self:K2_GetActorLocation()
        PlayerLocation.Z = 0
        Location.Z = 0
        local TargetRot = UGCMathUtility.FindLookAtRotation(Location, PlayerLocation)
        self:K2_SetActorRotation(TargetRot, false)
    end
end

--[[
function BP_TransferNode:ReceiveEndPlay()
    BP_TransferNode.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function BP_TransferNode:GetReplicatedProperties()
    return
end
--]]

--[[
function BP_TransferNode:GetAvailableServerRPCs()
    return
end
--]]

return BP_TransferNode