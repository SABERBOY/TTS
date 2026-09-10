UGCGameSystem.UGCRequire('Script.GameAttribute.game_attribute_type')

local UGCGlobalDamageCalculation = {}

function UGCGlobalDamageCalculation:GetCalculationResult(Context, ExtraResult)
    -- print("[UGCGlobalDamageCalculation] Context instigator --->"..tostring(Context.Instigator))
    print("[UGCGlobalDamageCalculation] Context SrcMagnitude --->"..tostring(Context.SrcMagnitude))
    print("[UGCGlobalDamageCalculation] Context RestrictedDamageType --->"..tostring(Context.RestrictedDamageType))
    print("[UGCGlobalDamageCalculation] Context DamageTypeTags --->"..tostring(#Context.DamageTypeTags))
    for _, Tag in pairs(Context.DamageTypeTags) do
        if Tag then
            print("[UGCGlobalDamageCalculation] Context Tag: --->"..Tag)
        end
    end

    print("[UGCGlobalDamageCalculation] Context TestGameplayTag.")
    local TestGameplayTag = {"AAA", "Attribute", "EquipmentSlot.Armor", "MainSlot1", "UGC.Damage.Type.Rifle", "UGC.Damage.Result.Critical"}
    for _, v in ipairs(TestGameplayTag) do
        local CritTag = UGCGameplayTagSystem.RequestGameplayTag(v)
        if CritTag then
            print("[UGCGlobalDamageCalculation] Context TestGameplayTag: --->"..CritTag.TagName)
        end
    end

    local SourceObject          = UGCAttributeSystem.GetSourceObjectFromContext(Context)
    local VictimActor           = UGCAttributeSystem.GetVictimFromContext(Context)      --受害者
    local Causer                = UGCAttributeSystem.GetCauserFromContext(Context)      --枪等武器或者人(空手情况)
    local InstigatorController  = UGCAttributeSystem.GetInstigatorFromContext(Context)  --攻击者的Controller
    local CauserActor           = InstigatorController:K2_GetPawn()           --攻击者角色
    print("[UGCGlobalDamageCalculation] Context CauserActor --->"..tostring(CauserActor))

    if not VictimActor or not CauserActor then
        print("[UGCGlobalDamageCalculation] VictimActor or CauserActor is null.")
        return 0
    end
    
    local SkillAttack = UGCAttributeSystem.GetSourceMagnitudeFromContext(Context)

    -- 直接伤害
    if self:HasTag(Context, "UGC.Damage.Type.Direct") then
        print("[UGCGlobalDamageCalculation] Direct damage:"..tostring(SkillAttack))
        return SkillAttack
    end

    -- 反伤伤害
    if self:HasTag(Context, "UGC.Damage.Type.CounterAttack") then
        print("[UGCGlobalDamageCalculation] CounterAttack damage:"..tostring(SkillAttack))
        return SkillAttack
    end
    
    
    
    -- A = Caster, B = Target
    -- SkillAttack = Skill.技能等级伤害 * A.玩家等级 + Skill.技能固定伤害
    -- B.防御减伤比 =（B.防御*（1+B.防御加成比例））*（1-A.防御穿透百分比））/（B.防御*（1+B.防御加成比例）+K*B.Lv+C）
    -- A.技能最终伤害 = SkillAttack *（1+A.∑某类型百分比增伤-B.∑某类型百分比减免+A.某伤害来源增伤）*（暴击 ？A.暴击伤害 : 1）*（1-B.防御减伤)
    local CauserBreakDefenceRatio = UGCAttributeSystem.GetGameAttributeValue(CauserActor, UGCCustomGameAttributeType.UGCAttributeGroup_Character_BreakDefenceRatio) --防御穿透百分比
    local CauserCriticalChance = UGCAttributeSystem.GetGameAttributeValue(CauserActor, UGCCustomGameAttributeType.UGCAttributeGroup_Character_CritChance) --暴击几率
    local CauserCriticalRatio = UGCAttributeSystem.GetGameAttributeValue(CauserActor, UGCCustomGameAttributeType.UGCAttributeGroup_Character_CritRatio) --暴击伤害加成
    local CauserHeadDamageRatio = UGCAttributeSystem.GetGameAttributeValue(CauserActor, UGCCustomGameAttributeType.UGCAttributeGroup_Character_HeadDamageBoost) --爆头伤害加成
    local CauserFireDamageRatio = UGCAttributeSystem.GetGameAttributeValue(CauserActor, UGCCustomGameAttributeType.UGCAttributeGroup_Character_FireDamageBoost) --火属性伤害加成
    local CauserAttackRatio = UGCAttributeSystem.GetGameAttributeValue(CauserActor, UGCCustomGameAttributeType.UGCAttributeGroup_Character_SkillDamageRatio) --角色攻击力加成
    local CauserRifleAttackRatio = UGCAttributeSystem.GetGameAttributeValue(CauserActor, UGCCustomGameAttributeType.UGCAttributeGroup_Character_RifleDamageRatio) --步枪攻击力加成
    local CauserMachineAttackRatio = UGCAttributeSystem.GetGameAttributeValue(CauserActor, UGCCustomGameAttributeType.UGCAttributeGroup_Character_MachineDamageRatio) --机枪攻击力加成
    local CauserShotgunAttackRatio = UGCAttributeSystem.GetGameAttributeValue(CauserActor, UGCCustomGameAttributeType.UGCAttributeGroup_Character_ShotgunDamageRatio) --霰弹枪攻击力加成
    local CauserDMRAttackRatio = UGCAttributeSystem.GetGameAttributeValue(CauserActor, UGCCustomGameAttributeType.UGCAttributeGroup_Character_DMRDamageRatio) --射手步枪枪械攻击力加成
    local CauserLv =  UGCAttributeSystem.GetGameAttributeValue(CauserActor, UGCCustomGameAttributeType.UGCAttributeGroup_Character_Level) or 1
    
    local causer_TestOne =  UGCAttributeSystem.GetGameAttributeValue(CauserActor, 'TestOne') or 1
    print("[UGCGlobalDamageCalculation] TestOne:"..tostring(causer_TestOne))

    local TargetDefence = UGCAttributeSystem.GetGameAttributeValue(VictimActor, UGCCustomGameAttributeType.UGCAttributeGroup_Character_Defence) --防御
    local TargetDefenceBoost = UGCAttributeSystem.GetGameAttributeValue(VictimActor, UGCCustomGameAttributeType.UGCAttributeGroup_Character_ExtraDefenseBoost) --防御加成比例
    local TargetHeadDefenceRatio = UGCAttributeSystem.GetGameAttributeValue(VictimActor, UGCCustomGameAttributeType.UGCAttributeGroup_Character_HeadDamageResist) --爆头伤害减少
    local TargetFireDefenceRatio = UGCAttributeSystem.GetGameAttributeValue(VictimActor, UGCCustomGameAttributeType.UGCAttributeGroup_Character_FireDamageResist) --火属性伤害减少
    local TargetCritDefenceRatio = UGCAttributeSystem.GetGameAttributeValue(VictimActor, UGCCustomGameAttributeType.UGCAttributeGroup_Character_CritDamageResist) --暴击伤害减少
    local TargetProjDefenceRatio = UGCAttributeSystem.GetGameAttributeValue(VictimActor, UGCCustomGameAttributeType.UGCAttributeGroup_Character_ProjDamageResist) --手雷减伤
    local TargetLv = UGCAttributeSystem.GetGameAttributeValue(VictimActor, UGCCustomGameAttributeType.UGCAttributeGroup_Character_Level) or 1
    
    -- B.防御减伤比
    local TmpDefence = TargetDefence * (1 + TargetDefenceBoost)
    local K = 0
    local C = 100
    local damage_decreace_ratio = 1 - TmpDefence * (1 - CauserBreakDefenceRatio) / (TmpDefence + K * TargetLv + C)

    -- 如果伤害不是手雷 
    if not self:HasTag(Context,"UGC.Damage.Proj") then
        TargetProjDefenceRatio = 0
    end

    -- 火属性伤害比例加成
    local FireDamageBoost = 1
    if self:HasTag(Context, "UGC.Damage.Property.Fire") then
        FireDamageBoost = (1 + CauserFireDamageRatio) * (1 - TargetFireDefenceRatio)
        local fire_debug = "CauserFireDamageRatio: " .. tostring(CauserFireDamageRatio).." ,"
        fire_debug = fire_debug .. "TargetFireDefenceRatio: ".. tostring(TargetFireDefenceRatio).." ,"
        fire_debug = fire_debug .. "FireBoost: ".. tostring(FireDamageBoost)
        print("[UGCGlobalDamageCalculation] HasTag Fire: " .. fire_debug)
    end

    -- 爆头伤害比例加成
    local HeadDamageBoost = 1
    if self:IsHeadDamage(Context) then
        HeadDamageBoost = 1 + CauserHeadDamageRatio - TargetHeadDefenceRatio
    end

    -- 步枪伤害比例加成
    if not self:HasTag(Context, "UGC.Damage.Type.Rifle") then
        CauserRifleAttackRatio = 0
    end
    -- 机枪伤害比例加成
    if not self:HasTag(Context, "UGC.Damage.Type.MachineGun") then
        CauserMachineAttackRatio = 0
    end
    -- 霰弹枪伤害比例加成
    if not self:HasTag(Context, "UGC.Damage.Type.Shotgun") then
        CauserShotgunAttackRatio = 0
    end
    -- 射手步枪枪伤害比例加成
    if not self:HasTag(Context, "UGC.Damage.Type.DMRGun") then
        CauserDMRAttackRatio = 0
    end


    local CauserGunTotalAttackRatio = CauserRifleAttackRatio + CauserMachineAttackRatio + CauserShotgunAttackRatio + CauserDMRAttackRatio
    print("[UGCGlobalDamageCalculation] Params: ".. "TargetDefence: ".. TargetDefence.. ", damage_decreace_ratio: ".. damage_decreace_ratio.. ", HeadDamageBoost: ".. HeadDamageBoost)
    print("[UGCGlobalDamageCalculation] Params: CauserGunTotalAttackRatio: ".. tostring(CauserGunTotalAttackRatio)..", CauserAttackRatio: "..tostring(CauserAttackRatio))

    -- 是否暴击
    local IsCritical = (math.random() <= CauserCriticalChance)
    local CriticalRatio = IsCritical and ((1 + CauserCriticalRatio) * (1 - TargetCritDefenceRatio)) or 1
    print("[UGCGlobalDamageCalculation] Params: ".. "SkillAttack: ".. SkillAttack..", IsCritical: ".. tostring(IsCritical).. ", CriticalRatio: ".. CriticalRatio)
    if IsCritical and ExtraResult then
        local CritTag = UGCGameplayTagSystem.RequestGameplayTag("UGC.Damage.Result.Critical")
        if CritTag then
            ExtraResult.ResultTags:Add(CritTag)
        end
    end

    -- 最终伤害
    local FinalDamage = SkillAttack * (1 + CauserGunTotalAttackRatio + CauserAttackRatio) * FireDamageBoost * HeadDamageBoost * CriticalRatio * damage_decreace_ratio * (1 - TargetProjDefenceRatio)
   
    print("[UGCGlobalDamageCalculation] Params: "..", FinalDamage: ".. FinalDamage)
    -- PSkill_Utils:DevLog("MBRTemplarGlow:GetCalculationResult ->", value, add_value, add_cdr, add_radio)

    -- 根据信号值再次处理伤害倍率
    FinalDamage = self:RecalculationDamageForSignalHP(VictimActor, FinalDamage)

    return FinalDamage, ExtraResult
end



-- 根据信号值再次处理伤害倍率
function UGCGlobalDamageCalculation:RecalculationDamageForSignalHP(VictimActor, Damage)
    print("[UGCGlobalDamageCalculation] RecalculationDamageForSignalHP")

    local CurrentSignalHP = UGCAttributeSystem.GetGameAttributeValue(VictimActor, "SignalHP")       --当前信号值
    print("[UGCGlobalDamageCalculation] Context CurrentSignalHP --->"..tostring(CurrentSignalHP))
    local MaxSignalHP = UGCAttributeSystem.GetGameAttributeValueMax(VictimActor, "SignalHP")       --Max信号值
    print("[UGCGlobalDamageCalculation] Context MaxSignalHP --->"..tostring(MaxSignalHP))

    local SignalHPPercent = (CurrentSignalHP / MaxSignalHP) * 100   --当前信号值百分比

    --根据信号值百分比，调整伤害倍率
    if SignalHPPercent <= 25 then
        Damage = Damage * 4
    elseif SignalHPPercent > 25 and SignalHPPercent <= 50 then
        Damage = Damage * 3
    elseif SignalHPPercent > 50 and SignalHPPercent <= 75 then
        Damage = Damage * 2
    else
        Damage = Damage * 1
    end
    print("[UGCGlobalDamageCalculation] Context Damage --->"..tostring(Damage))
    
    return Damage
end


-- 是否有某个tag
function UGCGlobalDamageCalculation:HasTag(Context, Tag)
    if not Tag or not Context then
        return false
    end

    for _, TagName in pairs(Context.DamageTypeTags) do
        if TagName == Tag then
            return true
        end
    end
    return false
end

return UGCGlobalDamageCalculation