--- BOSS AI 每实例战斗状态（规格 §3 / §7 / §11）
--- 生命周期：每只 BOSS 一个 State 实例（严禁共享 / 静态变量）。
--- 时间基准：所有接口的 now 由外部注入（秒），便于单元测试使用假时钟。
local Types = require('Script.AI.Boss.BossAI_Types')
local Random = require('Script.AI.Boss.BossAI_Random')

local State = {}
State.__index = State

--- 创建状态
---@param config table BossAI_Config
---@param seed number|nil 固定种子（复现用）
function State.New(config, seed)
    local self = setmetatable({}, State)
    self.config = config
    self.random = Random.New(seed or 20260922)
    self:Reset(0)
    return self
end

--- 完整重置（死亡 / 确认脱战 / 归位结束调用）
---@param now number
---@param opts table|nil { clearBreathingDebt = boolean }
function State:Reset(now, opts)
    opts = opts or {}
    local carryDebt, carryRemaining = 0, 0
    if opts.clearBreathingDebt == false and self.breathing ~= nil then
        carryDebt = self.breathing.debt
        carryRemaining = self.breathing.remainingSeconds
        if self.breathing.phase ~= Types.BreathingPhase.None then
            carryDebt = carryDebt + 1
            if self.breathing.phase == Types.BreathingPhase.Breathing and now ~= nil then
                carryRemaining = math.max(0, carryRemaining - math.max(0, now - self.breathing.startedAt))
            end
        end
    end
    self.activeAction = nil -- 旧危险清理回调不得再往本动作登记危险
    self.actionLocked = false
    if self.dangers ~= nil then
        self:ClearDangers() -- 重置前先禁用本实例尚可造成伤害的危险
    end
    self.cooldowns = {}       -- [skillId] = readyAt
    -- ID 跨 Reset 保持单调：旧 Timer/Notify/投射物回调不得命中新动作。
    self.actionInstanceId = self.actionInstanceId or 0
    self.activeAction = nil   -- { id, skillId, startedAt }
    self.actionLocked = false

    -- 压制预算（规格 §7）
    self.burstStartAt = now or 0
    self.burstActive = false -- 尚未进入追压；首次有效决策时才开始计时
    self.committedCount = 0

    -- 历史（规格 §6 RepeatFactor / 连续三次禁止）
    self.lastSkillId = Types.SkillID.None
    self.repeatCount = 0

    -- 喘息（规格 §7）
    self.breathing = {
        phase = Types.BreathingPhase.None,
        startedAt = 0,
        remainingSeconds = carryRemaining, -- 中止时保存，随后恢复
        debt = carryDebt,                  -- 欠下的喘息（轮数）
    }
    self.gapCloseAllowedTime = 0
    self.actualBreathingEndTime = nil

    -- 危险登记（规格 §7：投射物 / 地面攻击）
    -- Reset 前未能确认禁用伤害的危险必须继续留在登记表。
    self.dangers = self.dangers or {} -- [id] = { id, skillId, actionInstanceId, expireAt, active }
    self.nextDangerId = self.nextDangerId or 1
    self.expiredDangerCount = 0 -- 超时未注销计数（调试）
    self.dangerCleanupErrorCount = self.dangerCleanupErrorCount or 0

    -- 阶段（规格 §11）
    self.phase = 1
    self.phaseTransitionRequested = false
    self.phaseTransitionDone = false

end

-- =========================================================================
-- 冷却 / 承诺 / 历史
-- =========================================================================

--- 进入追压段；连续 Chase/Reposition/技能不重新计时。
function State:StartPressure(now)
    if self.burstActive then
        return false
    end
    self.burstStartAt = now
    self.burstActive = true
    return true
end

--- 技能冷却是否就绪
function State:IsSkillReady(skillId, now)
    local readyAt = self.cooldowns[skillId]
    return (readyAt == nil) or (now >= readyAt)
end

