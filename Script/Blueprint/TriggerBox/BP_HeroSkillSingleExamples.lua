---@class BP_HeroSkillSingleExamples_C:BP_ExampleBase_C
---@field Widget1 UWidgetComponent
---@field Widget2 UWidgetComponent
---@field Skill UClass
---@field SpawnMonsterClass UClass
--Edit Below--
local BP_HeroSkillSingleExamples = {
    SkillInstance = nil,
    CurrentMonster = nil,
}

function BP_HeroSkillSingleExamples:CheckCanActive(ClickParam)
    return true;
end

function BP_HeroSkillSingleExamples:AddSkill(ClickParam)
    ugcprint("BP_HeroSkillSingleExamples:AddSkill")
    if not UGCGameSystem.IsServer() then
        return
    end

    local PC = ClickParam.PlayerController
    if UE.IsValid(PC) then
        local Pawn = UGCPlayerControllerSystem.GetPlayerCharacter(PC)
        self.SkillInstance = UGCPersistEffectSystem.AddSkillByClass(Pawn, self.Skill)
    end
end

function BP_HeroSkillSingleExamples:RmoveSkill(ClickParam)
    ugcprint("BP_HeroSkillSingleExamples:RmoveSkill")
    if not UGCGameSystem.IsServer() then
        return
    end

    local PC = ClickParam.PlayerController
    if UE.IsValid(PC) then
        local Pawn = UGCPlayerControllerSystem.GetPlayerCharacter(PC)
        local SkillInstanceList = UGCPersistEffectSystem.GetSkillsByClass(Pawn, self.Skill);
        if #SkillInstanceList > 0 then
            for _, _SkillInstance in ipairs(SkillInstanceList) do
                UGCPersistEffectSystem.RemoveSkillInstance(Pawn, _SkillInstance)
            end
        end
    end
end

function BP_HeroSkillSingleExamples:ReceiveBeginPlay()
    BP_HeroSkillSingleExamples.SuperClass.ReceiveBeginPlay(self)

    local SkillCDO = STExtraGameplayStatics.GetClassDefaultObject(self.Skill)
    local SKillName = SkillCDO.UIInfo.SKillName
    local SkillDetail = SkillCDO.UIInfo.SkillDetail

    -- 服务器生成怪物并绑定重生逻辑
    if UGCGameSystem.IsServer() then
        if UE.IsValid(self.SpawnMonsterClass) then
            self:SpawnCurrentMonster()
        else
            print("BP_HeroSkillSingleExamples:ReceiveBeginPlay 没有配置可用的怪物类 SpawnMonsterClass")
        end
    else
        self.Widget2.Widget.TextBlock_Title:SetText("" .. tostring(SKillName))
        self.Widget1.Widget.TextBlock_Title:SetText("" .. tostring(SkillDetail))
    end
end

function BP_HeroSkillSingleExamples:SpawnCurrentMonster()
    print("BP_HeroSkillSingleExamples:SpawnCurrentMonster")
    if not UGCGameSystem.IsServer() then
        return
    end

    local Location = self:K2_GetActorLocation()
    local Rotation = self:K2_GetActorRotation()
    self.CurrentMonster = UGCGenericCharacterSystem.SpawnGenericCharacter(self, self.SpawnMonsterClass, Location, Rotation)
    if not UE.IsValid(self.CurrentMonster) then
        print("BP_HeroSkillSingleExamples:SpawnCurrentMonster 生成怪物失败")
        return
    end
    self.CurrentMonster.OnDestroyed:Add(self.RESpawn, self)
end

function BP_HeroSkillSingleExamples:RESpawn()
    print("BP_HeroSkillSingleExamples:RESpawn")
    self:SpawnCurrentMonster()
end

return BP_HeroSkillSingleExamples
