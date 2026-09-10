---@class BP_UGCPlayerPawn_C:BP_UGCPlayerPawn_C
--Edit Below--
---@class UGCPlayerPawn_C:BP_UGCPlayerPawn_C
-- Edit Below--
local Delegate = require("common.Delegate")

local BP_UGCPlayerPawn = {
    OnWeaponChange = nil,
    OnBulletHitDelegate = nil,
    OnSporeTransmission = nil,
    OnPoisoningDelegate = nil,
    OnChangeWeaponDelegate = nil
}

function BP_UGCPlayerPawn:UGC_ChangeCurrentUsingWeaponEvent(UsingWeaponSlot, LastSlot)
    self.OnWeaponChange()
    print("BP_UGCPlayerPawn:ReceiveBeginPlay Log: -- Call切换武器事件")
    self.OnChangeWeaponDelegate(UsingWeaponSlot, LastSlot)
end

function BP_UGCPlayerPawn:ReceiveBeginPlay()
    BP_UGCPlayerPawn.SuperClass.ReceiveBeginPlay(self)
    print("BP_UGCPlayerPawn:ReceiveBeginPlay Log: -- 创建自定义子弹命中事件")
    self.OnBulletHitDelegate = Delegate.New()
    print("BP_UGCPlayerPawn:ReceiveBeginPlay Log: -- 创建孢子传播事件")
    self.OnSporeTransmission = Delegate.New()
    print("BP_UGCPlayerPawn:ReceiveBeginPlay Log: -- 创建病毒传播事件")
    self.OnPoisoningDelegate = Delegate.New()
    print("BP_UGCPlayerPawn:ReceiveBeginPlay Log: -- 创建切换武器事件")
    self.OnChangeWeaponDelegate = Delegate.New()
end

function BP_UGCPlayerPawn:ReceiveEndPlay()
    BP_UGCPlayerPawn.SuperClass.ReceiveEndPlay(self)

end

function BP_UGCPlayerPawn:UGC_WeaponBulletHitEvent(ASTExtraShootWeapon, ASTExtraShootWeaponBulletBase, FHitResult)
    BP_UGCPlayerPawn.SuperClass.UGC_WeaponBulletHitEvent(self)
    print("BP_UGCPlayerPawn:UGC_WeaponBulletHitEvent Log: -- 发送子弹击中事件")
    self.OnBulletHitDelegate(ASTExtraShootWeapon, ASTExtraShootWeaponBulletBase, FHitResult)
end

function BP_UGCPlayerPawn:IsSkipSpawnDeadTombBox(EventInstigater)
    return true
end

-- Lua复制支持
function BP_UGCPlayerPawn:GetReplicatedProperties()
    return { "__SubObjectRepList", "Lazy"}
end

return BP_UGCPlayerPawn
