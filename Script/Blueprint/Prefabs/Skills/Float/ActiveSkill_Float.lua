---@class BP_Float_C:PESkillTemplate_Indicate_C
---@field UpDirection FVector
--Edit Below--
local ActiveSkill_Float = {
    OriginGravityScale = nil,
    bNeedToRestoreGravityScale = false,
    DamagedActor = {},
    bEnableNextStep = true
}
 
function ActiveSkill_Float:OnEnableSkill_BP()
    ActiveSkill_Float.SuperClass.OnEnableSkill_BP(self)
end

function ActiveSkill_Float:OnDisableSkill_BP()
    ActiveSkill_Float.SuperClass.OnDisableSkill_BP(self)
end

function ActiveSkill_Float:OnActivateSkill_BP()
    ActiveSkill_Float.SuperClass.OnActivateSkill_BP(self)
    local OwnerLocation = self:GetNetOwnerActor():K2_GetActorLocation()
    if  UGCGameSystem.IsServer() then
        self.DamagedActor = {}
    end
end

function ActiveSkill_Float:SetSprintDirection()
    self:SetSelectDirection(self.UpDirection)
end

-- 设置重力系数为0
function ActiveSkill_Float:SetGravityScaleZero()
    local OwnerCharacter =  self.Owner.Owner
    local MoveComp = OwnerCharacter:GetCharacterMovementComponent()
    if MoveComp then
        self.OriginGravityScale = MoveComp.GravityScale
        MoveComp.GravityScale = 0
        self.bNeedToRestoreGravityScale = true
    end
end

function ActiveSkill_Float:DisableNextStep()
    self.bEnableNextStep = false
end

function ActiveSkill_Float:EnableNextStep()
    self.bEnableNextStep = true
end

function ActiveSkill_Float:NextStep()
    if self.bEnableNextStep then
        ActiveSkill_Float.SuperClass.NextStep(self)
    end
end

-- 恢复重力系数
function ActiveSkill_Float:RestoreGravityScale()
    local OwnerCharacter =  self:GetNetOwnerActor()
    local MoveComp = OwnerCharacter:GetCharacterMovementComponent()
    if MoveComp then
        MoveComp.GravityScale = self.OriginGravityScale
        self.bNeedToRestoreGravityScale = false
    end
end


return ActiveSkill_Float