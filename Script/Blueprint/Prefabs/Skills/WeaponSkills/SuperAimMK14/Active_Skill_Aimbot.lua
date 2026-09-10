---@class Active_Skill_Aimbot_C:PESkillTemplate_Active_C
---@field ViewDistance float
---@field Duration float
--Edit Below--
---@class Active_Skill_Aimbot_C:PESkillTemplate_Active_C
---@field ViewDistance float  -- 视野距离（米）
---@field Duration float      -- 技能持续时间（秒）
-- Edit Below--

local Active_Skill_Aimbot = {
    TargetWeapon = nil,
    OwnerActor = nil,
    Controller = nil,
    -- 缓存的组件引用，提高性能
    CachedPlayerLocation = nil,
    CachedViewportSize = nil,
    -- 目标选择相关
    CurrentTargets = {},
    LastTargetUpdateTime = 0,
    TargetUpdateInterval = 0.1  -- 目标更新间隔（秒）
}

function Active_Skill_Aimbot:OnEnableSkill_BP()
    Active_Skill_Aimbot.SuperClass.OnEnableSkill_BP(self)
    -- 清空目标列表
    self.CurrentTargets = {}
    self.LastTargetUpdateTime = 0
end

function Active_Skill_Aimbot:OnDisableSkill_BP()
    Active_Skill_Aimbot.SuperClass.OnDisableSkill_BP(self)
    -- 清理缓存
    self:ClearCache()
end

-- 清理缓存数据
function Active_Skill_Aimbot:ClearCache()
    self.CachedPlayerLocation = nil
    self.CachedViewportSize = nil
    self.CurrentTargets = {}
end

-- 更新缓存的玩家位置和视口大小
function Active_Skill_Aimbot:UpdateCache()
    if self.OwnerActor then
        self.CachedPlayerLocation = self.OwnerActor:K2_GetActorLocation()
    end
    
    if self.Controller then
        self.CachedViewportSize = Vector.New()
        local ViewportX,ViewportY = self.Controller:GetViewportSize()
        self.CachedViewportSize.X = ViewportX
        self.CachedViewportSize.Y = ViewportY
    end
end

-- 改进的敌人视野检测方法
function Active_Skill_Aimbot:IsEnemyInView(Enemy)
    if not Enemy or not UE.IsValid(Enemy) then
        return false
    end

    -- 1. 阵营关系检查
    local Relation = self.OwnerActor:GetGeneralCampRelationWithActor(Enemy)
    if Relation == ECampRelation.Same or Relation == ECampRelation.Ally then
        return false
    end

    -- -- 2. 优化的距离检查（使用距离平方避免开方运算）

    local EnemyLocation = Enemy:K2_GetActorLocation()
    
    if not self.Controller then
        return true
    end

    -- 3. 完整的屏幕投影检查
    local Success, ScreenPosition = self.Controller:ProjectWorldLocationToScreen(EnemyLocation)
    if not Success then
        return false
    end
    
    -- 检查投影点是否在视口边界内
    local ViewportSizeX,ViewportSizeY = self.Controller:GetViewportSize()
    local ViewportSize = Vector.New()
    if self.CachedViewportSize ~= nil then
        ViewportSize = self.CachedViewportSize
        print("Active_Skill_Aimbot:IsEnemyInView(Enemy)--1"..tostring(ViewportSize))
    else
        ViewportSize.X = ViewportSizeX
        ViewportSize.Y = ViewportSizeY
        print("Active_Skill_Aimbot:IsEnemyInView(Enemy)--2"..tostring(ViewportSize))
    end
    if ScreenPosition.X < 0 or ScreenPosition.X > ViewportSize.X or 
       ScreenPosition.Y < 0 or ScreenPosition.Y > ViewportSize.Y then
        return false
    end

    return true
end

