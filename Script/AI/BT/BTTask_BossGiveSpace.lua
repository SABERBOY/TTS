---@class BTTask_BossGiveSpace_C:BTTask_LuaBase
--- Wait for this Boss's damaging hazards to end, then give a full 2-second window.
local Types = require('Script.AI.Boss.BossAI_Types')
local Runtime = require('Script.AI.Boss.BossAI_SkillRuntime')

local Task = {}
local running = setmetatable({}, { __mode = 'k' }) -- Never place a Pawn's timer on a shared BT node.
local K = Types.BBKeys

local function gameTime(pawn)
    local ok, value = pcall(function() return UGCGameSystem.GetTimeSeconds(pawn) end)
    if ok and type(value) == 'number' and value == value then return value end
    return nil
end

local function readBool(bb, key)
    local ok, value = pcall(function() return bb:GetValueAsBool(key) end)
    return ok and value == true
end

local function stopMovement(controller, pawn)
    pcall(function()
        if controller and controller.StopMovement then controller:StopMovement() end
        local movement = pawn and pawn.GetMovementComponent and pawn:GetMovementComponent()
        if movement and movement.StopMovementImmediately then movement:StopMovementImmediately() end
    end)
end

local function startIfIdle(runtime, now)
    if runtime:GetActiveAction() then return false end
    local state = runtime:GetState()
    if state:GetBreathingPhase() == Types.BreathingPhase.None then
        state:StartBreathing(now) -- Automatically resumes a saved debt.
    end
    return true
end

function Task:ReceiveExecuteAI(controller, pawn)
    if not pawn then self:FinishExecute(false); return end
    local now = gameTime(pawn)
    if not now then self:FinishExecute(false); return end
    local ok, runtime = pcall(function()
        return Runtime.ForPawn(pawn, { controller = controller })
    end)
    if not ok or not runtime then self:FinishExecute(false); return end
    local swept = pcall(runtime.TickDangers, runtime, now, 0)
    if not swept then self:FinishExecute(false); return end
    running[pawn] = { enteredAt = now }
    if startIfIdle(runtime, now) then stopMovement(controller, pawn) end
    -- Remain InProgress. Only ReceiveTickAI may finish after DrainThreats + Breathing.
end

function Task:ReceiveTickAI(controller, pawn, deltaSeconds)
    if not pawn or not running[pawn] then return end
    local runtime = Runtime.Get(pawn)
    local now = gameTime(pawn)
    if not runtime or not now then
        running[pawn] = nil
        self:FinishExecute(false)
        return
    end
    -- Timeout callbacks must close actual damage before State can count a clean window.
    local swept = pcall(runtime.TickDangers, runtime, now, deltaSeconds or 0)
    if not swept then
        running[pawn] = nil
        self:FinishExecute(false)
        return
    end
    if runtime:GetActiveAction() then
        -- A previous committed action is allowed to complete; no new attack starts here.
        local ok = pcall(runtime.Tick, runtime, now, deltaSeconds or 0)
        if not ok then
            running[pawn] = nil
            self:FinishExecute(false)
            return
        end
        if runtime:GetActiveAction() then return end
    end
    local state = runtime:GetState()
    if state:GetBreathingPhase() == Types.BreathingPhase.None then
        state:StartBreathing(now)
    end
    stopMovement(controller, pawn)
    local ok, event = pcall(state.TickBreathing, state, now)
    if not ok or not event then
        running[pawn] = nil
        self:FinishExecute(false)
        return
    end
    if event.event ~= 'finished' then return end
    running[pawn] = nil
    self:FinishExecute(true)
end

function Task:ReceiveAbortAI(_controller, pawn)
    if not pawn or not running[pawn] then
        if self.IsTaskAborting and self:IsTaskAborting() then self:FinishAbort() end
        return
    end
    if pawn then running[pawn] = nil end
    local runtime = pawn and Runtime.Get(pawn)
    if runtime then
        local now = gameTime(pawn) or 0
        local ok, bb = pcall(function() return pawn:GetBlackBoardComponent() end)
        local clear = ok and bb and (readBool(bb, K.IsDead) or readBool(bb, K.MustReset)
            or not readBool(bb, K.CombatActive))
        if clear then
            runtime:Reset(now, 'give-space-disengage-or-reset')
        else
            runtime:GetState():SuspendBreathing(now) -- Hard stagger keeps only the unserved time.
        end
    end
    self:FinishAbort()
end

return Task
