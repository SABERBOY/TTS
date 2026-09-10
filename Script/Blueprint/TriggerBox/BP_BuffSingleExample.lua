---@class BP_BuffSingleExample_C:BP_ExampleBase_C
---@field Widget1 UWidgetComponent
---@field Buff UClass
---@field SpawnMonsterClass UClass
--Edit Below--
local BP_BuffSingleExample = {
    CurrentMonster =nil,
}

function BP_BuffSingleExample:CheckCanActive(ClickParam)
    return true;
end

function BP_BuffSingleExample:PlayerAddBuff(ClickParam)
    ugcprint("BP_BuffSingleExample:AddSkill")
    if not UGCGameSystem.IsServer() then
        return 
    end

    local PC = ClickParam.PlayerController
    if UE.IsValid(PC) then
        local Pawn = UGCPlayerControllerSystem.GetPlayerCharacter(PC)
        if UE.IsValid(Pawn) and UE.IsValid(self.Buff) then
            UGCPersistEffectSystem.AddBuffByClass(Pawn, self.Buff, Pawn, -1.0, 1);
        end
    end
end


function BP_BuffSingleExample:MonsterAddBuff(ClickParam)
    ugcprint("BP_BuffSingleExample:MonsterAddBuff")
    if not UGCGameSystem.IsServer() then
        return
    end

    local PC = ClickParam.PlayerController
    if UE.IsValid(self.CurrentMonster) and UE.IsValid(self.Buff) and UE.IsValid(PC) then
        --怪物血量小于0不允许添加Buff
        if UGCAttributeSystem.GetGameAttributeValue(self.CurrentMonster, 'Health') <= 0 then
            print("BP_BuffSingleExample:MonsterAddBuff :怪物血量为0 不允许添加Buff")
            return
        end
        local causer = UGCPlayerControllerSystem.GetPlayerCharacter(PC)
        UGCPersistEffectSystem.AddBuffByClass(self.CurrentMonster, self.Buff, causer, -1.0, 1);
    end
end



function BP_BuffSingleExample:ReceiveBeginPlay()
    BP_BuffSingleExample.SuperClass.ReceiveBeginPlay(self)
    if not UE.IsValid(self.SpawnMonsterClass) then
        print("BP_BuffSingleExample:ReceiveBeginPlay 没有配置可用的怪物类 SpawnMonsterClass")
        return
    end

    -- 服务器生成怪物并绑定重生/移除Buff逻辑
    if UGCGameSystem.IsServer() then
        self:SpawnCurrentMonster()
    else
        -- Buff描述
        if self.Buff ~= nil then
            local MonsterBuffCDO = STExtraGameplayStatics.GetClassDefaultObject(self.Buff)
            local MosterBuffName = MonsterBuffCDO.BuffInfo.UIInfo.BuffName
            local MonsterBuffDetail = MonsterBuffCDO.BuffInfo.UIInfo.BuffDetail
            self.Widget1.Widget.TextBlock_Title:SetText(tostring(MosterBuffName) .. ": " .. tostring(MonsterBuffDetail))
        end
    end
end

function BP_BuffSingleExample:RemoveBuff(Comp,CurTag)
    print("BP_BuffSingleExample:RemoveBuff CurState")
    local Tag = UGCGameplayTagSystem.RequestGameplayTag("PawnState.Dead")
    if UGCGameplayTagSystem.EqualsTag(CurTag, Tag) then
        print("BP_BuffSingleExample:RemoveBuff：Monster Dead")
        UGCPersistEffectSystem.RemoveBuffByClass(self.CurrentMonster, self.Buff)
    end
end


function BP_BuffSingleExample:SpawnCurrentMonster()
    print("BP_BuffSingleExample:SpawnCurrentMonster")
    if not UGCGameSystem.IsServer() then
        return
    end

    local Location = self:K2_GetActorLocation()
    local Rotation = self:K2_GetActorRotation()
    self.CurrentMonster = UGCGenericCharacterSystem.SpawnGenericCharacter(self, self.SpawnMonsterClass, Location, Rotation)
    if not UE.IsValid(self.CurrentMonster) then
        print("BP_BuffSingleExample:SpawnCurrentMonster 生成怪物失败")
        return
    end
    self.CurrentMonster.OnDestroyed:Add(self.RESpawn, self)
    local PersistBaseComponent = UGCPersistEffectSystem.GetPersistBaseComponentByContent(self.CurrentMonster)
    PersistBaseComponent.DynamicStateEnterHandle:Add(self.RemoveBuff, self)
end

function BP_BuffSingleExample:RESpawn()
    print("BP_BuffSingleExample:RESpawn")
    self:SpawnCurrentMonster()
end


return BP_BuffSingleExample
