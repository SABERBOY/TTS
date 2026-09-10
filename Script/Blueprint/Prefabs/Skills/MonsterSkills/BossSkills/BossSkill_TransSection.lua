---@class BossSkill_TransSection_C:PESkillTemplate_Base_C
--Edit Below--
local BossSkill_TransSection = {}
 
function BossSkill_TransSection:OnEnableSkill_BP()
    BossSkill_TransSection.SuperClass.OnEnableSkill_BP(self)
end

function BossSkill_TransSection:OnDisableSkill_BP()
    BossSkill_TransSection.SuperClass.OnDisableSkill_BP(self)
end

function BossSkill_TransSection:OnActivateSkill_BP()
    BossSkill_TransSection.SuperClass.OnActivateSkill_BP(self)
end

function BossSkill_TransSection:OnDeActivateSkill_BP()
    BossSkill_TransSection.SuperClass.OnDeActivateSkill_BP(self)
end

function BossSkill_TransSection:CanActivateSkill_BP()
    return BossSkill_TransSection.SuperClass.CanActivateSkill_BP(self)
end

function BossSkill_TransSection:SetSelectDir()
    self:SetSelectDirection(Vector.New(0.0, 0.0, 1.0))
    --self:GetOwnerActor():Lo
end

function BossSkill_TransSection:SetSelectDirDown()
    self:SetSelectDirection(Vector.New(0.0, 0.0, -1.0))
    local MoveComp = self:GetOwnerActor():GetMovementComponent()
    if MoveComp then
        MoveComp.GravityScale = self.OriginGravityScale
    end
end

function BossSkill_TransSection:SetBossPositionToSelectPosition()
    --self:GetOwnerActor():K2_SetActorLocation(self.CachePosition)
    self:SetSelectTransform(self:GetOwnerActor():K2_GetActorLocation())
end


function BossSkill_TransSection:SetGrivatyZero()
    ugcprint('设置重力系数...................')
    local MoveComp = self:GetOwnerActor():GetMovementComponent()
    if MoveComp then
        self.OriginGravityScale = MoveComp.GravityScale
        MoveComp.GravityScale = 0
        ugcprint('怪物重力系数设置为0')
    end

    --self.CachePosition = self:GetOwnerActor():K2_GetActorLocation()    
end

function BossSkill_TransSection:SetInvincibleEnable()
    ugcprint('设置无敌')
    self:GetOwnerActor():SetGenericCharacterIsInvincible(true)
end

function BossSkill_TransSection:SetInvincibleDisabled()
    ugcprint('解除无敌')
    self:GetOwnerActor():SetGenericCharacterIsInvincible(false)
end


return BossSkill_TransSection