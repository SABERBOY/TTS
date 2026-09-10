---@class Skill_InfiniteVector_C:PESkillPassiveSkillTemplate_C
---@field TimeValidity float
---@field HitCount int32
---@field InfiniteBuffClass UClass
--Edit Below--
local Skill_InfiniteVector = {
    queue = {}
}

local Skill_Utils = UGCGameSystem.UGCRequire('Script.Blueprint.Prefabs.Skills.Skill_Utils')

-- 定义循环队列结构
local CircularQueue = {}
CircularQueue.__index = CircularQueue

-- 初始化队列
function CircularQueue:New(maxSize)
    local queue = {
        maxSize = maxSize,
        datas = {},
        head = 1,
        tail = 1,
        count = 0
    }
    return setmetatable(queue, CircularQueue)
end

-- 入队操作
function CircularQueue:Enqueue(data)
    self.datas[self.tail] = data
    self.tail = (self.tail % self.maxSize) + 1
    if self.count < self.maxSize then
        self.count = self.count + 1
    else
        self.head = (self.head % self.maxSize) + 1
    end
end

-- 获取队列头元素
function CircularQueue:GetHead()
    if self.count == 0 then
        return nil
    end
    return self.datas[self.head]
end

-- 获取队列尾元素
function CircularQueue:GetTail()
    if self.count == 0 then
        return nil
    end
    -- 返回尾指针上一个元素
    if self.tail > 1 then
        return self.datas[self.tail - 1]
    end
    return self.datas[self.maxSize]
end

-- 获取队列大小
function CircularQueue:GetSize()
    return self.count
end

function Skill_InfiniteVector:OnEnableSkill_BP()
    Skill_InfiniteVector.SuperClass.OnEnableSkill_BP(self)
    self.queue = CircularQueue:New(self.HitCount)
end


function Skill_InfiniteVector:CanActivateSkill_BP()
    Skill_Utils:LogInfo("Skill_InfiniteVector", "CanActivateSkill_BP")

    local TargetActors = self:GetSelectTargetActor(EPESkillSelectTarget.E_PESKILL_PickerType_AllTarget)
    local Length = TargetActors:Num()
    local CharacterClass = UE.LoadClass('/Script/Engine.Character')
    if not CharacterClass then
        Skill_Utils:LogError("Skill_InfiniteVector", "Failed to load Character class")
        return false
    end

    local OwnerPawn = self:GetNetOwnerActor()
    if UE.IsValid(OwnerPawn) then
        local PersistClientStateComp = OwnerPawn:GetPlayerPersistClientState()

        if not UE.IsValid(PersistClientStateComp) then
            Skill_Utils:LogError("Skill_InfiniteVector", "CanActivateSkill_BP : GetNetOwnerActor Error")
            return false
        end

        local BuffList = PersistClientStateComp:GetPersistEffectDataByClass(self.InfiniteBuffClass)
        if #BuffList >= 1 then
            return false;
        end
    else
        Skill_Utils:LogError("Skill_InfiniteVector", "CanActivateSkill_BP : GetNetOwnerActor Error")
        return false;
    end

    for i = 1, Length do
        -- 获取当前索引的元素
        local TargetActor = TargetActors:Get(i)
        if UE.IsA(TargetActor, CharacterClass) then
            -- 获取当前时间戳
            local CurrentTime = UGCMathUtility.UtcNow()
            -- 将当前时间戳加入队列
            self.queue:Enqueue(CurrentTime)
        end
    end
    
    -- 判断触发条件
    if self.queue:GetSize() < self.HitCount then
        return false
    end
    
    local TimeDelta = KismetMathLibrary.Subtract_DateTimeDateTime(self.queue:GetTail(), self.queue:GetHead())
    Skill_Utils:LogInfo("Skill_InfiniteVector", "TimeDelta:", KismetMathLibrary.GetTotalSeconds(TimeDelta))

    -- 判断时间是否超过有效期
    if KismetMathLibrary.GetTotalSeconds(TimeDelta) > self.TimeValidity then
        return false
    end

    -- 清空队列
    self.queue = CircularQueue:New(self.HitCount)

    return Skill_InfiniteVector.SuperClass.CanActivateSkill_BP(self)
end
function Skill_InfiniteVector:OnDisableSkill_BP()
    Skill_InfiniteVector.SuperClass.OnDisableSkill_BP(self)
    print("ActiveSkill_Fanaticism:OnDisableSkill_BP()")
    UGCPersistEffectSystem.RemoveBuffByClass(self:GetNetOwnerActor(), self.InfiniteBuffClass, -1)
end
return Skill_InfiniteVector
