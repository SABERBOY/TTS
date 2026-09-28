---@class BTTask_BossHardStagger_C:BTTask_LuaBase
--- A legal stagger interrupts the current action once and preserves breathing debt.
local Types = require('Script.AI.Boss.BossAI_Types')
local Runtime = require('Script.AI.Boss.BossAI_SkillRuntime')

local Task = {}
local running = setmetatable({}, { __mode = 'k' })
local consumed = setmetatable({}, { __mode = 'k' })
local K = Types.BBKeys

local function gameTime(pawn)
    local ok, value = pcall(function() return UGCGameSystem.GetTimeSeconds(pawn) end)
    if ok and type(value) == 'number' and value == value then return value end
    return nil
end

local function stopMovement(controller, pawn)
    pcall(function()
        if controller and controller.StopMovement then controller:StopMovement() end
        local movement = pawn and pawn.GetMovementComponent and pawn:GetMovementComponent()
        if movement and movement.StopMovementImmediately then movement:StopMovementImmediately() end
    end)
end

function Task:ReceiveExecuteAI(controller, pawn)
    if not pawn then self:FinishExecute(false); return end
    local okBB, bb = pcall(function() return pawn:GetBlackBoardComponent() end)
    if not okBB or not bb then self:FinishExecute(false); return end
    if consumed[pawn] then
        -- A synchronous selector search must not consume the same request twice.
        pcall(function() bb:SetValueAsBool(K.CanApplyHardStagger, false) end)
        if self.IsTaskExecuting and not self:IsTaskExecuting() then return end
        self:FinishExecute(true)
        return
    end
    consumed[pawn] = true
    local now = gameTime(pawn) or 0
    local runtime = Runtime.Get(pawn)
    if runtime then
        local active = runtime:GetActiveAction()
        if active then runtime:Abort(active.id, 'hard-stagger', now, false) end
        runtime:GetState():SuspendBreathing(now)
    end
    stopMovement(controller, pawn)
    local duration = runtime and runtime:GetState().config.HardStaggerSeconds or nil
    running[pawn] = { remaining = math.max(0, tonumber(duration) or 0.45) }
    -- Keep the flag during the stagger; consume it at completion.
end

function Task:ReceiveTickAI(controller, pawn, deltaSeconds)
    local run = pawn and running[pawn]
    if not run then return end
    stopMovement(controller, pawn)
    run.remaining = run.remaining - math.max(0, tonumber(deltaSeconds) or 0)
    if run.remaining > 0 then return end
    running[pawn] = nil
    local okBB, bb = pcall(function() return pawn:GetBlackBoardComponent() end)
    if okBB and bb then
        pcall(function() bb:SetValueAsBool(K.CanApplyHardStagger, false) end)
    end
    consumed[pawn] = nil
    -- A Self/Both blackboard observer may abort us synchronously when the flag clears.
    if self.IsTaskExecuting and not self:IsTaskExecuting() then return end
    self:FinishExecute(true)
end

function Task:ReceiveAbortAI(_controller, pawn)
    if pawn then running[pawn] = nil end
    if pawn then consumed[pawn] = nil end
    local okBB, bb = pcall(function() return pawn and pawn:GetBlackBoardComponent() end)
    if okBB and bb then
        pcall(function() bb:SetValueAsBool(K.CanApplyHardStagger, false) end)
    end
    self:FinishAbort()
end

return Task
