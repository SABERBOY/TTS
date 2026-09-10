---@class TestMonster_Range_C:BP_UGC_MobPawn_Base_C
--Edit Below--
local TestMonster_Range = {}
 
--[[
function TestMonster_Range:ReceiveBeginPlay()
    TestMonster_Range.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function TestMonster_Range:ReceiveTick(DeltaTime)
    TestMonster_Range.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function TestMonster_Range:ReceiveEndPlay()
    TestMonster_Range.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function TestMonster_Range:GetReplicatedProperties()
    return
end
--]]

--[[
function TestMonster_Range:GetAvailableServerRPCs()
    return
end
--]]

--[[
function TestMonster_Range:PreTakeDamageEvent(DamageCauser, EventInstigator, Damage, DamageContext)
     
end
--]]

--[[
function TestMonster_Range:PostTakeDamageEvent(DamageCauser, EventInstigator, Damage, DamageContext)
    
end
--]]

--[[
function TestMonster_Range:PreOverrideDamageValue(Damage, DamageType, EventInstigator, DamageCauser, Hit)
    return Damage
end
--]]

--[[
function TestMonster_Range:PostOverrideDamageValue(Damage, DamageType, EventInstigator, DamageCauser, Hit)
    return Damage
end
--]]

--[[
function TestMonster_Range:MobPawnDeadEvent(Killer, DamageCauser, KillingHitDamageType)
    
end
--]]

--[[
function TestMonster_Range:StateChangeEvent(OldState, NewState)
    
end
--]]




return TestMonster_Range