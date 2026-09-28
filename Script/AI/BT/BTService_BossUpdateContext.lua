---@class BTService_BossUpdateContext_C:BTAttachment_LuaBase
--- Attach above CombatActive, or call UpdateContext from the idle task.
local Types = require('Script.AI.Boss.BossAI_Types')
local Config = require('Script.AI.Boss.BossAI_Config')
local Runtime = require('Script.AI.Boss.BossAI_SkillRuntime')
local Observed = require('Script.AI.Boss.BossAI_Observed')
local Movement = require('Script.AI.BT.BTTask_BossChaseSlice').Move

local Service = {}
local K = Types.BBKeys
local SightRadius = Config.Perception.SightRadius
local LoseSightRadius = Config.Perception.LoseSightRadius
local HalfAngleCos = math.cos(math.rad(Config.Perception.PeripheralVisionHalfAngle))
local DefaultBossRadius, DefaultPlayerRadius = 75, 42
local warned = {}
local homeInitialized = setmetatable({}, { __mode = 'k' })
local deadReleased = setmetatable({}, { __mode = 'k' })

local function warnOnce(key, message)
    if warned[key] then return end
    warned[key] = true
    ugcprint('[BossContext] ' .. message)
end

local function valid(object)
    return object ~= nil and UE.IsValid(object)
end

local function horizontalDistance(a, b)
    local dx, dy = b.X - a.X, b.Y - a.Y
    return math.sqrt(dx * dx + dy * dy)
end

local function radius(actor, remembered, fallback)
    local capsule = actor and (actor.CapsuleComponent or actor.HitBox or actor.HitBox_Stand)
    if valid(capsule) and capsule.GetScaledCapsuleRadius then
        local ok, value = pcall(capsule.GetScaledCapsuleRadius, capsule)
        if ok and type(value) == 'number' and value > 0 then return value end
    end
    if type(remembered) == 'number' and remembered > 0 then return remembered end
    warnOnce('capsule', 'Capsule radius unavailable; using prototype fallback radii')
    return fallback
end

local function playerPawns()
    local gameState = UGCGameSystem.GetGameState()
    if not valid(gameState) or not gameState.PlayerArray then return nil end
    local players = {}
    for _, playerState in pairs(gameState.PlayerArray) do
        if valid(playerState) and playerState.GetPlayerCharacterSafety then
            local ok, pawn = pcall(playerState.GetPlayerCharacterSafety, playerState)
            if ok and valid(pawn) then players[pawn] = true end
        end
    end
    return players
end

local function legalEnemy(boss, player, players)
    if not valid(boss) or not valid(player) or boss == player then return false end
    if players and not players[player] then return false end
    if not player.IsAlive then
        warnOnce('alive-api', 'Player IsAlive unavailable; target acquisition disabled')
        return false
    end
    local aliveOk, alive = pcall(player.IsAlive, player)
    if not aliveOk or alive ~= true then return false end
    if not boss.GetGeneralCampRelationWithActor or not ECampRelation then
        warnOnce('camp', 'Camp relation unavailable; target acquisition disabled')
        return false
    end
    local ok, relation = pcall(boss.GetGeneralCampRelationWithActor, boss, player)
    if not ok then
        warnOnce('camp-call', 'Camp relation query failed; target acquisition disabled')
        return false
    end
    -- Perception may classify a player as neutral; game camp relation still
    -- decides whether the player is attackable by this particular boss.
    return relation == ECampRelation.Enemy
end

