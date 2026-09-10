---@class PassiveSkill_ElectrifiedStrike_C:PESkillPassiveSkillTemplate_C
---@field HittedTargetCamp TArray<ECampRelation>
--Edit Below--
local PassiveSkill_ElectrifiedStrike = {}
 
function PassiveSkill_ElectrifiedStrike:OnEnableSkill_BP()
    PassiveSkill_ElectrifiedStrike.SuperClass.OnEnableSkill_BP(self)
end

function PassiveSkill_ElectrifiedStrike:OnDisableSkill_BP()
    PassiveSkill_ElectrifiedStrike.SuperClass.OnDisableSkill_BP(self)
end

function PassiveSkill_ElectrifiedStrike:OnActivateSkill_BP()
    PassiveSkill_ElectrifiedStrike.SuperClass.OnActivateSkill_BP(self)
end

function PassiveSkill_ElectrifiedStrike:OnDeActivateSkill_BP()
    PassiveSkill_ElectrifiedStrike.SuperClass.OnDeActivateSkill_BP(self)
end

function PassiveSkill_ElectrifiedStrike:CanActivateSkill_BP()
    ugcprint("PassiveSkill_ElectrifiedStrike:CanActivateSkill_BP()")
    if PassiveSkill_ElectrifiedStrike.SuperClass.CanActivateSkill_BP(self) then
        local TargetActors = self:GetSelectTargetActor(EPESkillSelectTarget.E_PESKILL_PickerType_AllTarget)

        if TargetActors:Num() >= 1 then
            local TargetActor = TargetActors:Get(1)
            local Relation = TargetActor:GetGeneralCampRelationWithActor(self:GetNetOwnerActor())
            ugcprint("PassiveSkill_ElectrifiedStrike:CanActivateSkill_BP TargetActor"..tostring(TargetActor).. " CampRelation="..tostring(Relation))
            for _ , CampRelation in pairs(self.HittedTargetCamp) do
                if Relation == CampRelation then
                    return true
                end
            end
        else
            ugcprint("PassiveSkill_ElectrifiedStrike:CanActivateSkill_BP() [TargetActors:Num()<1]")
        end
    end

    return false
end

return PassiveSkill_ElectrifiedStrike