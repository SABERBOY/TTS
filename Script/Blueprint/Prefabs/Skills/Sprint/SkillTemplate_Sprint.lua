---@class SkillTemplate_SprintV2_C:PESkillTemplate_Active_C
--Edit Below--
local SkillTemplate_Sprint = {}
 
--[[
function SkillTemplate_Sprint:OnEnableSkill_BP()
end

function SkillTemplate_Sprint:OnDisableSkill_BP(DeltaTime)
end

function SkillTemplate_Sprint:OnActivateSkill_BP()
end

function SkillTemplate_Sprint:OnDeActivateSkill_BP()
end

function SkillTemplate_Sprint:CanActivateSkill_BP()
end

--]]

function SkillTemplate_Sprint:OnActivateSkill_BP()
    print("SkillTemplate_Sprint:OnActivateSkill_BP -- 技能触发")
    if self:HasAuthority() then
        print("SkillTemplate_Sprint:OnActivateSkill_BP -- 设置无敌状态")
        --self.Owner.Owner:SetInvincible(true) 
        self:GetNetOwnerActor():SetInvincible(true)
    end

    SkillTemplate_Sprint.SuperClass.OnActivateSkill_BP(self);
end

function SkillTemplate_Sprint:OnDeActivateSkill_BP()
    print("SkillTemplate_Sprint:OnDeActivateSkill_BP -- 退出技能")
    if self:HasAuthority() then
        --关闭无敌状态
        print("SkillTemplate_Sprint:OnDeActivateSkill_BP -- 关闭无敌状态")
        --self.Owner.Owner:SetInvincible(false)
        self:GetNetOwnerActor():SetInvincible(false)
    end
    SkillTemplate_Sprint.SuperClass.OnDeActivateSkill_BP(self);
end

return SkillTemplate_Sprint