---@class BTTask_BossSetIdleState_C:BTTask_LuaBase
--- The idle branch is an unconditional acquisition entry until the context
--- service is attached above the CombatActive decorator.
local Types = require('Script.AI.Boss.BossAI_Types')
local Runtime = require('Script.AI.Boss.BossAI_SkillRuntime')
local Service = require('Script.AI.BT.BTService_BossUpdateContext')
local Movement = require('Script.AI.BT.BTTask_BossChaseSlice').Move

local Task = {}
local K = Types.BBKeys

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
    Service.UpdateContext(controller, pawn)
    if board:GetValueAsBool(K.CombatActive) then
        -- A just-discovered target must survive this idle task.
        self:FinishExecute(true)
        return
    end
    Movement.StopForPawn(pawn)
    local runtime = Runtime.Get(pawn)
    local state = runtime and runtime:GetState()
    if not state or (state:GetBreathingPhase() == Types.BreathingPhase.None
        and not state:HasBreathingDebt()) then
        board:SetValueAsInt(K.ActionKind, Types.ActionKind.None)
        board:SetValueAsInt(K.SelectedSkill, Types.SkillID.None)
    end
    self:FinishExecute(true)
end

return Task
