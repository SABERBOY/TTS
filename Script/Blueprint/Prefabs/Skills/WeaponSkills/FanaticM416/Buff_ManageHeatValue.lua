---@class Buff_ManageHeatValue_C:PersistEffectBuff
---@field DecreasePerSecond float 每秒热值降低速度
---@field HeatValuePerStack float 每层堆叠增加的热值
---@field MaxStackNum int32 最大堆叠层数
---@field FireProhibiteBuffClass UClass 武器过热禁止射击Buff类
---@field TargetWeapon object 目标武器引用
---@field HeatValue number 当前热值

local Buff_ManageHeatValue = {
    TargetWeapon = nil,  -- 当前武器引用
    HeatValue = 0        -- 当前热值计数
}

local Skill_Utils = UGCGameSystem.UGCRequire('Script.Blueprint.Prefabs.Skills.Skill_Utils')

---@param OwnerActor object 拥有者Actor
function Buff_ManageHeatValue:OnApply_BP(OwnerActor)
    if not UGCGameSystem.IsServer() then
        return
    end

    if not OwnerActor then
        Skill_Utils:LogError("ManageHeatValue", "OnApply_BP: OwnerActor is nil")
        return
    end
    
    -- 获取当前武器
    self.TargetWeapon = UGCWeaponManagerSystem.GetCurrentWeapon(OwnerActor)
    if self.TargetWeapon then
        Skill_Utils:LogInfo("ManageHeatValue", "Buff applied, weapon reference saved")
    else
        Skill_Utils:LogWarning("ManageHeatValue", "Buff applied but no weapon found")
    end
    
    -- 初始化热值
    self.HeatValue = 0
end

---Buff堆叠层数变化时调用，更新热值
---@param PreNum number 变化前的堆叠层数
---@param CurNum number 变化后的堆叠层数
function Buff_ManageHeatValue:OnStackChange_BP(PreNum, CurNum)
    if not UGCGameSystem.IsServer() then
        return
    end

    -- 武器检查
    if not self.TargetWeapon then
        Skill_Utils:LogError("ManageHeatValue", "OnStackChange_BP: TargetWeapon is nil")
        return
    end

    -- 根据堆叠层数变化调整热值
    if PreNum > CurNum then
        Skill_Utils:LogInfo("ManageHeatValue", "Stack decreased", PreNum, "->", CurNum)
        self:DecreaseHeatValue()
    elseif PreNum < CurNum then
        Skill_Utils:LogInfo("ManageHeatValue", "Stack increased", PreNum, "->", CurNum)
        self:IncreaseHeatValue(CurNum)
    end
end

---降低热值
function Buff_ManageHeatValue:DecreaseHeatValue()
    -- 检查热值是否已为0
    if self.HeatValue <= 0 then
        return
    end

    -- 降低热值
    local previousHeat = self.HeatValue
    self.HeatValue = self.HeatValue - self.DecreasePerSecond
    
    -- 确保热值不小于0
    if self.HeatValue <= 0 then
        self.HeatValue = 0
        Skill_Utils:LogInfo("ManageHeatValue", "Heat value reduced to zero, removing fire prohibite buff")
        self:RemoveFireProhibiteBuff()
    else
        Skill_Utils:LogInfo("ManageHeatValue", "Heat value decreased", previousHeat, "->", self.HeatValue)
    end
end

---@param CurNum number 当前堆叠层数
function Buff_ManageHeatValue:IncreaseHeatValue(CurNum)
    -- 武器有效性检查
    if not UE.IsValid(self.TargetWeapon) then
        Skill_Utils:LogError("ManageHeatValue", "IncreaseHeatValue: TargetWeapon is invalid")
        return
    end

    -- 计算新热值
    local previousHeat = self.HeatValue
    self.HeatValue = CurNum * self.HeatValuePerStack
    Skill_Utils:LogInfo("ManageHeatValue", "Heat value updated", previousHeat, "->", self.HeatValue)

    -- 达到最大堆叠层数时添加禁止射击Buff
    if CurNum >= self.MaxStackNum then
        Skill_Utils:LogWarning("ManageHeatValue", "Maximum heat reached, adding fire prohibite buff")
        self:AddFireProhibiteBuff()
    end
end

---添加禁止射击Buff
function Buff_ManageHeatValue:AddFireProhibiteBuff()
    -- 检查Buff类是否有效
    if not UE.IsValid(self.FireProhibiteBuffClass) then
        Skill_Utils:LogError("ManageHeatValue", "AddFireProhibiteBuff: FireProhibiteBuffClass is invalid")
        return
    end

    -- 获取所有者并添加Buff
    local owner = self:GetNetOwnerActor()
    if not owner then
        Skill_Utils:LogError("ManageHeatValue", "AddFireProhibiteBuff: Owner is nil")
        return
    end
    
    UGCPersistEffectSystem.AddBuffByClass(owner, self.FireProhibiteBuffClass, owner, -1, 1)
    Skill_Utils:LogInfo("ManageHeatValue", "Fire prohibite buff added")
end

---移除禁止射击Buff
function Buff_ManageHeatValue:RemoveFireProhibiteBuff()
    -- 检查Buff类是否有效
    if not UE.IsValid(self.FireProhibiteBuffClass) then
        Skill_Utils:LogError("ManageHeatValue", "RemoveFireProhibiteBuff: FireProhibiteBuffClass is invalid")
        return
    end

    -- 获取所有者并移除Buff
    local owner = self:GetNetOwnerActor()
    if not owner then
        Skill_Utils:LogError("ManageHeatValue", "RemoveFireProhibiteBuff: Owner is nil")
        return
    end
    
    UGCPersistEffectSystem.RemoveBuffByClass(owner, self.FireProhibiteBuffClass)
    Skill_Utils:LogInfo("ManageHeatValue", "Fire prohibite buff removed")
end

return Buff_ManageHeatValue
