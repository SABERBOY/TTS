---@class BTTask_BossChaseSlice_C:BTTask_LuaBase
--- Shared movement helper for Chase, Search, Reposition and ReturnHome.
local Types = require('Script.AI.Boss.BossAI_Types')
local Config = require('Script.AI.Boss.BossAI_Config')
local Runtime = require('Script.AI.Boss.BossAI_SkillRuntime')

local Task = {}
local Move = {}
local runs = setmetatable({}, { __mode = 'k' })
local requests = setmetatable({}, { __mode = 'k' })
local retries = setmetatable({}, { __mode = 'k' })
local requestReports = setmetatable({}, { __mode = 'k' })
local possessionWarnings = setmetatable({}, { __mode = 'k' })
local capsuleWarnings = setmetatable({}, { __mode = 'k' })
local warnedPathQuery = false
local K = Types.BBKeys
local SliceSeconds = Config.Pressure.ChaseSliceSeconds
local NavQueryXY, NavQueryZ, MaxStartOffNavZ, MaxGoalOffNavZ = 150, 600, 150, 150

local function valid(object)
    return object ~= nil and UE.IsValid(object)
end

-- This UE4.18 controller exposes K2_GetPawn in Lua; GetPawn is not bound on
-- the project's BP_BossAIController. Keep the latter only for other wrappers.
function Move.ControllerOwnsPawn(controller, pawn)
    if not valid(controller) or not valid(pawn) then return false end
    local getter = controller.K2_GetPawn or controller.GetPawn
    if not getter then
        if not possessionWarnings[controller] then
            possessionWarnings[controller] = true
            ugcprint('[BossMove] Controller pawn getter unavailable; movement disabled')
        end
        return false
    end
    local ok, owned = pcall(getter, controller)
    if not ok then
        if not possessionWarnings[controller] then
            possessionWarnings[controller] = true
            ugcprint('[BossMove] Controller pawn lookup failed; movement disabled')
        end
        return false
    end
    return owned == pawn
end

local function enumEquals(value, group, name, fallback)
    return value == (group and group[name] or fallback)
end

local function distance(a, b)
    local dx, dy, dz = b.X - a.X, b.Y - a.Y, b.Z - a.Z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function sameGoal(a, b)
    if a == b then return true end
    if not a or not b or not a.X or not b.X then return false end
    return distance(a, b) < 1
end

local function finiteGoal(goal)
    if not goal then return false end
    for _, key in ipairs({ 'X', 'Y', 'Z' }) do
        local v = goal[key]
        if type(v) ~= 'number' or v ~= v or v == math.huge or v == -math.huge then
            return false
        end
    end
    return true
end

local function feetLocation(actor, center)
    local capsule = actor.CapsuleComponent
    if not valid(capsule) and actor.GetCapsuleComponent then
        local ok, component = pcall(actor.GetCapsuleComponent, actor)
        if ok then capsule = component end
    end
    if not valid(capsule) or not capsule.GetScaledCapsuleHalfHeight then
        return center, false
    end
    local ok, halfHeight = pcall(capsule.GetScaledCapsuleHalfHeight, capsule)
    if not ok or type(halfHeight) ~= 'number' or halfHeight ~= halfHeight
        or halfHeight < 0 or halfHeight == math.huge then
        if not capsuleWarnings[actor] then
            capsuleWarnings[actor] = true
            ugcprint('[BossMove] Capsule half height unavailable; native path result is authoritative')
        end
        return center, false
    end
    return { X = center.X, Y = center.Y, Z = center.Z - halfHeight }, true
end

local function hasLOS(controller, actor)
    if not controller.LineOfSightTo then return false end
    local ok, visible = pcall(controller.LineOfSightTo, controller, actor,
        Vector.New(0, 0, 0), false)
    return ok and visible == true
end

local function pointText(point)
    return '(' .. tostring(point.X) .. ',' .. tostring(point.Y)
        .. ',' .. tostring(point.Z) .. ')'
end

local function reportRequest(pawn, kind, result, startLocation, goalLocation)
    local key = kind .. ':' .. tostring(result)
    local seen = requestReports[pawn] or {}
    if seen[key] then return end
    seen[key] = true
    requestReports[pawn] = seen
    ugcprint('[BossMove] MoveTo ' .. kind .. ' result=' .. tostring(result)
        .. ' type=' .. type(result) .. ' expectedSuccess='
        .. tostring(EPathFollowingRequestResult and EPathFollowingRequestResult.RequestSuccessful)
        .. ' start=' .. pointText(startLocation) .. ' goal=' .. pointText(goalLocation))
