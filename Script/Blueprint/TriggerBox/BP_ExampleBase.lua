---@class BP_ExampleBase_C:AActor
---@field Box UBoxComponent
---@field StaticMesh1 UStaticMeshComponent
---@field P_Cg22_Start UParticleSystemComponent
---@field Widget UWidgetComponent
---@field ClickActorComponentBase UClickActorComponentBase
---@field BoxCollision UBoxComponent
---@field Title FString
--Edit Below--
local BP_ExampleBase = {}
function BP_ExampleBase:CheckCanActive(ClickParam)
    return true;
end
return BP_ExampleBase