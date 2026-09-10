---@class UGCPlayerController_C:BP_UGCPlayerController_C
--Edit Below--
---@class UGCPlayerController_C: BP_UGCPlayerController_C
-- Edit Below--
local UGCPlayerController = {
    Main_GameWidget = nil,
    AttrHUDWidget = nil,
    GamePlay_BattleResultsWidget = nil,
    IsHeroSelected = false,
    UGCHeroDescBackup = nil
}

function UGCPlayerController:ReceiveBeginPlay()
    UGCPlayerController.SuperClass.ReceiveBeginPlay(self)

    -- 注册物品属性读取重写（需在服务器和客户端都注册才能生效）
    -- 传入 HasAuthority 标记当前是否在服务器（权威）端，便于日志区分注册环境
    local UGCGameData = require('Script.Blueprint.UGCGameData')
    UGCGameData.RegisterItemPropertyOverrides(self:HasAuthority())

    if not self:HasAuthority() then
        local GameHUDClass = UE.LoadClass(
            UGCGameSystem.GetUGCResourcesFullPath('Asset/Blueprint/UMG/GameHUD.GameHUD_C')
        )
        self.Main_GameWidget = UserWidget.NewWidgetObjectBP(self, GameHUDClass)
        self.Main_GameWidget:AddToViewport()
    end

    self:GetCurPlayerState():InitPlayerState(self)
end

function UGCPlayerController:ReceiveEndPlay()
    UGCPlayerController.SuperClass.ReceiveEndPlay(self)
end

function UGCPlayerController:Client_SetAttriHUD()
end

function UGCPlayerController:Client_UpdateAttriHUD()
    ugcprint("UGCPlayerController:Client_UpdateAttriHUD()")
    if self.AttrHUDWidget then
        self.AttrHUDWidget:RemoveFromParent()
        self.AttrHUDWidget = nil
    end
    self:Client_SetAttriHUD()
end

function UGCPlayerController:ReceiveTick(DeltaTime)
    UGCPlayerController.SuperClass.ReceiveTick(self, DeltaTime)
end

-- 备份初始的英雄描述文本
function UGCPlayerController:Client_InitUGCHeroDescBackup()
    ugcprint("UGCPlayerController:Client_InitUGCHeroDescBackup()")
end

function UGCPlayerController:Client_OnPawnRespawn()
    print("UGCPlayerController:Client_OnPawnRespawn")
    -- 隐藏属性UI
    if self.AttrHUDWidget then
        self.AttrHUDWidget:SetVisibility(ESlateVisibility.Collapsed)
    end
end

function UGCPlayerController:Server_OnHeroSelectionFinished(SelectedHeroID)
    if SelectedHeroID ~= nil then
        self:GetCurPlayerState():OnHeroSelectionFinished(SelectedHeroID)
        self.IsHeroSelected = true
    end
end

function UGCPlayerController:GetReplicatedProperties()
    return
end

function UGCPlayerController:GetAvailableServerRPCs()
    return "ServerTeleportTo", "ServerRPC_StartCircle", "Client_OnPawnRespawn", "ServerRPC_ChangeAttr",
        "Client_OnMonsterWaveStart", "Server_OnHeroSelectionFinished", "ServerRPC_AddItemWithInstanceData"
end

-- GM按钮
function UGCPlayerController:ServerTeleportTo(TargetString)
    print("UGCPlayerController:ServerTeleport TargetString=" .. TargetString)
    if not UGCGameSystem.GameMode then
        return
    end
    for _, TransferNode in pairs(UGCGameSystem.GameMode.TransferNodeTable) do
        if TransferNode and TransferNode.CategoryName == TargetString then
            local TargetPos = TransferNode:K2_GetActorLocation()
            UGCPlayerControllerSystem.TeleportTo(self, TargetPos.X + 300, TargetPos.Y - 300, TargetPos.Z + 300)
        end
    end
end

-- 毒圈
function UGCPlayerController:ServerRPC_StartCircle()
    print("UGCPlayerController:ServerRPC_StartCircle")
    if not UGCGameSystem.GameMode then
        return
    end

    UGCCircleManagerSystem.StartCircle()
end

-- 修改属性
function UGCPlayerController:ServerRPC_ChangeAttr(AttrOwner, AttrName, Operation, Value)
    print(string.format("ChangeAttr: AttrName[%s], Operation[%s], Value[%f]", AttrName, Operation, Value))
    UGCAttributeSystem.AddGameAttributeOperation(AttrOwner, AttrName, EAttrOperator[Operation], Value)
end


-- GamePlay Start
function UGCPlayerController:Client_OnGameBeginPlay()
    self.Main_GameWidget.TextBlock_MonsterWave:SetVisibility(ESlateVisibility.Visible)
    self.Main_GameWidget.TopButtons:SetVisibility(ESlateVisibility.Collapsed)
    self:Client_OnPawnRespawn()
end

-- GamePlay Reset
function UGCPlayerController:Client_OnGameReset()
    self.Main_GameWidget.TopButtons:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
    if self.GamePlay_BattleResultsWidget then
        self.GamePlay_BattleResultsWidget:RemoveFromViewport()
    end
end

return UGCPlayerController
