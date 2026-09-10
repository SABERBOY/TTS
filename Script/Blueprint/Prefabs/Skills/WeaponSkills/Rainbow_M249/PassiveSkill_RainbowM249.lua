---@class PassiveSkill_RainbowM249_C:PESkillPassiveSkillTemplate_C
---@field ChargedSkillClass UClass
---@field BulletTail UParticleSystem
---@field LaserColorCycle ULuaArrayHelper<FLinearColor>
---@field CycleBoostShotCount int32
---@field CycleBoostShotNetIndex int32
---@field WeaponAttackBoostPerShot float
---@field bEnableColorDamageMatch bool
--Edit Below--

local PassiveSkill_RainbowM249 = {
    ---@type BP_UGC_ShootWeaponBase_C
    Weapon                      = nil,
    LaserTraceDistance          = nil,  -- 激光特效追踪距离，只与表现相关，默认取枪械子弹射程
    LaserColorIndex             = 0,    -- 激光颜色索引,lua数组索引从1开始，0表示还没有射出第一发
    LaserColorNum               = -1,   -- 激光颜色数量
    bInitialize                 = false,
    ColorVectors                = {},
    BulletTailEffectNum         = 7,    -- 激光子弹特效数量
    CurrentBulletTailEffectIdx  = 1,    -- 当前激光子弹特效索引
    bInit                       = false,
    TraceIgnoreActors           = {},
    ColorCheckDelegate          = nil,
    BaseDamage                  = nil,
    ExecuteTimeGap              = 1,
    WeaponManagerComp           = nil,

    ---@type UParticleSystemComponent
    BulletTailEffect            = nil,  -- 激光子弹特效

    ---@type UParticleSystemComponent[]
    BulletTailEffectPool        = {},   -- 激光子弹特效池

    ---@type FTimerHandle
    ColorCheckTimerHandle       = nil,  -- 颜色检查定时器相关
}

function PassiveSkill_RainbowM249:OnApply_BP()
    ugcprint("PassiveSkill_RainbowM249:OnApply_BP")

    if not self:HasAuthority() then
        local SkillOwner = self:GetNetOwnerActor()
        if SkillOwner then
            self.WeaponManagerComp = UGCWeaponManagerSystem.GetWeaponManagerComponent(SkillOwner)
            if self.WeaponManagerComp then
                self.WeaponManagerComp.ChangeCurrentUsingWeaponDelegate:Add(self.OnWeaponEquip, self)

                self.Weapon = self.WeaponManagerComp:GetCurrentUsingWeapon()
                if self.Weapon then
                    self.Weapon.OnBulletBeforeShootDelegate:Add(self.OnBulletBeforeshootInternal, self)
                end
            end
        end
    end
end

function PassiveSkill_RainbowM249:OnUnApply_BP()
    ugcprint("PassiveSkill_RainbowM249:OnUnApply_BP")

    if not self:HasAuthority() then
        ugcprint("PassiveSkill_RainbowM249:OnUnApply_BP. self.Weapon = " .. tostring(self.Weapon:GetWeaponDetailInfo()))
        self.Weapon.OnBulletBeforeShootDelegate:Remove(self.OnBulletBeforeshootInternal, self)
    end
end

function PassiveSkill_RainbowM249:OnEnableSkill_BP()
    PassiveSkill_RainbowM249.SuperClass.OnEnableSkill_BP(self)
    print("PassiveSkill_RainbowM249:OnEnableSkill_BP ")

    self:Init()
end

function PassiveSkill_RainbowM249:OnActivateSkill_BP()
    -- PassiveSkill_RainbowM249.SuperClass.OnActivateSkill_BP(self)
    ugcprint("PassiveSkill_RainbowM249:OnActivateSkill_BP")

    self:SkillActive()
end

function PassiveSkill_RainbowM249:SkillActive()
    ugcprint("PassiveSkill_RainbowM249:SkillActive" .. tostring(self.CycleBoostShotNetIndex))

    local NeedToCharge = false
    if self.CycleBoostShotCount > 0 then
        self.CycleBoostShotNetIndex = self.CycleBoostShotNetIndex + 1
        -- DOREPONCE(self, "CycleBoostShotNetIndex")
        if self.CycleBoostShotNetIndex >= self.CycleBoostShotCount + 1 then
            -- 重置
            self.CycleBoostShotNetIndex = 1
            local damageBonus = self.WeaponAttackBoostPerShot * (self.CycleBoostShotCount - 1)
            UGCAttributeSystem.AddGameAttributeValue(self.Weapon, 'BaseImpactDamageWrapper', -damageBonus * self.BaseDamage)
        end

        ugcprint("PassiveSkill_RainbowM249:SkillActive() CycleBoostShotNetIndex=" .. tostring(self.CycleBoostShotNetIndex))

        if self.CycleBoostShotNetIndex > 1 and self.CycleBoostShotNetIndex <= self.CycleBoostShotCount then
            UGCAttributeSystem.AddGameAttributeValue(self.Weapon, 'BaseImpactDamageWrapper', self.WeaponAttackBoostPerShot * self.BaseDamage)

            if self.CycleBoostShotNetIndex >= self.CycleBoostShotCount then
                NeedToCharge = true
            end
        end
    else
        ugcprint("PassiveSkill_RainbowM249:SkillActive() self.CycleBoostShotCount <= 0")
    end

    -- 打完七发主动技能获得一次充能
    if NeedToCharge then
        ---@type UPersistBaseComponent
        local Comp   = self.Owner
        local Skills = Comp:GetPersistEffectDataByClass(self.ChargedSkillClass)

        for _, Skill in ipairs(Skills) do
            print("PassiveSkill_RainbowM249:SkillActive() NeedToChargeSkill: " .. tostring(Skill))
            Skill:ChargeCDEnergy(1)
        end
    end
