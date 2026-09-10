---@class PassiveSkill_RisingWindsM249_C:PESkillPassiveSkillTemplate_C
---@field RecoveryItemID int32
---@field RecoveryItemCount int32
---@field ActorDetectFilter ULuaArrayHelper<UClass>
---@field HitCountThreshold int32
---@field BulletRecoverEffect UClass
--Edit Below--
---@class PassiveSkill_RisingWindsM249_C:PESkillPassiveSkillTemplate_C
---@field RecoveryItemID int32
---@field RecoveryItemCount int32
---@field ActorDetectFilter TArray<UClass*>
---@field HitCountThreshold int32
-- Edit Below--
local PassiveSkill_RisingWindsM249 = {
    HitCount = 0
}

function PassiveSkill_RisingWindsM249:OnActivateSkill_BP()
    PassiveSkill_RisingWindsM249.SuperClass.OnActivateSkill_BP(self)
    print("PassiveSkill_RisingWindsM249:OnActivateSkill_BP()")
    if UGCGameSystem.IsServer() then
        self.HitCount = self.HitCount + 1
        if self.HitCount == self.HitCountThreshold then
            -- 回复道具
            print("PassiveSkill_RisingWindsM249:OnActivateSkill_BP--AddBuffByClass")
            UGCPersistEffectSystem.AddBuffByClass(self:GetNetOwnerActor(), self.BulletRecoverEffect, self:GetNetOwnerActor())
            UGCBackPackSystem.AddItem(self:GetNetOwnerActor(), self.RecoveryItemID, self.RecoveryItemCount)
            self.HitCount = 0
        end
    end

end

function PassiveSkill_RisingWindsM249:CanActivateSkill_BP()
    if PassiveSkill_RisingWindsM249.SuperClass.CanActivateSkill_BP(self) then
        local TargetActors = self:GetSelectTargetActor(EPESkillSelectTarget.E_PESKILL_PickerType_AllTarget)
        -- 武器命中事件一次塞一个目标进去
        if TargetActors:Num() >= 1 then
            local TargetActor = TargetActors:Get(1)
            print("PassiveSkill_RisingWindsM249:CanActivateSkill_BP() TargetActor" .. tostring(TargetActor))
            if self.ActorDetectFilter == nil or self.ActorDetectFilter:Num() == 0 then
                -- self.ActorDetectFilter为空时，命中任何目标都能触发被动
                return true
            else
                -- self.ActorDetectFilter不为空时，只有当命中目标是列表内的Class，才能触发被动
                if TargetActor ~= nil then
                    for _, ActorClass in pairs(self.ActorDetectFilter) do
                        if UE.IsA(TargetActor, ActorClass) then
                            return true
                        end
                    end
                end
            end
        else
            print("PassiveSkill_RisingWindsM249:CanActivateSkill_BP() [TargetActors:Num()<1]")
        end
    end
    return false

end

return PassiveSkill_RisingWindsM249
