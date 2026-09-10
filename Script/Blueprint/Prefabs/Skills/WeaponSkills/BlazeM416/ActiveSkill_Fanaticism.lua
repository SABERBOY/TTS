---@class ActiveSkill_Fanaticism_C:PESkillTemplate_Active_C
---@field FanaticismBuffClass UClass
--Edit Below--
local ActiveSkill_Fanaticism = {}
 
function ActiveSkill_Fanaticism:OnEnableSkill_BP()
    ActiveSkill_Fanaticism.SuperClass.OnEnableSkill_BP(self)
end

function ActiveSkill_Fanaticism:OnDisableSkill_BP()
    ActiveSkill_Fanaticism.SuperClass.OnDisableSkill_BP(self)
    print("ActiveSkill_Fanaticism:OnDisableSkill_BP()")
    UGCPersistEffectSystem.RemoveBuffByClass(self:GetNetOwnerActor(), self.FanaticismBuffClass, -1)
end

function ActiveSkill_Fanaticism:OnActivateSkill_BP()
    ActiveSkill_Fanaticism.SuperClass.OnActivateSkill_BP(self)
end

function ActiveSkill_Fanaticism:OnDeActivateSkill_BP()
    ActiveSkill_Fanaticism.SuperClass.OnDeActivateSkill_BP(self)
end

function ActiveSkill_Fanaticism:CanActivateSkill_BP()
    return ActiveSkill_Fanaticism.SuperClass.CanActivateSkill_BP(self)
end

return ActiveSkill_Fanaticism