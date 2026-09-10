---@class BP_MonsterSkillSingleExample_C:BP_ExampleBase_C
---@field SpawnMonsterClass UClass
--Edit Below--
local BP_MonsterSkillSingleExample = {
    CurrentMonster = nil,
}

function BP_MonsterSkillSingleExample:CheckCanActive(ClickParam)
    return true
end

function BP_MonsterSkillSingleExample:ReceiveBeginPlay()
    BP_MonsterSkillSingleExample.SuperClass.ReceiveBeginPlay(self)

    -- 服务器生成怪物（本示例无需重生）
    if UGCGameSystem.IsServer() then
        if UE.IsValid(self.SpawnMonsterClass) then
            self:SpawnCurrentMonster()
        else
            print("BP_MonsterSkillSingleExample:ReceiveBeginPlay 没有配置可用的怪物类 SpawnMonsterClass")
        end
    end
end

function BP_MonsterSkillSingleExample:SpawnCurrentMonster()
    print("BP_MonsterSkillSingleExample:SpawnCurrentMonster")
    if not UGCGameSystem.IsServer() then
        return
    end

    local Location = self:K2_GetActorLocation()
    local Rotation = self:K2_GetActorRotation()
    self.CurrentMonster = UGCGenericCharacterSystem.SpawnGenericCharacter(self, self.SpawnMonsterClass, Location, Rotation)
    if not UE.IsValid(self.CurrentMonster) then
        print("BP_MonsterSkillSingleExample:SpawnCurrentMonster 生成怪物失败")
        return
    end
end

function BP_MonsterSkillSingleExample:MonsterStartAttack(ClickParam)
    local player = self:GetPlayerAndTarget()
    if player and player.controller and player.target then
        UnrealNetwork.CallUnrealRPC(player.controller, self, "ServerRPC_MonsterStartAttack", player.target)
    end
end

function BP_MonsterSkillSingleExample:MonsterStopAttack(ClickParam)
    local player = self:GetPlayerAndTarget()
    if player and player.controller and player.target then
        UnrealNetwork.CallUnrealRPC(player.controller, self, "ServerRPC_MonsterStopAttack", player.target)
    end
end

function BP_MonsterSkillSingleExample:GetPlayerAndTarget()
    local PC = UGCGameSystem.GetLocalPlayerController()
    if not UE.IsValid(PC) then
        return nil
    end

    local Target = UGCPlayerControllerSystem.GetPlayerCharacter(PC)
    if not UE.IsValid(Target) then
        return nil
    end

    return {
        controller = PC,
        target = Target
    }
end

function BP_MonsterSkillSingleExample:ServerRPC_MonsterStartAttack(Target)
    self:UpdateMonsterTarget(Target)
end

function BP_MonsterSkillSingleExample:ServerRPC_MonsterStopAttack(Target)
    self:UpdateMonsterTarget(nil)
end

function BP_MonsterSkillSingleExample:UpdateMonsterTarget(targetObject)
    if not UE.IsValid(self.CurrentMonster) then
        return
    end

    local BB = AIBlueprintHelperLibrary.GetBlackboard(self.CurrentMonster)
    if not BB then
        return
    end

    BB:SetValueAsObject("Target", targetObject)
end

function BP_MonsterSkillSingleExample:GetAvailableServerRPCs()
    return "ServerRPC_MonsterStartAttack", "ServerRPC_MonsterStopAttack"
end

return BP_MonsterSkillSingleExample
