---@class UGCAttributeGroup_C:GameAttributeGroup
--Edit Below--
local UGCAttributeGroup_Character = {}
local UGCGameData = UGCGameSystem.UGCRequire('Script.Blueprint.UGCGameData')
 
function UGCAttributeGroup_Character:OnInitGroup()
    -- 属性操作只在Server进行
	if not UGCGameSystem.IsServer() then
        return
    end
    local OwnerActor = self:GetGroupOwner()

    -- 记录默认值，用于等级提升后重新设置属性值
    self.BaseHealth = UGCAttributeSystem.GetGameAttributeValue(OwnerActor, 'BaseHealth')
    self.OrignalMagic = UGCAttributeSystem.GetGameAttributeValue(OwnerActor, 'MaxMagic')
    self.Defence = UGCAttributeSystem.GetGameAttributeValue(OwnerActor, 'Defence')

     --1秒后更新等级相关属性, 延迟是因为需要等待Character 和 PlayerState的绑定
     Timer.InsertTimer(1, function ()
        self:InitLevelRelated()
        self:UpdateMaxHealth()

        if OwnerActor and OwnerActor.GetPlayerStateSafety and OwnerActor:GetPlayerStateSafety() then
            local OwnerState = OwnerActor:GetPlayerStateSafety()
            -- 等级系统是可选的：本项目 UGCPlayerState 没有 OnLevelChanged 委托
            -- （也没有 UGCPlayerLevel 字段和 Asset/Data/Level 配表），没委托就不订阅
            if OwnerState.OnLevelChanged then
                print("[UGCAttributeGroup_Character] Listen LevelChanged: "..tostring(OwnerState))
                OwnerState.OnLevelChanged:Add(self.InitLevelRelated, self)
            end
        end
    end)

    self.HealthBoostDelegate = UGCAttributeSystem.AddGameAttributeChangedDelegate(OwnerActor, "HealthBoost", function (AttrName, CurValue)
        self:UpdateMaxHealth()
    end)
    self.BaseHealthDelegate = UGCAttributeSystem.AddGameAttributeChangedDelegate(OwnerActor, "BaseHealth", function (AttrName, CurValue)
        self:UpdateMaxHealth()
    end)

    -- 怪物属性默认值从表格里读取
    self:InitMonsterAttributes()
end

function UGCAttributeGroup_Character:InitMonsterAttributes()
    local OwnerActor = self:GetGroupOwner()
    if OwnerActor.MonsterID and OwnerActor.MonsterID > 0 then
        local MonsterDetailCfg = UGCGameData.GetMonsterConfig(OwnerActor.MonsterID)
        ugcprint("UGCAttributeGroup_Character:InitMonsterAttributes, MonsterID is: "..tostring(OwnerActor.MonsterID)..", MonsterDetailCfg:"..tostring(MonsterDetailCfg))
        if MonsterDetailCfg then
            UGCAttributeSystem.SetGameAttributeValue(OwnerActor, 'BaseHealth', MonsterDetailCfg.Health)
            -- UGCAttributeSystem.SetGameAttributeValue(OwnerActor, 'Defence', MonsterDetailCfg.Defence)
            UGCAttributeSystem.SetGameAttributeValue(OwnerActor, 'CritDamageResist', MonsterDetailCfg.CritDamageResist)
            UGCAttributeSystem.SetGameAttributeValue(OwnerActor, 'HeadDamageResist', MonsterDetailCfg.HeadDamageResist)
            UGCAttributeSystem.SetGameAttributeValue(OwnerActor, 'FireDamageResist', MonsterDetailCfg.FireDamageResist)
            UGCAttributeSystem.SetGameAttributeValue(OwnerActor, 'CounterAttackRatio', MonsterDetailCfg.CounterAttackRatio)
            UGCAttributeSystem.SetGameAttributeValue(OwnerActor, 'HealthStealRatio', MonsterDetailCfg.HealthStealRatio)
        end
    end
end

