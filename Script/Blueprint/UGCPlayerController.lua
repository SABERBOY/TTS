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

    -- 服务端：绑定装备槽位强化属性应用器（ReceiveBeginPlay 时 Pawn 可能尚未生成，带重试）
    if self:HasAuthority() then
        local EquipSlotAttrApplier = require('Script.Common.EquipSlotAttrApplier')
        local Controller = self
        local Retries = 0
        local function TryBind()
            local Pawn = Controller:GetPlayerCharacterSafety()
            if Pawn then
                EquipSlotAttrApplier.BindPlayer(Pawn)
                return
            end
            Retries = Retries + 1
            if Retries <= 40 and UGCGameSystem.SetTimer then
                UGCGameSystem.SetTimer(Controller, TryBind, 0.25, false)
            end
        end
        TryBind()
    end
end

function UGCPlayerController:ReceiveEndPlay()
    if self:HasAuthority() then
        local EquipSlotAttrApplier = require('Script.Common.EquipSlotAttrApplier')
        local Pawn = self:GetPlayerCharacterSafety()
        if Pawn then
            EquipSlotAttrApplier.UnbindPlayer(Pawn)
        end
    end
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
        "Client_OnMonsterWaveStart", "Server_OnHeroSelectionFinished", "ServerRPC_AddItemWithInstanceData",
        "ServerRPC_StrengthenEquipSlot", "ServerRPC_GMAddItem";
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


-- 装备槽位强化（ 装备系统：强化的是永久槽位/装备框，不是装备本体）
-- 服务端事务：校验槽位与余额 → 扣金币+装备零件 → 提升 UGCPlayerState.EquipSlotLevels（复制属性）
function UGCPlayerController:ServerRPC_StrengthenEquipSlot(SlotIdx, BatchCount)
    local EquipSlotSystem = require('Script.Common.EquipSlotSystem')
    local CurPlayerState = self:GetCurPlayerState()
    local PlayerPawn = self:GetPlayerCharacterSafety()
    if not CurPlayerState or not PlayerPawn then
        return
    end
    local OK, ErrCode, NewLevel = EquipSlotSystem.ServerTryStrengthen(CurPlayerState, PlayerPawn, SlotIdx, BatchCount or 1)
    print(string.format("ServerRPC_StrengthenEquipSlot Slot=%s Count=%s OK=%s Err=%s NewLevel=%s",
        tostring(SlotIdx), tostring(BatchCount), tostring(OK), tostring(ErrCode), tostring(NewLevel)))
end

---GM：添加物品。ItemID=0 时加第一货币（金币）
function UGCPlayerController:ServerRPC_GMAddItem(ItemID, Count)
    ItemID = tonumber(ItemID)
    Count = math.floor(tonumber(Count) or 1)
    if Count <= 0 then
        Count = 1
    end
    if not ItemID or ItemID == 0 then
        local EquipSlotSystem = require('Script.Common.EquipSlotSystem')
        ItemID = EquipSlotSystem.GetGoldItemID(self)
    end
    if not ItemID then
        print('[GM] ServerRPC_GMAddItem: no ItemID')
        return
    end
    local OK, Err = pcall(function()
        UGCBackpackSystemV2.AddItemV2(self, ItemID, Count)
    end)
    print(string.format('[GM] ServerRPC_GMAddItem ItemID=%s Count=%s ok=%s err=%s',
        tostring(ItemID), tostring(Count), tostring(OK), tostring(Err)))
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
