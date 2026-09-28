---@class BTTask_BossPlanNextAction_C:BTTask_LuaBase
--- Only this task chooses an action. Per-Boss history, budget and random stream live in State.
local Types = require('Script.AI.Boss.BossAI_Types')
local Decision = require('Script.AI.Boss.BossAI_Decision')
local Runtime = require('Script.AI.Boss.BossAI_SkillRuntime')
local Observed = require('Script.AI.Boss.BossAI_Observed')

local Task = {}
local pending = setmetatable({}, { __mode = 'k' }) -- Pawn -> bounded failure delay
local loggedError = setmetatable({}, { __mode = 'k' })
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

local function clearRoute(bb)
    pcall(function()
        bb:SetValueAsInt(K.SelectedSkill, Types.SkillID.None)
        bb:SetValueAsInt(K.ActionKind, Types.ActionKind.None)
    end)
end

local function deferFailure(pawn, seconds)
    pending[pawn] = { remaining = math.max(0.01, tonumber(seconds) or 0.2) }
end

function Task:ReceiveExecuteAI(controller, pawn)
    if not pawn then self:FinishExecute(false); return end
    local okBB, bb = pcall(function() return pawn:GetBlackBoardComponent() end)
    if not okBB or not bb then self:FinishExecute(false); return end
    clearRoute(bb)

    local okServer, server = pcall(function() return UGCGameSystem.IsServer() end)
    if not okServer or server ~= true then deferFailure(pawn, 0.2); return end

    local now = gameTime(pawn)
    if not now then deferFailure(pawn, 0.2); return end
    local okRuntime, runtime = pcall(function()
        return Runtime.ForPawn(pawn, { controller = controller })
    end)
    if not okRuntime or not runtime then deferFailure(pawn, 0.2); return end
    local swept = pcall(runtime.TickDangers, runtime, now, 0)
    if not swept then deferFailure(pawn, 0.2); return end
    local state = runtime:GetState()
    local target = read(bb, 'GetValueAsObject', K.TargetActor, nil)
    local targetValid = isValid(target)
    local observed = Observed.Get(pawn)
    local hasLOS = targetValid and read(bb, 'GetValueAsBool', K.HasLineOfSight, false) == true
        and observed ~= nil and observed.hasLOS == true and observed.targetActor == target
        and type(observed.edgeDistance) == 'number' and type(observed.heightDiff) == 'number'
        and type(observed.observedAt) == 'number'
        and now >= observed.observedAt and now - observed.observedAt <= 0.5

    local ctx = {
        now = now,
        target = target,
        targetValid = targetValid,
        isDead = read(bb, 'GetValueAsBool', K.IsDead, false),
        hasLOS = hasLOS,
        edgeDistance = hasLOS and observed.edgeDistance or read(bb, 'GetValueAsFloat', K.DistanceToTarget, 0),
        centerDistance = hasLOS and observed.centerDistance or nil,
        bossRadius = hasLOS and observed.bossRadius or nil,
        targetRadius = hasLOS and observed.targetRadius or nil,
        heightDiff = hasLOS and observed.heightDiff or nil,
        observedTargetLocation = hasLOS and observed.observedTargetLocation or nil,
        canChase = hasLOS and controller ~= nil and controller.MoveToActor ~= nil,
        canReposition = false, -- No read-only reachability proof for MoveGoal in this project.
        candidateSeconds = state.config.Pressure.ChaseSliceSeconds,
    }
    local preflightCtx = {}
    for key, value in pairs(ctx) do preflightCtx[key] = value end
    -- Preflight is read-only; Begin repeats the checks immediately before commitment.
    -- An unknown capability is rejected instead of drawing an unsafe attack.
    ctx.canUseSkill = function(skillId, _def)
        if type(runtime.CheckSkillLegal) ~= 'function' then return false, 'NoPreflight' end
        local okCheck, allowed, reason = pcall(runtime.CheckSkillLegal, runtime, skillId, preflightCtx)
        if not okCheck then
            if not loggedError[pawn] then
                loggedError[pawn] = true
                pcall(function() ugcprint('[BossPlan] skill preflight error: ' .. tostring(allowed)) end)
            end
            return false, 'PreflightError'
        end
        return allowed == true, reason
    end

    local okPlan, plan = pcall(Decision.PlanNextAction, state, ctx)
    if not okPlan or not plan then
        if not loggedError[pawn] then
            loggedError[pawn] = true
            pcall(function() ugcprint('[BossPlan] decision error: ' .. tostring(plan)) end)
        end
        deferFailure(pawn, state.config.Decision.FailBackoffSeconds)
        return
    end
    local kind = plan.actionKind or Types.ActionKind.None
    local skillId = kind == Types.ActionKind.Skill and plan.skillId or Types.SkillID.None
    local okWrite = pcall(function()
        bb:SetValueAsInt(K.SelectedSkill, skillId)
        bb:SetValueAsInt(K.ActionKind, kind)
    end)
    if not okWrite then
        clearRoute(bb)
        deferFailure(pawn, plan.backoff)
        return
    end
    if kind == Types.ActionKind.None then
        deferFailure(pawn, plan.backoff)
        return
    end
    self:FinishExecute(true)
end

function Task:ReceiveTickAI(_controller, pawn, deltaSeconds)
    local wait = pawn and pending[pawn]
    if not wait then return end
    wait.remaining = wait.remaining - math.max(0, tonumber(deltaSeconds) or 0)
    if wait.remaining > 0 then return end
    pending[pawn] = nil
    self:FinishExecute(false)
end

function Task:ReceiveAbortAI(_controller, pawn)
    if not pawn or not pending[pawn] then
        if self.IsTaskAborting and self:IsTaskAborting() then self:FinishAbort() end
        return
    end
    if pawn then pending[pawn] = nil end
    self:FinishAbort()
end

return Task
