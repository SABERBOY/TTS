---@class BossSkill_Teleport_C:PESkillTemplate_Base_C
--Edit Below--
local BossSkill_Teleport = {}
 
function BossSkill_Teleport:OnEnableSkill_BP()
    BossSkill_Teleport.SuperClass.OnEnableSkill_BP(self)
end

function BossSkill_Teleport:OnDisableSkill_BP()
    BossSkill_Teleport.SuperClass.OnDisableSkill_BP(self)
end

function BossSkill_Teleport:OnActivateSkill_BP()
    BossSkill_Teleport.SuperClass.OnActivateSkill_BP(self)
end

function BossSkill_Teleport:OnDeActivateSkill_BP()
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