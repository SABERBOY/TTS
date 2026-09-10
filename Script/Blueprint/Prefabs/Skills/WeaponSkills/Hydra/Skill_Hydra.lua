---@class Skill_Hydra_C:PESkillPassiveSkillTemplate_C
---@field SpawnRadius float
---@field MaxHydras int32
---@field HydraClass UClass
--Edit Below--
---@class Skill_Hydra_C:PESkillPassiveSkillTemplate_C
---@field SpawnRadius number 生成九头蛇的半径范围(米)
---@field HydraClass UClass 九头蛇Actor类引用
---@field MaxHydras number 最大九头蛇数量
---@field Hydras table 当前存在的九头蛇列表
---@field HdyraLocation vector 九头蛇生成位置

-- 九头蛇技能：在周围随机位置召唤九头蛇友军，自动向敌人投射攻击
local Skill_Hydra = {
    Hydras = {},           -- 已召唤的九头蛇列表
    SpawnParticleEffect = nil, -- 生成特效
    HdyraLocation = nil    -- 九头蛇生成位置
}

local Skill_Utils = UGCGameSystem.UGCRequire('Script.Blueprint.Prefabs.Skills.Skill_Utils')

--- 生成一个九头蛇实体
--- @return object|nil 生成的九头蛇对象，失败返回nil
function Skill_Hydra:SpawnHydra()
    -- 安全检查
    if not self.Owner or not self.Owner.Owner then
        Skill_Utils:LogError("Hydra", "SpawnHydra: Owner is nil")
        return nil
    end
    
    if not self.HydraClass then
        Skill_Utils:LogError("Hydra", "SpawnHydra: HydraClass is nil")
        return nil
    end
    
    if not self.SpawnRadius or self.SpawnRadius <= 0 then
        Skill_Utils:LogError("Hydra", "SpawnHydra: Invalid SpawnRadius")
        return nil
    end
    
    -- 获取所有者和位置
    local ownerActor = self.Owner.Owner
    local ownerLocation = ownerActor:K2_GetActorLocation()
    
    -- 计算随机位置
    local randomDegrees = math.random(0, 360)
    local randomRadians = randomDegrees * (math.pi / 180)
    local spawnDistance = self.SpawnRadius * 100 -- 转换为虚幻单位
    local randomX = math.cos(randomRadians) * spawnDistance
    local randomY = math.sin(randomRadians) * spawnDistance
    
    local newHydraLocation = {
        X = ownerLocation.X + randomX,
        Y = ownerLocation.Y + randomY,
        Z = ownerLocation.Z
    }
    
    -- 存储生成位置便于复制
    self.HdyraLocation = newHydraLocation
    
    -- 获取旋转值
    local newHydraRotation = ownerActor:K2_GetActorRotation()
    
    -- 生成九头蛇实体
    Skill_Utils:LogInfo("Hydra", "Spawning hydra at position", newHydraLocation.X, newHydraLocation.Y, newHydraLocation.Z)
    local newHydra = UGCActorComponentUtility.SpawnActor(ownerActor, self.HydraClass, newHydraLocation, newHydraRotation, {X=1, Y=1, Z=1}, ownerActor)
    
    -- 验证生成结果
    if newHydra and UE.IsValid(newHydra) then
        Skill_Utils:LogInfo("Hydra", "Hydra spawned successfully")
        local BlackBoardComp=newHydra:GetBlackBoardComponent()
        BlackBoardComp:SetValueAsObject("Teammate", ownerActor)
        return newHydra
    else
        Skill_Utils:LogError("Hydra", "Failed to spawn hydra")
        return nil
    end
end

--- 清理无效的九头蛇对象
function Skill_Hydra:CleanupInvalidHydras()
    local originalCount = #self.Hydras
    
    -- 从后向前遍历以安全删除
    for i = #self.Hydras, 1, -1 do
        local hydra = self.Hydras[i]
        if not hydra or not UE.IsValid(hydra) then
            table.remove(self.Hydras, i)
            Skill_Utils:LogInfo("Hydra", "Removed invalid hydra at index", i)
        end
    end
    
    local removedCount = originalCount - #self.Hydras
    if removedCount > 0 then
        Skill_Utils:LogInfo("Hydra", "Cleaned up", removedCount, "invalid hydras")
    end
end

--- 检查并限制九头蛇的数量
function Skill_Hydra:EnforceHydraLimit()
    if not self.MaxHydras then
        Skill_Utils:LogWarning("Hydra", "MaxHydras is not set")
        return
    end
    
    -- 当超过最大数量时，移除最早创建的九头蛇
    while #self.Hydras > self.MaxHydras do
        local oldestHydra = self.Hydras[1]
        if oldestHydra and UE.IsValid(oldestHydra) then
            oldestHydra:K2_DestroyActor()
            Skill_Utils:LogInfo("Hydra", "Destroyed oldest hydra to enforce limit")
        end
        table.remove(self.Hydras, 1)
    end
end

--- 技能激活时调用
function Skill_Hydra:OnActivateSkill_BP()
    Skill_Utils:LogInfo("Hydra", "Activating Hydra skill")
    
    -- 调用父类方法
    Skill_Hydra.SuperClass.OnActivateSkill_BP(self)
    
    -- 仅在服务器上执行
    if not UGCGameSystem.IsServer() then
        Skill_Utils:LogInfo("Hydra", "Skipping hydra spawn on client")
        return
    end
    
    -- 清理无效的九头蛇
    self:CleanupInvalidHydras()
    
    -- 生成新的九头蛇
    local newHydra = self:SpawnHydra()
    if newHydra then
        table.insert(self.Hydras, newHydra)
        Skill_Utils:LogInfo("Hydra", "Added new hydra, total count:", #self.Hydras)
    end
    
    -- 限制九头蛇数量
    self:EnforceHydraLimit()
end

--- 技能移除时清理所有九头蛇
function Skill_Hydra:OnUnApply_BP()
    if not UGCGameSystem.IsServer() then
        return
    end
    
    Skill_Utils:LogInfo("Hydra", "Cleaning up all hydras")
    
    -- 销毁所有九头蛇
    for i, hydra in ipairs(self.Hydras) do
        if hydra and UE.IsValid(hydra) then
            hydra:K2_DestroyActor()
        end
    end
    
    -- 清空数组
    self.Hydras = {}
    
    -- 调用父类方法
    Skill_Hydra.SuperClass.OnUnApply_BP(self)
end

return Skill_Hydra
