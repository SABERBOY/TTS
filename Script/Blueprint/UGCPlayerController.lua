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

    -- 客户端 ReceiveBeginPlay 时 PlayerState 可能还没就绪（GetCurPlayerState 返回 nil），
    -- 直接 :InitPlayerState 会 index nil；沿用下面 TryBind 的重试轮询等它就绪
    local InitRetries = 0
    local function TryInitPlayerState()
        local PlayerState = self:GetCurPlayerState()
        print("[UGCPlayerController] GetCurPlayerState PlayerState:".. tostring(PlayerState==nil))
        if PlayerState then
            PlayerState:InitPlayerState(self)
            return
        end
        InitRetries = InitRetries + 1
        if InitRetries > 40 then
            print("[UGCPlayerController] GetCurPlayerState 始终为 nil，放弃 InitPlayerState")
            return
        end
        if UGCGameSystem.SetTimer then
            UGCGameSystem.SetTimer(self, TryInitPlayerState, 0.25, false)
        end
    end
    TryInitPlayerState()

    -- 服务端：绑定装备槽位强化属性应用器（ReceiveBeginPlay 时 Pawn 可能尚未生成，带重试）
    if self:HasAuthority() then
        local EquipSlotAttrApplier = require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotAttrApplier')
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
    if self.BossWarningTimer and UGCGameSystem and UGCGameSystem.ClearTimer then
        UGCGameSystem.ClearTimer(self, self.BossWarningTimer)
        self.BossWarningTimer = nil
    end
    self.BossWarningTimerDelegate = nil
    self.BossWarningEntries = nil
    if self:HasAuthority() then
        require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceRuntime').Release(self)
        local EquipSlotAttrApplier = require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotAttrApplier')
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
        "ServerRPC_StrengthenEquipSlot", "ServerRPC_GMAddItem", "ServerRPC_NotifyEquipSlotChanged",
        "ServerRPC_GMSummonMonster", "ServerRPC_EquipAdvancePreview", "ServerRPC_EquipAdvanceCommit",
        "ServerRPC_EquipAdvanceGM";
end

-- Existing GameMode calls the first two methods through UnrealNetwork.CallUnrealRPC.
function UGCPlayerController:GetAvailableClientRPCs()
    return "Client_UpdateAttriHUD", "Client_OnPawnRespawn",
        "Client_BossWarning", "Client_BossWarningStop", "Client_EquipAdvanceResult"
end

-- Advancement owns validation/transactions. Controller only routes owned RPCs.
function UGCPlayerController:ServerRPC_EquipAdvancePreview(TargetKey, MaterialKeys)
    if not self:HasAuthority() then return end
    require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceRPC').Preview(self, TargetKey, MaterialKeys)
end

function UGCPlayerController:ServerRPC_EquipAdvanceCommit(Token, RequestID, Confirmed)
    if not self:HasAuthority() then return end
    require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceRPC').Commit(self, Token, RequestID, Confirmed)
end

function UGCPlayerController:ServerRPC_EquipAdvanceGM(Action, Args)
    if not self:HasAuthority() then return end
    require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceRPC').GM(self, Action, Args)
end

function UGCPlayerController:Client_EquipAdvanceResult(Result)
    require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceClient').Receive(Result)
end

local WARNING_INTERVAL = 0.1
local WARNING_STROKE_LIFE = 0.12
local WARNING_DANGER = { R = 1, G = 0.15, B = 0.05, A = 1 }
local WARNING_SAFE = { R = 0.12, G = 1, B = 0.22, A = 1 }
local WARNING_PROJECTILE = { R = 1, G = 0.55, B = 0.08, A = 1 }

local function WarningVector(x, y, z)
    return { X = x, Y = y, Z = z }
end

local function WarningFinite(value)
    return type(value) == 'number' and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function WarningLine(a, b, color)
    UGCDebugSystem.DrawDebugLine(a, b, color, WARNING_STROKE_LIFE)
end

local function WarningYaw(dx, dy)
    if math.atan2 then return math.deg(math.atan2(dy, dx)) end
    if dx == 0 then return dy >= 0 and 90 or -90 end
    local yaw = math.deg(math.atan(dy / dx))
    if dx < 0 then yaw = yaw + (dy >= 0 and 180 or -180) end
    return yaw
end

