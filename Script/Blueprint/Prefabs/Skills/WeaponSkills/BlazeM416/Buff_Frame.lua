---@class Buff_Frame_C:PersistEffectBuff
---@field BurningDamagePercentage float
---@field DamageTakenIncreasedPercentage float
--Edit Below--
local Buff_Frame = {}
local SkillUtils = UGCGameSystem.UGCRequire('Script.Blueprint.Prefabs.Skills.Skill_Utils')

-- function Buff_Frame:OnApply_BP(OwnerActor)
--     print("Buff_Frame:OnApply_BP(OwnerActor)")
--     if not UGCGameSystem.IsServer() then
--         return
--     end
    
--     -- 安全检查
--     if not OwnerActor then
--         SkillUtils:LogError("Buff_Frame", "OnApply_BP: OwnerActor is nil")
--         return
--     end
--     local MaxDefense = UGCAttributeSystem.GetGameAttributeValue(OwnerActor,"Defense")
--     UGCAttributeSystem.AddGameAttributeValue(OwnerActor, 'Defense', -10)--(MaxDefense*self.DamageTakenIncreasedPercentage/100)
-- end

-- function Buff_Frame:OnUnApply_BP(OwnerActor, Reason)
--     if not UGCGameSystem.IsServer() then
--         return
--     end
    
--     -- 安全检查
--     if not OwnerActor then
--         SkillUtils:LogError("Buff_Frame", "OnUnApply_BP: OwnerActor is nil")
--         return
--     end

--     local MaxDefense = UGCAttributeSystem.GetGameAttributeValue(OwnerActor,"Defense")
--     UGCAttributeSystem.AddGameAttributeValue(OwnerActor, 'Defense', 10)--MaxDefense*self.DamageTakenIncreasedPercentage/100
-- end

return Buff_Frame