end

-- A just-teleported target can be hundreds of centimetres above the walkable
-- floor. The project UGC binding returns both success and a projected FVector.
local function projectToNavigation(pawn, point)
    if not UGCNavigationSystem or not UGCNavigationSystem.ProjectPointToNavigation then
        return point, false
    end
    local ok, projected, navPoint = pcall(UGCNavigationSystem.ProjectPointToNavigation,
        pawn, point, Vector.New(NavQueryXY, NavQueryXY, NavQueryZ))
    if not ok or projected ~= true or not finiteGoal(navPoint) then
        return nil, true
    end
    return navPoint, true
end

local function pathReachable(pawn, navStart, navGoal)
    local navigation = NavigationSystem or UNavigationSystem
    if not navigation or not navigation.FindPathToLocationSynchronously then
        -- Native MoveTo still checks reachability if the optional Lua path
        -- query is absent; native rejection enters bounded backoff below.
        if not warnedPathQuery then
            warnedPathQuery = true
            ugcprint('[BossMove] Lua path query unavailable; validating with native MoveTo')
        end
        return true
    end
    local ok, path = pcall(navigation.FindPathToLocationSynchronously,
        pawn, navStart, navGoal, pawn, nil)
    if not ok or not path or not path.IsValid or not path.IsPartial then return false end
    local validOk, isValid = pcall(path.IsValid, path)
    local partialOk, isPartial = pcall(path.IsPartial, path)
    return validOk and isValid == true and partialOk and isPartial == false
end

local function sameRetry(entry, kind, goal)
    return entry and entry.kind == kind
        and (kind == 'Chase' and entry.goal == goal
            or kind ~= 'Chase' and sameGoal(entry.goal, goal))
end

local function retryRun(controller, pawn, kind, goal, seconds)
    return { controller = controller, pawn = pawn, kind = kind, goal = goal,
        elapsed = 0, maxSeconds = seconds, backoff = true }
end

local function backoff(controller, pawn, kind, goal, reason)
    local previous = retries[pawn]
    local attempts = sameRetry(previous, kind, goal)
        and math.min(previous.attempts + 1, 4) or 1
    Move.StopForPawn(pawn)
    if kind == 'ReturnHome' then return nil, reason end
    local seconds = math.min(1.6, 0.2 * 2 ^ (attempts - 1))
    local now = UGCGameSystem.GetTimeSeconds(pawn)
    retries[pawn] = { kind = kind, goal = kind == 'Chase' and goal
        or { X = goal.X, Y = goal.Y, Z = goal.Z },
        attempts = attempts, untilTime = now + seconds, reason = reason }
    if not previous or previous.reason ~= reason then
        ugcprint('[BossMove] ' .. kind .. ' navigation ' .. reason
            .. '; retry in ' .. tostring(seconds) .. 's')
    end
    return retryRun(controller, pawn, kind, goal, seconds)
end

local function backoffActiveRun(run, reason)
    local waiting, failure = backoff(run.controller, run.pawn, run.kind, run.goal, reason)
    if not waiting then return failure end
    run.backoff = true
    run.marker = nil
    run.elapsed = 0
    run.maxSeconds = waiting.maxSeconds
    return 'running'
end

function Move.StopForPawn(pawn)
    if pawn == nil then return end
    retries[pawn] = nil
    local marker = requests[pawn]
    if not marker then return end
    requests[pawn] = nil
    if valid(marker.controller) and marker.controller.StopMovement then
        marker.controller:StopMovement()
    end
end

function Move.Stop(run)
    if run and run.backoff then
        -- Keep the deadline if BT aborts and re-enters before it expires.
        -- Explicit StopForPawn (idle, reset, death, unpossess) clears it.
        return
    elseif run and requests[run.pawn] == run.marker then
        Move.StopForPawn(run.pawn)
    end
end