local function WarningPoint(warning, angleDeg, distance)
    local radians = math.rad(angleDeg)
    local c, s = math.cos(radians), math.sin(radians)
    return WarningVector(warning.x + (warning.dirX * c - warning.dirY * s) * distance,
        warning.y + (warning.dirX * s + warning.dirY * c) * distance, warning.z)
end

local function WarningArc(warning, firstAngle, lastAngle, distance, color)
    if lastAngle <= firstAngle then return end
    local segments = math.max(1, math.ceil((lastAngle - firstAngle) / 10))
    local previous = WarningPoint(warning, firstAngle, distance)
    for i = 1, segments do
        local current = WarningPoint(warning,
            firstAngle + (lastAngle - firstAngle) * i / segments, distance)
        WarningLine(previous, current, color)
        previous = current
    end
end

local function DrawBossWarning(warning, now)
    if not UGCDebugSystem then return end
    local center = WarningVector(warning.x, warning.y, warning.z)
    if warning.kind == 2 or warning.kind == 5 then
        -- The UGC API defaults to YZ axes, so XY ground axes are mandatory.
        UGCDebugSystem.DrawDebugCircle(center, warning.radius, WARNING_DANGER,
            WARNING_STROKE_LIFE, WarningVector(1, 0, 0), WarningVector(0, 1, 0), false)
    elseif warning.kind == 3 then
        local halfLength = warning.length * 0.5
        local middle = WarningVector(warning.x + warning.dirX * halfLength,
            warning.y + warning.dirY * halfLength, warning.z)
        UGCDebugSystem.DrawDebugBox(middle,
            WarningVector(halfLength, warning.radius, 4),
            { Pitch = 0, Yaw = WarningYaw(warning.dirX, warning.dirY), Roll = 0 },
            WARNING_DANGER, WARNING_STROKE_LIFE)
        WarningLine(center, WarningPoint(warning, 0, warning.length), WARNING_DANGER)
    elseif warning.kind == 4 then
        -- Visual prediction only. The server remains authoritative for traces,
        -- hit timing and damage, and sends Stop when this projectile ends.
        local elapsed = math.max(0, math.min(now - warning.startedAt, warning.duration))
        local travelled = warning.length * elapsed / warning.duration
        local projectile = WarningPoint(warning, 0, travelled)
        UGCDebugSystem.DrawDebugBox(projectile,
            WarningVector(warning.radius, warning.radius, warning.radius),
            { Pitch = 0, Yaw = WarningYaw(warning.dirX, warning.dirY), Roll = 0 },
            WARNING_PROJECTILE, WARNING_STROKE_LIFE)
        local ahead = math.min(warning.length - travelled, warning.radius * 3)
        if ahead > 0 then
            WarningLine(projectile, WarningPoint(warning, 0, travelled + ahead),
                WARNING_PROJECTILE)
        end
    elseif warning.kind == 6 or warning.kind == 7 then
        local firstAngle = warning.kind == 6 and -60 or -180
        local lastAngle = warning.kind == 6 and 60 or 180
        local distance = warning.kind == 6 and warning.length or warning.radius
        local gapStart = math.max(firstAngle, warning.gapCenter - warning.gapHalf)
        local gapEnd = math.min(lastAngle, warning.gapCenter + warning.gapHalf)
        WarningArc(warning, firstAngle, gapStart, distance, WARNING_DANGER)
        WarningArc(warning, gapEnd, lastAngle, distance, WARNING_DANGER)
        WarningArc(warning, gapStart, gapEnd, distance, WARNING_SAFE)
        if warning.kind == 6 then
            WarningLine(center, WarningPoint(warning, firstAngle, distance), WARNING_DANGER)
            WarningLine(center, WarningPoint(warning, lastAngle, distance), WARNING_DANGER)
        end
        for angle = firstAngle + 30, lastAngle - 1, 30 do
            if angle < gapStart or angle > gapEnd then
                WarningLine(center, WarningPoint(warning, angle, distance), WARNING_DANGER)
            end
        end
        WarningLine(center, WarningPoint(warning, gapStart, distance), WARNING_SAFE)
        WarningLine(center, WarningPoint(warning, gapEnd, distance), WARNING_SAFE)
        WarningLine(center, WarningPoint(warning, warning.gapCenter, distance), WARNING_SAFE)
    end
end

local function HasBossWarnings(self)
    for _, actions in pairs(self.BossWarningEntries or {}) do
        for _, shapes in pairs(actions) do
            if next(shapes) ~= nil then return true end
        end
    end
    return false
end