end

-- 初始化变量
function PassiveSkill_RainbowM249:Init()
    ugcprint("PassiveSkill_RainbowM249:Init Owner = " .. tostring(self:GetNetOwnerActor()))

    self.Weapon = UGCWeaponManagerSystem.GetCurrentWeapon(self.Owner.Owner)
    if self.Weapon == nil then
        print("PassiveSkill_RainbowM249:Init self.Weapon == nil!")
        return false
    end

    ---@param LinearColor FLinearColor
    for Idx, LinearColor in pairs(self.LaserColorCycle) do
        self.ColorVectors[Idx] = Vector.New(LinearColor.R, LinearColor.G, LinearColor.B)
    end

    self.LaserTraceDistance     = UGCGunSystem.GetBulletRange(self.Weapon)
    self.BaseDamage             = UGCAttributeSystem.GetGameAttributeValue(self.Weapon, 'BaseImpactDamageWrapper')
    self.LaserColorIndex        = 0
    self.LaserColorNum          = #self.LaserColorCycle
    self.CycleBoostShotNetIndex = 0
    self.bInitialize            = true

    if not self:HasAuthority() then
        self:ClientInit()
    end

    return true
end

function PassiveSkill_RainbowM249:ClientInit()
    ugcprint("PassiveSkill_RainbowM249:ClientInit")
    local WeaponMeshComp = self.Weapon:GetWeaponMeshComponent()
    if WeaponMeshComp == nil then
        ugcprint("PassiveSkill_RainbowM249:Clinet_InitBulletTailEffect WeaponMeshComp == nil - Init  BulletTailEffectPool")
        return false
    end

    -- 初始化特效池
    for i = 1, self.BulletTailEffectNum, 1 do
        self.BulletTailEffectPool[i] = GameplayStatics.SpawnEmitterAtLocation(self, self.BulletTail, {}, {}, {X = 1, Y = 1, Z = 1}, false)
        if self.BulletTailEffectPool[i] ~= nil then
            self.BulletTailEffectPool[i]:SetVisibility(false)
        end
    end

    return true
end

function PassiveSkill_RainbowM249:OnWeaponEquip(unused_slot)
    ugcprint("PassiveSkill_RainbowM249:OnWeaponEquip")

    if self.WeaponManagerComp == nil then
        return
    end

    local lastWeapon = self.WeaponManagerComp:GetLastUsedWeapon()
    if lastWeapon then
        lastWeapon.OnBulletBeforeShootDelegate:Remove(self.OnBulletBeforeshootInternal, self)
    end

    self.Weapon = self.WeaponManagerComp:GetCurrentUsingWeapon()
    if self.Weapon then
        self.Weapon.OnBulletBeforeShootDelegate:Add(self.OnBulletBeforeshootInternal, self)
    end
end 

function PassiveSkill_RainbowM249:OnBulletBeforeshootInternal(Bullet)
    ugcprint("PassiveSkill_RainbowM249:OnBulletBeforeshootInternal")
    self:ActivateSkill()
end

-- 射击时依次打出赤、橙、黄、绿、青、蓝、紫七种颜色的激光子弹
function PassiveSkill_RainbowM249:CountShootColors()
    self.CurrentBulletTailEffectIdx = (self.CurrentBulletTailEffectIdx % self.BulletTailEffectNum) + 1  -- 更新子弹特效索引
    self.LaserColorIndex            = (self.LaserColorIndex % self.LaserColorNum) + 1                   -- 更新颜色索引

    ugcprint("PassiveSkill_RainbowM249:CountShootColors LaserColorIndex=" .. tostring(self.LaserColorIndex))

    -- 设置特效颜色参数
    local Effect = self.BulletTailEffectPool[self.CurrentBulletTailEffectIdx]

    Effect:SetVectorParameter("BulletColor", self.ColorVectors[self.LaserColorIndex])
    Effect:SetVisibility(true)
    Effect:K2_Activate(true)
end

