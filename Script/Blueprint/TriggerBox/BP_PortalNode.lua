---@class BP_PortalNode_C:AActor
---@field ClickActorComponentBase UClickActorComponentBase
---@field Box UBoxComponent
---@field ParticleSystem UParticleSystemComponent
---@field DefaultSceneRoot USceneComponent
---@field Targer BP_TransferNode_C
--Edit Below--
local BP_PortalNode = {}
-- -@field ClickActorComponentBase UClickActorComponentBase

--[[
function BP_PortalNode:ReceiveBeginPlay()
    BP_PortalNode.SuperClass.ReceiveBeginPlay(self)
end
--]]

function BP_PortalNode:CheckCanActive(ClickParam)
    return true;
end

function BP_PortalNode:TeleportTo_Weapon()
    local PC = UGCGameSystem.GetLocalPlayerController()
    UnrealNetwork.CallUnrealRPC(PC, PC, "ServerTeleportTo", "武器")
end

function BP_PortalNode:TeleportTo_Monster()
    local PC = UGCGameSystem.GetLocalPlayerController()
    UnrealNetwork.CallUnrealRPC(PC, PC, "ServerTeleportTo", "怪物")
end

function BP_PortalNode:TeleportTo_Skill()
    local PC = UGCGameSystem.GetLocalPlayerController()
    UnrealNetwork.CallUnrealRPC(PC, PC, "ServerTeleportTo", "技能")
end

function BP_PortalNode:TeleportTo_Buff()
    local PC = UGCGameSystem.GetLocalPlayerController()
    UnrealNetwork.CallUnrealRPC(PC, PC, "ServerTeleportTo", "Buff")
end

function BP_PortalNode:TeleportTo_Item()
    local PC = UGCGameSystem.GetLocalPlayerController()
    UnrealNetwork.CallUnrealRPC(PC, PC, "ServerTeleportTo", "物品")
end

function BP_PortalNode:TeleportTo_Instance()
    local PC = UGCGameSystem.GetLocalPlayerController()
    UnrealNetwork.CallUnrealRPC(PC, PC, "ServerTeleportTo", "物品实例")  
end

function BP_PortalNode:TeleportTo_Tween()
    local PC = UGCGameSystem.GetLocalPlayerController()
    UnrealNetwork.CallUnrealRPC(PC, PC, "ServerTeleportTo", "Tween")  
end



return BP_PortalNode