--- 技能剩余冷却（秒，0 表示就绪）
function State:GetSkillCooldownRemain(skillId, now)
    local readyAt = self.cooldowns[skillId]
    if readyAt == nil then
        return 0
    end
    return math.max(0, readyAt - now)
end

--- 进入前摇：开始冷却 + 记一次承诺 + 更新历史（规格 §9 步骤 2-3）
--- 注意：被硬直打断不退还本轮次数与冷却。
---@param skillId number
---@param now number
---@return number actionInstanceId
function State:CommitSkill(skillId, now)
    if self:HasDangerCleanupFailure() then
        return nil -- fail closed：危险伤害关闭失败时不能发起新攻击
    end
    self:StartPressure(now) -- 直接执行技能时也要开启压制段
    local def = self.config.SkillById[skillId]
    if def ~= nil then
        self.cooldowns[skillId] = now + (def.cd or 0)
    end

    self.committedCount = self.committedCount + 1

    if skillId == self.lastSkillId then
        self.repeatCount = self.repeatCount + 1
    else
        self.lastSkillId = skillId
        self.repeatCount = 1
    end

    self.actionInstanceId = self.actionInstanceId + 1
    self.activeAction = { id = self.actionInstanceId, skillId = skillId, startedAt = now }
    self.actionLocked = true
    return self.actionInstanceId
end

--- 动作结束（后摇完整结束 / 中止）
---@param actionInstanceId number|nil 旧回调需校验 ID，避免结束新动作（规格 §9）
---@return boolean 是否成功结束（false 表示 ID 不匹配，已忽略）
function State:EndAction(actionInstanceId)
    if self.activeAction == nil then
        return false
    end
    if actionInstanceId ~= nil and actionInstanceId ~= self.activeAction.id then
        return false -- 旧回调，忽略
    end
    self.activeAction = nil
    self.actionLocked = false
    return true
end

function State:IsActionLocked()
    return self.actionLocked == true
end

function State:GetActiveAction()
    return self.activeAction
end

function State:GetCommittedCount()
    return self.committedCount
end

function State:GetBurstStartAt()
    return self.burstStartAt
end

function State:SetBurstStartAt(now)
    self.burstStartAt = now
    self.burstActive = true
    self.committedCount = 0
end

--- 最近一次已承诺技能
function State:GetLastSkillId()
    return self.lastSkillId
end

--- 该技能连续被承诺的次数（1 表示首次）
function State:GetRepeatCountFor(skillId)
    if skillId ~= self.lastSkillId then
        return 0
    end
    return self.repeatCount
end

-- =========================================================================
-- 危险登记（规格 §7）
-- =========================================================================

--- 登记一个有效危险
---@param skillId number
---@param actionInstanceId number
---@param expireAt number 最晚失效时刻（秒）
---@param onExpire function|nil 超时/重置时关闭实际伤害的回调
---@return number|nil dangerId 旧动作或无有效寿命时拒绝登记
function State:RegisterDanger(skillId, actionInstanceId, expireAt, onExpire)
    local active = self.activeAction
    if active == nil or active.id ~= actionInstanceId or active.skillId ~= skillId then
        return nil -- 旧动作延迟回调不能在新动作或重置后登记危险
    end
    local def = self.config.SkillById[skillId]
    if def == nil or type(def.maxDangerLife) ~= 'number' or def.maxDangerLife < 0
        or def.maxDangerLife ~= def.maxDangerLife or def.maxDangerLife == math.huge then
        return nil
    end
    local maxExpireAt = active.startedAt + (def.windup or 0) + (def.active or 0) + def.maxDangerLife
    if type(expireAt) ~= 'number' or expireAt ~= expireAt
        or expireAt == math.huge or expireAt == -math.huge then
        expireAt = maxExpireAt
    else
        expireAt = math.min(expireAt, maxExpireAt)
    end
    local id = self.nextDangerId
    self.nextDangerId = id + 1
    self.dangers[id] = {
        id = id,
        skillId = skillId,
        actionInstanceId = actionInstanceId,
        expireAt = expireAt,
        active = true,
        onExpire = type(onExpire) == 'function' and onExpire or nil,
    }
    -- 窗口期间若又出现可伤害对象，此前的静止时间不再满足连续 2 秒保障。
    if self.breathing.phase == Types.BreathingPhase.Breathing then
        self.breathing.phase = Types.BreathingPhase.DrainThreats
        self.breathing.remainingSeconds = self.config.Pressure.GuaranteedBreathingSeconds
    end
    return id
