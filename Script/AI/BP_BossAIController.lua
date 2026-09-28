local BP_BossAIController = {}
 
--[[
function ActorName:OnPossess(PossessedPawn)
    BP_BossAIController.SuperClass.OnPossess(self, PossessedPawn)

    -- local BehaviorTree = UE.LoadObject("填入要加载的BehaviorTree资源路径")
    -- if BehaviorTree ~= nil then
        -- self:RunBehaviorTree()
    -- end
end
--]]

--[[
function BP_BossAIController:OnUnpossess(UnpossessedPawn)
    BP_BossAIController.SuperClass.OnUnpossess(self, UnpossessedPawn)
end
--]]

return BP_BossAIController