local function perceptionCandidates(controller, players)
    if not controller.GetAIPerceptionComponent then
        warnOnce('perception-api', 'AIPerception API absent; using provisional LOS/radius/cone fallback')
        return nil
    end
    local ok, component = pcall(controller.GetAIPerceptionComponent, controller)
    if not ok then
        warnOnce('perception-component', 'AIPerceptionComponent lookup failed; using provisional LOS fallback')
        return nil
    end
    if not valid(component) then
        warnOnce('perception-missing', 'AIPerceptionComponent absent; using provisional LOS/radius/cone fallback')
        return nil
    end
    if not component.GetCurrentlyPerceivedActors then
        warnOnce('perception-query', 'AIPerception query API absent; using provisional LOS/radius/cone fallback')
        return nil
    end
    local output = {}
    local success, returned = pcall(component.GetCurrentlyPerceivedActors, component, nil, output)
    if not success then
        warnOnce('perception-call', 'AIPerception query failed; using LineOfSightTo fallback')
        return nil
    end
    local actors = returned or output
    local current = {}
    local countOk, count = pcall(function() return #actors end)
    if countOk and count > 0 then
        for index = 1, count do
            local actor = actors[index]
            if players[actor] then current[actor] = true end
        end
    else
        for _, actor in pairs(output) do
            if players[actor] then current[actor] = true end
        end
    end
    -- A successful empty result means no currently perceived player. It must
    -- not fall through to the LOS fallback or it bypasses configured Sight.
    -- The LuaHelper out-array bridge still needs PIE readback; if it reports
    -- success with an unfilled out parameter this errs toward no acquisition.
    if next(current) == nil then
        warnOnce('perception-empty', 'AIPerception returned no current player; acquisition remains closed')
    end
    return current
end

local function lineOfSight(controller, target)
    if not controller or not controller.LineOfSightTo then
        warnOnce('los-missing', 'LineOfSightTo unavailable; visual target acquisition disabled')
        return false
    end
    local ok, visible = pcall(controller.LineOfSightTo, controller, target,
        Vector.New(0, 0, 0), false)
    if not ok then
        warnOnce('los-call', 'LineOfSightTo failed; visual target acquisition disabled')
        return false
    end
    return visible == true
end

local function inAcquisitionCone(boss, bossLocation, targetLocation)
    local direction = boss:GetActorForwardVector()
    if not direction then return false end
    local dx, dy = targetLocation.X - bossLocation.X, targetLocation.Y - bossLocation.Y
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 1 then return true end
    local forwardLength = math.sqrt(direction.X * direction.X + direction.Y * direction.Y)
    if forwardLength < 0.001 then return false end
    return (dx * direction.X + dy * direction.Y) / (length * forwardLength) >= HalfAngleCos
end

local function ensureHome(boss, board)
    local ok, hasHome = pcall(board.IsVectorValueSet, board, K.HomeLocation)
    if ok and hasHome then return end
    if not ok and homeInitialized[boss] then return end
    board:SetValueAsVector(K.HomeLocation, boss:K2_GetActorLocation())
    homeInitialized[boss] = true
end

local function requestPhaseIfHealthCrossed(state, boss)
    if state:GetPhase() ~= 1 then return end
    if not UGCAttributeSystem or not UGCAttributeSystem.GetGameAttributeValue then
        warnOnce('health-api', 'Health attribute query unavailable; automatic phase request disabled')
        return
    end
    local healthOk, health = pcall(UGCAttributeSystem.GetGameAttributeValue, boss, 'Health')
    local maxOk, maximum = pcall(UGCAttributeSystem.GetGameAttributeValue, boss, 'HealthMax')
    if not healthOk or not maxOk or type(health) ~= 'number'
        or type(maximum) ~= 'number' or health ~= health or maximum ~= maximum
        or health == math.huge or health == -math.huge
        or maximum == math.huge or maximum <= 0 then
        warnOnce('health-value', 'Boss Health/HealthMax unavailable; automatic phase request disabled')
        return
    end
    if health > 0 and health / maximum <= 0.5 then state:RequestPhaseTransition() end
end

local function releaseEncounterState(boss, now, reason)
    local hadRuntime = Runtime.Get(boss) ~= nil
    local released = Runtime.Release(boss, now, reason)
    Observed.Clear(boss)
    if hadRuntime and released ~= true then
        -- Runtime keeps a failed danger cleanup in its registry for bounded
        -- retry. Park this encounter so it cannot immediately attack again.
        Observed.SetHomeFailed(boss, true)
        ugcprint('[BossContext] Runtime release failed; encounter parked for danger cleanup retry')
    end
end

local function disengage(boss, board, now)
    board:SetValueAsObject(K.TargetActor, nil)
    board:SetValueAsBool(K.HasLineOfSight, false)
    board:SetValueAsBool(K.CombatActive, false)
    board:SetValueAsInt(K.ActionKind, Types.ActionKind.None)
    board:SetValueAsInt(K.SelectedSkill, Types.SkillID.None)
    board:ClearValue(K.LastKnownTargetLocation)
    board:SetValueAsFloat(K.DistanceToTarget, -1)
    board:SetValueAsBool(K.PhaseTransitionReady, false)
    releaseEncounterState(boss, now, 'disengage')
end

function Service.UpdateContext(controller, boss)
    if not UGCGameSystem.IsServer() or not valid(boss) or not valid(controller) then return end
    if not Movement.ControllerOwnsPawn(controller, boss) then
        Movement.StopForPawn(boss)
        local oldBoard = boss:GetBlackBoardComponent()
        local now = UGCGameSystem.GetTimeSeconds(boss)
        if oldBoard then disengage(boss, oldBoard, now)
        else releaseEncounterState(boss, now, 'unpossess') end
        return
    end
    local board = boss:GetBlackBoardComponent()
    if not board then return end
    ensureHome(boss, board)
    local now = UGCGameSystem.GetTimeSeconds(boss)
    local runtime = Runtime.Get(boss)
    if runtime then runtime:TickDangers(now, 0) end
    if board:GetValueAsBool(K.IsDead) then
        if not deadReleased[boss] then
            Movement.StopForPawn(boss)
            disengage(boss, board, now)
            deadReleased[boss] = true
        end
        return
    end
    deadReleased[boss] = nil
    if board:GetValueAsBool(K.MustReset)
        or (Observed.Get(boss) and Observed.Get(boss).homeFailed) then return end

    local players = playerPawns()
    if not players then
        warnOnce('players', 'GameState.PlayerArray unavailable; preserving target but clearing current LOS')
        board:SetValueAsBool(K.HasLineOfSight, false)
        local previous = Observed.Get(boss) or {}
        Observed.Update(boss, {
            hasLOS = false,
            targetValid = false,
            bossRadius = previous.bossRadius,
            targetRadius = previous.targetRadius,
            homeFailed = previous.homeFailed,
        })
        return
    end
    local current = board:GetValueAsObject(K.TargetActor)
    local hadCombat = board:GetValueAsBool(K.CombatActive)
    if not legalEnemy(boss, current, players) then
        if current then board:ClearValue(K.LastKnownTargetLocation) end
        current = nil
        board:SetValueAsObject(K.TargetActor, nil)
        board:SetValueAsBool(K.HasLineOfSight, false)
    end

    local candidates = perceptionCandidates(controller, players)
    local bossLocation = boss:K2_GetActorLocation()
    local seen, seenLocation, bestDistance = nil, nil, nil
    if current and (not candidates or candidates[current]) and lineOfSight(controller, current) then
        local location = current:K2_GetActorLocation() -- only after confirmed LOS
        local distance = horizontalDistance(bossLocation, location)
        if distance <= LoseSightRadius and inAcquisitionCone(boss, bossLocation, location) then
            seen, seenLocation, bestDistance = current, location, distance
        end
    end
    if not seen then
        for player in pairs(players) do
            if player ~= current and legalEnemy(boss, player, players)
                and (not candidates or candidates[player]) and lineOfSight(controller, player) then
                local location = player:K2_GetActorLocation() -- never inspect an occluded target
                local distance = horizontalDistance(bossLocation, location)
                if distance <= SightRadius and inAcquisitionCone(boss, bossLocation, location)
                    and (bestDistance == nil or distance < bestDistance) then
                    seen, seenLocation, bestDistance = player, location, distance
                end
            end
        end
    end

    local previous = Observed.Get(boss) or {}
    local context = {
        bossRadius = previous.bossRadius,
        targetRadius = previous.targetRadius,
        homeFailed = previous.homeFailed,
    }
    local bossRadius = radius(boss, context.bossRadius, DefaultBossRadius)
    context.bossRadius = bossRadius
    local state = Runtime.ForPawn(boss, { controller = controller }):GetState()
    if seen then
        local targetRadius = radius(seen, seen == current and context.targetRadius or nil, DefaultPlayerRadius)
        local edge = math.max(0, bestDistance - bossRadius - targetRadius)
        board:SetValueAsObject(K.TargetActor, seen)
        board:SetValueAsBool(K.HasLineOfSight, true)
        board:SetValueAsBool(K.CombatActive, true)
        board:SetValueAsVector(K.LastKnownTargetLocation, seenLocation)
        board:SetValueAsFloat(K.DistanceToTarget, edge)
        context.targetValid, context.hasLOS = true, true
        context.edgeDistance, context.centerDistance = edge, bestDistance
        context.targetRadius, context.heightDiff = targetRadius, seenLocation.Z - bossLocation.Z
        context.observedTargetLocation = seenLocation
        context.targetActor, context.observedAt = seen, now
        if not hadCombat then state:StartPressure(now) end
    else
        board:SetValueAsBool(K.HasLineOfSight, false)
        if current then
            board:SetValueAsBool(K.CombatActive, true) -- losing LOS never ends the encounter
        else
            local anyLegal = false
            for player in pairs(players) do
                if legalEnemy(boss, player, players) then anyLegal = true; break end
            end
            if not anyLegal and hadCombat then disengage(boss, board, now); return end
            board:SetValueAsBool(K.CombatActive, hadCombat and anyLegal)
        end
        context.targetValid, context.hasLOS = current ~= nil, false
        context.heightDiff, context.observedTargetLocation = nil, nil
        context.targetActor, context.observedAt = nil, nil
        context.edgeDistance, context.centerDistance = nil, nil
        if board:IsVectorValueSet(K.LastKnownTargetLocation) then
            local known = board:GetValueAsVector(K.LastKnownTargetLocation)
            local distance = horizontalDistance(bossLocation, known)
            local edge = math.max(0, distance - bossRadius - (context.targetRadius or DefaultPlayerRadius))
            board:SetValueAsFloat(K.DistanceToTarget, edge)
            context.searchEdgeDistance = edge
        else
            board:SetValueAsFloat(K.DistanceToTarget, -1)
            context.searchEdgeDistance = nil
        end
    end
    requestPhaseIfHealthCrossed(state, boss)
    board:SetValueAsInt(K.CurrentPhase, state:GetPhase())
    board:SetValueAsBool(K.PhaseTransitionReady, state:CanApplyPhaseTransition(now))
    Observed.Update(boss, context)
end

function Service:ReceiveActivationAI(controller, boss)
    if not UGCGameSystem.IsServer() or not valid(boss) then return end
    local board = boss:GetBlackBoardComponent()
    if board then ensureHome(boss, board) end
end

function Service:ReceiveTickAI(controller, boss, _deltaSeconds)
    Service.UpdateContext(controller, boss)
end

function Service:ReceiveDeactivationAI(controller, boss)
    if not UGCGameSystem.IsServer() or not valid(boss) or not valid(controller) then return end
    if not Movement.ControllerOwnsPawn(controller, boss) then
        Movement.StopForPawn(boss)
        local now = UGCGameSystem.GetTimeSeconds(boss)
        local board = boss:GetBlackBoardComponent()
        if board then disengage(boss, board, now)
        else releaseEncounterState(boss, now, 'unpossess') end
    end
end

return Service
