---@class SuperAimMK14_C:BP_UGC_Rifle_Mk47_C
---@field WeaknessBuffClass UClass
--Edit Below--
local SuperAimMK14 = {
    ShootTimerHandle = {},
    ShootTimerDelegate = {},
}

function SuperAimMK14:GetAvailableServerRPCs()
    return "Server_StartApplyDamage", "Server_StopApplyDamage";
end

function SuperAimMK14:Server_StopApplyDamage()
    print("Stop Apply Damage")
    for _, handle in pairs(self.ShootTimerHandle) do
        UGCGameSystem.ClearTimer(self, handle)
        handle = nil  
    end
    self.ShootTimerDelegate = {}
end

function SuperAimMK14:Server_StartApplyDamage(Enemy)
    print("Start Apply Damage")
    --local BaseDamage = UGCAttributeSystem.GetGameAttributeValue(self, 'BaseImpactDamageWrapper')
    local ShootInterval = UGCAttributeSystem.GetGameAttributeValue(self, 'AutoShootIntervalWrapper')
    local DamageTypeTag = UGCGameplayTagSystem.RequestGameplayTag("Damage.Gun")
    local OwnerActor = self:GetOwnerPawn()
    local Controller = OwnerActor:GetPlayerControllerSafety()
    local AvatarDamagePosition = EAvatarDamagePosition.BigHead
    local ShootTimerHandle,ShootTimerDelegate =  UGCGameSystem.SetTimer(self,
            function ()
                if Enemy ~= nil then
                    UGCPersistEffectSystem.AddBuffByClass(OwnerActor, self.WeaknessBuffClass, OwnerActor, -1, 1)
                    UGCGameSystem.ApplyAvatarPositionDamage(Enemy, UGCAttributeSystem.GetGameAttributeValue(self, 'BaseImpactDamageWrapper'), Controller, OwnerActor, AvatarDamagePosition, {DamageTypeTag})
                    --UGCGameSystem.ApplyDamage(Enemy, BaseDamage, Controller, OwnerActor, {DamageTypeTag})
                end
            end, ShootInterval, true)
    table.insert(self.ShootTimerHandle,ShootTimerHandle)
    table.insert(self.ShootTimerDelegate,ShootTimerDelegate)
           
end
--[[
function SuperAimMK14:ReceiveBeginPlay()
    SuperAimMK14.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function SuperAimMK14:ReceiveTick(DeltaTime)
    SuperAimMK14.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function SuperAimMK14:ReceiveEndPlay()
    SuperAimMK14.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function SuperAimMK14:GetReplicatedProperties()
    return
end
--]]

--[[
function SuperAimMK14:GetAvailableServerRPCs()
    return
end
--]]

return SuperAimMK14