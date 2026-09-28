-- 技能生命周期与灰盒几何测试。纯 Lua，可用 lupa 或 PIE Lua 控制台运行。
-- local r = require('Script.AI.Boss.BossAI_RuntimeTests').RunAll()
local Config = require('Script.AI.Boss.BossAI_Config')
local State = require('Script.AI.Boss.BossAI_State')
local Types = require('Script.AI.Boss.BossAI_Types')
local Runtime = require('Script.AI.Boss.BossAI_SkillRuntime')
local Graybox = require('Script.AI.Boss.BossAI_Graybox')

local Tests = {}
local function actor(x, y, z)
    return { location = { X = x, Y = y, Z = z or 0 }, radius = 42, speed = 600 }
end
local function fakeAdapter(boss, target)
    local a = {
        boss = boss, target = target, damage = {}, warnings = {}, movementLocks = 0,
        releases = 0, pathSafe = true, dashSafe = true, sweptDistance = 0,
        projectiles = {}, projectileStops = 0, watchdogs = {},
    }
    function a:IsServer() return true end
    function a:IsValidTarget(t) return t == self.target and not t.destroyed end
    function a:GetPosition(t) return { X = t.location.X, Y = t.location.Y, Z = t.location.Z } end
    function a:GetVelocity(t) return t.velocity or { X = 0, Y = 0, Z = 0 } end
    function a:GetRadius(t) return t.radius end
    function a:GetSpeed(t) return t.speed end
    function a:HasLOS(_t) return true end
    function a:CheckDash(_start, _dir, _distance, _radius) return self.dashSafe end
    function a:CheckSafeRoute(_start, _finish, _width, _seconds) return self.pathSafe end
    function a:AcquireMovement(_def) self.movementLocks = self.movementLocks + 1; return {} end
    function a:ReleaseMovement(_token) self.movementLocks = self.movementLocks - 1; self.releases = self.releases + 1 end
    function a:MoveSwept(delta)
        local d = math.sqrt(delta.X * delta.X + delta.Y * delta.Y)
        local moved = self.blocked and 0 or d
        self.sweptDistance = self.sweptDistance + moved
        if moved > 0 then
            self.boss.location.X = self.boss.location.X + delta.X
            self.boss.location.Y = self.boss.location.Y + delta.Y
        end
        return moved
    end
    function a:HasClearDamagePath(_from, _to) return not self.damageWall end
    function a:CanShowWarning() return self.warningSafe ~= false end
    function a:ApplyDamage(t, damage, skillId, actionId)
        self.damage[#self.damage + 1] = { target = t, amount = damage, skill = skillId, action = actionId }
        return true
    end
    function a:ShowWarning(shape)
        self.warnings[#self.warnings + 1] = shape
        return shape, shape.center
    end
    function a:HideWarning(_handle) end
    function a:TraceProjectile(_from, to, _radius, t)
        -- 测试替身只返回最终到达的目标；真实适配器负责碰撞扫掠。
        local dx, dy = to.X - t.location.X, to.Y - t.location.Y
        if math.sqrt(dx * dx + dy * dy) <= 80 then return t, false end
        return nil, false
    end
    function a:StartProjectile(spec, _onHit, onStop)
        local handle = { active = true, spec = spec }
        self.projectiles[#self.projectiles + 1] = handle
        function handle:Stop()
            if not self.active then return end
            self.active = false
            a.projectileStops = a.projectileStops + 1
            onStop()
        end
        return handle
    end
    function a:ScheduleWatchdog(seconds, callback)
        local handle = { seconds = seconds, callback = callback, cancelled = false }
        self.watchdogs[#self.watchdogs + 1] = handle
        return handle
    end
    function a:CancelWatchdog(handle) handle.cancelled = true end
    return a
end
local function setup(id, distance)
    local boss, target = actor(0, 0), actor(distance or 200, 0)
    local adapter = fakeAdapter(boss, target)
    local state = State.New(Config, id * 31)
    local runtime = Runtime.New(state, adapter, boss)
    local ctx = { now = 10, target = target, targetValid = true, hasLOS = true,
        edgeDistance = distance or 200, heightDiff = 0, pathOk = true }
    return runtime, state, adapter, boss, target, ctx
end
local function assertEq(got, want, message)
    assert(got == want, (message or 'value') .. ': got=' .. tostring(got) .. ' want=' .. tostring(want))
end
local function run(name, fn, results)
    local ok, err = pcall(fn)
    results[#results + 1] = { name = name, pass = ok, detail = ok and '' or tostring(err) }
    print('[BossAI-RuntimeTest] ' .. name .. ' ' .. (ok and 'PASS' or ('FAIL ' .. tostring(err))))
end

function Tests.RunAll()
    local results = {}
    run('preflight ignores target capsule but still rejects world wall', function()
        local _, _, a, boss, target, ctx = setup(1, 200)
        local ignoredTarget
        a.HasClearDamagePath = function(self, _from, _to, ignored)
            ignoredTarget = ignored
            return ignored == target and not self.damageWall
        end
        local plan, reason = Graybox.Prepare(Config.SkillById[1], ctx, a, boss)
        assert(plan, tostring(reason))
        assertEq(ignoredTarget, target)
        a.damageWall = true
        plan, reason = Graybox.Prepare(Config.SkillById[1], ctx, a, boss)
        assertEq(plan, nil)
        assertEq(reason, 'Blocked')
    end, results)
    run('failed validation does not commit cooldown', function()
        local rt, st, a, _, _, ctx = setup(3, 900)
        a.dashSafe = false
        local ok = rt:Begin(Types.SkillID.S3, ctx)
        assertEq(ok, false)
        assertEq(st:GetCommittedCount(), 0)
        assertEq(st:GetSkillCooldownRemain(3, 10), 0)
    end, results)
    run('commit refusal releases preflight movement and warning', function()
        local rt, st, a, _, _, ctx = setup(2, 200)
        local hidden = 0
        a.HideWarning = function() hidden = hidden + 1 end
        st.CommitSkill = function() return nil end
        local ok, reason = rt:Begin(2, ctx)
        assertEq(ok, false)
        assertEq(reason, 'CommitRefused')
        assertEq(a.movementLocks, 0)
        assertEq(a.releases, 1)
        assertEq(hidden, 1)
        assertEq(a.watchdogs[1].cancelled, true)
        assertEq(rt:GetActiveAction(), nil)
        assertEq(st:GetCommittedCount(), 0)
    end, results)
    run('windup active recovery finish only after full recovery', function()
        local rt, st, a, _, _, ctx = setup(1, 200)
        local ok, id = rt:Begin(1, ctx)
        assertEq(ok, true)
        assertEq(st:GetCommittedCount(), 1)
        assertEq(rt:Tick(10.64, 0.64).phase, Types.ActionPhase.Windup)
        assertEq(rt:Tick(10.65, 0.01).phase, Types.ActionPhase.Active)
        assertEq(rt:Tick(11.45, 0.80).phase, Types.ActionPhase.Recovery)
        assertEq(rt:Tick(12.24, 0.79).status, 'running')
        assertEq(rt:Tick(12.25, 0.01).status, 'finished')
        assertEq(rt:Tick(13, 0.75).status, 'finished')
        assertEq(st:GetActiveAction(), nil)
        assertEq(a.releases, 1)
        assertEq(id, 1)
    end, results)
    run('abort stops future hits and stale id cannot abort a new action', function()
        local rt, st, a, _, _, ctx = setup(1, 200)
        local ok, oldId = rt:Begin(1, ctx); assertEq(ok, true)
        assertEq(rt:Abort(oldId, 'stagger', 10.2), true)
        assertEq(rt:Abort(oldId, 'again', 10.3), false)
        rt:Tick(11.2, 1)
        assertEq(#a.damage, 0)
        ctx.now = 14
        local ok2, newId = rt:Begin(1, ctx); assertEq(ok2, true)
        assert(newId > oldId)
        assertEq(rt:Abort(oldId, 'stale', 14.1), false)
        assertEq(st:GetActiveAction().id, newId)
        assertEq(a.movementLocks, 1)
    end, results)
    run('S1 two windows deduplicate one target per segment', function()
        local rt, _, a, _, _, ctx = setup(1, 200)
        assertEq(rt:Begin(1, ctx), true)
        rt:Tick(10.66, 0.66)
        rt:Tick(10.80, 0.14)
        rt:Tick(11.14, 0.34)
        rt:Tick(11.25, 0.11)
        assertEq(#a.damage, 2)
        assertEq(a.damage[1].amount, 8)
        assertEq(a.damage[2].amount, 8)
    end, results)
    run('S3 blocked sweep stops without teleporting', function()
        local rt, _, a, boss, _, ctx = setup(3, 900)
        assertEq(rt:Begin(3, ctx), true)
        a.blocked = true
        rt:Tick(10.95, 0.95)
        rt:Tick(11.20, 0.25)
        assertEq(a.sweptDistance, 0)
        assertEq(boss.location.X, 0)
    end, results)
    run('S3 final warning matches revalidated locked dash direction', function()
        local rt, _, a, _, target, ctx = setup(3, 900)
        assertEq(rt:Begin(3, ctx), true)
        target.location.X, target.location.Y = 0, 900
        rt:Tick(10.50, 0.50)
        local warning = a.warnings[#a.warnings]
        assert(warning and warning.kind == 'dash-line')
        assert(math.abs(warning.direction.X) < 0.01)
        assert(warning.direction.Y > 0.99)
        rt:Tick(11.10, 0.60)
        assert(a.sweptDistance > 0)
    end, results)
    run('S3 waits a full warning interval after a late aim-lock tick', function()
        local rt, _, a, _, _, ctx = setup(3, 900)
        assertEq(rt:Begin(3, ctx), true)
        rt:Tick(10.70, 0.70)
        assertEq(#a.warnings, 1)
        rt:Tick(10.98, 0.28)
        assertEq(a.sweptDistance, 0)
        rt:Tick(11.20, 0.22)
        assert(a.sweptDistance > 0)
    end, results)
    run('S3 misses its telegraph window instead of dashing on a hitch', function()
        local rt, _, a, _, _, ctx = setup(3, 900)
        assertEq(rt:Begin(3, ctx), true)
        local outcome = rt:Tick(11.00, 1.00)
        assertEq(outcome.status, 'failed')
        assertEq(a.sweptDistance, 0)
        assertEq(#a.warnings, 0)
    end, results)
    run('S2 cannot hit outside its warned fixed front area', function()
        local rt, _, a, _, target, ctx = setup(2, 200)
        assertEq(rt:Begin(2, ctx), true)
        target.location.X = -200
        rt:Tick(10.65, 0.65)
        rt:Tick(11.30, 0.65)
        assertEq(#a.damage, 0)
    end, results)
    run('S5 warned points remain fixed after target moves', function()
        local rt, _, a, _, target, ctx = setup(5, 1000)
        assertEq(rt:Begin(5, ctx), true)
        assertEq(#a.warnings, 3)
        assert(a.warnings[1].center.X ~= a.warnings[2].center.X
            or a.warnings[1].center.Y ~= a.warnings[2].center.Y,
            'first and second fixed points overlapped a stationary target')
        local first = a.warnings[1].center.X
        target.location.X = 1800
        rt:Tick(11.30, 1.30)
        assertEq(a.warnings[1].center.X, first)
        assertEq(first, 1000)
    end, results)
    run('S5 damage uses the exact projected warning points', function()
        local rt, _, a, _, _, ctx = setup(5, 1000)
        a.ShowWarning = function(self, shape)
            local projected = { kind = shape.kind, radius = shape.radius,
                center = { X = shape.center.X + 500, Y = shape.center.Y, Z = shape.center.Z } }
            self.warnings[#self.warnings + 1] = projected
            return projected, projected.center
        end
        assertEq(rt:Begin(5, ctx), true)
        assertEq(rt.action.points[1].X, a.warnings[1].center.X)
        rt:Tick(11.33, 1.33)
        assertEq(#a.damage, 0)
    end, results)
    run('warnings cover their final damage windows', function()
        local rt2, _, a2, _, _, ctx2 = setup(2, 200)
        assertEq(rt2:Begin(2, ctx2), true)
        assert(a2.warnings[1].duration >= rt2.action.def.windup + rt2.action.def.active)
        local rt3, _, a3, _, _, ctx3 = setup(3, 900)
        assertEq(rt3:Begin(3, ctx3), true)
        rt3:Tick(10.50, 0.50)
        assert(a3.warnings[1].duration + 0.000001 >= rt3.action.def.windup
            + rt3.action.def.active - rt3.action.def.aimLockAt)
        local rt5, _, a5, _, _, ctx5 = setup(5, 1000)
        assertEq(rt5:Begin(5, ctx5), true)
        for i = 1, 3 do
            assert(a5.warnings[i].duration >= rt5.action.def.windup
                + rt5.action.def.hitWindows[i][2])
        end
        local rt6, _, a6, _, _, ctx6 = setup(6, 900)
        assertEq(rt6:Begin(6, ctx6), true)
        assert(a6.warnings[1].duration >= rt6.action.def.windup
            + rt6.action.def.active + rt6.action.def.projectile.life)
        local rt7, _, a7, _, _, ctx7 = setup(7, 900)
        assertEq(rt7:Begin(7, ctx7), true)
        assert(a7.warnings[1].duration >= rt7.action.def.windup + rt7.action.def.active)
    end, results)
    run('S6 safe gap warning stays until the last live projectile stops', function()
        local rt, _, a, _, _, ctx = setup(6, 900)
        local hidden = 0
        a.HideWarning = function() hidden = hidden + 1 end
        assertEq(rt:Begin(6, ctx), true)
        rt:Tick(11.10, 1.10)
        rt:Tick(11.80, 0.70)
        assertEq(#a.projectiles, 18)
        assertEq(rt:Tick(13.60, 1.80).status, 'finished')
        assertEq(hidden, 0)
        for i = 1, #a.projectiles do a.projectiles[i]:Stop() end
        assertEq(hidden, 1)
    end, results)
    run('S6 and S7 reject when no validated safe route', function()
        for _, id in ipairs({6, 7}) do
            local rt, st, a, _, _, ctx = setup(id, 900)
            a.pathSafe = false
            assertEq(rt:Begin(id, ctx), false)
            assertEq(st:GetCommittedCount(), 0)
            assertEq(st:GetSkillCooldownRemain(id, 10), 0)
        end
    end, results)
    run('S4 cannot launch invisible projectiles', function()
        local rt, st, a, _, _, ctx = setup(4, 900)
        a.warningSafe = false
        assertEq(rt:Begin(4, ctx), false)
        assertEq(st:GetCommittedCount(), 0)
    end, results)
    run('S6 and S7 cancel damage if their safe route closes before pulse', function()
        for _, id in ipairs({6, 7}) do
            local rt, _, a, _, _, ctx = setup(id, 900)
            assertEq(rt:Begin(id, ctx), true)
            a.pathSafe = false
            local outcome = rt:Tick(id == 6 and 11.05 or 11.83, 1.83)
            assertEq(outcome.status, 'failed')
            assertEq(#a.damage, 0)
            assertEq(#a.projectiles, 0)
        end
    end, results)
    run('danger timeout disables damage and breathing waits for it', function()
        local rt, st, a, _, _, ctx = setup(4, 900)
        assertEq(rt:Begin(4, ctx), true)
        rt:Tick(10.81, 0.81)
        assert(st:GetActiveDangerCount(10.81) > 0)
        st:StartBreathing(10.81)
        assertEq(st:TickBreathing(10.81).phase, Types.BreathingPhase.DrainThreats)
        rt:TickDangers(14, 3.19)
        assertEq(st:GetActiveDangerCount(14), 0)
        assertEq(a.projectileStops, #a.projectiles)
        assertEq(st:TickBreathing(14).phase, Types.BreathingPhase.Breathing)
    end, results)
    run('release retains failed cleanup until bounded retry succeeds', function()
        local boss, target = actor(0, 0), actor(900, 0)
        local adapter = fakeAdapter(boss, target)
        local state = State.New(Config, 43)
        local rt = Runtime.ForPawn(boss, { state = state, adapter = adapter })
        local ctx = { now = 10, target = target, targetValid = true,
            hasLOS = true, edgeDistance = 900, heightDiff = 0, pathOk = true }
        local ok, id = rt:Begin(4, ctx); assertEq(ok, true)
        local attempts = 0
        state:RegisterDanger(4, id, 11, function()
            attempts = attempts + 1
            if attempts <= 3 then error('transient disable failure') end
        end)
        assertEq(Runtime.Release(boss, 10.2, 'death'), false)
        assertEq(Runtime.Get(boss), rt)
        assert(state:HasDangerCleanupFailure())
        local retry = adapter.watchdogs[#adapter.watchdogs]
        retry.callback()
        assertEq(Runtime.Get(boss), nil)
        assertEq(state:GetActiveDangerCount(11), 0)
    end, results)
    run('releasing a never engaged Boss is already clean', function()
        assertEq(Runtime.Release(actor(0, 0), 10, 'death'), true)
    end, results)
    run('S4 creates exactly three finite nontracking projectiles', function()
        local rt, st, a, _, target, ctx = setup(4, 900)
        assertEq(rt:Begin(4, ctx), true)
        rt:Tick(11.20, 1.20)
        assertEq(#a.projectiles, 3)
        local dir = a.projectiles[1].spec.direction
        target.location.Y = 1500
        assertEq(a.projectiles[1].spec.direction, dir)
        for _, p in ipairs(a.projectiles) do assert(p.spec.life <= 2) end
        rt:Reset(11.3, 'death')
        assertEq(st:GetActiveDangerCount(11.3), 0)
        assertEq(a.projectileStops, 3)
    end, results)
    run('projectile spawn failure terminates committed skill safely', function()
        local rt, st, a, _, _, ctx = setup(4, 900)
        a.StartProjectile = function() return nil end
        assertEq(rt:Begin(4, ctx), true)
        local outcome = rt:Tick(10.75, 0.75)
        assertEq(outcome.status, 'failed')
        assertEq(st:GetActiveAction(), nil)
        assertEq(st:GetCommittedCount(), 1)
        assert(st:GetSkillCooldownRemain(4, 10.75) > 0)
    end, results)
    run('S6 reuses one safe gap for both projectile rounds', function()
        local rt, _, a, _, _, ctx = setup(6, 900)
        assertEq(rt:Begin(6, ctx), true)
        local safe = a.warnings[1].safe
        rt:Tick(12.60, 2.60)
        assertEq(#a.projectiles, 18)
        local forbidden = math.cos(math.rad(safe.halfAngle))
        for _, p in ipairs(a.projectiles) do
            local d = p.spec.direction
            assert(d.X * safe.axis.X + d.Y * safe.axis.Y < forbidden,
                'a bullet closed the warned safe gap')
        end
    end, results)
    run('S6 target movement during warning cannot rotate safe gap', function()
        local rt, _, a, _, target, ctx = setup(6, 900)
        assertEq(rt:Begin(6, ctx), true)
        local safe = a.warnings[1].safe
        local warnedDir = a.warnings[1].direction
        target.location.X, target.location.Y = 0, 900
        rt:Tick(10.50, 0.50)
        rt:Tick(11.05, 0.55)
        assert(#a.projectiles > 0)
        local forbidden = math.cos(math.rad(safe.halfAngle))
        for _, p in ipairs(a.projectiles) do
            local d = p.spec.direction
            assert(d.X * safe.axis.X + d.Y * safe.axis.Y < forbidden,
                'player movement rotated bullets into prior safe gap')
            assert(d.X * warnedDir.X + d.Y * warnedDir.Y >= math.cos(math.rad(60.01)),
                'bullet moved outside the warned fan')
        end
    end, results)
    run('S7 keeps warned safe wedge free of both pulses', function()
        local rt, _, a, _, target, ctx = setup(7, 900)
        assertEq(rt:Begin(7, ctx), true)
        rt:Tick(11.83, 1.83)
        assertEq(#a.damage, 0)
        target.location.X, target.location.Y = 0, 650
        rt:Tick(12.23, 0.40)
        assertEq(#a.damage, 1)
        assertEq(a.damage[1].amount, 15)
    end, results)
    run('late watchdog tick never emits missed attacks', function()
        local rt, st, a, _, _, ctx = setup(1, 200)
        assertEq(rt:Begin(1, ctx), true)
        assertEq(rt:Tick(20, 10).status, 'failed')
        assertEq(#a.damage, 0)
        assertEq(st:GetActiveAction(), nil)
    end, results)
    run('old watchdog callback cannot end a later action', function()
        local rt, st, a, _, _, ctx = setup(1, 200)
        local ok, oldId = rt:Begin(1, ctx); assertEq(ok, true)
        assertEq(#a.watchdogs, 1)
        local old = a.watchdogs[1]
        rt:Abort(oldId, 'test', 10.2)
        ctx.now = 14
        local ok2, newId = rt:Begin(1, ctx); assertEq(ok2, true)
        old.callback()
        assertEq(st:GetActiveAction().id, newId)
        a.watchdogs[2].callback()
        assertEq(st:GetActiveAction(), nil)
        assertEq(rt:Tick(20, 6).status, 'aborted')
    end, results)
    run('two runtimes do not share action locks or cooldowns', function()
        local a, sa, _, _, _, ca = setup(1, 200)
        local b, sb, _, _, _, cb = setup(1, 200)
        assertEq(a:Begin(1, ca), true)
        assertEq(sa:GetCommittedCount(), 1)
        assertEq(sb:GetCommittedCount(), 0)
        assertEq(b:Begin(1, cb), true)
        assertEq(sa:GetCommittedCount(), 1)
        assertEq(sb:GetCommittedCount(), 1)
    end, results)
    run('warning RPC carries only primitive geometry and can stop', function()
        local boss, target = actor(0, 0), actor(900, 0)
        function boss:GetName() return 'BossA' end
        local pc = {}
        function pc:GetAvailableClientRPCs()
            return 'Client_BossWarning', 'Client_BossWarningStop'
        end
        local calls = {}
        local game = { GetControllerByPawn = function(t) return t == target and pc or nil end }
        local net = { CallUnrealRPC = function(source, dest, name, ...)
            calls[#calls + 1] = { source = source, dest = dest, name = name, args = { ... } }
        end }
        local provider = Graybox.NewRPCWarningProvider(game, net)
        assertEq(provider:CanShow(target), true)
        local handle = provider:Show(boss, { kind = 'fixed-point', center = { X = 900, Y = 0, Z = 0 },
            radius = 180, duration = 1.2 }, target, 4, 2)
        assert(handle)
        assertEq(calls[1].name, 'Client_BossWarning')
        assertEq(calls[1].args[1], 'BossA')
        assertEq(calls[1].args[2], 4)
        assertEq(calls[1].args[3], 2)
        assertEq(calls[1].args[4], 5)
        assertEq(calls[1].args[8], 180)
        for _, arg in ipairs(calls[1].args) do
            assert(type(arg) == 'string' or type(arg) == 'number')
        end
        provider:Hide(handle)
        assertEq(calls[2].name, 'Client_BossWarningStop')
        assertEq(calls[2].args[1], 'BossA')
        assertEq(calls[2].args[2], 4)
        assertEq(calls[2].args[3], 2)
        local projectile = provider:Show(boss,
            { kind = 'projectile', center = { X = 0, Y = 0, Z = 100 },
                direction = { X = 1, Y = 0 }, radius = 35, duration = 2, length = 3200 },
            target, 4, 101)
        assert(projectile)
        assertEq(calls[3].args[3], 101)
        assertEq(calls[3].args[4], 4)
        assertEq(calls[3].args[7], 100)
        assertEq(calls[3].args[12], 3200)
        provider:Hide(projectile)
        assertEq(calls[4].name, 'Client_BossWarningStop')
        assertEq(calls[4].args[3], 101)
        local stopOnly = { GetAvailableClientRPCs = function()
            return 'Client_BossWarningStop'
        end }
        local stopOnlyGame = { GetControllerByPawn = function() return stopOnly end }
        assertEq(Graybox.NewRPCWarningProvider(stopOnlyGame, net):CanShow(target), false)
    end, results)
    run('UGC projectile retains timer delegate until stopped', function()
        local originalGame, originalKismet = UGCGameSystem, KismetSystemLibrary
        UGCGameSystem = { SetTimer = function() return 77, { callbackRoot = true } end,
            ClearTimer = function() end }
        KismetSystemLibrary = {}
        local adapter = Graybox.NewUGCAdapter(actor(0, 0), nil)
        adapter.IsServer = function() return true end
        adapter.ShowWarning = function() return {} end
        adapter.HideWarning = function() end
        local handle = adapter:StartProjectile({ origin = { X = 0, Y = 0, Z = 100 },
            direction = { X = 1, Y = 0, Z = 0 }, radius = 35, speed = 1600,
            life = 2, target = actor(900, 0), actionId = 1, ordinal = 1 },
            function() end, function() end)
        assert(handle and handle.delegate and handle.delegate.callbackRoot)
        handle:Stop()
        UGCGameSystem, KismetSystemLibrary = originalGame, originalKismet
        assertEq(handle.delegate, nil)
    end, results)
    run('projectile stop retries a transient timer-clear failure without damage', function()
        local originalGame, originalKismet = UGCGameSystem, KismetSystemLibrary
        local clearCalls, stops = 0, 0
        UGCGameSystem = { SetTimer = function() return 77, { callbackRoot = true } end,
            ClearTimer = function()
                clearCalls = clearCalls + 1
                if clearCalls == 1 then error('temporary timer failure') end
            end }
        KismetSystemLibrary = {}
        local adapter = Graybox.NewUGCAdapter(actor(0, 0), nil)
        adapter.IsServer = function() return true end
        adapter.ShowWarning = function() return {} end
        adapter.HideWarning = function() end
        local handle = adapter:StartProjectile({ origin = { X = 0, Y = 0, Z = 100 },
            direction = { X = 1, Y = 0, Z = 0 }, radius = 35, speed = 1600,
            life = 2, target = actor(900, 0), actionId = 1, ordinal = 1 },
            function() end, function() stops = stops + 1 end)
        local firstOk = pcall(handle.Stop, handle)
        local inactiveAfterFailure = handle.active == false
        local timerRetained = handle.handle == 77 and handle.delegate ~= nil
        local secondOk = pcall(handle.Stop, handle)
        UGCGameSystem, KismetSystemLibrary = originalGame, originalKismet
        assertEq(firstOk, false)
        assertEq(inactiveAfterFailure, true)
        assertEq(timerRetained, true)
        assertEq(secondOk, true)
        assertEq(clearCalls, 2)
        assertEq(stops, 1)
        assertEq(handle.handle, nil)
    end, results)
    run('warning ground trace accepts mutated OutHit return form', function()
        local oldTrace, oldQuery, oldDraw = KismetSystemLibrary, ETraceTypeQuery, EDrawDebugTrace
        local target = actor(4, 5)
        local ignoredTarget = false
        KismetSystemLibrary = { LineTraceSingle = function(_, _, _, _, _, ignored, _, outHit)
            for _, item in ipairs(ignored) do
                if item == target then ignoredTarget = true end
            end
            outHit.ImpactPoint = { X = 4, Y = 5, Z = 50 }
            outHit.ImpactNormal = { X = 0, Y = 0, Z = 1 }
            return true
        end }
        ETraceTypeQuery = { TraceTypeQuery1 = 1 }
        EDrawDebugTrace = { None = 0 }
        local adapter = Graybox.NewUGCAdapter(actor(0, 0), nil)
        local ground = adapter:ProjectWarningToGround({ X = 4, Y = 5, Z = 100 }, target)
        KismetSystemLibrary, ETraceTypeQuery, EDrawDebugTrace = oldTrace, oldQuery, oldDraw
        assert(ground)
        assertEq(ground.Z, 55)
        assertEq(ignoredTarget, true)
    end, results)
    run('warning ground trace rejects a hit without a walkable surface normal', function()
        local oldTrace, oldQuery, oldDraw = KismetSystemLibrary, ETraceTypeQuery, EDrawDebugTrace
        KismetSystemLibrary = { LineTraceSingle = function(_, _, _, _, _, _, _, outHit)
            outHit.ImpactPoint = { X = 0, Y = 0, Z = 0 }
            return true
        end }
        ETraceTypeQuery = { TraceTypeQuery1 = 1 }
        EDrawDebugTrace = { None = 0 }
        local adapter = Graybox.NewUGCAdapter(actor(0, 0), nil)
        local ground = adapter:ProjectWarningToGround({ X = 0, Y = 0, Z = 100 })
        KismetSystemLibrary, ETraceTypeQuery, EDrawDebugTrace = oldTrace, oldQuery, oldDraw
        assertEq(ground, nil)
    end, results)
    run('UGC adapter reads exposed capsule properties for radius and safe sweeps', function()
        local oldTrace, oldQuery, oldDraw, oldUE, oldNav, oldNavClass =
            KismetSystemLibrary, ETraceTypeQuery, EDrawDebugTrace, UE,
            UGCNavigationSystem, NavigationSystem
        local boss, target, hitBoxActor = actor(0, 0), actor(200, 0), actor(0, 0)
        boss.GetCapsuleComponent = function() error('getter unavailable in UGC') end
        boss.CapsuleComponent = {
            GetScaledCapsuleRadius = function() return 80 end,
            GetScaledCapsuleHalfHeight = function() return 310 end,
        }
        target.HitBox_Stand = {
            GetScaledCapsuleRadius = function() return 42 end,
            GetScaledCapsuleHalfHeight = function() return 90 end,
        }
        hitBoxActor.HitBox = { GetScaledCapsuleRadius = function() return 55 end }
        target.GetMovementComponent = function() return { MaxWalkSpeed = 600 } end
        UE = { IsValid = function() return true end }
        ETraceTypeQuery = { TraceTypeQuery1 = 1 }
        EDrawDebugTrace = { None = 0 }
        local sweeps = {}
        KismetSystemLibrary = { CapsuleTraceSingle = function(_, _, _, sweepRadius, halfHeight)
            sweeps[#sweeps + 1] = { radius = sweepRadius, halfHeight = halfHeight }
            return false
        end }
        UGCNavigationSystem = { ProjectPointToNavigation = function(_, point) return true, point end }
        NavigationSystem = { FindPathToLocationSynchronously = function()
            return { IsValid = function() return true end, IsPartial = function() return false end,
                GetPathLength = function() return 200 end }
        end }
        local ok, err = pcall(function()
            local adapter = Graybox.NewUGCAdapter(boss, nil)
            assertEq(adapter:GetRadius(boss), 80)
            assertEq(adapter:GetRadius(target), 42)
            assertEq(adapter:GetRadius(hitBoxActor), 55)
            local startPos, endPos = { X = 0, Y = 0, Z = 0 }, { X = 200, Y = 0, Z = 0 }
            assertEq(adapter:CheckDash(startPos, { X = 1, Y = 0, Z = 0 }, 200, 80, target), true)
            assertEq(adapter:CheckSafeRoute(startPos, endPos, 164, 1, target), true)
            assertEq(sweeps[1].halfHeight, 310)
            assertEq(sweeps[3].halfHeight, 90)
        end)
        KismetSystemLibrary, ETraceTypeQuery, EDrawDebugTrace, UE,
            UGCNavigationSystem, NavigationSystem = oldTrace, oldQuery, oldDraw, oldUE,
                oldNav, oldNavClass
        assert(ok, tostring(err))
    end, results)
    run('target capsule is ignored in traces but a world blocker is not', function()
        local oldTrace, oldQuery, oldDraw, oldUE, oldNav, oldNavClass =
            KismetSystemLibrary, ETraceTypeQuery, EDrawDebugTrace, UE,
            UGCNavigationSystem, NavigationSystem
        local boss, target = actor(0, 0), actor(200, 0)
        local capsule = { GetScaledCapsuleHalfHeight = function() return 90 end }
        boss.GetCapsuleComponent = function() return capsule end
        target.GetCapsuleComponent = function() return capsule end
        target.GetMovementComponent = function() return { MaxWalkSpeed = 600 } end
        UE = { IsValid = function() return true end }
        ETraceTypeQuery = { TraceTypeQuery1 = 1 }
        EDrawDebugTrace = { None = 0 }
        local worldBlocked = false
        local function trace(_, _, _, _, _, ignored)
            if worldBlocked then return true end
            for _, item in ipairs(ignored) do if item == target then return false end end
            return true -- no explicit target ignore: the player capsule is first hit
        end
        KismetSystemLibrary = {
            LineTraceSingle = trace,
            SphereTraceSingle = function(_, _, _, _, _, _, ignored)
                return trace(nil, nil, nil, nil, nil, ignored)
            end,
            CapsuleTraceSingle = function(_, _, _, _, _, _, _, ignored)
                return trace(nil, nil, nil, nil, nil, ignored)
            end,
        }
        UGCNavigationSystem = { ProjectPointToNavigation = function(_, point) return true, point end }
        NavigationSystem = { FindPathToLocationSynchronously = function()
            return { IsValid = function() return true end, IsPartial = function() return false end,
                GetPathLength = function() return 200 end }
        end }
        local adapter = Graybox.NewUGCAdapter(boss, nil)
        local startPos, endPos = { X = 0, Y = 0, Z = 0 }, { X = 200, Y = 0, Z = 0 }
        local direction = { X = 1, Y = 0, Z = 0 }
        local clearDamage = adapter:HasClearDamagePath(startPos, endPos, target)
        local clearProjectile = adapter:HasClearProjectilePath(startPos, endPos, 35, target)
        local clearDash = adapter:CheckDash(startPos, direction, 200, 80, target)
        local clearRoute = adapter:CheckSafeRoute(startPos, endPos, 164, 1, target)
        worldBlocked = true
        local blockedDamage = adapter:HasClearDamagePath(startPos, endPos, target)
        local blockedProjectile = adapter:HasClearProjectilePath(startPos, endPos, 35, target)
        local blockedDash = adapter:CheckDash(startPos, direction, 200, 80, target)
        local blockedRoute = adapter:CheckSafeRoute(startPos, endPos, 164, 1, target)
        KismetSystemLibrary, ETraceTypeQuery, EDrawDebugTrace, UE,
            UGCNavigationSystem, NavigationSystem = oldTrace, oldQuery, oldDraw, oldUE,
                oldNav, oldNavClass
        assertEq(clearDamage, true)
        assertEq(clearProjectile, true)
        assertEq(clearDash, true)
        assertEq(clearRoute, true)
        assertEq(blockedDamage, false)
        assertEq(blockedProjectile, false)
        assertEq(blockedDash, false)
        assertEq(blockedRoute, false)
    end, results)
    run('safe route requires a complete navigable path, not only endpoint projection', function()
        local oldTrace, oldQuery, oldDraw, oldUE, oldNav, oldNavClass =
            KismetSystemLibrary, ETraceTypeQuery, EDrawDebugTrace, UE,
            UGCNavigationSystem, NavigationSystem
        local boss, target = actor(0, 0), actor(200, 0)
        target.GetCapsuleComponent = function() return {
            GetScaledCapsuleHalfHeight = function() return 90 end } end
        target.GetMovementComponent = function() return { MaxWalkSpeed = 600 } end
        UE = { IsValid = function() return true end }
        ETraceTypeQuery = { TraceTypeQuery1 = 1 }
        EDrawDebugTrace = { None = 0 }
        KismetSystemLibrary = { CapsuleTraceSingle = function() return false end }
        UGCNavigationSystem = { ProjectPointToNavigation = function(_, point) return true, point end }
        NavigationSystem = { FindPathToLocationSynchronously = function()
            return { IsValid = function() return false end, IsPartial = function() return true end,
                GetPathLength = function() return 200 end }
        end }
        local adapter = Graybox.NewUGCAdapter(boss, nil)
        local clear = adapter:CheckSafeRoute({ X = 0, Y = 0, Z = 0 },
            { X = 200, Y = 0, Z = 0 }, 164, 1, target)
        KismetSystemLibrary, ETraceTypeQuery, EDrawDebugTrace, UE,
            UGCNavigationSystem, NavigationSystem = oldTrace, oldQuery, oldDraw, oldUE,
                oldNav, oldNavClass
        assertEq(clear, false)
    end, results)
    local pass = 0
    for _, r in ipairs(results) do if r.pass then pass = pass + 1 end end
    return { pass = pass, total = #results, results = results }
end

return Tests
