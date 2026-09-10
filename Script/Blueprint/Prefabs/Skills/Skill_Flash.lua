---@class Skill_Flash_C:PESkillTemplate_Base_C
--Edit Below--
local Skill_Flash = {}

function Skill_Flash:HasValidSelectedDirection()
    local SelectedDir = self:GetSelectDirection()
    local Zero = UGCMathUtility.MakeVector(0.0,0.0,0.0)
    return UGCMathUtility.NotEqualVector(SelectedDir, Zero)
end

function Skill_Flash:OnActivateSkill_BP()
    print("Skill_Flash:OnActivateSkill_BP -- 技能触发")
    if self:HasAuthority() then
        print("Skill_Flash:OnActivateSkill_BP -- 设置无敌状态")
        --self.Owner.Owner:SetInvincible(true) 
        self:GetNetOwnerActor():SetInvincible(true)
    end

    Skill_Flash.SuperClass.OnActivateSkill_BP(self);
end

function Skill_Flash:OnDeActivateSkill_BP()
    print("Skill_Flash:OnDeActivateSkill_BP -- 退出技能")
    if self:HasAuthority() then
        --关闭无敌状态
        print("Skill_Flash:OnDeActivateSkill_BP -- 关闭无敌状态")
        --self.Owner.Owner:SetInvincible(false)
        self:GetNetOwnerActor():SetInvincible(false)
    end
    Skill_Flash.SuperClass.OnDeActivateSkill_BP(self);
end
return Skill_Flash