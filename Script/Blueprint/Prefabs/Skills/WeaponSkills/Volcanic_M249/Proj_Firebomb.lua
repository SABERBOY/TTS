---@class Proj_Firebomb_C:UniversalProjectileBase
---@field ParticleSystem UParticleSystemComponent
---@field Sphere USphereComponent
---@field BaseDamage float
---@field DamageAttenuationRate float
--Edit Below--
---@class Proj_Firebomb_C:UniversalProjectileBase
---@field ParticleSystem UParticleSystemComponent
---@field Sphere USphereComponent

local Proj_Firebomb = {
}
function Proj_Firebomb:DamageCalculate()
    --每0.1秒计算抛体运动的距离
    local EnemyList = self:FindEnemyPawn()
    if EnemyList == nil then
        return 0
    end
    for _, Enemy in pairs(EnemyList) do
        local DamageBuffTag = STExtraGameplayStatics.RequestGameplayTag("Item.ShootWeapon.MachineGun.M249", true)
        local Distance = STExtraBlueprintFunctionLibrary.GetDistanceVector(Enemy:K2_GetActorLocation(), self:K2_GetActorLocation())
        local AttenuationRate = 0
        if Distance>176 then
            AttenuationRate = Distance/100*self.DamageAttenuationRate
        end
        if AttenuationRate>0.3 then
            AttenuationRate = 0.3
        end
		UGCGameSystem.ApplyDamage(Enemy, self.BaseDamage*(1-AttenuationRate), self:GetOwner():GetPlayerControllerSafety(), self:GetOwner(), {DamageBuffTag})
    end
    return 0
end
-- function Proj_Firebomb:ReceiveBeginPlay()
--     
-- end

function Proj_Firebomb:FindEnemyPawn()
    local EnemyList = {};
    local  DrawDebugTrace = EDrawDebugTrace.None
    local bHit, Results = KismetSystemLibrary.SphereTraceMultiForObjects(self,  self:K2_GetActorLocation(),  self:K2_GetActorLocation(), 1000, {EObjectTypeQuery.ObjectTypeQuery3}, false, {}, DrawDebugTrace, {}, true, {R=1, G=0, B=0, A=1}, {R=0, G=1, B=0, A=1}, 3)
    if bHit then
        for _, v in pairs(Results) do
            if v.Actor:IsValid() then
                print("Proj_Firebomb:FindEnemyPawn: HitActor:"..tostring(v.Actor:Get()))
                local Relation = self:GetOwner():GetGeneralCampRelationWithActor(v.Actor:Get())
                if Relation == ECampRelation.Same or Relation == ECampRelation.Ally then
                else
                    table.insert(EnemyList,v.Actor:Get());   
                end
            else
                ugcprint("Proj_Firebomb:FindEnemyPawn: v.Actor:IsNotValid()")
            end
        end
    end
    return EnemyList
end

return Proj_Firebomb