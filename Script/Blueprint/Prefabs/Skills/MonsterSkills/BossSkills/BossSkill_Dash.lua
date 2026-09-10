---@class BossSkill_Dash_C:PESkillTemplate_Base_C
--Edit Below--
local BossSkill_Dash = {}
 
--[[
function BossSkill_Dash:OnEnableSkill_BP()
end

function BossSkill_Dash:OnDisableSkill_BP(DeltaTime)
end

function BossSkill_Dash:OnActivateSkill_BP()
end

function BossSkill_Dash:OnDeActivateSkill_BP()
end

function BossSkill_Dash:CanActivateSkill_BP()
end

--]]

function BossSkill_Dash:OnActivateSkill_BP()
    print("BossSkill_Dash:OnActivateSkill_BP -- 技能触发")
    if self:HasAuthority() then
        print("BossSkill_Dash:OnActivateSkill_BP -- 设置无敌状态")
        --self.Owner.Owner:SetInvincible(true) 
        self:GetOwnerActor():SetGenericCharacterIsInvincible(true)
    end

    BossSkill_Dash.SuperClass.OnActivateSkill_BP(self);
end

function BossSkill_Dash:OnDeActivateSkill_BP()
    print("BossSkill_Dash:OnDeActivateSkill_BP -- 退出技能")
    if self:HasAuthority() then
        --关闭无敌状态
        print("BossSkill_Dash:OnDeActivateSkill_BP -- 关闭无敌状态")
        --self.Owner.Owner:SetInvincible(false)
        self:GetOwnerActor():SetGenericCharacterIsInvincible(false)
    end
    BossSkill_Dash.SuperClass.OnDeActivateSkill_BP(self);
end

function BossSkill_Dash:HideActorInGame()
    self:GetOwnerActor():SetActorHiddenInGame(true)
end

function BossSkill_Dash:UnHideActorInGame()
    self:GetOwnerActor():SetActorHiddenInGame(false)
end



return BossSkill_Dash