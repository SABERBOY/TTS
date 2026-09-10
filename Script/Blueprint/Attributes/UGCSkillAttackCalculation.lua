---@class UGCSkillAttackCalculation_C:STExtraGameMagnitudeCalculation
---@field Skill_Damage_Level float
-- Edit Below--
local UGCSkillAttackCalculation = {}

function UGCSkillAttackCalculation:GetCalculationResult(context)
    local victim_actor = self:GetTargetActor(context)
    local causer_actor = self:GetCauser(context)
    local source_object = self:GetSourceObject(context)

    if not victim_actor or not causer_actor then
        print("[UGCSkillAttackCalculation] victim_actor or causer_actor is null.")
        return 0
    end

    local causer_lv = 1
    local skill_damage_const = self:GetSourceDamageMagnitude(context)
    local skill_damage_lv = self.Skill_Damage_Level

    local skill_attack = causer_lv * skill_damage_lv + skill_damage_const
    print("[UGCSkillAttackCalculation] Params: " .. "skill_attack: " .. skill_attack)

    return skill_attack
end

return UGCSkillAttackCalculation
