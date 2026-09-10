---@class Skill_BuildFireworks_C:PESkillTemplate_Base_C
--Edit Below--
local Skill_BuildFireworks = {}
 
--[[
function Skill_BuildFireworks:OnEnableSkill_BP()
end

function Skill_BuildFireworks:OnDisableSkill_BP(DeltaTime)
end



function Skill_BuildFireworks:CanActivateSkill_BP()
end

--]]

-- function Skill_BuildFireworks:OnActivateSkill_BP()
--     print("Skill_BuildFireworks:OnActivateSkill_BP()")
-- end

function Skill_BuildFireworks:OnDeActivateSkill_BP()
    print("Skill_BuildFireworks:OnDeActivateSkill_BP()")
    UGCPersistEffectSystem.RemoveSkillInstance(self:GetOwnerActor(), self)
end

-- function Skill_BuildFireworks:Indicate_Entry()
--     print("Skill_BuildFireworks:Indicate_Entry()")
   
-- end

-- function Skill_BuildFireworks:Indicate_Exit()
--     print("Skill_BuildFireworks:Indicate_Exit()")
--     UGCPersistEffectSystem.RemoveSkillInstance(self:GetOwnerActor(), self)
-- end




return Skill_BuildFireworks