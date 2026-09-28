-- 每只 Boss 独立的异步技能运行时；BT Task 每帧 Tick，不以共享节点存储动作状态。
local Config = require('Script.AI.Boss.BossAI_Config')
local Types = require('Script.AI.Boss.BossAI_Types')
local State = require('Script.AI.Boss.BossAI_State')
local Decision = require('Script.AI.Boss.BossAI_Decision')
local Graybox = require('Script.AI.Boss.BossAI_Graybox')

local Runtime = {}
Runtime.__index = Runtime
local registry = setmetatable({}, { __mode = 'k' })

local function finite(x)
    return type(x) == 'number' and x == x and x ~= math.huge and x ~= -math.huge
end
local function result(action, status, phase, reason)
    return { status = status, phase = phase, actionId = action and action.id or 0,
        skillId = action and action.skillId or Types.SkillID.None, reason = reason }
end
local function logError(message)
    if type(ugcprint) == 'function' then pcall(ugcprint, '[BossAI-Runtime] ' .. message)
    else print('[BossAI-Runtime] ' .. message) end
end

function Runtime.New(state, adapter, boss)
    assert(state and adapter and boss, 'BossAI Runtime requires state, adapter and boss')
    return setmetatable({ state = state, adapter = adapter, boss = boss,
        action = nil, terminal = nil }, Runtime)
end

function Runtime.ForPawn(pawn, opts)
    if not pawn then return nil end
    local current = registry[pawn]
    if current then
        if opts and opts.controller and current.adapter then
            current.adapter.controller = opts.controller
        end
        return current
    end
    opts = opts or {}
    local state = opts.state or State.New(opts.config or Config, opts.seed)
    local adapter = opts.adapter or Graybox.NewUGCAdapter(pawn, opts.controller, opts)
    current = Runtime.New(state, adapter, pawn)
    registry[pawn] = current
    return current
end

function Runtime.Get(pawn) return pawn and registry[pawn] or nil end

-- 仅用于实例首次创建之前显式提供引擎适配；运行中的适配器不可热替换。
function Runtime.ConfigurePawn(pawn, opts)
    if not pawn or registry[pawn] then return false end
    Runtime.ForPawn(pawn, opts)
    return true
end

function Runtime.Release(pawn, now, reason)
    local current = Runtime.Get(pawn)
    if not current then return true end -- 幂等：未进入过战斗的 Boss 无待清理状态
    local clean = current:Reset(now or 0, reason or 'release')
    if clean then
        registry[pawn] = nil
        return true
    end
    current.pendingRelease = true
    return false
end

function Runtime:GetState() return self.state end
function Runtime:GetActiveAction() return self.state:GetActiveAction() end
function Runtime:GetActiveDangerCount(now) return self.state:GetActiveDangerCount(now) end
function Runtime:GetActiveDangerDeadline(now) return self.state:GetActiveDangerDeadline(now) end
function Runtime:TickDangers(now, _dt)
    local swept = self.state:SweepDangers(now)
    local failed = self.state:HasDangerCleanupFailure()
    if failed and not self.cleanupFailureLogged then
        self.cleanupFailureLogged = true
        logError('danger cleanup failed; damage shutdown unconfirmed for Boss ' .. tostring(self.boss))
    elseif not failed and self.cleanupFailureLogged then
        self.cleanupFailureLogged = false
        logError('danger cleanup recovered for Boss ' .. tostring(self.boss))
    end
    if self.pendingRelease and not failed and self.state:GetActiveDangerCount(now) == 0 then
        self.pendingRelease = false
        if self.cleanupRetryHandle then
            pcall(self.adapter.CancelWatchdog, self.adapter, self.cleanupRetryHandle)
            self.cleanupRetryHandle = nil
        end
        registry[self.boss] = nil
    end
    return swept
end

