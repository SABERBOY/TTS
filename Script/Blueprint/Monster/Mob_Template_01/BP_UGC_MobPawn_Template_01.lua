---@class BP_UGC_MobPawn_Template_01_C:BP_UGC_MobPawn_Normal_Far_C
--Edit Below--
local BP_UGC_MobPawn_Template_01 = {}
 
--[[
function BP_UGC_MobPawn_Template_01:ReceiveBeginPlay()
    BP_UGC_MobPawn_Template_01.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function BP_UGC_MobPawn_Template_01:ReceiveTick(DeltaTime)
    BP_UGC_MobPawn_Template_01.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function BP_UGC_MobPawn_Template_01:ReceiveEndPlay()
    BP_UGC_MobPawn_Template_01.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function BP_UGC_MobPawn_Template_01:GetReplicatedProperties()
    return
end
--]]

--[[
function BP_UGC_MobPawn_Template_01:GetAvailableServerRPCs()
    return
end
--]]

--[[
function BP_UGC_MobPawn_Template_01:PreTakeDamageEvent(DamageCauser, EventInstigator, Damage, DamageContext)
     
end
--]]

--[[
function BP_UGC_MobPawn_Template_01:PostTakeDamageEvent(DamageCauser, EventInstigator, Damage, DamageContext)
    
end
--]]

--[[
function BP_UGC_MobPawn_Template_01:PreOverrideDamageValue(Damage, DamageType, EventInstigator, DamageCauser, Hit)
    return Damage
end
--]]

--[[
function BP_UGC_MobPawn_Template_01:PostOverrideDamageValue(Damage, DamageType, EventInstigator, DamageCauser, Hit)
    return Damage
end
--]]

--[[
function BP_UGC_MobPawn_Template_01:MobPawnDeadEvent(Killer, DamageCauser, KillingHitDamageType)
    
end
--]]

--[[
function BP_UGC_MobPawn_Template_01:StateChangeEvent(OldState, NewState)
    
end
--]]




return BP_UGC_MobPawn_Template_01