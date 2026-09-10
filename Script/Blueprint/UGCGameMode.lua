---@class UGCGameMode_C:BP_UGCGameBase_C
--Edit Below--
local UGCGameMode = {
    TransferNodeTable = {}
}

function UGCGameMode:ReceiveBeginPlay()
    UGCGameMode.SuperClass.ReceiveBeginPlay(self)


    UGCGenericMessageSystem.ListenGlobalMessage(self, UGCGenericMessageSystem.Messages.UGC.Game.GameStart, self, self.OnGameStart)
    UGCGenericMessageSystem.ListenGlobalMessage(self, UGCGenericMessageSystem.Messages.UGC.Game.GameEnd, self, self.OnGameEnd)
    UGCGenericMessageSystem.ListenGlobalMessage(self, UGCGenericMessageSystem.Messages.UGC.PlayerPawn.PawnRespawn, self, self.OnPawnRespawn)
    UGCGenericMessageSystem.ListenGlobalMessage(self, UGCGenericMessageSystem.Messages.UGC.PlayerPawn.PawnDefeat, self, self.OnPawnDefeat)
end

function UGCGameMode:OnPawnRespawn(InPlayerKey)
    print("UGCGameMode:OnPawnRespawn InPlayerKey="..InPlayerKey)

    -- 重新绑定属性HUD到Respawn的Pawn上
    local RespawnPlayerController = UGCGameSystem.GetPlayerControllerByPlayerKey(InPlayerKey)
    if RespawnPlayerController then
        UnrealNetwork.CallUnrealRPC(RespawnPlayerController, RespawnPlayerController, "Client_UpdateAttriHUD")
    end

    local PlayerKey = self.WorldBase.GamePlayPlayers[InPlayerKey]
    if PlayerKey and PlayerKey == InPlayerKey then
        local PlayerController = UGCGameSystem.GetPlayerControllerByPlayerKey(PlayerKey)
        if PlayerController then
            local TargetPos = self.WorldBase:K2_GetActorLocation()
            UGCPlayerControllerSystem.TeleportTo(PlayerController, TargetPos.X, TargetPos.Y, TargetPos.Z+350)

            UnrealNetwork.CallUnrealRPC(PlayerController, PlayerController, "Client_OnPawnRespawn")

            self.WorldBase:InfiniteBullet()
        end
    end
    
end


function UGCGameMode:OnPawnDefeat(InVictimerKey, InKillerKey, InDamageType)
    print("UGCGameMode:OnPawnDefeat InVictimerKey="..InVictimerKey.." InKillerKey="..InKillerKey.." InDamageType="..InDamageType)
    
    local Victimer = UGCGameSystem.GetPlayerControllerByPlayerKey(InVictimerKey)
    local Killer = UGCGameSystem.GetPlayerControllerByPlayerKey(InKillerKey)

    local RespawnComponent = UGCGameSystem.GetRespawnComponent()
    if RespawnComponent then
        RespawnComponent:RemoveRespawnPlayer(Victimer.PlayerKey)
        RespawnComponent:AddRespawnPlayerWithTime(Victimer.PlayerKey, 0.1)
    end
end

function UGCGameMode:OnGameStart()
    self.TransferNodeTable = UGCActorComponentUtility.GetAllActorsOfClass(self, UGCObjectUtility.LoadClass(UGCGameSystem.GetUGCResourcesFullPath('Asset/Blueprint/TriggerBox/BP_TransferNode.BP_TransferNode_C')))
    print("UGCGameMode:OnGameStart TransferNodeTable = ".. #self.TransferNodeTable)
end

function UGCGameMode:OnGameEnd()
    print("UGCGameMode:OnGameEnd")
end


return UGCGameMode