function Runtime:ScheduleCleanupRetry()
    if self.cleanupRetryHandle or not self.state:HasDangerCleanupFailure() then return end
    local attempts = 0
    local function retry()
        self.cleanupRetryHandle = nil
        attempts = attempts + 1
        self:TickDangers(math.huge, 0)
        if self.state:HasDangerCleanupFailure() then
            if attempts >= 20 then
                logError('danger cleanup still unresolved after 20 retries for Boss '
                    .. tostring(self.boss))
            else
                local ok, handle = pcall(self.adapter.ScheduleWatchdog, self.adapter, 0.25, retry)
                if ok then self.cleanupRetryHandle = handle end
                if not self.cleanupRetryHandle then
                    logError('danger cleanup retry scheduling failed for Boss ' .. tostring(self.boss))
                end
            end
        end
    end
    if type(self.adapter.ScheduleWatchdog) == 'function' then
        local ok, handle = pcall(self.adapter.ScheduleWatchdog, self.adapter, 0.25, retry)
        if ok then self.cleanupRetryHandle = handle end
    end
    if not self.cleanupRetryHandle then
        logError('danger cleanup retry unavailable for Boss ' .. tostring(self.boss))
    end
end

-- 可由规划任务调用的只读预验证，Begin 时仍必须再验证一次。
function Runtime:CheckSkillLegal(skillId, ctx)
    ctx = ctx or {}
    local def = self.state.config.SkillById[skillId]
    if not def then return false, 'UnknownSkill' end
    if not finite(ctx.now) then return false, 'InvalidTime' end
    if self.state:IsActionLocked() then return false, 'Busy' end
    -- Planner 的 ctx.canUseSkill 会回调本函数；静态检查使用不带该闭包的快照。
    local staticCtx = {}
    for key, value in pairs(ctx) do
        if key ~= 'canUseSkill' then staticCtx[key] = value end
    end
    local ok, reason = Decision.CheckSkillLegal(self.state, def, staticCtx)
    if not ok then return false, reason end
    local plan, prepareReason = Graybox.Prepare(def, ctx, self.adapter, self.boss)
    if not plan then return false, prepareReason end
    if self.state:ShouldGiveSpace(ctx.now, (def.windup or 0) + (def.active or 0)
        + (def.recovery or 0), ctx.now + (def.windup or 0) + (def.active or 0)
        + (def.maxDangerLife or 0)) then return false, 'PressureBudget' end
    return true, nil, plan
end

function Runtime:Begin(skillId, ctx)
    ctx = ctx or {}
    local ok, reason, plan = self:CheckSkillLegal(skillId, ctx)
    if not ok then return false, reason end
    local def = self.state.config.SkillById[skillId]
    local action = plan
    action.def = def
    action.skillId = skillId
    action.startedAt = ctx.now
    action.phase = Types.ActionPhase.Windup
    action.lastElapsed = -0.000001
    action.hitKeys = {}
    action.damageEnabled = true
    action.directionLocked = false
    action.dashDistance = 0
    action.dashBlocked = false
    action.stepDistance = 0
    action.projectileFailure = false
    action.terminal = false
    action.warnings = {}
    action.warningId = (self.state.actionInstanceId or 0) + 1

    -- 资源/预警/movement 失败不进入前摇，故不会扣 CD 或承诺次数。
    local warned, warnReason = Graybox.Begin(action, self.adapter)
    if not warned then return false, warnReason end
    local acquired, token = pcall(self.adapter.AcquireMovement, self.adapter, def)
    if not acquired or token == nil then
        Graybox.End(action, self.adapter)
        return false, 'MovementUnavailable'
    end
    action.movementToken = token
    if type(self.adapter.ScheduleWatchdog) ~= 'function'
        or type(self.adapter.CancelWatchdog) ~= 'function' then
        pcall(self.adapter.ReleaseMovement, self.adapter, token)
        Graybox.End(action, self.adapter)
        return false, 'NoWatchdogAdapter'
    end
    local watchdogSeconds = def.windup + def.active + def.recovery + 0.5
    local nextId = action.warningId
    local scheduled, watchdog = pcall(self.adapter.ScheduleWatchdog, self.adapter,
        watchdogSeconds, function()
            local active = self.action
            if active and not active.terminal and active.id == nextId then
                self:Abort(nextId, 'WatchdogExpired', action.startedAt + watchdogSeconds, false)
            end
        end)
    if not scheduled or not watchdog then
        pcall(self.adapter.ReleaseMovement, self.adapter, token)
        Graybox.End(action, self.adapter)
        return false, 'WatchdogUnavailable'
    end
    action.watchdogHandle = watchdog
    local committed, actionId = pcall(self.state.CommitSkill, self.state, skillId, ctx.now)
    if not committed or not actionId then
        pcall(self.adapter.CancelWatchdog, self.adapter, watchdog)
        pcall(self.adapter.ReleaseMovement, self.adapter, token)
        Graybox.End(action, self.adapter)
        return false, 'CommitRefused'
    end
    action.id = actionId
    self.action = action
    self.terminal = nil
    return true, action.id
