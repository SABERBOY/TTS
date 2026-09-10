---@class Buff_InfiniteAmmo_C:PersistEffectBuff
--Edit Below--
local Buff_InfiniteAmmo = {
    ---@type table<STExtraShootWeapon, bool>
	TargetWeapons = {},
}
 
-- buff启动条件
--[[
function Buff_InfiniteAmmo:CanApply_BP(OwnerActor)
-- return true
end
--]]
---@param Weapon ASTExtraShootWeapon
function Buff_InfiniteAmmo:SetInfiniteAmmo(Weapon)
    local bHasInfiniteBullets = Weapon:GetWeaponHasInfiniteBulletsFromEntity()
    print("Buff_InfiniteAmmo:SetInfiniteAmmo", tostring(bHasInfiniteBullets))
    if bHasInfiniteBullets == false then
        UGCGunSystem.EnableClipInfiniteBullets(Weapon, true)
    end
    Weapon:TriggerInstantReloadOnServer(UGCGunSystem.GetMaxBulletNumInOneClip(Weapon))
    UGCGunSystem.EnableInfiniteBullets(Weapon, true)
    self.TargetWeapons[Weapon] = bHasInfiniteBullets
end

-- buff开始
function Buff_InfiniteAmmo:OnApply_BP(OwnerActor)
    if OwnerActor and UE.IsValid(OwnerActor) then
        local Weapon1 = UGCWeaponManagerSystem.GetWeaponBySlot(OwnerActor, ESurviveWeaponPropSlot.SWPS_MainShootWeapon1)
        if Weapon1 and UE.IsValid(Weapon1) then
            self:SetInfiniteAmmo(Weapon1)
        else
            print("Buff_InfiniteAmmo:InfiniteBullet Weapon1 is nil")
        end
        local Weapon2 = UGCWeaponManagerSystem.GetWeaponBySlot(OwnerActor, ESurviveWeaponPropSlot.SWPS_MainShootWeapon2)
        if Weapon2 and UE.IsValid(Weapon2) then
            self:SetInfiniteAmmo(Weapon2)
        else
            print("Buff_InfiniteAmmo:InfiniteBullet Weapon2 is nil")
        end
    
        local SubWeapon = UGCWeaponManagerSystem.GetWeaponBySlot(OwnerActor, ESurviveWeaponPropSlot.SWPS_SubShootWeapon)
        if SubWeapon and UE.IsValid(SubWeapon) then
            self:SetInfiniteAmmo(SubWeapon)
        else
            print("Buff_InfiniteAmmo:InfiniteBullet SubWeapon is nil")
        end
    end
end


-- buff结束
function Buff_InfiniteAmmo:OnUnApply_BP(OwnerActor, Reason)
    for Weapon, bHasInfiniteBullets in pairs(self.TargetWeapons) do
        if UE.IsValid(Weapon) then
            UGCGunSystem.EnableClipInfiniteBullets(Weapon, bHasInfiniteBullets)
            UGCGunSystem.EnableInfiniteBullets(Weapon, false)
        end
    end
    self.TargetWeapons = {}
end


-- buff合并条件，A为当前身上已有buff，B为外来buff，当要挂载外来buff时会判断A.CanMerge(B)
--[[
function Buff_InfiniteAmmo:CanMerge_BP(PersistEffect)
-- return true
end
--]]

-- buff合并，A为当前身上已有buff，B为外来buff，调用A.OnMerge(B)
--[[
function Buff_InfiniteAmmo:OnMerge_BP(PersistEffect)

end
--]]

-- 开启Tick需要SetTickEnable(true)，或buff为间隔触发类型会自动开启
--[[
function Buff_InfiniteAmmo:Tick_BP(OwnerActor, DeltaTime)

end
--]]

--[[
function Buff_InfiniteAmmo:OnInterrupted_BP(OwnerActor)

end
--]]

-- buff总持续时长变化，如修改ApplyTime、修改StackNum
--[[
function Buff_InfiniteAmmo:OnTotalDurationChange_BP(PreTime, CurTime)

end
--]]

-- buff堆叠层数变化
--[[
function Buff_InfiniteAmmo:OnStackChange_BP(PreNum, CurNum)

end
--]]

-- buff触发前条件判断
--[[
function Buff_InfiniteAmmo:CanTrigger_BP()
	return true
end
--]]

-- buff触发效果
--[[
function Buff_InfiniteAmmo:OnTrigger_BP(Delta)

end
--]]

return Buff_InfiniteAmmo