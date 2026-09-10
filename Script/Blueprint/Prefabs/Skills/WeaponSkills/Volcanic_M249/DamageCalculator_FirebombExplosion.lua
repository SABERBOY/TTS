---@class DamageCalculator_FirebombExplosion_C:STExtraGameMagnitudeCalculation
---@field ExplosionDecayPerMeter float
---@field ExplosionDecayMaxLimit float
---@field BaseAttackMultiplier float
-- Edit Below--
local DamageCalculator_FirebombExplosion = {}

function DamageCalculator_FirebombExplosion:GetCalculationResult(context)
    local victim_actor = self:GetTargetActor(context)
    local causer_actor = self:GetCauser(context)
    local source_object = self:GetSourceObject(context)

    -- 计算被攻击者与炎爆弹之间的距离
    local dist = victim_actor:GetDistanceTo(source_object)

    local BaseAttack = UGCAttributeSystem.GetGameAttributeValue(causer_actor, 'BaseAttack')

    local DecayRatio = (dist / 100) * self.ExplosionDecayPerMeter
    if DecayRatio > self.ExplosionDecayMaxLimit then
        DecayRatio = self.ExplosionDecayMaxLimit
    end

    local damage = BaseAttack * self.BaseAttackMultiplier * (1 - DecayRatio)
    return damage

end

return DamageCalculator_FirebombExplosion
