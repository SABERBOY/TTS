---@class ActiveSkill_ThorM416_C:PESkillTemplate_Active_C
---@field FanaticismBuffClass UClass
--Edit Below--
local ActiveSkill_ThorM416 = {}
 
function ActiveSkill_ThorM416:OnEnableSkill_BP()
    ActiveSkill_ThorM416.SuperClass.OnEnableSkill_BP(self)
end

function ActiveSkill_ThorM416:OnDisableSkill_BP()
    ActiveSkill_ThorM416.SuperClass.OnDisableSkill_BP(self)
    UGCPersistEffectSystem.RemoveBuffByClass(self:GetNetOwnerActor(), self.FanaticismBuffClass, 1, nil)
end

function ActiveSkill_ThorM416:OnActivateSkill_BP()
    ActiveSkill_ThorM416.SuperClass.OnActivateSkill_BP(self)
end

function ActiveSkill_ThorM416:OnDeActivateSkill_BP()
    ActiveSkill_ThorM416.SuperClass.OnDeActivateSkill_BP(self)
end

function ActiveSkill_ThorM416:CanActivateSkill_BP()
    return ActiveSkill_ThorM416.SuperClass.CanActivateSkill_BP(self)
end

return ActiveSkill_ThorM416