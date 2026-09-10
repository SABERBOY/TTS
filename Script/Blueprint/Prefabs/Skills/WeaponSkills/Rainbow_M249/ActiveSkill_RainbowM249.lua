---@class ActiveSkill_RainbowM249_C:PESkillTemplate_Active_C
---@field LaserEffectParticleRes UParticleSystem
---@field LaserHitEffectParticleRes UParticleSystem
---@field LaserDisEffectParticleRes UParticleSystem
---@field EnergyEffectParticleRes UParticleSystem
---@field LaserTraceDistance float
---@field DamageTraceOffset FVector
--Edit Below--
local ActiveSkill_RainbowM249 = {
    -- 粒子特效
    LaserEffect = nil,
    LaserHitEffect = nil,
    LaserDisEffect = nil,
    EnergyEffect = nil,
    -- 激光信息
    LaserEndPos = nil,
    TraceStartPos = nil,
    ---@type BP_UGC_ShootWeaponBase_C
    Weapon = nil,
    WeaponMeshComp = nil,
    FireLocation = nil,
    MuzzleLocation = nil,
    MuzzleRotation = nil,
    MuzzleScale = nil,
    InstigatorCampID = nil,
}


function ActiveSkill_RainbowM249:OnEnableSkill_BP()
    ActiveSkill_RainbowM249.SuperClass.OnEnableSkill_BP(self)
    local PlayerInstigator = self:GetNetOwnerActor():GetInstigator()
    if PlayerInstigator ~= nil then
        -- 获取阵营ID
        self.InstigatorCampID = PlayerInstigator:GetGeneralCampID()
        print("ActiveSkill_RainbowM249:OnEnableSkill_BP InstigatorCampID="..tostring(self.InstigatorCampID))
    else
        print("ActiveSkill_RainbowM249:OnEnableSkill_BP [HealingInstigator == nil]")
    end
    self:SetCDRecoverRate(0)
    self:InitWeapon()
end

function ActiveSkill_RainbowM249:OnDisableSkill_BP()
    ActiveSkill_RainbowM249.SuperClass.OnDisableSkill_BP(self)
end

function ActiveSkill_RainbowM249:OnActivateSkill_BP()
    ActiveSkill_RainbowM249.SuperClass.OnActivateSkill_BP(self)
    ugcprint("ActiveSkill_RainbowM249:OnActivateSkill_BP()")
end

function ActiveSkill_RainbowM249:OnDeActivateSkill_BP()
    ActiveSkill_RainbowM249.SuperClass.OnDeActivateSkill_BP(self)
end

function ActiveSkill_RainbowM249:CanActivateSkill_BP()
    return ActiveSkill_RainbowM249.SuperClass.CanActivateSkill_BP(self)
end


-- 初始化武器
function ActiveSkill_RainbowM249:InitWeapon()
    if self.Weapon == nil then
        self.Weapon = UGCWeaponManagerSystem.GetCurrentWeapon(self.Owner.Owner)
    end 
    ugcprint("ActiveSkill_RainbowM249:InitWeapon() Weapon="..tostring(self.Weapon))
end

-- 发射激光，并执行一次射线检测
function ActiveSkill_RainbowM249:StartFire()
    ugcprint("ActiveSkill_RainbowM249:StartFire()")

    if self.Weapon == nil then
        self:InitWeapon()
    end

    self:LaserTrace()
    if not UGCGameSystem.IsServer() then
        self.WeaponMeshComp = self.Weapon:GetWeaponMeshComponent()
    else
        self:S_LaserTrace()
    end

    --self.FireLocation = self.WeaponMeshComp:GetSocketLocation("Muzzle")
    self.MuzzleLocation,self.MuzzleRotation,self.MuzzleScale = UGCMathUtility.BreakTransform(self.Weapon:GetMuzzleTransform())
    self:ClientActiveLaserEffect(true)
end

-- 停止发射
function ActiveSkill_RainbowM249:StopFire()
    ugcprint("ActiveSkill_RainbowM249:StopFire()")

    if self.Weapon == nil then
        self:InitWeapon()
    end
    self:ClientActiveLaserEffect(false)
    if UE.IsValid(self.LaserHitEffect) then
        self.LaserHitEffect:K2_DestroyComponent(self.LaserHitEffect)
        self.LaserHitEffect = nil
    else
        self.LaserHitEffect = nil
    end
    self.LaserEffect:K2_DestroyComponent(self.LaserEffect)
    self.LaserEffect = nil
