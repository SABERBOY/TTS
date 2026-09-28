---@class BTTask_BossSearch_C:BTTask_LuaBase
--- Search only uses the last confirmed position, never a hidden actor transform.
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
    if not board or board:GetValueAsBool(K.HasLineOfSight)
        or not board:IsVectorValueSet(K.LastKnownTargetLocation) then
        Movement.StopForPawn(pawn)
        self:FinishExecute(false)
        return
    end
    local lastKnown = board:GetValueAsVector(K.LastKnownTargetLocation)
    local run, reason = Movement.Begin(controller, pawn, 'Search',
        lastKnown, 100, SliceSeconds, true)
    if run then
        runs[pawn] = run
    elseif reason == 'arrived' then
        -- Dwell at the last known point so an unreacquired target cannot cause
        -- an immediate BT replan loop.
        runs[pawn] = { wait = true, elapsed = 0, pawn = pawn, controller = controller }
    else
        ugcprint('[BossMove] Search failed: ' .. tostring(reason))
        self:FinishExecute(false)
    end
end

function Task:ReceiveTickAI(_controller, pawn, deltaSeconds)
    local run = runs[pawn]
    if not run then return end
    local board = pawn and UE.IsValid(pawn) and pawn:GetBlackBoardComponent()
    if not board or not Movement.ControllerOwnsPawn(run.controller, pawn) then
        Movement.Stop(run)
        runs[pawn] = nil
        self:FinishExecute(false)
        return
    end
    if board:GetValueAsBool(K.HasLineOfSight) then
        Movement.Stop(run)
        runs[pawn] = nil
        self:FinishExecute(true)
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
        self:FinishExecute(true) -- keep path across search slices
    else
        Movement.Stop(run)
        ugcprint('[BossMove] Search stopped: ' .. tostring(result))
        self:FinishExecute(false)
    end
end

function Task:ReceiveAbortAI(_controller, pawn)
    Movement.Stop(runs[pawn])
    runs[pawn] = nil
    self:FinishAbort()
end

return Task