local function StopBossWarningTimer(self)
    if self.BossWarningTimer then
        UGCGameSystem.ClearTimer(self, self.BossWarningTimer)
        self.BossWarningTimer = nil
    end
    self.BossWarningTimerDelegate = nil
end

local function PulseBossWarnings(self)
    local now = UGCGameSystem.GetTimeSeconds(self)
    for bossKey, actions in pairs(self.BossWarningEntries or {}) do
        for actionId, shapes in pairs(actions) do
            for shapeIndex, warning in pairs(shapes) do
                if now >= warning.expiresAt then
                    shapes[shapeIndex] = nil
                else
                    DrawBossWarning(warning, now)
                end
            end
            if next(shapes) == nil then actions[actionId] = nil end
        end
        if next(actions) == nil then self.BossWarningEntries[bossKey] = nil end
    end
    if not HasBossWarnings(self) then StopBossWarningTimer(self) end
end

-- All RPC payload fields are primitives. Duration is relative to this client's
-- receive time; server and client world clocks do not need to be synchronized.
function UGCPlayerController:Client_BossWarning(bossKey, actionId, shapeIndex, kindCode,
    x, y, z, radius, durationSeconds, dirX, dirY, length, gapCenterDeg, gapHalfDeg)
    if type(bossKey) ~= 'string' or bossKey == '' then return end
    local values = { actionId, shapeIndex, kindCode, x, y, z, radius,
        durationSeconds, dirX, dirY, length, gapCenterDeg, gapHalfDeg }
    for i = 1, 13 do
        if not WarningFinite(values[i]) then return end
    end
    if actionId < 0 or actionId % 1 ~= 0 or shapeIndex % 1 ~= 0
        or (kindCode == 4 and (shapeIndex < 101 or shapeIndex > 199))
        or (kindCode ~= 4 and (shapeIndex < 1 or shapeIndex > 3))
        or (kindCode ~= 2 and kindCode ~= 3 and kindCode ~= 4 and kindCode ~= 5
            and kindCode ~= 6 and kindCode ~= 7)
        or durationSeconds <= 0 or durationSeconds > 30 then return end
    if kindCode == 4 and durationSeconds > 2 then return end
    if (kindCode == 2 or kindCode == 3 or kindCode == 4
        or kindCode == 5 or kindCode == 7)
        and radius <= 0 then return end
    if (kindCode == 3 or kindCode == 4 or kindCode == 6) and length <= 0 then return end
    if (kindCode == 6 or kindCode == 7)
        and (gapHalfDeg <= 0 or gapHalfDeg > 180) then return end

    local directionLength = math.sqrt(dirX * dirX + dirY * dirY)
    if (kindCode == 3 or kindCode == 4 or kindCode == 6 or kindCode == 7)
        and directionLength < 0.001 then
        return
    end
    if directionLength >= 0.001 then
        dirX, dirY = dirX / directionLength, dirY / directionLength
    end
    local now = UGCGameSystem.GetTimeSeconds(self)
    self.BossWarningEntries = self.BossWarningEntries or {}
    local actions = self.BossWarningEntries[bossKey] or {}
    self.BossWarningEntries[bossKey] = actions
    local shapes = actions[actionId] or {}
    actions[actionId] = shapes
    local warning = {
        kind = kindCode, x = x, y = y, z = z, radius = radius,
        dirX = dirX, dirY = dirY, length = length,
        gapCenter = gapCenterDeg, gapHalf = gapHalfDeg,
        startedAt = now, duration = durationSeconds,
        expiresAt = now + durationSeconds,
    }
    shapes[shapeIndex] = warning
    DrawBossWarning(warning, now)
    if not self.BossWarningTimer then
        local controller = self
        local timer, delegate = UGCGameSystem.SetTimer(self, function()
            PulseBossWarnings(controller)
        end, WARNING_INTERVAL, true)
        self.BossWarningTimer = timer
        self.BossWarningTimerDelegate = delegate
    end
end

