---@class Buff_AutoAim_C:PersistEffectBuff
---@field CureParticleClass UParticleSystem
--Edit Below--
local Buff_AutoAim = {
    OwnerActor = nil,
    CacheAutoAimTask = nil
}
 
-- buff开始

function Buff_AutoAim:OnApply_BP(OwnerActor)
    if self:IsAutonomous(true) then
        print("@ActorName.OnApply_BP OuterSpeed:"..self.Config.OuterSpeed.." OuterMaxRange:"..self.Config.OuterAdsorbMaxRange.." OuterMinRange:"..self.Config.OuterAdsorbMinRange.." AimNPC:"..tostring(self.AimNPC))
        self.CacheAutoAimTask = UGCGameplayTaskSystem.Weapon.AutoAim.NewTask(self, OwnerActor, self.Config.InnerSpeed, 
            self.Config.InnerAdsorbMaxRange, self.Config.InnerAdsorbMinRange, self.Config.OuterSpeed, self.Config.OuterAdsorbMaxRange, self.Config.OuterAdsorbMinRange, self.AimNPC)
    end
end



function Buff_AutoAim:OnUnApply_BP(OwnerActor, Reason)
    if self.CacheAutoAimTask ~= nil then
        self.CacheAutoAimTask:EndTask()
    end
end


return Buff_AutoAim