local BTTask_ResetRotation = {}

function BTTask_ResetRotation:ReceiveExecuteAI(OwnerController, ControlledPawn)
    print("monsterK2_SetActorRotation")
    ControlledPawn:K2_SetActorRotation(self.Rotation)
    self:FinishExecute(true)
end

return BTTask_ResetRotation