end

 -- 客户端：激光表现
function ActiveSkill_RainbowM249:ClientActiveLaserEffect(bActive)
    if  UGCGameSystem.IsServer() then
        return
    end
    
    ugcprint("ActiveSkill_RainbowM249:ClientActiveLaserEffect bActive "..tostring(bActive))
    --激光光柱效果
   
    
    if not UE.IsValid(self.LaserEffect) then
        if self.WeaponMeshComp == nil then
            ugcprint("ActiveSkill_RainbowM249:ClientActiveLaserEffect WeaponMeshComp == nil - Spawn LaserEffect")
            return
        end
        --self.LaserEffect = GameplayStatics.SpawnEmitterAttached(self.LaserEffectParticleRes, WeaponMeshComp, "Muzzle", {}, {}, { X = 1, Y = 1, Z = 1 }, EAttachLocation.KeepRelativeOffset, false)
        
        print("ActiveSkill_RainbowM249:ClientActiveLaserEffect--MuzzleLocation = "..tostring(self.MuzzleLocation.X).." "..tostring(self.MuzzleLocation.Y).." "..tostring(self.MuzzleLocation.Z))
        self.LaserEffect = GameplayStatics.SpawnEmitterAtLocation(self, self.LaserEffectParticleRes, self.MuzzleLocation, self.MuzzleRotation, Vector.New(1, 1, 1), true)
        local TraceStartPos = self.MuzzleLocation
        local Distance = STExtraBlueprintFunctionLibrary.Dist(TraceStartPos, self.LaserEndPos)
        self.LaserEffect:SetVectorParameter("BeamTarget", Vector.New(Distance, 1, 1))
        local TargetRot = UGCMathUtility.FindLookAtRotation(TraceStartPos, self.LaserEndPos)
        self.LaserEffect:K2_SetWorldRotation(TargetRot, false, {}, false)
        --self.LaserEffect:K2_DestroyComponent(self.LaserEffect)
        if not UE.IsValid(self.LaserEffect) then
            ugcprint("ActiveSkill_RainbowM249:ClientActiveLaserEffect SpawnEmitter failed - Spawn LaserEffect")
            return nil
        end
    end
    if UE.IsValid( self.LaserEffect) then
        self.LaserEffect:SetVisibility(bActive)
    end

    --激光命中点效果
    
    if bActive then--self.LaserHitEffect == nil
        if self.WeaponMeshComp == nil then
            ugcprint("ActiveSkill_RainbowM249:ClientActiveLaserEffect WeaponMeshComp == nil - Spawn LaserHitEffect")
            return nil
        end
        self.LaserHitEffect = GameplayStatics.SpawnEmitterAtLocation(self, self.LaserHitEffectParticleRes, self.LaserEndPos, self:GetNetOwnerActor():K2_GetActorRotation(), Vector.New(1, 1, 1), true)
        if self.LaserHitEffect == nil then
            ugcprint("ActiveSkill_RainbowM249:ClientActiveLaserEffect SpawnEmitter failed - Spawn LaserHitEffect")
            return nil
        end
        print("ActiveSkill_RainbowM249:ClientActiveLaserEffect--MuzzleLocation = "..tostring(self.LaserEndPos.X).." "..tostring(self.LaserEndPos.Y).." "..tostring(self.LaserEndPos.Z))
    end

    --self.LaserHitEffect:SetVisibility(bActive)
    --self.LaserHitEffect:K2_SetWorldLocation(self.LaserEndPos, false, {}, false)
    
    

    -- 关闭激光
    if bActive == false then
        --local WeaponMeshComp = self.Weapon:GetWeaponMeshComponent()
        if self.WeaponMeshComp == nil then
            ugcprint("ActiveSkill_RainbowM249:ClientActiveLaserEffect WeaponMeshComp = nil - Spawn LaserDisEffect")
            return nil
        end

        --光柱消散特效
        
        -- local MuzzleLocation = WeaponMeshComp:GetSocketLocation("Muzzle")
        -- print("ActiveSkill_RainbowM249:ClientActiveLaserEffect--MuzzleLocation = "..tostring(MuzzleLocation.X).." "..tostring(MuzzleLocation.Y).." "..tostring(MuzzleLocation.Z))
        -- if self.LaserDisEffect == nil then
        --     ugcprint("ActiveSkill_RainbowM249:ClientActiveLaserEffect SpawnEmitter failed - Spawn LaserDisEffect")
        -- end
        
        --local MuzzleLocation,MuzzleRotation,MuzzleScale = UGCMathUtility.BreakTransform(self.Weapon:GetMuzzleTransform())
        self.LaserDisEffect = GameplayStatics.SpawnEmitterAtLocation(self, self.LaserDisEffectParticleRes, self.MuzzleLocation, self.MuzzleRotation, Vector.New(1, 1, 1), true)
        local TraceStartPos = self.MuzzleLocation
        local Distance = STExtraBlueprintFunctionLibrary.Dist(TraceStartPos, self.LaserEndPos)
        self.LaserDisEffect:SetVectorParameter("BeamTarget", Vector.New(Distance, 1, 1))
        local TargetRot = UGCMathUtility.FindLookAtRotation(TraceStartPos, self.LaserEndPos)
        self.LaserDisEffect:K2_SetWorldRotation(TargetRot, false, {}, false)
        ugcprint("ActiveSkill_RainbowM249:ClientActiveLaserEffect SpawnEmitter LaserDisEffect Distance: " .. Distance)

        --能量消散效果
        
        --local MuzzleLocation = WeaponMeshComp:GetSocketLocation("Muzzle")
        print("ActiveSkill_RainbowM249:ClientActiveLaserEffect--MuzzleLocation = "..tostring(self.MuzzleLocation.X).." "..tostring(self.MuzzleLocation.Y).." "..tostring(self.MuzzleLocation.Z))
        self.EnergyEffect = GameplayStatics.SpawnEmitterAtLocation(self, self.EnergyEffectParticleRes, self.MuzzleLocation, self:GetNetOwnerActor():K2_GetActorRotation(), Vector.New(1, 1, 1), true)
        if self.EnergyEffect == nil then
            ugcprint("ActiveSkill_RainbowM249:ClientActiveLaserEffect SpawnEmitter failed - Spawn EnergyEffect")
        end
        ugcprint("ActiveSkill_RainbowM249:ClientActiveLaserEffect SpawnEmitter EnergyEffect")
    end

