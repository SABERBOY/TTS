---@class BossSkill_Teleport_2_C:PESkillTemplate_Base_C
--Edit Below--
local BossSkill_Teleport = {}
 
function BossSkill_Teleport:OnEnableSkill_BP()
    BossSkill_Teleport.SuperClass.OnEnableSkill_BP(self)
end

function BossSkill_Teleport:OnDisableSkill_BP()
    BossSkill_Teleport.SuperClass.OnDisableSkill_BP(self)
end

function BossSkill_Teleport:OnActivateSkill_BP()
    print("BossSkill_Dash:OnActivateSkill_BP -- 技能触发")
    if self:HasAuthority() then
        print("BossSkill_Dash:OnActivateSkill_BP -- 设置无敌状态")
        --self.Owner.Owner:SetInvincible(true) 
        self:GetOwnerActor():SetGenericCharacterIsInvincible(true)
    end
    BossSkill_Teleport.SuperClass.OnActivateSkill_BP(self)
end

function BossSkill_Teleport:OnDeActivateSkill_BP()
    print("BossSkill_Dash:OnDeActivateSkill_BP -- 退出技能")
    if self:HasAuthority() then
        --关闭无敌状态
        print("BossSkill_Dash:OnDeActivateSkill_BP -- 关闭无敌状态")
        --self.Owner.Owner:SetInvincible(false)
        self:GetOwnerActor():SetGenericCharacterIsInvincible(false)
    end
    BossSkill_Teleport.SuperClass.OnDeActivateSkill_BP(self)
end

function BossSkill_Teleport:CanActivateSkill_BP()
    return BossSkill_Teleport.SuperClass.CanActivateSkill_BP(self)
end

function BossSkill_Teleport:TPToSelectTransform()
    local TargetPos = self:GetSelectTransform().Translation
    ugcprint('Test.......................................TP')
    self:GetOwnerActor():K2_SetActorLocation(Vector.New(TargetPos.X, TargetPos.Y, TargetPos.Z + 88.0))
    if UGCGameSystem.IsServer() then

    end
end

return BossSkill_Teleport