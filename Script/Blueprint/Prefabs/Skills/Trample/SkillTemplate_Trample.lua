---@class SkillTemplate_Trample_C:PESkillTemplate_Charge_C
--Edit Below--
local SkillTemplate_Trample = {}
 
function SkillTemplate_Trample:DisableFaceRotation()
    self.Owner.Owner.bDisableFaceRotation = true
end

function SkillTemplate_Trample:EnableFaceRotation()
    self.Owner.Owner.bDisableFaceRotation = false
end

-- function SkillTemplate_Trample:OnEnableSkill_BP()
-- end

-- function SkillTemplate_Trample:OnDisableSkill_BP(DeltaTime)
   
-- end

-- function SkillTemplate_Trample:OnActivateSkill_BP()
    
-- end

function SkillTemplate_Trample:OnDeActivateSkill_BP()
    SkillTemplate_Trample.SuperClass.OnDeActivateSkill_BP(self)
    -- 确保技能结束后，恢复角色面向旋转
    self:EnableFaceRotation() 
end

-- function SkillTemplate_Trample:CanActivateSkill_BP()
-- end



return SkillTemplate_Trample