end
--服务端逻辑，发射射线检测用于造成伤害
function ActiveSkill_RainbowM249:S_LaserTrace()
    local TraceStartPos = Vector.New(self:GetNetOwnerActor():K2_GetActorLocation().X+self.DamageTraceOffset.X,
    self:GetNetOwnerActor():K2_GetActorLocation().Y+self.DamageTraceOffset.Y,
    self:GetNetOwnerActor():K2_GetActorLocation().Z+self.DamageTraceOffset.Z)

    local PlayerController = self:GetNetOwnerActor():GetPlayerControllerSafety()
    local TraceDir = PlayerController:GetActorForwardVector()
    local TraceEndPos = Vector.New(
                TraceStartPos.X + TraceDir.X * self.LaserTraceDistance, 
                TraceStartPos.Y + TraceDir.Y * self.LaserTraceDistance, 
                TraceStartPos.Z + TraceDir.Z * self.LaserTraceDistance
                )
    
    print("ActiveSkill_RainbowM249:S_LaserTrace--TraceStartPos = "..tostring(TraceStartPos.X).." "..tostring(TraceStartPos.Y).." "..tostring(TraceStartPos.Z))
    print("ActiveSkill_RainbowM249:S_LaserTrace--TraceEndPos = "..tostring(TraceEndPos.X).." "..tostring(TraceEndPos.Y).." "..tostring(TraceEndPos.Z))
    local bHit, Results = KismetSystemLibrary.LineTraceMultiForObjects(self,TraceStartPos,TraceEndPos,{EObjectTypeQuery.ObjectTypeQuery3},false,{self:GetNetOwnerActor()},EDrawDebugTrace.None)
    local CharacterList = {}
    if bHit then
        for k, v in pairs(Results) do
            if v.Actor:IsValid() then
                print("ActiveSkill_RainbowM249:S_LaserTrace: HitActor:"..tostring(v.Actor:Get()))
                table.insert(CharacterList,v.Actor:Get());
                local CampRelation = v.Actor:Get():GetGeneralCampRelationWithCampID(self.InstigatorCampID) 
                -- 友军或同盟时
                if CampRelation == ECampRelation.Same or  CampRelation == ECampRelation.Ally then

                else
                    local Damage = 30*3.5 
                    UGCGameSystem.ApplyDamage(v.Actor:Get(), Damage, PlayerController, self:GetNetOwnerActor(), EDamageType.ShootDamage)  
                end

            else
                print("ActiveSkill_RainbowM249:HitActor: Error")
            end
        end
        ugcprint("SphereTraceArrayLength:"..tostring(#Results));
    else
        print("ActiveSkill_RainbowM249:HitActor: Error --notbHit ")
    end
    ugcprint("ActiveSkill_RainbowM249:Results"..tostring(#Results));
end
-- --客户端逻辑，发射射线进行检测
function ActiveSkill_RainbowM249:LaserTrace()
    ugcprint("ActiveSkill_RainbowM249:LaserTrace()")
    if self.Weapon == nil then
        ugcprint("ActiveSkill_RainbowM249:LaserTrace() self.Weapon == nil")
        return
    end

    local MuzzleTransform = self.Weapon:GetMuzzleTransform()
    local MuzzleLocation,MuzzleRotation,MuzzleScale =  UGCMathUtility.BreakTransform(MuzzleTransform)
    log_tree("ActiveSkill_RainbowM249:LaserTrace()--MuzzleLocation",MuzzleLocation)
    log_tree("ActiveSkill_RainbowM249:LaserTrace()--CharacterLocation",self:GetNetOwnerActor():K2_GetActorLocation())
    log_tree("ActiveSkill_RainbowM249:LaserTrace()",Vector.New(MuzzleLocation.X-self:GetNetOwnerActor():K2_GetActorLocation().X,
    MuzzleLocation.Y-self:GetNetOwnerActor():K2_GetActorLocation().Y,
    MuzzleLocation.Z-self:GetNetOwnerActor():K2_GetActorLocation().Z
    ))

    local TraceStartPos = MuzzleLocation
    local MuzzleLoc = MuzzleLocation
    local TraceDir = UGCMathUtility.Normal(
                        UGCMathUtility.GetForwardVector(MuzzleRotation)
                        )
    
    -- 设置主端射线检测的起点和方向
    if self:GetNetOwnerActor():IsLocallyControlled() then
        TraceStartPos = self:GetNetOwnerActor():GetActiveCameraLocation()
        TraceDir = UGCMathUtility.GetForwardVector(self:GetNetOwnerActor():GetActiveCameraRotation())
    end

    local TraceEndPos = Vector.New(
                TraceStartPos.X + TraceDir.X * self.LaserTraceDistance, 
                TraceStartPos.Y + TraceDir.Y * self.LaserTraceDistance, 
                TraceStartPos.Z + TraceDir.Z * self.LaserTraceDistance
                )
            

    self.LaserEndPos = TraceEndPos:Copy()

    ---@type FHitResult
    local HitResult = GameplayStatics.MakeHitResult()
    local bHit = STExtraBlueprintFunctionLibrary.LineTraceByChannel(HitResult,self,TraceStartPos,TraceEndPos,nil,ECollisionChannel.ECC_WorldDynamic)
    if bHit then
        self.LaserEndPos.X = HitResult.ImpactPoint.X
        self.LaserEndPos.Y = HitResult.ImpactPoint.Y
        self.LaserEndPos.Z = HitResult.ImpactPoint.Z
    else
        HitResult.ImpactPoint.X = self.LaserEndPos.X
        HitResult.ImpactPoint.X = self.LaserEndPos.X
        HitResult.ImpactPoint.Z = self.LaserEndPos.Z
    end
    
    --计算模拟端当前命中点
    local SimLerpImpactLoc = self.LaserEndPos
    --客户端设置激光光柱长度
    if UE.IsValid(self.LaserEffect) then
        local Distance = STExtraBlueprintFunctionLibrary.Dist(MuzzleLoc, SimLerpImpactLoc)
        local TargetRot = UGCMathUtility.FindLookAtRotation(MuzzleLoc, SimLerpImpactLoc)
        self.LaserEffect:K2_SetWorldRotation(TargetRot, false, {}, false)
        self.LaserEffect:SetVectorParameter("LaserBeamTarget", Vector.New(Distance, 1, 1))

    end

end

return ActiveSkill_RainbowM249