function Active_Skill_Aimbot:GetEnemysInRange()
    if self.OwnerActor == nil then
        self.OwnerActor = self.Owner.Owner
    end 
    local EnemyList = {};
    local  DrawDebugTrace = EDrawDebugTrace.None
    local bHit, Results = KismetSystemLibrary.SphereTraceMultiForObjects(self,  self.OwnerActor:K2_GetActorLocation(),  self.OwnerActor:K2_GetActorLocation(), self.ViewDistance * 100, {EObjectTypeQuery.ObjectTypeQuery3}, false, {}, DrawDebugTrace, {}, true, {R=1, G=0, B=0, A=1}, {R=0, G=1, B=0, A=1}, 3)
    if bHit then
        for _, v in pairs(Results) do
            if v.Actor:IsValid() then
                print("Active_Skill_Aimbot:InitCharacterList: HitActor:"..tostring(v.Actor:Get()))
                table.insert(EnemyList,v.Actor:Get());   
            else
                print("Active_Skill_Aimbot:EnemyList: v.Actor:IsNotValid()")
            end
        end
        ugcprint("Active_Skill_Aimbot:GetEnemyInRange()--tostring(#Results)"..tostring(#Results));
    end
    return EnemyList
end

-- 获取视野内的敌人列表，按距离排序
function Active_Skill_Aimbot:GetEnemiesInView()
    local CharacterClass = UE.LoadClass('/Script/Engine.Character')
    local AllEnemies = self:GetEnemysInRange()
    local EnemiesInView = {}
    
    -- 更新缓存
    self:UpdateCache()
    
    for _, Enemy in ipairs(AllEnemies) do
        if self:IsEnemyInView(Enemy) then
            table.insert(EnemiesInView, {
                Actor = Enemy,
            })
        end
    end
    return EnemiesInView
end

-- 选择攻击目标
function Active_Skill_Aimbot:SelectTargets()
    local CurrentTime = GameplayStatics.GetTimeSeconds(self)
    
    -- 如果距离上次更新时间太短，使用缓存的目标
    if CurrentTime - self.LastTargetUpdateTime < self.TargetUpdateInterval then
        return self.CurrentTargets
    end
    
    self.LastTargetUpdateTime = CurrentTime
    local EnemiesInView = self:GetEnemiesInView()
       
    for i = 1, #EnemiesInView do
        table.insert(self.CurrentTargets, EnemiesInView[i])
    end
    
    return self.CurrentTargets
end

function Active_Skill_Aimbot:OnActivateSkill_BP()
    Active_Skill_Aimbot.SuperClass.OnActivateSkill_BP(self)
    print("Active_Skill_Aimbot:OnActivateSkill_BP() - 开始自动瞄准射击")
    self.OwnerActor = self.Owner.Owner
    if not self.OwnerActor then
        print("Active_Skill_Aimbot:OnActivateSkill_BP() - OwnerActor is nil")
        return
    end

    self.Controller = self.OwnerActor:GetPlayerControllerSafety()
    if not self.Controller then
        print("Active_Skill_Aimbot:OnActivateSkill_BP() - Controller is nil")
        return
    end
    
    self.TargetWeapon = UGCWeaponManagerSystem.GetCurrentWeapon(self.OwnerActor)
    if not self.TargetWeapon then
        print("Active_Skill_Aimbot:OnActivateSkill_BP() - TargetWeapon is nil")
        return
    end

    -- 服务器端逻辑：启用无限子弹并开始射击
    if UGCGameSystem.IsServer() then
        UGCGunSystem.EnableInfiniteBullets(self.TargetWeapon, true)
        UnrealNetwork.CallUnrealRPC_Multicast(self, "Multicast_StartFire")
    end

    -- 设置定时器，在Duration秒后停止射击
    UGCGameSystem.SetTimer(self, function()
        if UGCGameSystem.IsServer() then
            print("Active_Skill_Aimbot:OnActivateSkill_BP() - 自动瞄准射击结束")
            UGCGunSystem.EnableInfiniteBullets(self.TargetWeapon, false)
            UnrealNetwork.CallUnrealRPC_Multicast(self, "Multicast_StopFire")    
        end
    end, self.Duration, false)
end

-- 改进的多播开始射击方法
function Active_Skill_Aimbot:Multicast_StartFire()
    print("Active_Skill_Aimbot:Multicast_StartFire()")
    self.OwnerActor = self.Owner.Owner
    if not self.OwnerActor then
        print("Active_Skill_Aimbot:Multicast_StartFire() - OwnerActor is nil")
        return
    end

    self.Controller = self.OwnerActor:GetPlayerControllerSafety()
    print("Active_Skill_Aimbot:Multicast_StartFire()--self.Controller"..tostring(self.Controller))
    if not self.Controller then
        print("Active_Skill_Aimbot:Multicast_StartFire() - Controller is nil")
        return
    end
    
    self.TargetWeapon = UGCWeaponManagerSystem.GetCurrentWeapon(self.OwnerActor)
    if not self.TargetWeapon then
        print("Active_Skill_Aimbot:Multicast_StartFire() - TargetWeapon is nil")
        return
    end

    -- 开启瞄准镜
    UGCGunSystem.OpenScope(self.OwnerActor, true)

    -- 选择攻击目标
    local Targets = self:SelectTargets()
    
    if #Targets > 0 then
        -- 只对第一个目标开始射击（避免重复调用StartFire）
        UGCGunSystem.StartFire(self.TargetWeapon)
        
        -- 对所有选中的目标应用伤害
        for _, TargetInfo in ipairs(Targets) do
            print("Active_Skill_Aimbot:Multicast_StartFire()--_, TargetInfo in ipairs(Targets)")
            UnrealNetwork.CallUnrealRPC(self.Controller, self.TargetWeapon, "Server_StartApplyDamage", TargetInfo.Actor)
        end
        
        print(string.format("Active_Skill_Aimbot:Multicast_StartFire() - 开始攻击 %d 个目标", #Targets))
    else
        print("Active_Skill_Aimbot:Multicast_StartFire() - 视野内无有效目标")
    end
end

-- 技能停用时的处理（注意：这里是技能的主要逻辑入口点）
function Active_Skill_Aimbot:OnDeActivateSkill_BP()
    Active_Skill_Aimbot.SuperClass.OnDeActivateSkill_BP(self)
   
end

-- 改进的多播停止射击方法
function Active_Skill_Aimbot:Multicast_StopFire()
    self.OwnerActor = self.Owner.Owner
    if not self.OwnerActor then
        print("Active_Skill_Aimbot:Multicast_StopFire() - OwnerActor is nil")
        return
    end
    
    self.Controller = self.OwnerActor:GetPlayerControllerSafety()
    if not self.Controller then
        print("Active_Skill_Aimbot:Multicast_StopFire() - Controller is nil")
        return
    end
    
    self.TargetWeapon = UGCWeaponManagerSystem.GetCurrentWeapon(self.OwnerActor)
    if not self.TargetWeapon then
        print("Active_Skill_Aimbot:Multicast_StopFire() - TargetWeapon is nil")
        return
    end
    
    -- 关闭瞄准镜和停止射击
    UGCGunSystem.OpenScope(self.OwnerActor, false)
    UGCGunSystem.StopFire(self.TargetWeapon)
    
    -- 停止对所有目标的伤害应用
    UnrealNetwork.CallUnrealRPC(self.Controller, self.TargetWeapon, "Server_StopApplyDamage")
    
    -- 清理缓存和目标列表
    self:ClearCache()
    
    print("Active_Skill_Aimbot:Multicast_StopFire() - 停止自动瞄准射击")
end

function Active_Skill_Aimbot:CanActivateSkill_BP()
    return Active_Skill_Aimbot.SuperClass.CanActivateSkill_BP(self)
end

return Active_Skill_Aimbot
