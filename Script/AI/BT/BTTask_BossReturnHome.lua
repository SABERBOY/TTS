---@class BTTask_BossReturnHome_C:BTTask_LuaBase
--- Navigation return is bounded. Failure parks this encounter in idle and
--- records homeFailed for explicit external retry; it never teleports.
local Types = require('Script.AI.Boss.BossAI_Types')
local Runtime = require('Script.AI.Boss.BossAI_SkillRuntime')
local Observed = require('Script.AI.Boss.BossAI_Observed')
local Movement = require('Script.AI.BT.BTTask_BossChaseSlice').Move

local Task = {}
local runs = setmetatable({}, { __mode = 'k' })
local K = Types.BBKeys
local ArriveRadius, ReturnTimeout = 150, 20

local function clearEncounter(pawn, board, success)
    local now = UGCGameSystem.GetTimeSeconds(pawn)
    local clean = Runtime.Release(pawn, now,
        success and 'return-home' or 'return-home-failed')
    board:SetValueAsBool(K.MustReset, false)
    board:SetValueAsBool(K.CombatActive, false)
    board:SetValueAsBool(K.HasLineOfSight, false)
    board:SetValueAsObject(K.TargetActor, nil)
    board:ClearValue(K.LastKnownTargetLocation)
    board:ClearValue(K.MoveGoal)
    board:SetValueAsFloat(K.DistanceToTarget, -1)
    board:SetValueAsInt(K.ActionKind, Types.ActionKind.None)
    board:SetValueAsInt(K.SelectedSkill, Types.SkillID.None)
    board:SetValueAsInt(K.CurrentPhase, 1)
    board:SetValueAsBool(K.PhaseTransitionReady, false)
    board:SetValueAsBool(K.CanApplyHardStagger, false)
    Observed.Clear(pawn)
    if not success or clean ~= true then
        Observed.SetHomeFailed(pawn, true)
        ugcprint(clean ~= true
            and '[BossMove] ReturnHome danger cleanup failed; encounter parked for retry'
            or '[BossMove] ReturnHome failed; encounter parked until an explicit reset')
    end
    return success and clean == true
end

function Task:ReceiveExecuteAI(controller, pawn)
    if not UGCGameSystem.IsServer() or not pawn or not UE.IsValid(pawn) then
        self:FinishExecute(false)
        return
    end
    local board = pawn:GetBlackBoardComponent()
    if not board then
        self:FinishExecute(false)
        return
    end
    local observed = Observed.Get(pawn)
    if observed and observed.homeFailed then
        Movement.StopForPawn(pawn)
        board:SetValueAsBool(K.CombatActive, false)
        board:SetValueAsBool(K.HasLineOfSight, false)
        self:FinishExecute(false)
        return
    end
    board:SetValueAsBool(K.CombatActive, false)
    board:SetValueAsBool(K.HasLineOfSight, false)
    local now = UGCGameSystem.GetTimeSeconds(pawn)
    local runtime = Runtime.Get(pawn)
    if runtime then
        local state = runtime:GetState()
        local active = runtime:GetActiveAction()
        if active then
            runtime:Abort(active.id, 'return-home', now, true)
        else
            state:ClearDangers()
        end
        if state:HasDangerCleanupFailure() then
            Movement.StopForPawn(pawn)
            clearEncounter(pawn, board, false)
            self:FinishExecute(false)
            return
        end
    end
    Movement.StopForPawn(pawn)
    if not board:IsVectorValueSet(K.HomeLocation) then
        clearEncounter(pawn, board, false)
        self:FinishExecute(false)
        return
    end
    local home = board:GetValueAsVector(K.HomeLocation)
    local run, reason = Movement.Begin(controller, pawn, 'ReturnHome',
        home, ArriveRadius, ReturnTimeout, false)
    if not run then
        local success = reason == 'arrived'
        self:FinishExecute(clearEncounter(pawn, board, success))
        return
    end
    runs[pawn] = run
end

function Task:ReceiveTickAI(_controller, pawn, deltaSeconds)
    local run = runs[pawn]
    if not run then return end
    local result = Movement.Advance(run, deltaSeconds)
    if result == 'running' then return end
    runs[pawn] = nil
    Movement.Stop(run)
    if not pawn or not UE.IsValid(pawn) then
        self:FinishExecute(false)
        return
    end
    local board = pawn:GetBlackBoardComponent()
    if not board then
        self:FinishExecute(false)
        return
    end
    local success = result == 'arrived'
    self:FinishExecute(clearEncounter(pawn, board, success))
end

function Task:ReceiveAbortAI(_controller, pawn)
    Movement.Stop(runs[pawn])
    runs[pawn] = nil
    self:FinishAbort()
end

return Task
