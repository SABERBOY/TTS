---@class Skill_TeammateChickenMagicV2_C:PESkillTemplate_Base_C
--Edit Below--
local Skill_TeammateChickenMagic = {}
 
--[[
function Skill_TeammateChickenMagic:OnEnableSkill_BP()
end

function Skill_TeammateChickenMagic:OnDisableSkill_BP(DeltaTime)
end

function Skill_TeammateChickenMagic:OnActivateSkill_BP()
end

function Skill_TeammateChickenMagic:OnDeActivateSkill_BP()
    UGCPersistEffectSystem.RemoveSkillInstance(self:GetOwnerActor(), self)
end

function Skill_TeammateChickenMagic:CanActivateSkill_BP()
end

--]]

-- function Skill_TeammateChickenMagic:OnActivateSkill_BP()
--     print("Skill_TeammateChickenMagic:OnActivateSkill_BP()")
-- end

function Skill_TeammateChickenMagic:OnDeActivateSkill_BP()
    print("Skill_TeammateChickenMagic:OnDeActivateSkill_BP()")
    UGCPersistEffectSystem.RemoveSkillInstance(self:GetOwnerActor(), self)
end

-- function Skill_TeammateChickenMagic:Indicate_Entry()
--     print("Skill_TeammateChickenMagic:Indicate_Entry()")
   
-- end

-- function Skill_TeammateChickenMagic:Indicate_Exit()
--     print("Skill_TeammateChickenMagic:Indicate_Exit()")
--     UGCPersistEffectSystem.RemoveSkillInstance(self:GetOwnerActor(), self)
-- end




return Skill_TeammateChickenMagic