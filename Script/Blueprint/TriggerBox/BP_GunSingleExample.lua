---@class BP_GunSingleExample_C:BP_ExampleBase_C
---@field ShootingTarget5 UChildActorComponent
---@field ShootingTarget4 UChildActorComponent
---@field ShootingTarget3 UChildActorComponent
---@field ShootingTarget2 UChildActorComponent
---@field ShootingTarget1 UChildActorComponent
---@field ChildActor2 UChildActorComponent
---@field ChildActor1 UChildActorComponent
---@field ChildActor UChildActorComponent
---@field Grid4 UStaticMeshComponent
---@field Grid3 UStaticMeshComponent
---@field Grid2 UStaticMeshComponent
---@field Grid1 UStaticMeshComponent
---@field TextRender4 UTextRenderComponent
---@field TextRender3 UTextRenderComponent
---@field TextRender2 UTextRenderComponent
---@field TextRender1 UTextRenderComponent
---@field StaticMesh5 UStaticMeshComponent
---@field StaticMesh4 UStaticMeshComponent
---@field StaticMesh3 UStaticMeshComponent
---@field StaticMesh2 UStaticMeshComponent
---@field StaticMesh1_0 UStaticMeshComponent
--Edit Below--
---@class BP_GunSingleExample_C:BP_ExampleBase_C
---@field TextRender4 UTextRenderComponent
---@field TextRender3 UTextRenderComponent
---@field TextRender2 UTextRenderComponent
---@field TextRender1 UTextRenderComponent
---@field StaticMesh5 UStaticMeshComponent
---@field StaticMesh4 UStaticMeshComponent
---@field StaticMesh3 UStaticMeshComponent
---@field StaticMesh2 UStaticMeshComponent
---@field StaticMesh1 UStaticMeshComponent
-- Edit Below--
local BP_GunSingleExample = {
    
}

function BP_GunSingleExample:CheckCanActive(ClickParam)
    return true;
end

function BP_GunSingleExample:OnFireExample_ReloadBullets()
    print("OnFireExample_Reload:OnFireExample_Reload")

    -- 获取当前玩家
    local PC = UGCGameSystem.GetLocalPlayerController()
    if not PC then
        print("OnFireExample_Reload: Failed to get PlayerController")
        return
    end

    local PlayerCharacter = PC:GetPlayerCharacterSafety()
    if not PlayerCharacter then
        print("OnFireExample_Reload: Failed to get PlayerCharacter")
        return
    end

    local CurrentWeapon = UGCWeaponManagerSystem.GetCurrentWeapon(PlayerCharacter)
    
    if not CurrentWeapon then
        print("OnFireExample_Reload: No weapon equipped")
        
        return
    end

    UnrealNetwork.CallUnrealRPC(PC, self, "Server_AddBullets", CurrentWeapon, true,PlayerCharacter)
end

function BP_GunSingleExample:Server_AddBullets(Gun, IsEnable,PlayerCharacter)
    if not UGCGameSystem.IsServer() then
        print("Server_AddBullets: Not on the server")
        return
    end
    print("Server_AddBullets:CurrentUsingAmmoID1")
    if PlayerCharacter == nil then
        print("Server_AddBullets: PlayerCharacter is nil")
        return
    end
    ---local CurrentUsingAmmoID =UGCWeaponManagerSystem.GetCurrentUsingAmmoID(self.PlayerCharacter)
    local WeaponManagerComponent = UGCWeaponManagerSystem.GetWeaponManagerComponent(PlayerCharacter);
    if WeaponManagerComponent ~= nil then
            local CurrentUsingAmmoID = Gun:GetCurrentUsingAmmoID();
            print(CurrentUsingAmmoID)
            UGCBackpackSystemV2.AddItemV2(PlayerCharacter, CurrentUsingAmmoID, 200)
    end

    print("Server_AddBullets:CurrentUsingAmmoID")
    
    ---UGCGunSystem.EnableInfiniteBullets(Gun, IsEnable)
end
--------------------------------------------------------------------------

function BP_GunSingleExample:OnFireExample_EnableInfinite()
    print("OnFireExample_EnableInfinite:OnFireExample_EnableInfinite")

    -- 获取当前玩家
    local PC = UGCGameSystem.GetLocalPlayerController()
    if not PC then
        print("OnFireExample_EnableInfinite: Failed to get PlayerController")
        return
    end

    local PlayerCharacter = PC:GetPlayerCharacterSafety()
    if not PlayerCharacter then
        print("OnFireExample_EnableInfinite: Failed to get PlayerCharacter")
        return
    end

    local CurrentWeapon = UGCWeaponManagerSystem.GetCurrentWeapon(PlayerCharacter)
    
    if not CurrentWeapon then
        print("OnFireExample_EnableInfinite: No weapon equipped")
        
        return
    end

    UnrealNetwork.CallUnrealRPC(PC, self, "Server_EnableInfiniteBullets", CurrentWeapon, true,PlayerCharacter)
end

function BP_GunSingleExample:Server_EnableInfiniteBullets(Gun, IsEnable,PlayerCharacter)
    if not UGCGameSystem.IsServer() then
        print("Server_EnableInfiniteBullets: Not on the server")
        return
    end
    print("Server_EnableInfiniteBullets:OnFireExample_EnableInfinite1")
    if PlayerCharacter == nil then
        print("Server_EnableInfiniteBullets: PlayerCharacter is nil")
        return
    end

    print("ForceReloadAndEnableInfiniteBulletsForceReloadAndEnableInfiniteBullets")
    
    UGCGunSystem.ForceReloadAndEnableInfiniteBullets(Gun, IsEnable)
end

function BP_GunSingleExample:GetAvailableServerRPCs()
    return "Server_EnableInfiniteBullets", "Server_AddBullets"
end

return BP_GunSingleExample
