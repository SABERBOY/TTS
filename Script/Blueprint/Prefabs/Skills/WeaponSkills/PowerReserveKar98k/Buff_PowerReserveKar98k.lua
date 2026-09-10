---@class Buff_PowerReserveKar98k_C:PersistEffectBuff
---@field BonusPercentagePerStack float
---@field MaxBonusPercentage float
--Edit Below--
---@class Buff_PowerReserveKar98k_C:PersistEffectBuff
---@field BonusPercentagePerStack float
---@field MaxBonusPercentage float
-- Edit Below--
local Buff_PowerReserveKar98k = {
    CurrentBonusPercentage = 0,
    TargetWeapon = nil,
    CurNumRemember = 0,
    BulletDamagetRemember = nil,
}

local Skill_Utils = UGCGameSystem.UGCRequire('Script.Blueprint.Prefabs.Skills.Skill_Utils')

local MAX_STACK_NUM = 5

-- buff开始
function Buff_PowerReserveKar98k:OnApply_BP(OwnerActor)
    Skill_Utils:LogInfo("Buff_PowerReserveKar98k", "OnApply_BP")

    if not UGCGameSystem.IsServer() then
        return
    end 

    self.CurrentBonusPercentage = 0
    self.TargetWeapon = UGCWeaponManagerSystem.GetCurrentWeapon(OwnerActor)
    if self.TargetWeapon==nil then
        return
    end
    self.BulletDamagetRemember = UGCAttributeSystem.GetGameAttributeValue(self.TargetWeapon,'BaseImpactDamageWrapper')*self.BonusPercentagePerStack/100
end

-- buff结束
function Buff_PowerReserveKar98k:OnUnApply_BP(OwnerActor, Reason)
    Skill_Utils:LogInfo("Buff_PowerReserveKar98k", "OnUnApply_BP")

    if not UGCGameSystem.IsServer() then
        return
    end 

    if self.TargetWeapon ~= nil then
        UGCAttributeSystem.AddGameAttributeValue(self.TargetWeapon, 'BaseImpactDamageWrapper', -self.CurNumRemember*self.BulletDamagetRemember)
        self.TargetWeapon = nil
    end
end

-- buff触发前条件判断
-- function Buff_PowerReserveKar98k:CanTrigger_BP()
--     Skill_Utils:LogInfo("Buff_PowerReserveKar98k", "CanTrigger_BP()" .. tostring(self:GetStackNum()))

--     if self:GetStackNum() > MAX_STACK_NUM then
--         print("Buff_PowerReserveKar98k:CanTrigger_BP()--ret")
--         return false
--     end

--     return true
-- end
function Buff_PowerReserveKar98k:OnStackChange_BP(PreNum, CurNum)

end
-- buff触发效果
function Buff_PowerReserveKar98k:OnTrigger_BP(Delta)
    Skill_Utils:LogInfo("Buff_PowerReserveKar98k", "OnTrigger_BP()" .. tostring(self:GetStackNum()))
    self.CurNumRemember = self:GetStackNum()
    print("Buff_PowerReserveKar98k:OnTrigger_BP()")
    if not UGCGameSystem.IsServer() then
        return
    end

    self.CurrentBonusPercentage = self.CurrentBonusPercentage + self.BonusPercentagePerStack
    local BonusToAdd = self.BonusPercentagePerStack
    if self.CurrentBonusPercentage > self.MaxBonusPercentage then
        BonusToAdd = BonusToAdd - (self.CurrentBonusPercentage - self.MaxBonusPercentage)
        self.CurrentBonusPercentage = self.MaxBonusPercentage
    end

    if self.TargetWeapon ~= nil then
        print("Buff_PowerReserveKar98k:OnTrigger_BP()-- self.BulletDamagetRemember"..tostring(self.BulletDamagetRemember))
        UGCAttributeSystem.AddGameAttributeValue(self.TargetWeapon, 'BaseImpactDamageWrapper', self.BulletDamagetRemember)
        Skill_Utils:LogInfo("Buff_PowerReserveKar98k", "OnTrigger_BP", UGCAttributeSystem.GetGameAttributeValue(self.TargetWeapon, 'BaseImpactDamageWrapper'))
    end
end

return Buff_PowerReserveKar98k
