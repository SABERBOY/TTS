--- BOSS AI 决策核心（规格 §6 两级带权随机）
--- 纯逻辑：只依赖 State 的查询接口、Config 与外部上下文 ctx，便于单元测试。
--- 时间基准：ctx.now（外部注入）。
local Types = require('Script.AI.Boss.BossAI_Types')

local Decision = {}

-- =========================================================================
-- 工具
-- =========================================================================

--- 统一选招距离（规格 §4）
--- EdgeDistance = Max(0, HorizontalCenterDistance - BossScaledCapsuleRadius - TargetScaledCapsuleRadius)
function Decision.ComputeEdgeDistance(centerDist, bossRadius, targetRadius)
    local d = (centerDist or 0) - (bossRadius or 0) - (targetRadius or 0)
    if d < 0 then
        d = 0
    end
    return d
end

--- 权重安全化（规格 §6：零权重、负权重、非有限权重）
local function sanitizeWeight(w)
    w = tonumber(w) or 0
    if w ~= w or w == math.huge or w == -math.huge then -- NaN / Inf
        return 0
    end
    if w <= 0 then
        return 0
    end
    return w
end

-- =========================================================================
-- 合法性判定
-- =========================================================================

--- 检查单个技能是否合法
---@param state table BossAI_State
---@param def table 技能定义
---@param ctx table 决策上下文
---@param intentSkillIds table 本意图允许的技能集合（可选）
---@return boolean ok, string|nil reason
function Decision.CheckSkillLegal(state, def, ctx, intentSkillIds)
    local R = Types.RejectReason

    if intentSkillIds ~= nil and not intentSkillIds[def.id] then
        return false, R.IntentEmpty
    end

    if not ctx.targetValid then
        return false, R.NoTarget
    end

    -- 冷却
    if not state:IsSkillReady(def.id, ctx.now) then
        return false, R.Cooldown
    end

    -- 视线（本版七技能开始前均需有效视线）
    if def.requiresLOS and not ctx.hasLOS then
        return false, R.NoLOS
    end

    -- 距离（EdgeDistance）
    local edge = ctx.edgeDistance
    if edge == nil then
        edge = Decision.ComputeEdgeDistance(ctx.centerDistance or 0, ctx.bossRadius, ctx.targetRadius)
    end
    if edge < (def.minDist or 0) - 1e-3 or edge > (def.maxDist or math.huge) + 1e-3 then
        return false, R.OutOfRange
    end

    -- 高度差独立检查
    local heightTol = state.config.Perception.HeightToleranceForSkill or 300
    if ctx.heightDiff ~= nil and math.abs(ctx.heightDiff) > heightTol then
        return false, R.HeightDiff
    end

    -- 路径 / 落点（突进、地面技）
    if def.requiresPath and ctx.pathOk == false then
        return false, R.PathBlocked
    end

    -- 危险区域冲突（安全区校验失败 / 与残留危险重叠）
    if ctx.dangerConflict then
        return false, R.DangerConflict
    end

    -- 喘息后的 GapClose 延迟内禁止 S3（规格 §7）
    if def.id == Types.SkillID.S3 and state:IsGapCloseBlocked(ctx.now) then
        return false, R.GapCloseBlocked
    end

    -- 连续两次相同后第三次直接禁止（即使只剩该技能也不能绕过，规格 §6）
    local rep = state:GetRepeatCountFor(def.id)
    local banAt = state.config.Repeat.BanAfterConsecutiveCount
    if rep >= (banAt - 1) and rep > 0 then
        -- rep == 2 表示已连续 2 次；第三次直接禁止
        if rep + 1 >= banAt then
            return false, R.RepeatBan
        end
    end

    -- 阶段锁定（PhaseLocked 预留：本版七技能不因阶段禁用，仅加权）
    if def.phaseLocked and def.phaseLocked > state:GetPhase() then
        return false, R.PhaseLocked
    end

    -- 运行时几何/安全通道预检可按技能拒绝；预检存在但未给出明确 true 时视为未知。
    -- 未提供预检的纯逻辑调用继续使用上述静态条件。
    if type(ctx.canUseSkill) == 'function' then
        local allowed, reason = ctx.canUseSkill(def.id, def)
        if allowed ~= true then
            return false, reason or R.PathBlocked
        end
    elseif ctx.skillAllowed ~= nil and ctx.skillAllowed[def.id] ~= true then
        local reasons = ctx.skillRejectReasons or {}
        return false, reasons[def.id] or R.PathBlocked
    end

    return true
end

-- =========================================================================
-- 权重计算
-- =========================================================================

