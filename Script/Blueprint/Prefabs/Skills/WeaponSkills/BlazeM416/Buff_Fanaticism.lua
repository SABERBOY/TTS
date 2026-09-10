---@class Buff_Fanaticism_C:PersistEffectBuff
---@field DamageBonusPercentage float
---@field ReloadSpeedBonusPercentage float
--Edit Below--
---@class Buff_Fanaticism_C:PersistEffectBuff
---@field DamageBonusPercentage float 伤害加成百分比
---@field ReloadSpeedBonusPercentage float 装填速度加成百分比
---@field bIsActive boolean Buff是否激活
---@field ReloadValue float 装填速度恢复值

-- 狂热Buff：狂热状态，狂热状态下伤害提升50%，换弹速度提升100%，持续10秒
local Buff_Fanaticism = {
    bIsActive = false,   -- Buff激活状态
    ReloadValue = 0,     -- 装填速度恢复值
    DamageRemember = nil,
    TargetWeapon = nil,
}

local SkillUtils = UGCGameSystem.UGCRequire('Script.Blueprint.Prefabs.Skills.Skill_Utils')

---Buff应用时调用
---@param OwnerActor object 拥有者Actor
function Buff_Fanaticism:OnApply_BP(OwnerActor)
    -- 仅在服务端执行
    if not UGCGameSystem.IsServer() then
        return
    end
    
    -- 安全检查
    if not OwnerActor then
        SkillUtils:LogError("Buff_Fanaticism", "OnApply_BP: OwnerActor is nil")
        return
    end
    
    -- 应用伤害加成
    local damageBonus = self.DamageBonusPercentage / 100
    self.DamageRemember = UGCAttributeSystem.GetGameAttributeValue(OwnerActor:GetCurrentWeapon(),'BaseImpactDamageWrapper')
    UGCAttributeSystem.AddGameAttributeValue(OwnerActor:GetCurrentWeapon(), 'BaseImpactDamageWrapper', damageBonus*self.DamageRemember)
    
    -- 应用装填速度加成
    self.ReloadValue = UGCAttributeSystem.GetGameAttributeValue(OwnerActor:GetCurrentWeapon(), 'ReloadTimeFactorWrapper') / 2
    UGCAttributeSystem.AddGameAttributeValue(OwnerActor:GetCurrentWeapon(), 'ReloadTimeFactorWrapper', -self.ReloadValue)
    
    -- 记录属性变化
    SkillUtils:LogInfo("Buff_Fanaticism", string.format("Damage bonus ratio: %.2f", UGCAttributeSystem.GetGameAttributeValue(OwnerActor:GetCurrentWeapon(), 'BaseImpactDamageWrapper')))
    SkillUtils:LogInfo("Buff_Fanaticism", string.format("Reload time factor: %.2f", UGCAttributeSystem.GetGameAttributeValue(OwnerActor:GetCurrentWeapon(), 'ReloadTimeFactorWrapper')))
    
    self.bIsActive = true
end

---Buff移除时调用
---@param OwnerActor object 拥有者Actor
---@param Reason string 移除原因
function Buff_Fanaticism:OnUnApply_BP(OwnerActor, Reason)
    -- 仅在服务端执行
    if not UGCGameSystem.IsServer() then
        return
    end
    
    -- 安全检查
    if not OwnerActor then
        SkillUtils:LogError("Buff_Fanaticism", "OnUnApply_BP: OwnerActor is nil")
        return
    end
    
    -- 移除伤害加成
    local damageBonus = self.DamageBonusPercentage / 100
    local CurrentDamage = UGCAttributeSystem.GetGameAttributeValue(OwnerActor:GetCurrentWeapon(),'BaseImpactDamageWrapper')
    UGCAttributeSystem.AddGameAttributeValue(OwnerActor:GetCurrentWeapon(), 'BaseImpactDamageWrapper', -damageBonus*self.DamageRemember)
    
    -- 移除装填速度加成
    UGCAttributeSystem.AddGameAttributeValue(OwnerActor:GetCurrentWeapon(), 'ReloadTimeFactorWrapper', self.ReloadValue)
    
    -- 记录属性变化
    SkillUtils:LogInfo("Buff_Fanaticism", string.format("Damage bonus ratio: %.2f", UGCAttributeSystem.GetGameAttributeValue(OwnerActor:GetCurrentWeapon(), 'BaseImpactDamageWrapper')))
    SkillUtils:LogInfo("Buff_Fanaticism", string.format("Reload time factor: %.2f", UGCAttributeSystem.GetGameAttributeValue(OwnerActor:GetCurrentWeapon(), 'ReloadTimeFactorWrapper')))
    
    -- 重置状态
    self.bIsActive = false
end
return Buff_Fanaticism