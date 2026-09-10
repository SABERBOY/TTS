---@class Skill_PowerReserveKar98k_C:PESkillPassiveSkillTemplate_C
---@field PowerReserveKar98kBuffClass UClass
---@field RemoveBuffTime float
---@field AddBuffTime float
local Skill_PowerReserveKar98k = {
    TimerHandle = nil,
    RemoveBuffTimer = nil,
    BulletHitDelegate = nil
}

function Skill_PowerReserveKar98k:OnApply_BP()
    Skill_PowerReserveKar98k.SuperClass.OnApply_BP(self)

    local owner = self:GetNetOwnerActor()
    if not owner then
        return
    end

    self.BulletHitDelegate = owner.OnBulletHitDelegate:Add(self.RemoveBuff, self)
end

function Skill_PowerReserveKar98k:RemoveBuff()
    local owner = self.Owner and self.Owner.Owner
    if not owner then
        return
    end

    self.BulletHitTimerHandle, _ = UGCGameSystem.SetTimer(self, function()
        UGCPersistEffectSystem.RemoveBuffByClass(owner, self.PowerReserveKar98kBuffClass, 6, nil)
    end, 0.2, false)
end

function Skill_PowerReserveKar98k:OnUnApply_BP()
    Skill_PowerReserveKar98k.SuperClass.OnUnApply_BP(self)

    if self.BulletHitDelegate then
        local owner = self:GetNetOwnerActor()
        if owner then
            owner.OnBulletHitDelegate:Remove(self.BulletHitDelegate, self)
        end
        self.BulletHitDelegate = nil
    end

    if self.BulletHitTimerHandle then
        UGCGameSystem.ClearTimer(self, self.BulletHitTimerHandle)
        self.BulletHitTimerHandle = nil
    end

    if self.RemoveBuffTimer then
        UGCGameSystem.ClearTimer(self, self.RemoveBuffTimer)
        self.RemoveBuffTimer = nil
    end

    if self.TimerHandle then
        UGCGameSystem.ClearTimer(self, self.TimerHandle)
        self.TimerHandle = nil
    end

    local owner = self.Owner and self.Owner.Owner
    if owner then
        UGCPersistEffectSystem.RemoveBuffByClass(owner, self.PowerReserveKar98kBuffClass, 6, nil)
    end
end

function Skill_PowerReserveKar98k:OnEnableSkill_BP()
    Skill_PowerReserveKar98k.SuperClass.OnEnableSkill_BP(self)
end

function Skill_PowerReserveKar98k:OnDisableSkill_BP()
    Skill_PowerReserveKar98k.SuperClass.OnDisableSkill_BP(self)

    local owner = self.Owner and self.Owner.Owner
    if owner then
        UGCPersistEffectSystem.RemoveBuffByClass(owner, self.PowerReserveKar98kBuffClass, -1, nil)
    end
end

function Skill_PowerReserveKar98k:OnActivateSkill_BP()
    Skill_PowerReserveKar98k.SuperClass.OnActivateSkill_BP(self)

    local owner = self.Owner and self.Owner.Owner
    if not owner then
        return
    end

    self.TimerHandle, _ = UGCGameSystem.SetTimer(self, function()
        UGCPersistEffectSystem.AddBuffByClass(owner, self.PowerReserveKar98kBuffClass,owner,-1, 1)
    end, self.AddBuffTime, true)
end

function Skill_PowerReserveKar98k:OnDeActivateSkill_BP()
    Skill_PowerReserveKar98k.SuperClass.OnDeActivateSkill_BP(self)

    if self.TimerHandle then
        UGCGameSystem.ClearTimer(self, self.TimerHandle)
        self.TimerHandle = nil
    end

    local owner = self.Owner and self.Owner.Owner
    if not owner then
        return
    end

    self.RemoveBuffTimer, _ = UGCGameSystem.SetTimer(self, function()
        UGCPersistEffectSystem.RemoveBuffByClass(owner, self.PowerReserveKar98kBuffClass, 6, nil)
        UGCGameSystem.ClearTimer(self, self.RemoveBuffTimer)
        self.RemoveBuffTimer = nil
    end, self.RemoveBuffTime, false)
end

return Skill_PowerReserveKar98k