-- 初始化等级相关的数据
function UGCAttributeGroup_Character:InitLevelRelated()
    local OwnerActor = self:GetGroupOwner()
    -- print("[UGCAttributeGroup_Character] InitLevelRelated: "..tostring(OwnerActor.GetPlayerStateSafety))

    if OwnerActor and OwnerActor.GetPlayerStateSafety then
        local OwnerState = OwnerActor:GetPlayerStateSafety()
        print("[UGCAttributeGroup_Character] InitLevelRelated: "..tostring(OwnerState))
        if OwnerState then
            -- local player = self:GetPlayerCharacter()
            local PlayerLevel = OwnerState.UGCPlayerLevel
            -- 没接等级系统时 UGCPlayerLevel 为 nil，下面 LvGlobalCfg 分支要做 PlayerLevel - 1，
            -- nil 会直接抛算术错误；等级表也读不到，这里直接返回
            if not PlayerLevel then
                return
            end
            -- 设置等级对应的属性值
            local LvCfg = UGCGameData.GetLevelConfig(PlayerLevel)
            if LvCfg then
                for _, AttributeCfg in pairs(LvCfg.Attributes) do
                    UGCAttributeSystem.SetGameAttributeValue(OwnerActor, AttributeCfg.Attribute.AttributeName, AttributeCfg.Value)
                    print("[UGCAttributeGroup_Character] Init Attribute: "..AttributeCfg.Attribute.AttributeName.." value： "..AttributeCfg.Value)
                end
            end

            -- 设置等级对应的增量
            local LvGlobalCfg = UGCGameData.GetGlobalLevelConfig()
            if LvGlobalCfg then
                UGCAttributeSystem.SetGameAttributeValue(OwnerActor, 'BaseHealth', self.BaseHealth + LvGlobalCfg.HealthDelta * (PlayerLevel - 1))
                UGCAttributeSystem.SetGameAttributeValue(OwnerActor, 'MaxMagic', self.OrignalMagic + LvGlobalCfg.MagicDelta * (PlayerLevel - 1))
                -- UGCAttributeSystem.SetGameAttributeValue(OwnerActor, 'Defence', self.Defence + LvGlobalCfg.DefenceDelta * (OwnerState.UGCPlayerLevel - 1))
                print("[UGCAttributeGroup_Character] MaxMagic: "..self.OrignalMagic..', Level: '..PlayerLevel..', magic delta:'..LvGlobalCfg.MagicDelta)
            end
        end
    end  
end

-- 力量决定HealthMax
function UGCAttributeGroup_Character:UpdateMaxHealth()
    -- local OwnerActor = self:GetGroupOwner()
    -- if OwnerActor and self.OwnerAttrComp then
    --     local OldValue = UGCAttributeSystem.GetGameAttributeValue(OwnerActor, 'HealthMax')
    --     local HealthBoost = UGCAttributeSystem.GetGameAttributeValue(OwnerActor, 'HealthBoost')
    --     local BaseHealth = UGCAttributeSystem.GetGameAttributeValue(OwnerActor, 'BaseHealth')
    --     local NewValue = (1 + HealthBoost) * BaseHealth
    --     if OldValue ~= NewValue then
    --         UGCAttributeSystem.SetGameAttributeValue(OwnerActor, 'HealthMax', NewValue)
    --         UGCAttributeSystem.AddGameAttributeValue(OwnerActor, 'Health', NewValue - OldValue)
    --     end
    --     print("[UGCAttributeGroup_Character] HealthMax New: ".. NewValue)
    -- else
    --     print("[UGCAttributeGroup_Character] param error: ".. OwnerActor..", Comp value: ".. self.OwnerAttrComp)
    -- end
end

-- Destroy
function UGCAttributeGroup_Character:OnDestroyGroup()
    local OwnerActor = self:GetGroupOwner()

    if self.HealthBoostDelegate then
        UGCAttributeSystem.RemoveGameAttributeChangedDelegate(OwnerActor, "HealthBoost", self.HealthBoostDelegate)
        self.HealthBoostDelegate = nil
    end
    if self.BaseHealthDelegate then
        UGCAttributeSystem.RemoveGameAttributeChangedDelegate(OwnerActor, "BaseHealth", self.BaseHealthDelegate)
        self.BaseHealthDelegate = nil
    end
end

-- 技能CD倍率计算
function UGCAttributeGroup_Character:GetSkillCDRecoverRate_Override(OriginalValue, AttributeOwnerActor)
    if not AttributeOwnerActor then
        return OriginalValue
    end
    local TargetLv = 1
    local K = 0
    local C = 100
    local TargetSkillCd = UGCAttributeSystem.GetGameAttributeValue(AttributeOwnerActor, 'SkillCD') or 0 --获取技能冷却属性

    local Value =  (K * TargetLv + C) / (TargetSkillCd + K * TargetLv + C)
    -- print("[UGCDerivedAttributes] OverrideSkillCDRecoverRate: ".. OriginalValue.. ", new value: ".. value.. ", owner: ".. tostring(AttributeOwnerActor))
    return Value
end

function UGCAttributeGroup_Character:GetMagic_Override(OriginalValue, AttributeOwnerActor)
	return OriginalValue;
end

function UGCAttributeGroup_Character:GetHeadDamageBoost_Override(OriginalValue, AttributeOwnerActor)
	return OriginalValue;
end

return UGCAttributeGroup_Character