---@class Skill_FanaticM416_C:PESkillPassiveSkillTemplate_C
---@field FanaticM416Class UClass
---@field ManageHeatValue UClass
---@field ImproveAttackSpeed UClass
---@field FireProhibiteBuffClass UClass

-- 狂热M416技能：射击命中目标时提高攻击速度，并积累热值
-- 热值达到阈值后会过热并临时禁止射击
local Skill_FanaticM416 = {}

local Skill_Utils = UGCGameSystem.UGCRequire('Script.Blueprint.Prefabs.Skills.Skill_Utils')

---技能移除时调用，移除事件监听
function Skill_FanaticM416:OnUnApply_BP()
    if not UGCGameSystem.IsServer() then
        return
    end 

    local owner = self:GetNetOwnerActor()
    if not owner then
        Skill_Utils:LogError("FanaticM416", "OnUnApply_BP: Owner is nil")
        return
    end

    -- 移除子弹命中事件监听
    owner.OnBulletHitDelegate:Remove(self.AddFanaticBuff, self)
    Skill_Utils:LogInfo("FanaticM416", "Bullet hit delegate removed")

    -- 移除射击禁止状态
    local stopFireBuff = owner:GetPersistBaseComponent():GetPersistEffectDataByClass(self.FireProhibiteBuffClass)
    if stopFireBuff and #stopFireBuff >= 1 then
        UGCPersistEffectSystem.ResetDynamicStateDisabled(owner, "PawnState.Gun.GunFire")
        Skill_Utils:LogInfo("FanaticM416", "Gun fire state reset")
    end
end

---技能应用时调用，检查是否有禁止射击buff
function Skill_FanaticM416:OnApply_BP()
    if not UGCGameSystem.IsServer() then
        return
    end

    local owner = self:GetNetOwnerActor()
    if not owner then
        Skill_Utils:LogError("FanaticM416", "OnApply_BP: Owner is nil")
        return
    end

    -- 检查是否有禁止射击buff
    local stopFireBuff = owner:GetPersistBaseComponent():GetPersistEffectDataByClass(self.FireProhibiteBuffClass)
    if stopFireBuff and #stopFireBuff >= 1 then
        UGCPersistEffectSystem.SetDynamicStateDisabled(owner, "PawnState.Gun.GunFire", true)
        Skill_Utils:LogInfo("FanaticM416", "Gun fire disabled due to existing prohibite buff")
    end
end

---技能激活时调用，添加子弹命中事件监听
function Skill_FanaticM416:OnActivateSkill_BP()
    self.SuperClass.OnActivateSkill_BP(self)

    local owner = self:GetNetOwnerActor()
    if not owner then
        Skill_Utils:LogError("FanaticM416", "OnActivateSkill_BP: Owner is nil")
        return
    end

    -- 添加子弹命中事件监听
    owner.OnBulletHitDelegate:Add(self.AddFanaticBuff, self)
    Skill_Utils:LogInfo("FanaticM416", "Bullet hit delegate added")
end

---子弹命中时调用，添加相关buff
---@param weapon object 武器对象
---@param bullet object 子弹对象
---@param hitResult table 命中结果
function Skill_FanaticM416:AddFanaticBuff(weapon, bullet, hitResult)
    local owner = self:GetNetOwnerActor()
    if not owner then
        Skill_Utils:LogError("FanaticM416", "AddFanaticBuff: Owner is nil")
        return
    end
    -- 添加热值管理和攻击速度提升buff
    UGCPersistEffectSystem.AddBuffByClass(owner, self.ManageHeatValue,owner,-1,2)
    UGCPersistEffectSystem.AddBuffByClass(owner, self.ImproveAttackSpeed)

    Skill_Utils:LogInfo("FanaticM416", "Added heat and attack speed buffs")
end

---检查技能是否可以激活
---@return boolean 是否可以激活
function Skill_FanaticM416:CanActivateSkill_BP()
    local owner = self:GetNetOwnerActor()
    if not owner then
        Skill_Utils:LogError("FanaticM416", "CanActivateSkill_BP: Owner is nil")
        return false
    end

    -- 检查当前武器是否为M416
    local currentWeapon = UGCWeaponManagerSystem.GetCurrentWeapon(owner)
    if not currentWeapon then
        Skill_Utils:LogInfo("FanaticM416", "No weapon equipped")
        return false
    end

    if UE.IsA(currentWeapon, self.FanaticM416Class) then
        Skill_Utils:LogInfo("FanaticM416", "M416 weapon detected, can activate skill")
        return self.SuperClass.CanActivateSkill_BP(self)
    end

    Skill_Utils:LogInfo("FanaticM416", "Not using M416, cannot activate skill")
    return false
end

return Skill_FanaticM416

