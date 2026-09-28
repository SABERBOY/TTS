--- BOSS AI 纯逻辑自测（规格 §14：用例 4 / 5 / 6 / 7 / 8 / 9 / 11 / 12）
--- 不依赖引擎对象：假时钟 + 固定种子；可在 PIE 的 Lua console 或 DS 执行。
--- 用法：
---   local Tests = UGCGameSystem.UGCRequire('Script.AI.Boss.BossAI_Tests')
---   local r = Tests.RunAll()
local Types    = require('Script.AI.Boss.BossAI_Types')
local Config   = require('Script.AI.Boss.BossAI_Config')
local State    = require('Script.AI.Boss.BossAI_State')
local Decision = require('Script.AI.Boss.BossAI_Decision')

local Tests = {}

local results = {}
local function check(name, cond, detail)
    results[#results + 1] = { name = name, pass = cond and true or false, detail = detail }
    -- 即时打印：不依赖汇总表，便于在热重载等场景下直接观察结果
    print(string.format('[BossAI-Test] %-42s %s %s', name, (cond and true or false) and 'PASS' or 'FAIL', detail or ''))
    return cond
end

--- 构造一个"一切合法"的决策上下文
local function MakeCtx(overrides)
    local ctx = {
        now = 10.0,
        targetValid = true,
        hasLOS = true,
        edgeDistance = 200,      -- 默认落在 S1 范围内
        heightDiff = 0,
        pathOk = true,
        dangerConflict = false,
        canChase = true,
        canReposition = true,
        isDead = false,
    }
    for k, v in pairs(overrides or {}) do
        ctx[k] = v
    end
    return ctx
end

local function NewState(seed)
    return State.New(Config, seed or 20260922)
end

-- =========================================================================
-- 用例 4：相同快照与随机种子可复现，候选遍历稳定
-- =========================================================================
function Tests.Case4_Determinism()
    local function Run(seed)
        local st = NewState(seed)
        local out = {}
        for i = 1, 30 do
            local ctx = MakeCtx({ now = 10.0 + i * 0.5 })
            -- 交替推进（承诺 → 结束），模拟连续决策
            local plan = Decision.PlanNextAction(st, ctx)
            out[#out + 1] = tostring(plan.actionKind) .. ':' .. tostring(plan.skillId)
            if plan.actionKind == Types.ActionKind.Skill then
                st:CommitSkill(plan.skillId, ctx.now)
                st:EndAction(nil)
            end
        end
        return table.concat(out, ',')
    end

    local a = Run(777)
    local b = Run(777)
    check('Case4 相同种子可复现', a == b, a == b and '' or ('a=' .. a .. ' b=' .. b))
    -- 说明：不同种子不保证序列不同（大量决策由冷却/距离门控主导，随机性被掩盖）；
    -- 随机分布的正确性由 Case6（10000 次抽样）独立验证。
    -- 候选遍历稳定：无随机参与时，两次构建的候选顺序一致
    local st = NewState(1)
    local ctx = MakeCtx({ now = 1.0 })
    local _, d1 = Decision.PickSkillFrom(st, ctx, { 1, 2, 3, 4 })
    local _, d2 = Decision.PickSkillFrom(st, ctx, { 1, 2, 3, 4 })
    local ok = #d1 == #d2
    for i = 1, #d1 do
        ok = ok and (d1[i].id == d2[i].id and d1[i].reason == d2[i].reason)
    end
    check('Case4 候选遍历顺序稳定', ok, '')
end

-- =========================================================================
-- 用例 5：冷却 / 距离 / 视线不合法则不进入随机池
-- =========================================================================
function Tests.Case5_LegalityFiltering()
    local st = NewState(5)

    -- 无视线：除 S7（0-1100 仍要求 LOS）外全部 NoLOS
    local ctx = MakeCtx({ now = 1.0, hasLOS = false, edgeDistance = 200 })
    local picked, dbg = Decision.PickSkillFrom(st, ctx, { 1, 2, 3, 4 })
    check('Case5 无视线时 S1-S4 全部拒绝', picked == nil, '')
    local allNoLOS = #dbg == 4
    for i = 1, #dbg do
        allNoLOS = allNoLOS and (dbg[i].reason == Types.RejectReason.NoLOS)
    end
    check('Case5 拒绝原因为 NoLOS', allNoLOS, '')

    -- 超距：edge=2000 时 S1 超上限（320）
    ctx = MakeCtx({ now = 1.0, edgeDistance = 2000 })
    local ok1 = Decision.CheckSkillLegal(st, Config.SkillById[1], ctx)
    check('Case5 超距拒绝 S1', ok1 == false, '')
    -- 近距：edge=100 时 S3 低于下限（550）
    ctx = MakeCtx({ now = 1.0, edgeDistance = 100 })
    local ok3 = Decision.CheckSkillLegal(st, Config.SkillById[3], ctx)
    check('Case5 过近拒绝 S3', ok3 == false, '')

    -- 冷却：承诺 S1 后立即再查
    local st2 = NewState(5)
    st2:CommitSkill(Types.SkillID.S1, 100.0)
    local ctxCd = MakeCtx({ now = 100.5, edgeDistance = 200 })
    local okCd, reasonCd = Decision.CheckSkillLegal(st2, Config.SkillById[1], ctxCd)
    check('Case5 冷却中拒绝', okCd == false and reasonCd == Types.RejectReason.Cooldown, tostring(reasonCd))
    local ctxReady = MakeCtx({ now = 104.0, edgeDistance = 200 })
    check('Case5 冷却结束放行', Decision.CheckSkillLegal(st2, Config.SkillById[1], ctxReady) == true, '')
end

-- =========================================================================
-- 用例 6：固定权重 20 / 30 独立抽样 10000 次 ≈ 40% / 60%（±2 个百分点）
-- =========================================================================
function Tests.Case6_WeightedDistribution()
    local st = NewState(31337)
    local N = 10000
    local countA = 0
    local entries = { { value = 'A', weight = 20 }, { value = 'B', weight = 30 } }
    for _i = 1, N do
        local v = st.random:PickWeighted(entries)
        if v == 'A' then
            countA = countA + 1
        end
    end
    local ratioA = countA / N
    local ratioB = 1 - ratioA
    check('Case6 A≈40% (±2pp)', math.abs(ratioA - 0.40) <= 0.02, string.format('A=%.4f', ratioA))
    check('Case6 B≈60% (±2pp)', math.abs(ratioB - 0.60) <= 0.02, string.format('B=%.4f', ratioB))
end

-- =========================================================================
-- 用例 7：同技能不能连续三次；即使只剩该技能也采用非攻击回退
-- =========================================================================
function Tests.Case7_RepeatBan()
    local st = NewState(7)
    local now = 50.0
    -- 连续承诺两次 S1
    st:CommitSkill(Types.SkillID.S1, now)
    st:EndAction(nil)
    st:CommitSkill(Types.SkillID.S1, now + 5.0)
    st:EndAction(nil)
    check('Case7 连续计数=2', st:GetRepeatCountFor(Types.SkillID.S1) == 2, tostring(st:GetRepeatCountFor(Types.SkillID.S1)))

    -- 开启新压制窗口，只清除预算计数，保留连续选招历史。
    -- 否则两个承诺已耗去 10 秒，Plan 会优先返回 pressure-budget，
    -- 无法证明第三次是被 RepeatBan 拒绝。
    local ctx = MakeCtx({ now = now + 10.0, edgeDistance = 200, canReposition = false })
    st:SetBurstStartAt(ctx.now)
    check('Case7 新压制窗口保留连续历史', st:GetRepeatCountFor(Types.SkillID.S1) == 2,
        tostring(st:GetRepeatCountFor(Types.SkillID.S1)))
    check('Case7 S1 冷却已结束', st:IsSkillReady(Types.SkillID.S1, ctx.now),
        'readyAt=' .. tostring(st.cooldowns[Types.SkillID.S1]))

    -- 第三次：即使 S1 冷却已好、距离/视线合法，也应被禁止
    local ok, reason = Decision.CheckSkillLegal(st, Config.SkillById[1], ctx)
    check('Case7 第三次 S1 被禁止', ok == false and reason == Types.RejectReason.RepeatBan, tostring(reason))

    -- 只剩 S1 可用的场景：把其他技能全部置于冷却
    for id = 2, 7 do
        st.cooldowns[id] = ctx.now + 999
    end
    check('Case7 规划前压制预算未阻断',
        not st:ShouldGiveSpace(ctx.now, Config.Pressure.ChaseSliceSeconds),
        'committed=' .. tostring(st:GetCommittedCount()) .. ' burstStart=' .. tostring(st:GetBurstStartAt()))
    local plan = Decision.PlanNextAction(st, ctx)
    local s1RejectedByRepeatBan = false
    for _, entry in ipairs(plan.debug.candidates or {}) do
        if entry.id == Types.SkillID.S1 and entry.reason == Types.RejectReason.RepeatBan then
            s1RejectedByRepeatBan = true
        end
    end
    check('Case7 只剩 S1 时由 RepeatBan 回退 Chase',
        plan.actionKind == Types.ActionKind.Chase and s1RejectedByRepeatBan,
        'kind=' .. tostring(plan.actionKind) .. ' S1RepeatBan=' .. tostring(s1RejectedByRepeatBan)
            .. ' reason=' .. tostring(plan.debug.reason))
end

-- =========================================================================
-- 用例 8：站桩候选为空时移除意图并归一化，不死循环
-- =========================================================================
function Tests.Case8_StationaryIntentRemoval()
    local st = NewState(8)
    -- 把 S5-S7 全部置于冷却，构造确定的"站桩候选为空"场景
    for id = 5, 7 do
        st.cooldowns[id] = 9999
    end
    local ctx = MakeCtx({ now = 1.0, edgeDistance = 800 })
    local pool, dbg = Decision.BuildIntentPool(st, ctx)
    local hasStationary = false
    for i = 1, #pool do
        if pool[i].value == Types.Intent.StationaryCast then
            hasStationary = true
        end
    end
    check('Case8 站桩意图被移除', hasStationary == false, '')
    check('Case8 池非空（压力/站位保留）', #pool > 0, 'poolSize=' .. tostring(#pool))

    -- 单次调用即返回，不循环重抽
    local plan = Decision.PlanNextAction(st, ctx)
    check('Case8 单次规划返回', plan ~= nil and plan.actionKind ~= nil, 'kind=' .. tostring(plan.actionKind))
end

-- =========================================================================
-- 用例 9：三次承诺后 GiveSpace；追击片段不重置预算
-- =========================================================================
function Tests.Case9_PressureBudgetAndGiveSpace()
    local st = NewState(9)
    local now = 100.0
    for i = 1, 3 do
        st:CommitSkill(i, now + i * 0.1)
        st:EndAction(nil)
    end
    check('Case9 承诺计数=3', st:GetCommittedCount() == 3, '')
    check('Case9 触发 GiveSpace', st:ShouldGiveSpace(now + 1.0, 1.0) == true, '')

    local plan = Decision.PlanNextAction(st, MakeCtx({ now = now + 2.0 }))
    check('Case9 计划为 GiveSpace', plan.actionKind == Types.ActionKind.GiveSpace, 'kind=' .. tostring(plan.actionKind))

    -- 追击片段（Chase 决策）不重置预算：模拟一次 Chase 后预算快照不变
    local st2 = NewState(9)
    st2:CommitSkill(Types.SkillID.S1, 10.0)
    st2:EndAction(nil)
    local burstBefore = st2:GetBurstStartAt()
    local committedBefore = st2:GetCommittedCount()
    -- 让 Pressure 无合法技能、可 Chase
    for id = 1, 4 do
        st2.cooldowns[id] = 999
    end
    -- canReposition=false + 站桩超距 → 意图池只剩 Pressure（无合法技能 → 必然降级 Chase）
    local ctx = MakeCtx({ now = 12.0, edgeDistance = 3000, canReposition = false })
    local plan2 = Decision.PlanNextAction(st2, ctx)
    check('Case9 Chase 计划', plan2.actionKind == Types.ActionKind.Chase, 'kind=' .. tostring(plan2.actionKind))
    check('Case9 追击不重置预算', st2:GetBurstStartAt() == burstBefore and st2:GetCommittedCount() == committedBefore, '')
end

-- =========================================================================
-- 用例 11：喘息结束后 0.8 秒内拒绝 S3
-- =========================================================================
function Tests.Case11_GapCloseDelay()
    local st = NewState(11)
    local now = 200.0
    -- 无危险 → 直接进入 B 阶段
    st:StartBreathing(now)
    local tick1 = st:TickBreathing(now)
    check('Case11 进入完整喘息', tick1.event == 'breathingStarted', tick1.event)
    -- 满 2 秒
    local endTime = now + Config.Pressure.GuaranteedBreathingSeconds
    local tick2 = st:TickBreathing(endTime + 0.001)
    check('Case11 喘息结束', tick2.event == 'finished', tick2.event)

    -- 结束后 0.4 秒：S3 被拒绝
    local ctx = MakeCtx({ now = endTime + 0.4, edgeDistance = 800 })
    local ok, reason = Decision.CheckSkillLegal(st, Config.SkillById[3], ctx)
    check('Case11 GapClose 期内拒绝 S3', ok == false and reason == Types.RejectReason.GapCloseBlocked, tostring(reason))

    -- 结束后 0.9 秒：放行
    local ctx2 = MakeCtx({ now = endTime + 0.9, edgeDistance = 800 })
    check('Case11 GapClose 结束后放行 S3', Decision.CheckSkillLegal(st, Config.SkillById[3], ctx2) == true, '')

    -- 其他技能不受 GapClose 限制
    local ctx3 = MakeCtx({ now = endTime + 0.4, edgeDistance = 200 })
    check('Case11 GapClose 不影响 S1', Decision.CheckSkillLegal(st, Config.SkillById[1], ctx3) == true, '')
end

-- =========================================================================
-- 用例 12：下一动作超预算时提前喘息，不切断已承诺动画
-- =========================================================================
function Tests.Case12_PredictBudget()
    local st = NewState(12)
    local now = 300.0
    -- 已用掉 7.5 秒、承诺 2 次；候选动作总时长 2.0 秒 → 预测 9.5 > 8.0
    st:SetBurstStartAt(now - 7.5)
    st:CommitSkill(Types.SkillID.S1, now - 7.4)
    st:EndAction(nil)
    st:CommitSkill(Types.SkillID.S4, now - 3.0)
    st:EndAction(nil)
    check('Case12 预测超预算 → GiveSpace', st:ShouldGiveSpace(now, 2.0) == true, '')
    check('Case12 预测未超预算 → 不触发', st:ShouldGiveSpace(now, 0.3) == false, '')

    -- 已承诺动作不被切断：GiveSpace 仅作为决策输出，activeAction 保持不变
    local st2 = NewState(12)
    local id = st2:CommitSkill(Types.SkillID.S2, 500.0) -- 进入前摇
    local plan = Decision.PlanNextAction(st2, MakeCtx({ now = 500.1 }))
    check('Case12 决策不修改已承诺动作', st2.activeAction ~= nil and st2.activeAction.id == id,
        'plan=' .. tostring(plan.actionKind))
end

-- 追击开始即计入压制段，第一招不能把已花费的追击时间抹掉。
function Tests.Case13_ChaseStartsPressureClock()
    local st = NewState(13)
    local chaseCtx = MakeCtx({ now = 100.0, edgeDistance = 3000, canReposition = false })
    local chase = Decision.PlanNextAction(st, chaseCtx)
    check('Case13 首次追击开启压制计时',
        chase.actionKind == Types.ActionKind.Chase and st:GetBurstStartAt() == 100.0,
        'kind=' .. tostring(chase.actionKind) .. ' start=' .. tostring(st:GetBurstStartAt()))

    local id = st:CommitSkill(Types.SkillID.S1, 101.0)
    st:EndAction(id)
    check('Case13 第一招不重置追击时间', st:GetBurstStartAt() == 100.0,
        'start=' .. tostring(st:GetBurstStartAt()))

    local late = Decision.PlanNextAction(st, MakeCtx({ now = 107.3, edgeDistance = 3000, canReposition = false }))
    check('Case13 追击片段超时先喘息', late.actionKind == Types.ActionKind.GiveSpace,
        'kind=' .. tostring(late.actionKind))
end

-- 候选技能必须按自身后摇和危险寿命预先预算，不能借通用时长或移动回退绕过。
function Tests.Case14_SelectedSkillBudget()
    local st = NewState(14)
    st:SetBurstStartAt(300.0)
    for _, id in ipairs({ 1, 2, 3, 5, 6, 7 }) do
        st.cooldowns[id] = 999.0
    end
    -- S4 总动作 1.9 秒，计划于 305.4 时结束为 307.3（预算内）；
    -- 末次危险上界 0.7+0.6+2.0=3.3 秒，失效于 308.7（预算外）。
    local ctx = MakeCtx({ now = 305.4, edgeDistance = 1200, canChase = false, canReposition = false,
        candidateSeconds = 0.1 })
    local plan = Decision.PlanNextAction(st, ctx)
    check('Case14 S4 危险超过预算先喘息', plan.actionKind == Types.ActionKind.GiveSpace,
        'kind=' .. tostring(plan.actionKind) .. ' skill=' .. tostring(plan.skillId))
    check('Case14 预算拒绝不承诺技能', st:GetCommittedCount() == 0, tostring(st:GetCommittedCount()))

    -- 禁用此测试配置的危险尾巴，单独证明完整 Recovery 仍纳入预算。
    local testConfig = {}
    for k, v in pairs(Config) do testConfig[k] = v end
    testConfig.SkillById = {}
    for k, v in pairs(Config.SkillById) do testConfig.SkillById[k] = v end
    local s1 = {}
    for k, v in pairs(Config.SkillById[Types.SkillID.S1]) do s1[k] = v end
    s1.maxDangerLife = 0
    testConfig.SkillById[Types.SkillID.S1] = s1
    local recoveryState = State.New(testConfig, 143)
    recoveryState:SetBurstStartAt(400.0)
    recoveryState.cooldowns[Types.SkillID.S2] = 999.0
    recoveryState.cooldowns[Types.SkillID.S7] = 999.0
    local recoveryPlan = Decision.PlanNextAction(recoveryState,
        MakeCtx({ now = 406.0, edgeDistance = 200, canChase = false, canReposition = false }))
    check('Case14 S1 完整后摇越过预算先喘息', recoveryPlan.actionKind == Types.ActionKind.GiveSpace,
        'kind=' .. tostring(recoveryPlan.actionKind))

    -- 已登记危险即使选下一段短动作，也必须计入最晚失效时刻。
    local st2 = NewState(141)
    st2:SetBurstStartAt(500.0)
    local actionId = st2:CommitSkill(Types.SkillID.S1, 506.0)
    st2:RegisterDanger(Types.SkillID.S1, actionId, 508.5)
    st2:EndAction(actionId)
    local withDanger = Decision.PlanNextAction(st2,
        MakeCtx({ now = 507.2, edgeDistance = 3000, canReposition = false, candidateSeconds = 0.1 }))
    check('Case14 现存危险越过预算先喘息', withDanger.actionKind == Types.ActionKind.GiveSpace,
        'kind=' .. tostring(withDanger.actionKind))

    local st3 = NewState(142)
    st3:SetBurstStartAt(600.0)
    for id = 1, 7 do st3.cooldowns[id] = 999.0 end
    local reposition = Decision.PlanNextAction(st3,
        MakeCtx({ now = 607.3, edgeDistance = 3000, canChase = false, canReposition = true,
            candidateSeconds = 0.1 }))
    check('Case14 Reposition 不绕过片段预算', reposition.actionKind == Types.ActionKind.GiveSpace,
        'kind=' .. tostring(reposition.actionKind))
end

-- 中止时按真实时钟扣掉已喘息时间，危险未消失时先回排空阶段。
function Tests.Case15_BreathingResume()
    local st = NewState(15)
    st:StartBreathing(100.0)
    st:TickBreathing(100.0)
    st:SuspendBreathing(100.75)
    check('Case15 中止保留真实剩余 1.25 秒', math.abs(st:GetBreathingRemaining() - 1.25) < 1e-6,
        'remaining=' .. tostring(st:GetBreathingRemaining()))
    st:ResumeBreathingIfNeeded(101.0)
    local before = st:TickBreathing(102.24)
    local after = st:TickBreathing(102.26)
    check('Case15 恢复后仅补足剩余时长', before.event ~= 'finished' and after.event == 'finished',
        'before=' .. tostring(before.event) .. ' after=' .. tostring(after.event))

    local st2 = NewState(151)
    local actionId = st2:CommitSkill(Types.SkillID.S4, 200.0)
    st2:RegisterDanger(Types.SkillID.S4, actionId, 202.0)
    st2:EndAction(actionId)
    st2:StartBreathing(200.0)
    st2:TickBreathing(200.0)
    st2:SuspendBreathing(200.5)
    st2:ResumeBreathingIfNeeded(200.6)
    check('Case15 危险尚在则恢复 DrainThreats',
        st2:GetBreathingPhase() == Types.BreathingPhase.DrainThreats,
        'phase=' .. tostring(st2:GetBreathingPhase()))
    local drained = st2:TickBreathing(202.01)
    check('Case15 危险超时后开始完整窗口',
        drained.event == 'breathingStarted' and math.abs(st2:GetBreathingRemaining() - 2.0) < 1e-6,
        'event=' .. tostring(drained.event))

    local st3 = NewState(152)
    st3:StartBreathing(300.0)
    st3:TickBreathing(300.0)
    st3:SuspendBreathing(300.5)
    st3:Reset(301.0, { clearBreathingDebt = false })
    check('Case15 非脱战重置保留喘息债务', st3:HasBreathingDebt()
        and math.abs(st3:GetBreathingRemaining() - 1.5) < 1e-6,
        'debt=' .. tostring(st3:HasBreathingDebt()) .. ' remain=' .. tostring(st3:GetBreathingRemaining()))
end

-- 超时危险清理伤害；跨 Reset 的旧回调不得结束新动作或注销新危险。
function Tests.Case16_StaleCallbacksAndDangerTimeout()
    local st = NewState(16)
    local disabled = 0
    local oldAction = st:CommitSkill(Types.SkillID.S4, 100.0)
    local oldDanger = st:RegisterDanger(Types.SkillID.S4, oldAction, 100.5,
        function() disabled = disabled + 1 end)
    local oldDangerRecord = st.dangers[oldDanger]
    st:EndAction(oldAction)
    st:StartBreathing(100.0)
    st:TickBreathing(100.0)
    local drained = st:TickBreathing(100.51)
    check('Case16 超时危险禁用并记录', drained.event == 'breathingStarted'
        and disabled == 1 and st.expiredDangerCount == 1 and st.dangers[oldDanger] == nil
        and oldDangerRecord.active == false,
        'disabled=' .. tostring(disabled) .. ' expired=' .. tostring(st.expiredDangerCount))

    st:Reset(200.0)
    local newAction = st:CommitSkill(Types.SkillID.S1, 201.0)
    local newDanger = st:RegisterDanger(Types.SkillID.S1, newAction, 202.0)
    st:EndAction(oldAction)
    st:UnregisterDanger(oldDanger)
    check('Case16 旧回调不影响重置后新动作', newAction ~= oldAction and st:GetActiveAction().id == newAction,
        'old=' .. tostring(oldAction) .. ' new=' .. tostring(newAction))
    check('Case16 旧危险 ID 不注销新危险', newDanger ~= oldDanger and st.dangers[newDanger] ~= nil,
        'old=' .. tostring(oldDanger) .. ' new=' .. tostring(newDanger))

    -- 外部传错的超远绝对时刻不能把 DrainThreats 拖成无限期。
    local capped = st:RegisterDanger(Types.SkillID.S1, newAction, 999999.0)
    check('Case16 危险截止受技能最大寿命约束', capped ~= nil
        and math.abs(st.dangers[capped].expireAt - 204.05) < 1e-6,
        'expire=' .. tostring(capped and st.dangers[capped].expireAt))

    local cleanupState = NewState(161)
    local resetDisabled = 0
    local resetAction = cleanupState:CommitSkill(Types.SkillID.S4, 50.0)
    cleanupState:RegisterDanger(Types.SkillID.S4, resetAction, 52.0,
        function() resetDisabled = resetDisabled + 1 end)
    cleanupState:Reset(50.1)
    check('Case16 重置禁用本实例残留危险', resetDisabled == 1
        and cleanupState:GetActiveDangerCount(50.1) == 0,
        'disabled=' .. tostring(resetDisabled))
    local stale = cleanupState:RegisterDanger(Types.SkillID.S4, resetAction, 52.0)
    check('Case16 重置后拒绝旧动作登记危险', stale == nil,
        'dangerId=' .. tostring(stale))
end

function Tests.Case17_NoTargetDoesNotStartPressure()
    local st = NewState(17)
    local plan = Decision.PlanNextAction(st, MakeCtx({ now = 100.0, targetValid = false, hasLOS = false }))
    check('Case17 无目标保持空计划', plan.actionKind == Types.ActionKind.None,
        'kind=' .. tostring(plan.actionKind))
    local nextPlan = Decision.PlanNextAction(st, MakeCtx({ now = 101.0, edgeDistance = 3000,
        canReposition = false }))
    check('Case17 获得目标时才开启压制计时',
        nextPlan.actionKind == Types.ActionKind.Chase and st:GetBurstStartAt() == 101.0,
        'kind=' .. tostring(nextPlan.actionKind) .. ' start=' .. tostring(st:GetBurstStartAt()))
end

function Tests.Case18_PerSkillSafetyPreflight()
    local st = NewState(18)
    for _, id in ipairs({ 1, 2, 4, 5, 6, 7 }) do st.cooldowns[id] = 999.0 end
    local ctx = MakeCtx({ now = 100.0, edgeDistance = 800, canChase = false, canReposition = false,
        canUseSkill = function(skillId)
            if skillId == Types.SkillID.S3 then return nil, Types.RejectReason.PathBlocked end
            return true
        end })
    local skillOk, reason = Decision.CheckSkillLegal(st, Config.SkillById[3], ctx)
    check('Case18 未知安全通道拒绝 S3', skillOk == false and reason == Types.RejectReason.PathBlocked,
        'ok=' .. tostring(skillOk) .. ' reason=' .. tostring(reason))
    local pool = Decision.BuildIntentPool(st, ctx)
    local plan = Decision.PlanNextAction(st, ctx)
    check('Case18 被预检拒绝的技能不入意图池', #pool == 0
        and plan.actionKind == Types.ActionKind.None,
        'pool=' .. tostring(#pool) .. ' kind=' .. tostring(plan.actionKind))

    local dangerCtx = MakeCtx({ now = 100.0, edgeDistance = 800,
        canUseSkill = function(skillId)
            if skillId == Types.SkillID.S6 then return false, Types.RejectReason.DangerConflict end
            return true
        end })
    local s6ok, s6reason = Decision.CheckSkillLegal(NewState(181), Config.SkillById[6], dangerCtx)
    check('Case18 安全区失败保留逐技能拒绝原因', s6ok == false
        and s6reason == Types.RejectReason.DangerConflict,
        'reason=' .. tostring(s6reason))

    local mapCtx = MakeCtx({ now = 100.0, edgeDistance = 800,
        skillAllowed = { [Types.SkillID.S3] = false },
        skillRejectReasons = { [Types.SkillID.S3] = Types.RejectReason.PathBlocked } })
    local mapOk, mapReason = Decision.CheckSkillLegal(NewState(182), Config.SkillById[3], mapCtx)
    local unknownOk = Decision.CheckSkillLegal(NewState(183), Config.SkillById[4], mapCtx)
    check('Case18 预检表拒绝失败与未知项', mapOk == false
        and mapReason == Types.RejectReason.PathBlocked and unknownOk == false,
        'S3=' .. tostring(mapReason) .. ' S4=' .. tostring(unknownOk))
end

function Tests.Case19_DangerQueryIsReadOnly()
    local st = NewState(19)
    local disabled = 0
    local actionId = st:CommitSkill(Types.SkillID.S4, 100.0)
    local dangerId = st:RegisterDanger(Types.SkillID.S4, actionId, 100.5,
        function() disabled = disabled + 1 end)
    st:EndAction(actionId)
    local count = st:GetActiveDangerCount(100.6)
    local deadline = st:GetActiveDangerDeadline(100.6)
    st:DebugSnapshot(100.6)
    check('Case19 危险查询不触发伤害关闭', count == 0 and deadline == nil
        and disabled == 0 and st.dangers[dangerId] ~= nil,
        'disabled=' .. tostring(disabled))
    local swept = st:SweepDangers(100.6)
    check('Case19 显式 Sweep 关闭并记录超时', swept == 1
        and disabled == 1 and st.expiredDangerCount == 1,
        'swept=' .. tostring(swept) .. ' disabled=' .. tostring(disabled))
end

function Tests.Case20_DangerDuringBreathingRestartsWindow()
    local st = NewState(20)
    st:StartBreathing(100.0)
    st:TickBreathing(100.0)
    -- 模拟已进入窗口后才到达的延迟危险登记；此后必须重新给完整 2 秒。
    local actionId = st:CommitSkill(Types.SkillID.S4, 100.5)
    st:RegisterDanger(Types.SkillID.S4, actionId, 101.5)
    st:EndAction(actionId)
    local interrupted = st:TickBreathing(100.75)
    check('Case20 喘息中出现有效危险回 DrainThreats',
        interrupted.phase == Types.BreathingPhase.DrainThreats
        and math.abs(st:GetBreathingRemaining() - 2.0) < 1e-6,
        'phase=' .. tostring(interrupted.phase) .. ' remain=' .. tostring(st:GetBreathingRemaining()))
    local resumed = st:TickBreathing(101.51)
    local before = st:TickBreathing(103.50)
    local after = st:TickBreathing(103.52)
    check('Case20 危险结束后重新完整喘息 2 秒', resumed.event == 'breathingStarted'
        and before.event ~= 'finished' and after.event == 'finished',
        'resumed=' .. tostring(resumed.event) .. ' before=' .. tostring(before.event)
            .. ' after=' .. tostring(after.event))
end

function Tests.Case21_DangerCleanupFailureBlocksBreathing()
    local st = NewState(21)
    local disableFails = true
    local actionId = st:CommitSkill(Types.SkillID.S4, 100.0)
    local dangerId = st:RegisterDanger(Types.SkillID.S4, actionId, 100.5,
        function()
            if disableFails then error('damage disable failed') end
        end)
    st:EndAction(actionId)
    st:StartBreathing(100.0)
    st:TickBreathing(100.0)
    local failedTick = st:TickBreathing(100.51)
    check('Case21 清理失败时保持 DrainThreats',
        failedTick.phase == Types.BreathingPhase.DrainThreats
        and st:GetActiveDangerCount(100.51) == 1 and st.dangers[dangerId] ~= nil
        and st.dangers[dangerId].active == true and st.dangerCleanupErrorCount == 1,
        'phase=' .. tostring(failedTick.phase) .. ' errors=' .. tostring(st.dangerCleanupErrorCount))
    check('Case21 清理失败阻止新攻击',
        Decision.PlanNextAction(st, MakeCtx({ now = 100.6 })).actionKind == Types.ActionKind.GiveSpace,
        '')

    disableFails = false
    local recoveredTick = st:TickBreathing(100.7)
    check('Case21 重试成功后才开始完整喘息', recoveredTick.event == 'breathingStarted'
        and st:GetActiveDangerCount(100.7) == 0 and st.dangers[dangerId] == nil
        and math.abs(st:GetBreathingRemaining() - 2.0) < 1e-6,
        'event=' .. tostring(recoveredTick.event))

    local resetState = NewState(211)
    local resetAction = resetState:CommitSkill(Types.SkillID.S4, 200.0)
    local resetDanger = resetState:RegisterDanger(Types.SkillID.S4, resetAction, 201.0,
        function() error('reset disable failed') end)
    resetState:Reset(200.1)
    check('Case21 Reset 清理失败仍保留危险', resetState.dangers[resetDanger] ~= nil
        and resetState:GetActiveDangerCount(200.1) == 1,
        'active=' .. tostring(resetState:GetActiveDangerCount(200.1)))
    local resetPlan = Decision.PlanNextAction(resetState, MakeCtx({ now = 200.2 }))
    check('Case21 Reset 失败后禁止继续攻击', resetPlan.actionKind == Types.ActionKind.GiveSpace,
        'kind=' .. tostring(resetPlan.actionKind))
    local blockedAction = resetState:CommitSkill(Types.SkillID.S1, 200.3)
    check('Case21 清理失败直接承诺技能也被拒绝', blockedAction == nil
        and resetState:GetCommittedCount() == 0,
        'actionId=' .. tostring(blockedAction))
end

-- =========================================================================
-- 运行全部
-- =========================================================================
function Tests.RunAll()
    results = {}
    -- 逐个追加：即使某个用例为 nil 也不会导致数组断裂（Lua # 对含 nil 的表不可靠）
    local cases = {}
    cases[#cases + 1] = Tests.Case4_Determinism
    cases[#cases + 1] = Tests.Case5_LegalityFiltering
    cases[#cases + 1] = Tests.Case6_WeightedDistribution
    cases[#cases + 1] = Tests.Case7_RepeatBan
    cases[#cases + 1] = Tests.Case8_StationaryIntentRemoval
    cases[#cases + 1] = Tests.Case9_PressureBudgetAndGiveSpace
    cases[#cases + 1] = Tests.Case11_GapCloseDelay
    cases[#cases + 1] = Tests.Case12_PredictBudget
    cases[#cases + 1] = Tests.Case13_ChaseStartsPressureClock
    cases[#cases + 1] = Tests.Case14_SelectedSkillBudget
    cases[#cases + 1] = Tests.Case15_BreathingResume
    cases[#cases + 1] = Tests.Case16_StaleCallbacksAndDangerTimeout
    cases[#cases + 1] = Tests.Case17_NoTargetDoesNotStartPressure
    cases[#cases + 1] = Tests.Case18_PerSkillSafetyPreflight
    cases[#cases + 1] = Tests.Case19_DangerQueryIsReadOnly
    cases[#cases + 1] = Tests.Case20_DangerDuringBreathingRestartsWindow
    cases[#cases + 1] = Tests.Case21_DangerCleanupFailureBlocksBreathing
    print('[BossAI-Test] cases count = ' .. tostring(#cases))

    for i = 1, #cases do
        if cases[i] == nil then
            results[#results + 1] = { name = 'Case#' .. i, pass = false, detail = 'MISSING (function is nil)' }
        else
            local ok, err = pcall(cases[i])
            if not ok then
                results[#results + 1] = { name = 'Case#' .. i .. '(exception)', pass = false, detail = tostring(err) }
            end
        end
    end

    local passed, failed = 0, 0
    for i = 1, #results do
        local r = results[i]
        if r.pass then
            passed = passed + 1
        else
            failed = failed + 1
        end
        print(string.format('[BossAI-Test] %-42s %s %s', r.name, r.pass and 'PASS' or 'FAIL', r.detail or ''))
    end
    print(string.format('[BossAI-Test] ===== TOTAL %d, PASS %d, FAIL %d =====', #results, passed, failed))
    return { total = #results, passed = passed, failed = failed, results = results }
end

return Tests
