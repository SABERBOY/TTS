---@class BTTask_BossReposition_C:BTTask_LuaBase
local Types = require('Script.AI.Boss.BossAI_Types')
local Config = require('Script.AI.Boss.BossAI_Config')
local Movement = require('Script.AI.BT.BTTask_BossChaseSlice').Move

local Task = {}
local runs = setmetatable({}, { __mode = 'k' })
local K = Types.BBKeys
local SliceSeconds = Config.Pressure.ChaseSliceSeconds

function Task:ReceiveExecuteAI(controller, pawn)
    if not UGCGameSystem.IsServer() or not pawn or not UE.IsValid(pawn) then
        self:FinishExecute(false)
        return
    end
    local board = pawn:GetBlackBoardComponent()
    if not board or not board:IsVectorValueSet(K.MoveGoal) then
        Movement.StopForPawn(pawn)
        self:FinishExecute(false)
        return
    end
    local goal = board:GetValueAsVector(K.MoveGoal)
    local run, reason = Movement.Begin(controller, pawn, 'Reposition',
        goal, 100, SliceSeconds, true)
    if run then
        runs[pawn] = run
    elseif reason == 'arrived' then
        runs[pawn] = { wait = true, elapsed = 0, pawn = pawn, controller = controller }
    else
        ugcprint('[BossMove] Reposition failed: ' .. tostring(reason))
        self:FinishExecute(false)
    end
end

function Task:ReceiveTickAI(_controller, pawn, deltaSeconds)
    local run = runs[pawn]
    if not run then return end
    if not Movement.ControllerOwnsPawn(run.controller, pawn) then
        Movement.Stop(run)
        runs[pawn] = nil
        self:FinishExecute(false)
        return
    end
    if run.wait then
        run.elapsed = run.elapsed + math.max(0, deltaSeconds or 0)
        if run.elapsed >= SliceSeconds then
            runs[pawn] = nil
            self:FinishExecute(true)
        end
        return
    end
    local result = Movement.Advance(run, deltaSeconds)
    if result == 'running' then return end
    runs[pawn] = nil
    if result == 'arrived' then
        Movement.Stop(run)
        self:FinishExecute(true)
    elseif result == 'slice' then
        self:FinishExecute(true) -- preserve the same path over decision slices
    else
        Movement.Stop(run)
        ugcprint('[BossMove] Reposition stopped: ' .. tostring(result))
        self:FinishExecute(false)
    end
end

function Task:ReceiveAbortAI(_controller, pawn)
    Movement.Stop(runs[pawn])
    runs[pawn] = nil
    self:FinishAbort()
end

return Task