--- MoveTo uses pathfinding and forbids partial paths. The actual result is
--- monitored asynchronously; a successful request is not arrival.
function Move.Begin(controller, pawn, kind, goal, radius, maxSeconds, keepOnSlice)
    if not UGCGameSystem.IsServer() or not Move.ControllerOwnsPawn(controller, pawn) then
        if valid(pawn) then Move.StopForPawn(pawn) end
        return nil, 'unpossessed'
    end
    local actorGoal = kind == 'Chase'
    if actorGoal then
        if not valid(goal) or not hasLOS(controller, goal) then
            Move.StopForPawn(pawn)
            return nil, 'lost-los'
        end
    elseif not finiteGoal(goal) then
        Move.StopForPawn(pawn)
        return nil, 'invalid-goal'
    end
    local pending = retries[pawn]
    if pending and not sameRetry(pending, kind, goal) then
        retries[pawn] = nil
        pending = nil
    end
    local now = UGCGameSystem.GetTimeSeconds(pawn)
    if pending and now < pending.untilTime then
        return retryRun(controller, pawn, kind, goal, pending.untilTime - now)
    end

    local currentLocation = pawn:K2_GetActorLocation()
    local goalLocation = actorGoal and goal:K2_GetActorLocation() or goal
    local currentFeet, hasStartCapsule = feetLocation(pawn, currentLocation)
    local goalFeet, hasGoalCapsule = goalLocation, false
    if actorGoal then goalFeet, hasGoalCapsule = feetLocation(goal, goalLocation) end
    local navStart, startWasProjected = projectToNavigation(pawn, currentLocation)
    if not navStart then return backoff(controller, pawn, kind, goal, 'nav-start-unavailable') end
    local navGoal, goalWasProjected = projectToNavigation(pawn, goalLocation)
    if not navGoal then return backoff(controller, pawn, kind, goal, 'nav-goal-unavailable') end
    -- The saved Boss capsule is roughly 620 cm tall. Its actor origin is
    -- ~310 cm above the floor while its feet remain on the nav surface.
    if startWasProjected and hasStartCapsule
        and math.abs(navStart.Z - currentFeet.Z) > MaxStartOffNavZ then
        return backoff(controller, pawn, kind, goal, 'nav-start-off-mesh')
    end

    local goalHeight = hasGoalCapsule and goalFeet.Z or goalLocation.Z
    local mode = actorGoal and math.abs(navGoal.Z - goalHeight) <= MaxGoalOffNavZ
        and 'actor' or 'location'
    local previous = requests[pawn]
    local sameRequest = previous and previous.controller == controller
        and previous.kind == kind and previous.mode == mode
        and (actorGoal and previous.goal == goal or not actorGoal and sameGoal(previous.goal, goal))
        and (mode == 'actor' or distance(previous.navGoal, navGoal) < (actorGoal and 100 or 1))
    if previous and not sameRequest then
        -- Stop a live actor path before Search can dwell at its cached point.
        Move.StopForPawn(pawn)
    end
    if distance(currentFeet, navGoal) <= radius then
        Move.StopForPawn(pawn)
        return nil, 'arrived'
    end
    if startWasProjected and goalWasProjected
        and not pathReachable(pawn, navStart, navGoal) then
        return backoff(controller, pawn, kind, goal, 'nav-unreachable')
    end

    local reuse = sameRequest
    if reuse and controller.GetMoveStatus then
        local statusOk, status = pcall(controller.GetMoveStatus, controller)
        reuse = statusOk and status ~= nil
            and not enumEquals(status, EPathFollowingStatus, 'Idle', 0)
    elseif reuse then
        reuse = false
    end
    local marker
    if reuse then
        marker = previous
    else
        local ok, result
        if mode == 'actor' then
            ok, result = pcall(controller.MoveToActor, controller, goal, radius,
                false, true, false, nil, false)
        else
            ok, result = pcall(controller.MoveToLocation, controller, navGoal, radius,
                false, true, true, false, nil, false, false)
        end
        reportRequest(pawn, kind, result, currentLocation, navGoal)
        if not ok then
            return backoff(controller, pawn, kind, goal, 'move-call-failed')
        end
        if enumEquals(result, EPathFollowingRequestResult, 'AlreadyAtGoal', 1) then
            Move.StopForPawn(pawn)
            return nil, 'arrived'
        end
        if not enumEquals(result, EPathFollowingRequestResult, 'RequestSuccessful', 2) then
            return backoff(controller, pawn, kind, goal, 'move-request-failed')
        end
        marker = { controller = controller, kind = kind, goal = goal,
            navGoal = navGoal, mode = mode }
        requests[pawn] = marker
    end
    -- Retain the previous failure count until path following actually moves.
    -- A native request can be accepted and stop on the very next tick.
    local activeGoal = reuse and marker.navGoal or navGoal
    return {
        controller = controller, pawn = pawn, kind = kind, goal = goal,
        radius = radius, elapsed = 0, maxSeconds = maxSeconds,
        keepOnSlice = keepOnSlice == true, marker = marker,
        navGoal = activeGoal, mode = mode,
    }