function PassiveSkill_RainbowM249:OnDisableSkill_BP()
    ugcprint("PassiveSkill_RainbowM249:OnDisableSkill_BP()")
    PassiveSkill_RainbowM249.SuperClass.OnDisableSkill_BP(self)
    -- 移除伤害加成
    if self.CycleBoostShotCount > 0 then
        if self.CycleBoostShotNetIndex >= self.CycleBoostShotCount + 1 then
            -- 重置
            self.CycleBoostShotNetIndex = 1
            local damageBonus = self.WeaponAttackBoostPerShot * (self.CycleBoostShotCount - 1)
            UGCAttributeSystem.AddGameAttributeValue(self.Weapon, 'BaseImpactDamageWrapper', -damageBonus * self.BaseDamage)
        end
    end
end

function PassiveSkill_RainbowM249:ShowLaser()
    print("[PassiveSkill_RainbowM249: Multicast_UpdateLaser] client self.bInitialize = " .. tostring(self.bInitialize))
    
    if self:HasAuthority() then
        return
    end

    if not self.bInitialize then
        self:Init()
    end

    self:CountShootColors()
    local MuzzleLocation, TraceDir = self:GetWeaponParams()
    if MuzzleLocation ~= nil and TraceDir ~= nil then
        local LaserEndPos = self:LineTrace(MuzzleLocation, TraceDir, nil)
        self:UpdateLaser(MuzzleLocation, LaserEndPos)
    end
end

-- DS上用子弹命中事件代替子弹射击事件（DS上无子弹射击）
function PassiveSkill_RainbowM249:OnDeActivateSkill_BP()
    PassiveSkill_RainbowM249.SuperClass.OnDeActivateSkill_BP(self)
end

-- 线性检测，返回终点Hit位置
function PassiveSkill_RainbowM249:LineTrace(TraceStartPos, TraceDir, Bullet)
    self.TraceIgnoreActors = {}
    -- 忽略子弹
    if Bullet ~= nil then
        table.insert(self.TraceIgnoreActors, Bullet)
    end

    -- 忽略自己
    local OwnerPawn = self.Weapon:GetOwnerPawn()
    if OwnerPawn ~= nil then
        table.insert(self.TraceIgnoreActors, OwnerPawn)
    end

    -- 忽略队友
    if UE.IsValid(OwnerPawn) and UE.IsValid(OwnerPawn.STExtraPlayerState) then
        local TeammateList = OwnerPawn.STExtraPlayerState:GetTeamMatePlayerStateList({}, true)
        for k, v in pairs(TeammateList) do
            if UE.IsValid(v) then
                local TargetPlayer = v:GetPlayerCharacter()
                if UE.IsValid(TargetPlayer) then
                    table.insert(self.TraceIgnoreActors, TargetPlayer)
                end
            end
        end
    end

    local TraceEndPos = UGCMathUtility.AddVector(TraceStartPos, UGCMathUtility.MultiplyVector(TraceDir, self.LaserTraceDistance))
    local bHit, HitResult = KismetSystemLibrary.LineTraceSingle(self, TraceStartPos, TraceEndPos, ECollisionChannel.ECC_WorldDynamic, false, self.TraceIgnoreActors)
    if bHit then
        TraceEndPos = HitResult.ImpactPoint:Copy()
    end

    return TraceEndPos
end

-- 客户端逻辑，获取武器参数 - 枪口 和 枪口方向
function PassiveSkill_RainbowM249:GetWeaponParams()
    if self.Weapon == nil then
        ugcprint("PassiveSkill_RainbowM249:GetWeaponParams() self.Weapon == nil")
        return nil, nil
    end

    local MuzzleTransform = self.Weapon:GetMuzzleTransform()
    local MuzzleLocation, MuzzleRotation, _ = UGCMathUtility.BreakTransform(MuzzleTransform)

    -- 枪口方向
    local TraceDir = UGCMathUtility.Normal(UGCMathUtility.GetForwardVector(MuzzleRotation))

    return MuzzleLocation, TraceDir
end

function PassiveSkill_RainbowM249:UpdateLaser(LaserStartPos, LaserEndPos)
    ---@type UParticleSystemComponent
    local Effect = self.BulletTailEffectPool[self.CurrentBulletTailEffectIdx]
    if Effect ~= nil then
        local Distance = UGCMathUtility.GetPointDistanceToSegment(LaserStartPos, LaserEndPos, LaserEndPos)
        -- local Distance = STExtraBlueprintFunctionLibrary.Dist(LaserStartPos, LaserEndPos)
        local TargetRot = UGCMathUtility.FindLookAtRotation(LaserStartPos, LaserEndPos)

        Effect:K2_SetWorldLocation(LaserStartPos, true, {}, true)
        Effect:K2_SetWorldRotation(TargetRot, true, {}, true)
        Effect:SetVectorParameter("Target", Vector.New(Distance, 0, 0))

        -- 绘制起点
        -- UGCDebugSystem.DrawDebugPoint(LaserStartPos,5,{A=1,B=1,G=0,R=0},3)
        -- -- 绘制激光轨迹
        -- UGCDebugSystem.DrawDebugLine(LaserStartPos,LaserEndPos, {A=1,B=1,G=0,R=0},3)
    end
end

return PassiveSkill_RainbowM249
