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

    -- 服务器生成怪物并绑定重生逻辑
    if UGCGameSystem.IsServer() then
        if UE.IsValid(self.SpawnMonsterClass) then
            self:SpawnCurrentMonster()
        else
            print("BP_HeroSkillSingleExamples:ReceiveBeginPlay 没有配置可用的怪物类 SpawnMonsterClass")
        end
        return
    end

    -- Skill 是逐个实例在编辑器里配的，示例关卡里有没配的空实例，
    -- GetClassDefaultObject(nil) 返回 nil；而 UIInfo 只有客户端刷界面文本时才用得到
    local SkillCDO = UE.IsValid(self.Skill) and STExtraGameplayStatics.GetClassDefaultObject(self.Skill)
    local UIInfo = SkillCDO and SkillCDO.UIInfo
    if not UIInfo then
        print("BP_HeroSkillSingleExamples:ReceiveBeginPlay 没有配置可用的技能类 Skill，跳过界面文本")
        return
    end

    self.Widget2.Widget.TextBlock_Title:SetText("" .. tostring(UIInfo.SKillName))
    self.Widget1.Widget.TextBlock_Title:SetText("" .. tostring(UIInfo.SkillDetail))
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