end

--- Returns running, arrived, slice or a failure reason.
function Move.Advance(run, deltaSeconds)
    local controller, pawn = run.controller, run.pawn
    if not Move.ControllerOwnsPawn(controller, pawn) then
        return 'unpossessed'
    end
    if run.backoff then
        if run.kind == 'Chase' then
            local board = pawn:GetBlackBoardComponent()
            if not board or not board:GetValueAsBool(K.HasLineOfSight)
                or not valid(run.goal) or not hasLOS(controller, run.goal) then
                return 'lost-los'
            end
        end
        run.elapsed = run.elapsed + math.max(0, deltaSeconds or 0)
        return run.elapsed >= run.maxSeconds and 'slice' or 'running'
    end
    if requests[pawn] ~= run.marker then return 'superseded' end
    run.elapsed = run.elapsed + math.max(0, deltaSeconds or 0)
    local goalLocation
    if run.kind == 'Chase' then
        local board = pawn:GetBlackBoardComponent()
        if not board or not board:GetValueAsBool(K.HasLineOfSight)
            or not valid(run.goal) or not hasLOS(controller, run.goal) then
            return 'lost-los'
        end
        if run.mode == 'location' then
            goalLocation = run.navGoal
        else
            goalLocation = feetLocation(run.goal, run.goal:K2_GetActorLocation())
        end
    else
        goalLocation = run.navGoal
    end
    local currentFeet = feetLocation(pawn, pawn:K2_GetActorLocation())
    if distance(currentFeet, goalLocation) <= run.radius then
        return 'arrived'
    end
    if controller.HasPartialPath and controller:HasPartialPath() then
        return backoffActiveRun(run, 'partial-path')
    end
    if controller.GetMoveStatus then
        local status = controller:GetMoveStatus()
        if enumEquals(status, EPathFollowingStatus, 'Idle', 0) and run.elapsed > 0.1 then
            return backoffActiveRun(run, 'path-stopped')
        elseif enumEquals(status, EPathFollowingStatus, 'Moving', 3) then
            retries[pawn] = nil
        end
    end
    if run.elapsed >= run.maxSeconds then return 'slice' end
    return 'running'
end

Task.Move = Move

local function finish(task, pawn, success, stop)
    local run = runs[pawn]
    runs[pawn] = nil
    if stop then Move.Stop(run) end
    task:FinishExecute(success)
end

function Task:ReceiveExecuteAI(controller, pawn)
    local board = valid(pawn) and pawn:GetBlackBoardComponent()
    if not board or not board:GetValueAsBool(K.HasLineOfSight) then
        if valid(pawn) then Move.StopForPawn(pawn) end
        self:FinishExecute(false)
        return
    end
    local state = Runtime.ForPawn(pawn, { controller = controller }):GetState()
    if state:IsActionLocked() or state:GetBreathingPhase() ~= Types.BreathingPhase.None
        or state:HasBreathingDebt() then
        Move.StopForPawn(pawn)
        self:FinishExecute(false)
        return
    end
    local target = board:GetValueAsObject(K.TargetActor)
    local run, reason = Move.Begin(controller, pawn, 'Chase', target, 100, SliceSeconds, true)
    if not run then
        if reason ~= 'arrived' then ugcprint('[BossMove] Chase failed: ' .. reason) end
        self:FinishExecute(reason == 'arrived')
        return
    end
    runs[pawn] = run
end

function Task:ReceiveTickAI(_controller, pawn, deltaSeconds)
    local run = runs[pawn]
    if not run then return end
    local result = Move.Advance(run, deltaSeconds)
    if result == 'running' then return end
    if result == 'arrived' then
        finish(self, pawn, true, true)
    elseif result == 'slice' then
        finish(self, pawn, true, false) -- leave path running across decision slices
    else
        ugcprint('[BossMove] Chase stopped: ' .. result)
        finish(self, pawn, false, true)
    end
end

function Task:ReceiveAbortAI(_controller, pawn)
    Move.Stop(runs[pawn])
    runs[pawn] = nil
    self:FinishAbort()
end

return Task
