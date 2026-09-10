---@class Passive_Skill_Burn_C:PESkillPassiveSkillTemplate_C
--Edit Below--
---@class Passive_Skill_Burn_C:PESkillPassiveSkillTemplate_C
---@field private CharacterClass UClass 角色类引用缓存

-- 燃烧被动技能：筛选并激活对目标角色的燃烧效果
local Passive_Skill_Burn = {
    CharacterClass = nil -- 缓存Character类，避免重复加载
}

local SkillUtils = UGCGameSystem.UGCRequire('Script.Blueprint.Prefabs.Skills.Skill_Utils')

--- 检查技能是否可以激活
--- 该函数会筛选出所有Character类型的目标，并设置为技能目标
---@return boolean 是否可以激活技能
function Passive_Skill_Burn:CanActivateSkill_BP()
    -- 安全检查
    if not self then
        SkillUtils:LogError("Passive_Skill_Burn", "Self reference is nil in CanActivateSkill_BP")
        return false
    end
    
    -- 加载Character类
    if not self.CharacterClass then
        self.CharacterClass = UE.LoadClass('/Script/Engine.Character')
        if not self.CharacterClass then
            SkillUtils:LogError("Passive_Skill_Burn", "Failed to load Character class")
            return false
        end
    end
    
    -- 获取目标
    local TargetActors = self:GetSelectTargetActor(EPESkillSelectTarget.E_PESKILL_PickerType_AllTarget)
    
    -- 目标检查
    if not TargetActors then
        SkillUtils:LogWarning("Passive_Skill_Burn", "Target actors array is nil")
        return Passive_Skill_Burn.SuperClass.CanActivateSkill_BP(self)
    end
    
    -- 筛选角色目标
    local TargetCount = TargetActors:Num()
    SkillUtils:LogInfo("Passive_Skill_Burn", "Processing", TargetCount, "potential targets")
    
    local ValidTargets = 0
    for i = TargetCount, 1, -1 do
        local TargetActor = TargetActors:Get(i)
        if not TargetActor or not UE.IsA(TargetActor, self.CharacterClass) then
            TargetActors:RemoveAt(i)
        else
            ValidTargets = ValidTargets + 1
        end
    end
    
    SkillUtils:LogInfo("Passive_Skill_Burn", "Found", ValidTargets, "valid character targets")
    
    -- 设置筛选后的目标
    self:SetSelectTargetActor(TargetActors)
    
    -- 调用父类方法继续处理
    return Passive_Skill_Burn.SuperClass.CanActivateSkill_BP(self)
end

return Passive_Skill_Burn