end

--- 注销危险（伤害禁用 / 销毁时调用）
function State:UnregisterDanger(dangerId)
    local d = self.dangers[dangerId]
    if d ~= nil then
        d.active = false
        self.dangers[dangerId] = nil
    end
end

--- 尝试关闭一个危险的实际伤害；回调异常时保留未解决状态。
local function tryDisableDanger(self, danger)
    if danger.onExpire ~= nil then
        local ok, err = pcall(danger.onExpire, danger)
        if not ok then
            danger.cleanupFailed = true
            danger.cleanupError = tostring(err)
            danger.active = true -- 回调失败，不能假定实际伤害已关闭
            self.dangerCleanupErrorCount = (self.dangerCleanupErrorCount or 0) + 1
            return false
        end
    end
    danger.active = false
    danger.cleanupFailed = false
    danger.cleanupError = nil
    return true
end

--- 关闭所有危险；失败项继续登记，直到显式清理成功。
---@return boolean 全部危险是否确认已关闭
function State:ClearDangers()
    local unresolved = {}
    for id, d in pairs(self.dangers) do
        if not tryDisableDanger(self, d) then
            unresolved[id] = d
        end
    end
    self.dangers = unresolved
    return next(unresolved) == nil
end

--- 扫描超时危险并重试关闭失败项；失败时保持阻塞状态并记录错误。
---@return number swept 本次清理数量
function State:SweepDangers(now)
    local swept = 0
    for id, d in pairs(self.dangers) do
        local expired = d.expireAt ~= nil and now >= d.expireAt
        if expired or d.cleanupFailed then
            if expired and not d.timeoutObserved then
                d.timeoutObserved = true
                self.expiredDangerCount = self.expiredDangerCount + 1
            end
            if tryDisableDanger(self, d) then
                self.dangers[id] = nil
                swept = swept + 1
            end
        end
    end
    return swept
end

function State:HasDangerCleanupFailure()
    for _, d in pairs(self.dangers) do
        if d.cleanupFailed then
            return true
        end
    end
    return false
end

--- 当前仍可伤害或关闭失败的危险数量（纯查询）。
function State:GetActiveDangerCount(now)
    local n = 0
    for _id, d in pairs(self.dangers) do
        if d.cleanupFailed or d.expireAt == nil or now <= d.expireAt then
            n = n + 1
        end
    end
    return n
end

--- 当前危险的最晚失效时刻；关闭失败时返回无限期阻塞（纯查询）。
function State:GetActiveDangerDeadline(now)
    local deadline = nil
    for _id, d in pairs(self.dangers) do
        if d.cleanupFailed or d.expireAt == nil or now <= d.expireAt then
            local dangerDeadline = (d.cleanupFailed or d.expireAt == nil) and math.huge or d.expireAt
            if deadline == nil or dangerDeadline > deadline then
                deadline = dangerDeadline
            end
        end
    end
    return deadline
end

-- =========================================================================
-- 压制预算与喘息（规格 §7）
-- =========================================================================