function UGCPlayerController:Client_BossWarningStop(bossKey, actionId, shapeIndex)
    if type(bossKey) ~= 'string' or not WarningFinite(actionId)
        or not WarningFinite(shapeIndex) then return end
    local actions = self.BossWarningEntries and self.BossWarningEntries[bossKey]
    local shapes = actions and actions[actionId]
    if not shapes then return end
    shapes[shapeIndex] = nil
    if next(shapes) == nil then actions[actionId] = nil end
    if next(actions) == nil then self.BossWarningEntries[bossKey] = nil end
    if not HasBossWarnings(self) then StopBossWarningTimer(self) end
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
    local EquipSlotSystem = require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotSystem')
    local CurPlayerState = self:GetCurPlayerState()
    local PlayerPawn = self:GetPlayerCharacterSafety()
    if not CurPlayerState or not PlayerPawn then
        return
    end
    local OK, ErrCode, NewLevel = EquipSlotSystem.ServerTryStrengthen(CurPlayerState, PlayerPawn, SlotIdx, BatchCount or 1)
    print(string.format("ServerRPC_StrengthenEquipSlot Slot=%s Count=%s OK=%s Err=%s NewLevel=%s",
        tostring(SlotIdx), tostring(BatchCount), tostring(OK), tostring(ErrCode), tostring(NewLevel)))
end

-- 服务端：客户端上报"装备槽发生变化"，重算该槽（或全量）槽位强化加成。
-- 这是**第二道保险**：
--   主保险 = EquipSlotAttrApplier 在服务端启的 0.25s 装备快照轮询（内核装备委托在 DS 不广播）；
--   此入口由客户端侧的装备变化委托驱动（该委托在客户端会广播，实测穿戴/卸下各一次），
--   作用是：客户端发起换装后回退更快，且万一轮询定时器失守时属性仍能被纠正。
-- @param SlotName string 内核槽位名（如 EquipmentSlot.Common.Head），空串/未识别时做全量重算
function UGCPlayerController:ServerRPC_NotifyEquipSlotChanged(SlotName)
    local EquipSlotAttrApplier = require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotAttrApplier')
    local PlayerPawn = self:GetPlayerCharacterSafety()
    if not PlayerPawn then
        return
    end
    if type(SlotName) ~= 'string' or SlotName == '' then
        SlotName = nil
    end
    print(string.format('[EquipNotify] server recalc equip slot attr SlotName=%s', tostring(SlotName)))
    EquipSlotAttrApplier.OnEquipChanged(PlayerPawn, SlotName)
end

---GM：添加物品。ItemID=0 时加第一货币（金币）
function UGCPlayerController:ServerRPC_GMAddItem(ItemID, Count)
    ItemID = tonumber(ItemID)
    Count = math.floor(tonumber(Count) or 1)
    if Count <= 0 then
        Count = 1
    end
    if not ItemID or ItemID == 0 then
        local EquipSlotSystem = require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotSystem')
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


---GM：一键召唤超级怪物到玩家身边。
---优先把场景里已有的 SuperMonster 传送到玩家脚下；没有则直接在玩家位置生成一只；
---最后把玩家写入怪物的黑板 Target，让它立即进入战斗追击。
function UGCPlayerController:ServerRPC_GMSummonMonster()
    local PlayerPawn = self:GetPlayerCharacterSafety()
    if not PlayerPawn then
        print('[GM] ServerRPC_GMSummonMonster: no PlayerPawn')
        return
    end

    local MonsterClass = UE.LoadClass('/TTS/Asset/Blueprint/Prefabs/Monsters/SuperMonster.SuperMonster_C')
    if not MonsterClass then
        print('[GM] ServerRPC_GMSummonMonster: load SuperMonster class failed')
        return
    end

    local SpawnLoc = PlayerPawn:K2_GetActorLocation()
    local Ctx = UGCGameSystem.GetGameMode() or PlayerPawn

    local Monster = nil
    local MonsterList = UGCActorComponentUtility.GetAllActorsOfClass(Ctx, MonsterClass)
    if MonsterList then
        for _, M in pairs(MonsterList) do
            if UE.IsValid(M) then
                Monster = M
                break
            end
        end
    end

    if Monster then
        Monster:K2_SetActorLocation(SpawnLoc)
        print('[GM] ServerRPC_GMSummonMonster: teleported existing SuperMonster to player')
    else
        local Rotation = PlayerPawn:K2_GetActorRotation()
        Monster = UGCGenericCharacterSystem.SpawnGenericCharacter(PlayerPawn, MonsterClass, SpawnLoc, Rotation)
        print(string.format('[GM] ServerRPC_GMSummonMonster: spawned new SuperMonster ok=%s',
            tostring(UE.IsValid(Monster))))
    end
    if not UE.IsValid(Monster) then
        return
    end

    local BB = Monster:GetBlackBoardComponent()
    if BB then
        BB:SetValueAsObject('Target', PlayerPawn)
        print('[GM] ServerRPC_GMSummonMonster: Target set to player')
    end
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