--- Weight = BaseWeight × DistanceFactor × PhaseFactor × RepeatFactor
function Decision.ComputeSkillWeight(state, def, ctx)
    local cfg = state.config
    local w = sanitizeWeight(def.baseWeight)

    -- 距离因子（原型：合法即 1.0，拒绝在 CheckSkillLegal 完成）
    local df = cfg.DistanceFactor
    if type(df) == 'function' then
        w = w * sanitizeWeight(df(def, ctx.edgeDistance))
    end

    -- 阶段系数（Phase 2 的 S2/S3/S7 = 1.2）
    local pfTable = cfg.PhaseSkillFactor[state:GetPhase()]
    local pf = 1.0
    if pfTable ~= nil and pfTable[def.id] ~= nil then
        pf = pfTable[def.id]
    end
    w = w * sanitizeWeight(pf)

    -- 重复系数：最近一次已承诺技能再次被选时 RepeatFactor = 0.2
    if state:GetLastSkillId() == def.id then
        w = w * (cfg.Repeat.RepeatFactor or 0.2)
    end

    return sanitizeWeight(w)
end

--- 组内合法技能抽样（按 SkillID 稳定顺序遍历）
---@return number|nil skillId, table debugEntries
function Decision.PickSkillFrom(state, ctx, skillIds)
    local entries = {}
    local debugEntries = {}

    for i = 1, #skillIds do
        local skillId = skillIds[i]
        local def = state.config.SkillById[skillId]
        if def ~= nil then
            local ok, reason = Decision.CheckSkillLegal(state, def, ctx, nil)
            if ok then
                local w = Decision.ComputeSkillWeight(state, def, ctx)
                if w > 0 then
                    entries[#entries + 1] = { value = skillId, weight = w }
                else
                    debugEntries[#debugEntries + 1] = { id = skillId, weight = 0, reason = Types.RejectReason.ZeroWeight }
                end
            else
                debugEntries[#debugEntries + 1] = { id = skillId, weight = 0, reason = reason }
            end
        end
    end

    if #entries == 0 then
        return nil, debugEntries
    end

    local picked = state.random:PickWeighted(entries)
    return picked, debugEntries
end

-- =========================================================================
-- 意图池与主决策（规格 §6）
-- =========================================================================

local PRESSURE_SKILLS   = { Types.SkillID.S1, Types.SkillID.S2, Types.SkillID.S3, Types.SkillID.S4 }
local STATIONARY_SKILLS = { Types.SkillID.S5, Types.SkillID.S6, Types.SkillID.S7 }

local function hasLegalSkill(state, ctx, skillIds)
    for i = 1, #skillIds do
        local def = state.config.SkillById[skillIds[i]]
        if def ~= nil and Decision.CheckSkillLegal(state, def, ctx)
            and Decision.ComputeSkillWeight(state, def, ctx) > 0 then
            return true
        end
    end
    return false
end

-- 最后一个危险可能在 Active 尾端生成，故以该时刻加最大危险寿命为保守上界。
local function skillBudget(state, skillId, now)
    local def = state.config.SkillById[skillId]
    local windup = def.windup or 0
    local active = def.active or 0
    local recovery = def.recovery or 0
    local lastDangerEnd = nil
    if def.maxDangerLife ~= nil then
        lastDangerEnd = now + windup + active + math.max(0, def.maxDangerLife)
    end
    return windup + active + recovery, lastDangerEnd
end

local function movementSeconds(state, ctx)
    local slice = state.config.Pressure.ChaseSliceSeconds or 0.8
    local suggested = tonumber(ctx.candidateSeconds) or 0
    return math.max(slice, suggested)
end

--- 构建意图池（应用归一化规则）
---@return table entries { {value=intent, weight=number} }, table debug
function Decision.BuildIntentPool(state, ctx)
    local cfg = state.config
    local I = Types.Intent
    local phase = state:GetPhase()
    local entries = {}
    local debug = {}

    -- Pressure：有合法 S1-S4 时抽技能；无技能但可合理接近时仍进入本意图（抽中后退化为 Chase，规格 §6）
    if hasLegalSkill(state, ctx, PRESSURE_SKILLS) or ctx.canChase then
        entries[#entries + 1] = { value = I.Pressure, weight = cfg.IntentWeights[I.Pressure][phase] or 0 }
    else
        debug[#debug + 1] = { intent = 'Pressure', reason = 'no-legal-skill-and-no-chase' }
    end

    -- StationaryCast：只有存在合法 S5-S7 时进入意图池
    if hasLegalSkill(state, ctx, STATIONARY_SKILLS) then
        entries[#entries + 1] = { value = I.StationaryCast, weight = cfg.IntentWeights[I.StationaryCast][phase] or 0 }
    else
        debug[#debug + 1] = { intent = 'StationaryCast', reason = Types.RejectReason.StationaryCastEmpty }
    end

    -- Reposition：必须存在可达目标
    if ctx.canReposition then
        entries[#entries + 1] = { value = I.Reposition, weight = cfg.IntentWeights[I.Reposition][phase] or 0 }
    else
        debug[#debug + 1] = { intent = 'Reposition', reason = Types.RejectReason.NoReachableTarget }
    end

    return entries, debug
end

--- 主入口：完成一次规划（对应 BTTask_BossPlanNextAction）
---@param state table
---@param ctx table {
---    now, targetValid, hasLOS, edgeDistance|(centerDistance,bossRadius,targetRadius),
---    heightDiff, pathOk, dangerConflict, canChase, canReposition, candidateSeconds
--- }
---@return table plan { actionKind, skillId, backoff, debug }
function Decision.PlanNextAction(state, ctx)
    local A = Types.ActionKind
    local plan = {
        actionKind = A.None,
        skillId = Types.SkillID.None,
        backoff = state.config.Decision.FailBackoffSeconds,
        debug = { candidates = {}, rejectedEntity = {}, intent = nil },
    }

    -- 0) 死亡、无目标或动作锁时不规划下一动作。
    if ctx.isDead then
        plan.debug.reason = Types.RejectReason.Dead
        return plan
    end
    if not ctx.targetValid then
        plan.debug.reason = Types.RejectReason.NoTarget
        return plan
    end
    if state:IsActionLocked() then
        plan.debug.reason = Types.RejectReason.Busy
        return plan
    end

    -- 第一次有效战斗决策即开启压制段；完整喘息后已有新起点，不会重置。
    state:StartPressure(ctx.now)

    -- 1) 喘息优先（欠下/进行中）
    if state:HasBreathingDebt() or state:GetBreathingPhase() ~= Types.BreathingPhase.None then
        plan.actionKind = A.GiveSpace
        plan.debug.reason = 'breathing'
        return plan
    end

    -- 2) 已欠预算/现存危险越界，先兑现喘息。
    if state:ShouldGiveSpace(ctx.now) then
        plan.actionKind = A.GiveSpace
        plan.debug.reason = 'pressure-budget'
        return plan
    end

    -- 3) 无视线：搜索（不参与普通随机）
    if not ctx.hasLOS then
        plan.actionKind = A.Search
        plan.debug.reason = 'no-los'
        return plan
    end

    -- 4) 按意图权重抽样（一次抽样，不循环重抽）
    local pool, poolDebug = Decision.BuildIntentPool(state, ctx)
    plan.debug.rejectedIntent = poolDebug

    if #pool == 0 then
        -- 空池：有界等待（退避），不反复起手
        plan.actionKind = A.None
        plan.debug.reason = Types.RejectReason.IntentEmpty
        return plan
    end

    local intent = state.random:PickWeighted(pool)
    plan.debug.intent = Types.IntentName[intent] or 'Unknown'

    if intent == Types.Intent.Pressure then
        local skillIds = PRESSURE_SKILLS
        local skillId, dbg = Decision.PickSkillFrom(state, ctx, skillIds)
        plan.debug.candidates = dbg
        if skillId ~= nil then
            local total, lastDangerEnd = skillBudget(state, skillId, ctx.now)
            if state:ShouldGiveSpace(ctx.now, total, lastDangerEnd) then
                plan.actionKind = A.GiveSpace
                plan.debug.reason = 'pressure-budget'
                return plan
            end
            plan.actionKind = A.Skill
            plan.skillId = skillId
            return plan
        end
        -- Pressure 无合法技能：可合理接近时 Chase，否则 Reposition
        if ctx.canChase then
            plan.actionKind = state:ShouldGiveSpace(ctx.now, movementSeconds(state, ctx))
                and A.GiveSpace or A.Chase
            if plan.actionKind == A.GiveSpace then plan.debug.reason = 'pressure-budget' end
            return plan
        end
        if ctx.canReposition then
            plan.actionKind = state:ShouldGiveSpace(ctx.now, movementSeconds(state, ctx))
                and A.GiveSpace or A.Reposition
            if plan.actionKind == A.GiveSpace then plan.debug.reason = 'pressure-budget' end
            return plan
        end
        plan.actionKind = A.None
        plan.debug.reason = Types.RejectReason.NoReachableTarget
        return plan

    elseif intent == Types.Intent.StationaryCast then
        local skillId, dbg = Decision.PickSkillFrom(state, ctx, STATIONARY_SKILLS)
        plan.debug.candidates = dbg
        if skillId ~= nil then
            local total, lastDangerEnd = skillBudget(state, skillId, ctx.now)
            if state:ShouldGiveSpace(ctx.now, total, lastDangerEnd) then
                plan.actionKind = A.GiveSpace
                plan.debug.reason = 'pressure-budget'
                return plan
            end
            plan.actionKind = A.Skill
            plan.skillId = skillId
            return plan
        end
        -- 理论上不会发生（池构建时已验证）；安全兜底
        plan.actionKind = A.None
        plan.debug.reason = Types.RejectReason.StationaryCastEmpty
        return plan

    elseif intent == Types.Intent.Reposition then
        plan.actionKind = state:ShouldGiveSpace(ctx.now, movementSeconds(state, ctx))
            and A.GiveSpace or A.Reposition
        if plan.actionKind == A.GiveSpace then plan.debug.reason = 'pressure-budget' end
        return plan
    end

    plan.debug.reason = Types.RejectReason.IntentEmpty
    return plan
end

return Decision