--- 预测威胁真空时刻
--- PredictedThreatFreeTime = Max(当前登记危险最晚失效, 候选动作后摇结束, 候选技能最后危险预计失效)
function State:PredictThreatFreeTime(now, candidateRecoveryEnd, candidateLastDangerEnd)
    local t = now
    local d = self:GetActiveDangerDeadline(now)
    if d ~= nil and d > t then
        t = d
    end
    if candidateRecoveryEnd ~= nil and candidateRecoveryEnd > t then
        t = candidateRecoveryEnd
    end
    if candidateLastDangerEnd ~= nil and candidateLastDangerEnd > t then
        t = candidateLastDangerEnd
    end
    return t
end

--- 是否应优先进入 GiveSpace（喘息）
--- 规则：已承诺次数达到上限，或"下一动作"将令本轮压制超过预算时长。
---@param now number
---@param candidateTotalSeconds number|nil 候选动作（前摇+有效+后摇）总时长
---@param candidateLastDangerEnd number|nil 候选技能最后危险预计失效的绝对时刻
function State:ShouldGiveSpace(now, candidateTotalSeconds, candidateLastDangerEnd)
    if self.breathing.phase ~= Types.BreathingPhase.None then
        return true
    end
    if self.breathing.debt > 0 then
        return true
    end
    local P = self.config.Pressure
    if self.committedCount >= P.MaxCommittedSkillsPerBurst then
        return true
    end
    if not self.burstActive then
        return false
    end
    local recoveryEnd = now + math.max(0, candidateTotalSeconds or 0)
    local threatFreeAt = self:PredictThreatFreeTime(now, recoveryEnd, candidateLastDangerEnd)
    if threatFreeAt - self.burstStartAt > P.PressureBudgetSeconds then
        return true
    end
    return false
end

--- 开始喘息（进入 A 阶段 DrainThreats）
---@param now number
---@return boolean 是否成功进入
function State:StartBreathing(now)
    if self.breathing.phase ~= Types.BreathingPhase.None then
        return false
    end
    if self.breathing.debt > 0 then
        return self:ResumeBreathingIfNeeded(now)
    end
    self.breathing.phase = Types.BreathingPhase.DrainThreats
    self.breathing.startedAt = now
    self.breathing.remainingSeconds = self.config.Pressure.GuaranteedBreathingSeconds
    return true
end

--- 推进喘息状态机
--- A) 等本 BOSS 已发出的有效危险结束 → B) 完整 2 秒静止窗口 → 结束
---@param now number
---@return table { phase, event } event ∈ {'none','breathingStarted','finished'}
function State:TickBreathing(now)
    local P = self.config.Pressure
    local b = self.breathing
    self:SweepDangers(now) -- 状态推进显式清理，纯查询不关闭伤害
    if b.phase == Types.BreathingPhase.DrainThreats then
        if self:GetActiveDangerCount(now) == 0 then
            b.phase = Types.BreathingPhase.Breathing
            b.startedAt = now
            return { phase = b.phase, event = 'breathingStarted' }
        end
        return { phase = b.phase, event = 'none' }
    elseif b.phase == Types.BreathingPhase.Breathing then
        local elapsed = math.max(0, now - b.startedAt)
        b.remainingSeconds = math.max(0, b.remainingSeconds - elapsed)
        b.startedAt = now
        if self:GetActiveDangerCount(now) > 0 then
            b.phase = Types.BreathingPhase.DrainThreats
            b.remainingSeconds = P.GuaranteedBreathingSeconds
            return { phase = b.phase, event = 'none' }
        end
        if b.remainingSeconds <= 0 then
            b.phase = Types.BreathingPhase.None
            self.actualBreathingEndTime = now
            self.gapCloseAllowedTime = now + P.GapCloseDelayAfterBreathing
            -- 下一压制段从实际喘息结束开始（规格 §7）
            self.burstStartAt = now
            self.burstActive = true
            self.committedCount = 0
            return { phase = b.phase, event = 'finished' }
        end
        return { phase = b.phase, event = 'none' }
    end
    return { phase = Types.BreathingPhase.None, event = 'none' }
end