end

local function closeAction(self, action, status, now, reason)
    if action.terminal then return self.terminal end
    action.terminal = true
    action.damageEnabled = false
    if action.watchdogHandle then
        pcall(self.adapter.CancelWatchdog, self.adapter, action.watchdogHandle)
        action.watchdogHandle = nil
    end
    Graybox.End(action, self.adapter)
    pcall(self.adapter.ReleaseMovement, self.adapter, action.movementToken)
    action.movementToken = nil
    self.state:EndAction(action.id)
    action.phase = status == 'finished' and Types.ActionPhase.Finished
        or Types.ActionPhase.Aborted
    self.terminal = result(action, status, action.phase, reason)
    return self.terminal
end

function Runtime:Tick(now, _dt)
    local action = self.action
    self:TickDangers(now)
    if not action then return self.terminal or result(nil, 'idle', Types.ActionPhase.None) end
    if action.terminal then return self.terminal end
    if not finite(now) then return closeAction(self, action, 'failed', now, 'InvalidTime') end
    local elapsed = math.max(0, now - action.startedAt)
    local endActive = action.def.windup + action.def.active
    local endAction = endActive + action.def.recovery
    local previous = action.lastElapsed
    if elapsed > endAction + 0.5 then
        -- 丢 Tick/关卡暂停之后，不补发已错过的命中或投射物。
        return closeAction(self, action, 'failed', now, 'WatchdogOverdue')
    end
    local tickOk, tickError = pcall(Graybox.Tick, action, self, previous, elapsed, now)
    if not tickOk then return closeAction(self, action, 'failed', now, tostring(tickError)) end
    if action.warningFailure then
        return closeAction(self, action, 'failed', now, action.warningFailure)
    end
    if action.projectileFailure then
        return closeAction(self, action, 'failed', now, 'ProjectileSpawnFailed')
    end
    action.lastElapsed = elapsed
    local epsilon = 0.000001 -- 十进制配置在浮点时钟中的边界误差
    if elapsed + epsilon >= endAction then return closeAction(self, action, 'finished', now) end
    if elapsed + epsilon >= endActive then
        action.phase = Types.ActionPhase.Recovery
        action.damageEnabled = false
    elseif elapsed + epsilon >= action.def.windup then
        action.phase = Types.ActionPhase.Active
    else
        action.phase = Types.ActionPhase.Windup
    end
    return result(action, 'running', action.phase)
end

-- 同步清理；旧 ID、重复中止均返回 false。普通硬直不撤回已发射弹体。
function Runtime:Abort(actionId, reason, now, clearDangers)
    local action = self.action
    if not action or action.terminal or action.id ~= actionId then return false end
    closeAction(self, action, 'aborted', now, reason or 'abort')
    if clearDangers then self.state:ClearDangers() end
    return true
end

function Runtime:Reset(now, reason)
    local action = self.action
    if action and not action.terminal then self:Abort(action.id, reason or 'reset', now, true) end
    self.state:ClearDangers()
    self.state:Reset(now or 0)
    self.action = nil
    self.terminal = nil
    local clean = not self.state:HasDangerCleanupFailure()
        and self.state:GetActiveDangerCount(now or 0) == 0
    if not clean then
        if not self.cleanupFailureLogged then
            self.cleanupFailureLogged = true
            logError('danger cleanup failed during reset; damage shutdown unconfirmed for Boss '
                .. tostring(self.boss))
        end
        self:ScheduleCleanupRetry()
    end
    return clean
end

return Runtime
