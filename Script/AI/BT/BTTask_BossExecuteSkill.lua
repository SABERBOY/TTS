---@class BTTask_BossExecuteSkill_C:BTTask_LuaBase
--- The BT task stays active through Windup, Active and the full Recovery.
local Types = require('Script.AI.Boss.BossAI_Types')
local Runtime = require('Script.AI.Boss.BossAI_SkillRuntime')
local Observed = require('Script.AI.Boss.BossAI_Observed')

local Task = {}
local running = setmetatable({}, { __mode = 'k' }) -- Pawn -> { actionId } or bounded backoff
local loggedFailures = setmetatable({}, { __mode = 'k' })
local K = Types.BBKeys

local function gameTime(pawn)
    local ok, value = pcall(function() return UGCGameSystem.GetTimeSeconds(pawn) end)
    if ok and type(value) == 'number' and value == value then return value end
    return nil
end

local function read(bb, method, key, fallback)
    local ok, value = pcall(function() return bb[method](bb, key) end)
    if ok and value ~= nil then return value end
    return fallback
end

local function isValid(actor)
    if actor == nil then return false end
    local ok, valid = pcall(function() return UE.IsValid(actor) end)
    return ok and valid == true
end

local function logOnce(pawn, skillId, reason)
    local byReason = loggedFailures[pawn]
    if not byReason then byReason = {}; loggedFailures[pawn] = byReason end
    local key = tostring(skillId) .. ':' .. tostring(reason)
    if byReason[key] then return end
    byReason[key] = true
    pcall(function() ugcprint('[BossSkill] S' .. tostring(skillId) .. ' rejected: ' .. tostring(reason)) end)
end

local function clearRoute(bb)
    if not bb then return end
    pcall(function()
        bb:SetValueAsInt(K.SelectedSkill, Types.SkillID.None)
        bb:SetValueAsInt(K.ActionKind, Types.ActionKind.None)
    end)
end

local function backoff(pawn, bb, seconds)
    clearRoute(bb)
    running[pawn] = { kind = 'backoff', remaining = math.max(0.01, tonumber(seconds) or 0.2) }
end

function Task:ReceiveExecuteAI(controller, pawn)
    if not pawn then self:FinishExecute(false); return end
    local okBB, bb = pcall(function() return pawn:GetBlackBoardComponent() end)
    if not okBB or not bb then self:FinishExecute(false); return end
    local okServer, server = pcall(function() return UGCGameSystem.IsServer() end)
    if not okServer or server ~= true then backoff(pawn, bb, 0.2); return end
    local skillId = read(bb, 'GetValueAsInt', K.SelectedSkill, Types.SkillID.None)
    if type(skillId) ~= 'number' or skillId < Types.SkillID.S1 or skillId > Types.SkillID.S7
        or read(bb, 'GetValueAsInt', K.ActionKind, Types.ActionKind.None) ~= Types.ActionKind.Skill then
        backoff(pawn, bb, 0.2)
        return
    end

    local now = gameTime(pawn)
    if not now then backoff(pawn, bb, 0.2); return end
    local target = read(bb, 'GetValueAsObject', K.TargetActor, nil)
    local targetValid = isValid(target)
    local observed = Observed.Get(pawn)
    local hasLOS = targetValid and read(bb, 'GetValueAsBool', K.HasLineOfSight, false) == true
        and observed ~= nil and observed.hasLOS == true and observed.targetActor == target
        and type(observed.edgeDistance) == 'number' and type(observed.heightDiff) == 'number'
        and type(observed.observedAt) == 'number'
        and now >= observed.observedAt and now - observed.observedAt <= 0.5
    local okRuntime, runtime = pcall(function()
        return Runtime.ForPawn(pawn, { controller = controller })
    end)
    if not okRuntime or not runtime then backoff(pawn, bb, 0.2); return end
    local ctx = {
        now = now, target = target, targetValid = targetValid, hasLOS = hasLOS,
        edgeDistance = hasLOS and observed.edgeDistance or nil,
        centerDistance = hasLOS and observed.centerDistance or nil,
        bossRadius = hasLOS and observed.bossRadius or nil,
        targetRadius = hasLOS and observed.targetRadius or nil,
        heightDiff = hasLOS and observed.heightDiff or nil,
        observedTargetLocation = hasLOS and observed.observedTargetLocation or nil,
    }
    local okBegin, began, result = pcall(runtime.Begin, runtime, skillId, ctx)
    if not okBegin or not began then
        logOnce(pawn, skillId, okBegin and result or began)
        backoff(pawn, bb, runtime:GetState().config.Decision.FailBackoffSeconds)
        return
    end
    running[pawn] = { kind = 'active', actionId = result }
end

function Task:ReceiveTickAI(_controller, pawn, deltaSeconds)
    local run = pawn and running[pawn]
    if not run then return end
    if run.kind == 'backoff' then
        run.remaining = run.remaining - math.max(0, tonumber(deltaSeconds) or 0)
        if run.remaining > 0 then return end
        running[pawn] = nil
        self:FinishExecute(false)
        return
    end
    local runtime = Runtime.Get(pawn)
    if not runtime then
        running[pawn] = nil
        self:FinishExecute(false)
        return
    end
    local now = gameTime(pawn)
    if not now then
        runtime:Abort(run.actionId, 'clock-unavailable', 0, false)
        running[pawn] = nil
        self:FinishExecute(false)
        return
    end
    local okTick, result = pcall(runtime.Tick, runtime, now, deltaSeconds or 0)
    if not okTick or not result or result.actionId ~= run.actionId then
        logOnce(pawn, 'tick', okTick and 'invalid-result' or result)
        runtime:Abort(run.actionId, 'tick-failed', now, false)
        running[pawn] = nil
        self:FinishExecute(false)
        return
    end
    if result.status == 'running' then return end
    running[pawn] = nil -- Remove before notifying BT: terminal notification is at most once.
    local okBB, bb = pcall(function() return pawn:GetBlackBoardComponent() end)
    if okBB then clearRoute(bb) end
    self:FinishExecute(result.status == 'finished')
end

function Task:ReceiveAbortAI(_controller, pawn)
    local run = pawn and running[pawn]
    if not run then
        if self.IsTaskAborting and self:IsTaskAborting() then self:FinishAbort() end
        return
    end
    if pawn then running[pawn] = nil end
    local okBB, bb = pcall(function() return pawn and pawn:GetBlackBoardComponent() end)
    local dead = okBB and bb and read(bb, 'GetValueAsBool', K.IsDead, false)
    local reset = okBB and bb and read(bb, 'GetValueAsBool', K.MustReset, false)
    local disengaged = okBB and bb and not read(bb, 'GetValueAsBool', K.CombatActive, false)
    local runtime = pawn and Runtime.Get(pawn)
    if run and run.kind == 'active' and runtime then
        runtime:Abort(run.actionId, dead and 'death' or reset and 'reset' or
            disengaged and 'disengage' or 'bt-abort', gameTime(pawn) or 0,
            dead or reset or disengaged)
    end
    if okBB then clearRoute(bb) end
    self:FinishAbort()
end

return Task