--- 中止喘息（被硬直 / 转阶段打断）：传入 now 保存真实剩余时长，随后恢复
--- 注意：欠下或正在执行的喘息不得被抹掉；仅死亡 / 确认脱战可清空。
function State:SuspendBreathing(now)
    local b = self.breathing
    if b.phase == Types.BreathingPhase.Breathing then
        if now ~= nil then
            b.remainingSeconds = math.max(0, b.remainingSeconds - math.max(0, now - b.startedAt))
        end
        b.phase = Types.BreathingPhase.None
        b.debt = b.debt + 1 -- 欠下，必须恢复
    elseif b.phase == Types.BreathingPhase.DrainThreats then
        b.phase = Types.BreathingPhase.None
        b.debt = b.debt + 1
    end
end

--- 恢复被中止的喘息（在安全决策点调用）
function State:ResumeBreathingIfNeeded(now)
    local b = self.breathing
    if b.phase == Types.BreathingPhase.None and b.debt > 0 then
        self:SweepDangers(now)
        if self:GetActiveDangerCount(now) > 0 then
            b.phase = Types.BreathingPhase.DrainThreats
            b.remainingSeconds = self.config.Pressure.GuaranteedBreathingSeconds
        else
            b.phase = Types.BreathingPhase.Breathing
        end
        b.startedAt = now
        -- remainingSeconds 已在中止时扣除真实经过时间，不能重新给满两秒。
        b.debt = b.debt - 1
        return true
    end
    return false
end

function State:GetBreathingPhase()
    return self.breathing.phase
end

function State:GetBreathingRemaining()
    return self.breathing.remainingSeconds
end

function State:HasBreathingDebt()
    return self.breathing.debt > 0
end

--- 喘息结束后 GapClose 延迟内禁止 S3（规格 §7）
function State:IsGapCloseBlocked(now)
    return now < self.gapCloseAllowedTime
end

-- =========================================================================
-- 阶段（规格 §11）
-- =========================================================================

function State:GetPhase()
    return self.phase
end

--- 血量首次 <= 50%：仅登记请求，等待安全切换点
function State:RequestPhaseTransition()
    if self.phaseTransitionDone or self.phaseTransitionRequested then
        return false
    end
    self.phaseTransitionRequested = true
    return true
end

function State:IsPhaseTransitionRequested()
    return self.phaseTransitionRequested
end

--- 判定当前是否处于"可切换"的合法点：
--- 没有活动技能、没有待兑现喘息
function State:CanApplyPhaseTransition(now)
    if not self.phaseTransitionRequested or self.phaseTransitionDone then
        return false
    end
    if self.actionLocked then
        return false
    end
    if self.breathing.phase ~= Types.BreathingPhase.None or self.breathing.debt > 0 then
        return false
    end
    if self:GetActiveDangerCount(now) > 0 then
        return false
    end
    return true
end

--- 执行阶段切换（仅一次）
function State:ApplyPhaseTransition()
    if self.phaseTransitionDone then
        return false
    end
    self.phase = 2
    self.phaseTransitionDone = true
    self.phaseTransitionRequested = false
    return true
end

-- =========================================================================
-- 调试快照（规格 §13）
-- =========================================================================

function State:DebugSnapshot(now)
    return {
        phase = self.phase,
        committed = self.committedCount,
        burstElapsed = self.burstActive and (now - self.burstStartAt) or 0,
        lastSkill = self.lastSkillId,
        repeatCount = self.repeatCount,
        breathingPhase = self.breathing.phase,
        breathingRemain = self.breathing.remainingSeconds,
        breathingDebt = self.breathing.debt,
        activeDangers = self:GetActiveDangerCount(now),
        expiredDangers = self.expiredDangerCount,
        dangerCleanupErrors = self.dangerCleanupErrorCount,
        gapCloseBlocked = self:IsGapCloseBlocked(now),
        actionLocked = self.actionLocked,
        actionId = self.activeAction and self.activeAction.id or 0,
        randomSeed = self.random:GetSeed(),
    }
end

return State
