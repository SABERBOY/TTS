---@class BTTask_BossDeath_C:BTTask_LuaBase
--- Idempotent terminal cleanup for one Boss. Existing character death presentation owns visuals.
local Types = require('Script.AI.Boss.BossAI_Types')
local Runtime = require('Script.AI.Boss.BossAI_SkillRuntime')

local Task = {}
local handled = setmetatable({}, { __mode = 'k' })
local K = Types.BBKeys

local function gameTime(pawn)
    local ok, value = pcall(function() return UGCGameSystem.GetTimeSeconds(pawn) end)
    if ok and type(value) == 'number' and value == value then return value end
    return 0
end

function Task:ReceiveExecuteAI(controller, pawn)
    if not pawn then self:FinishExecute(false); return end
    local okBB, bb = pcall(function() return pawn:GetBlackBoardComponent() end)
    if okBB and bb then
        pcall(function()
            bb:SetValueAsBool(K.IsDead, true)
            bb:SetValueAsBool(K.CombatActive, false)
            bb:SetValueAsBool(K.HasLineOfSight, false)
            bb:SetValueAsBool(K.PhaseTransitionReady, false)
            bb:SetValueAsBool(K.CanApplyHardStagger, false)
            bb:SetValueAsBool(K.MustReset, false)
            bb:SetValueAsInt(K.SelectedSkill, Types.SkillID.None)
            bb:SetValueAsInt(K.ActionKind, Types.ActionKind.None)
            bb:SetValueAsObject(K.TargetActor, nil)
        end)
    end
    if not handled[pawn] then
        local cleanupOK = pcall(function() Runtime.Release(pawn, gameTime(pawn), 'death') end)
        pcall(function()
            if controller and controller.StopMovement then controller:StopMovement() end
            local movement = pawn.GetMovementComponent and pawn:GetMovementComponent()
            if movement and movement.StopMovementImmediately then movement:StopMovementImmediately() end
        end)
        if not cleanupOK then
            pcall(function() ugcprint('[BossDeath] runtime cleanup failed; retrying') end)
            self:FinishExecute(false)
            return
        end
        handled[pawn] = true
    end
    self:FinishExecute(true)
    pcall(function()
        local brain = controller and (controller.BrainComponent or
            (controller.GetBrainComponent and controller:GetBrainComponent()))
        if brain and brain.StopLogic then brain:StopLogic('BossDead') end
    end)
end

function Task:ReceiveAbortAI(_controller, _pawn)
    self:FinishAbort()
end

return Task
