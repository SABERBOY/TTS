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

    -- 刷传送点标题是纯客户端表现：DS 上 WidgetComponent 不会实例化 UUserWidget，
    -- 之前无条件执行导致服务端每个传送点都报一次 index a nil value（客户端一直正常）
    if UGCGameSystem.IsServer() then
        return
    end

    local TitleWidget = self.Widget and self.Widget.Widget
    if not TitleWidget or not TitleWidget.TextBlock_Title then
        print("BP_TransferNode:ReceiveBeginPlay Widget/TextBlock_Title 未配置，跳过标题设置")
        return
    end
    TitleWidget.TextBlock_Title:SetText(self.CategoryName)
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