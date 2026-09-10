---@class SkillTemplate_Combo_C:PESkillTemplate_Base_C
---@field IsShowComboTime bool
---@field ComboInputProgress float
---@field Combo1Time float
---@field Combo2Time float
---@field NowProgressTime float
--Edit Below--
local SkillTemplate_Combo = {}
 
function SkillTemplate_Combo:OnEnableSkill_BP()
    SkillTemplate_Combo.SuperClass.OnEnableSkill_BP(self)
end

function SkillTemplate_Combo:OnDisableSkill_BP()
    SkillTemplate_Combo.SuperClass.OnDisableSkill_BP(self)
end

function SkillTemplate_Combo:OnActivateSkill_BP()
    SkillTemplate_Combo.SuperClass.OnActivateSkill_BP(self)
end

function SkillTemplate_Combo:OnDeActivateSkill_BP()
    SkillTemplate_Combo.SuperClass.OnDeActivateSkill_BP(self)
end

function SkillTemplate_Combo:CanActivateSkill_BP()
    return SkillTemplate_Combo.SuperClass.CanActivateSkill_BP(self)
end

function SkillTemplate_Combo:ShowComboInputProgress()
    self.IsShowComboTime = true
    self.ComboInputProgress = 1.0
    self.NowProgressTime = 0.0
end

function SkillTemplate_Combo:UpdateComboInputProgress()
    self.NowProgressTime = self.NowProgressTime + 0.02
    if self:GetCurrentStateName() == 'Combo1' then
        self.ComboInputProgress = self.NowProgressTime / self.Combo1Time
    elseif self:GetCurrentStateName() == 'Combo2' then
        self.ComboInputProgress = self.NowProgressTime / self.Combo2Time
    end
end

function SkillTemplate_Combo:UnShowComboInputProgress()
    self.IsShowComboTime = false
end

return SkillTemplate_Combo