---@class BTTask_BossPhaseTransition_C:BTTask_LuaBase
--- Consume the phase request once, and only after action, danger and breathing settle.
local Types = require('Script.AI.Boss.BossAI_Types')
local Runtime = require('Script.AI.Boss.BossAI_SkillRuntime')

local Task = {}
local K = Types.BBKeys

local function gameTime(pawn)
    local ok, value = pcall(function() return UGCGameSystem.GetTimeSeconds(pawn) end)
    if ok and type(value) == 'number' and value == value then return value end
    return nil
end

local function finishIfExecuting(task, success)
    -- Clearing a Self/Both observed key can abort this task synchronously.
    if task.IsTaskExecuting and not task:IsTaskExecuting() then return end
    task:FinishExecute(success)
end

function Task:ReceiveExecuteAI(_controller, pawn)
    if not pawn then self:FinishExecute(false); return end
    local okBB, bb = pcall(function() return pawn:GetBlackBoardComponent() end)
    if not okBB or not bb then self:FinishExecute(false); return end
    local runtime = Runtime.Get(pawn)
    local now = gameTime(pawn)
    if not runtime or not now then self:FinishExecute(false); return end
    local state = runtime:GetState()

    -- A stale/duplicate decorator request must not play the transition again.
    if state.phaseTransitionDone then
        pcall(function()
            bb:SetValueAsInt(K.CurrentPhase, state:GetPhase())
            bb:SetValueAsBool(K.PhaseTransitionReady, false)
        end)
        finishIfExecuting(self, true)
        return
    end
    if not state:IsPhaseTransitionRequested() then
        pcall(function() bb:SetValueAsBool(K.PhaseTransitionReady, false) end)
        finishIfExecuting(self, false)
        return
    end
    if not state:CanApplyPhaseTransition(now) then
        -- Keep the request in State. Service can re-arm the priority flag at a safe boundary.
        pcall(function() bb:SetValueAsBool(K.PhaseTransitionReady, false) end)
        finishIfExecuting(self, false)
        return
    end

    if not state:ApplyPhaseTransition() then
        self:FinishExecute(false)
        return
    end
    local okWrite = pcall(function()
        bb:SetValueAsInt(K.CurrentPhase, state:GetPhase())
        bb:SetValueAsBool(K.PhaseTransitionReady, false)
    end)
    finishIfExecuting(self, okWrite)
end

function Task:ReceiveAbortAI(_controller, _pawn)
    self:FinishAbort()
end

return Task
