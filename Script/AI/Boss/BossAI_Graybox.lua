-- 七技能的可执行几何/伤害灰盒。所有引擎调用收敛在可注入 adapter 中。
-- 服务端无可复制预警时，地面/弹幕技拒绝起手，避免隐形攻击。
local Types = require('Script.AI.Boss.BossAI_Types')
local Graybox = {}

local function v(x, y, z) return { X = x or 0, Y = y or 0, Z = z or 0 } end
local function add(a, b) return v(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
local function sub(a, b) return v(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
local function mul(a, n) return v(a.X * n, a.Y * n, a.Z * n) end
local function dot(a, b) return a.X * b.X + a.Y * b.Y end
local function len(a) return math.sqrt(a.X * a.X + a.Y * a.Y) end
local function unit(a)
    local n = len(a)
    if n < 0.0001 then return v(1, 0, 0) end
    return v(a.X / n, a.Y / n, 0)
end
local function rotate(a, degrees)
    local radians = math.rad(degrees)
    local c, s = math.cos(radians), math.sin(radians)
    return v(a.X * c - a.Y * s, a.X * s + a.Y * c, 0)
end
local function clamp(x, lo, hi) return math.max(lo, math.min(hi, x)) end
local function targetDistanceToSegment(point, a, b)
    local ab = sub(b, a)
    local denom = dot(ab, ab)
    local t = denom > 0 and clamp(dot(sub(point, a), ab) / denom, 0, 1) or 0
    return len(sub(point, add(a, mul(ab, t))))
end
local function isFinite(x)
    return type(x) == 'number' and x == x and x ~= math.huge and x ~= -math.huge
end
local function validPosition(p)
    return p and isFinite(p.X) and isFinite(p.Y) and isFinite(p.Z)
end
local function hasMethod(o, name) return o and type(o[name]) == 'function' end

local function targetPosition(action, adapter)
    if not adapter:IsValidTarget(action.target) then return nil end
    local p = adapter:GetPosition(action.target)
    return validPosition(p) and p or nil
end

local function lockDirection(action, adapter)
    if action.directionLocked then return end
    local target = targetPosition(action, adapter)
    if target and adapter:HasLOS(action.target) then
        local origin = adapter:GetPosition(action.boss)
        action.direction = unit(sub(target, origin))
    end
    action.directionLocked = true
end

local function damageTarget(action, adapter, amount, source, predicate)
    if not action.damageEnabled or action.hitKeys[source] then return false end
    local target = targetPosition(action, adapter)
    if not target then return false end
    local origin = adapter:GetPosition(action.boss)
    if not validPosition(origin) then return false end
    if math.abs(target.Z - origin.Z) > (action.heightTolerance or 300) then return false end
    if not predicate(target, origin) then return false end
    if not adapter:HasClearDamagePath(origin, target, action.target) then return false end
    if not adapter:ApplyDamage(action.target, amount, action.skillId, action.id) then return false end
    action.hitKeys[source] = true
    return true
end

local function arcHit(action, adapter, key, radius, halfAngle, amount)
    damageTarget(action, adapter, amount, key, function(target, origin)
        local delta = sub(target, origin)
        local reach = radius + (adapter:GetRadius(action.target) or 0)
        if len(delta) > reach then return false end
        if len(delta) < 0.001 then return true end
        return dot(unit(delta), action.direction) >= math.cos(math.rad(halfAngle))
    end)
end

local function pointHit(action, adapter, key, point, radius, amount)
    damageTarget(action, adapter, amount, key, function(target)
        return len(sub(target, point)) <= radius + (adapter:GetRadius(action.target) or 0)
            and math.abs(target.Z - point.Z) <= (action.heightTolerance or 300)
    end)
end

local function makeSafeRoute(def, ctx, adapter, bossPos, targetPos, radius)
    if not hasMethod(adapter, 'CheckSafeRoute') then return nil, 'NoSafeRouteValidator' end
    local distance = math.max(1, len(sub(targetPos, bossPos)))
    local playerSpeed = adapter:GetSpeed(ctx.target)
    if not isFinite(playerSpeed) or playerSpeed <= 0 then return nil, 'NoPlayerSpeed' end
    local width = radius * 2 + (def.safeWidthExtra or def.gapMinClearWidth or 80)
    local projectileRadius = 35
    local halfAngle = math.deg(math.asin(clamp((width + 2 * projectileRadius) / (2 * distance), 0, 0.95)))
    halfAngle = math.max(20, halfAngle)
    if halfAngle >= 58 then return nil, 'GapTooNarrow' end
    local toward = unit(sub(targetPos, bossPos))
    local offsets = { 0, -25, 25 }
    for i = 1, #offsets do
        local axis = rotate(toward, offsets[i])
        local endpoint
        if def.id == Types.SkillID.S7 then
            endpoint = add(bossPos, mul(axis, (def.hitRadius or 900) + radius + 80))
        else
            endpoint = add(bossPos, mul(axis, distance))
        end
        local travel = len(sub(endpoint, targetPos))
        if travel <= playerSpeed * (def.windup or 0)
            and adapter:CheckSafeRoute(targetPos, endpoint, width, def.windup, ctx.target) then
            return { axis = axis, endpoint = endpoint, width = width,
                halfAngle = halfAngle, relativeAngle = offsets[i] }
        end
    end
    return nil, 'NoSafeRoute'
end

-- 纯预验证，供 Plan 与最终 Begin 共用。任何必需能力缺失时拒绝。
function Graybox.Prepare(def, ctx, adapter, boss)
    if not def or not ctx or not adapter or not boss then return nil, 'MissingContext' end
    if not hasMethod(adapter, 'IsServer') or not adapter:IsServer() then return nil, 'NotAuthority' end
    if not ctx.targetValid or not ctx.hasLOS or not ctx.target then return nil, 'NoVisibleTarget' end
    if not adapter:IsValidTarget(ctx.target) or not adapter:HasLOS(ctx.target) then return nil, 'NoVisibleTarget' end
    local bossPos, targetPos = adapter:GetPosition(boss), adapter:GetPosition(ctx.target)
    if not validPosition(bossPos) or not validPosition(targetPos) then return nil, 'InvalidPosition' end
    local radius = adapter:GetRadius(ctx.target)
    if not isFinite(radius) or radius <= 0 then return nil, 'UnknownTargetRadius' end
    local bossRadius = adapter:GetRadius(boss)
    if not isFinite(bossRadius) or bossRadius <= 0 then return nil, 'UnknownBossRadius' end
    local edge = math.max(0, len(sub(targetPos, bossPos)) - bossRadius - radius)
    if edge < def.minDist - 0.001 or edge > def.maxDist + 0.001 then return nil, 'OutOfRange' end
    local height = math.abs(targetPos.Z - bossPos.Z)
    if height > (ctx.heightTolerance or 300) then return nil, 'HeightDiff' end
    if not hasMethod(adapter, 'HasClearDamagePath')
        or not adapter:HasClearDamagePath(bossPos, targetPos, ctx.target) then return nil, 'Blocked' end
    if not hasMethod(adapter, 'ApplyDamage') then return nil, 'NoDamageAdapter' end
    if (def.id == 1 or def.id == 3 or def.id == 4)
        and not hasMethod(adapter, 'MoveSwept') then return nil, 'NoSweptMovement' end
    if (def.id == 4 or def.id == 6) and not hasMethod(adapter, 'StartProjectile') then
        return nil, 'NoProjectileAdapter'
    end
    if def.id == 2 or def.id == 3 or def.id == 4
        or def.id == 5 or def.id == 6 or def.id == 7 then
        if not hasMethod(adapter, 'CanShowWarning') or not adapter:CanShowWarning(ctx.target) then
            return nil, 'NoReplicatedWarning'
        end
    end
    local plan = { boss = boss, target = ctx.target, targetAtStart = targetPos,
        bossAtStart = bossPos, direction = unit(sub(targetPos, bossPos)),
        heightTolerance = ctx.heightTolerance or 300, targetRadius = radius,
        bossRadius = bossRadius, warnings = {} }
    if def.id == 3 then
        if ctx.pathOk == false or not hasMethod(adapter, 'CheckDash')
            or not adapter:CheckDash(bossPos, plan.direction, def.dashMaxDistance,
                bossRadius, ctx.target) then
            return nil, 'NoSafeDashChannel'
        end
    elseif def.id == 5 then
        local velocity = adapter:GetVelocity(ctx.target) or v(0, 0, 0)
        local predict = clamp(def.predictMaxSeconds or 0, 0, 0.6)
        local forward = unit(sub(targetPos, bossPos))
        local lateral = rotate(forward, 90)
        local predicted = add(targetPos, mul(velocity, predict))
        if len(sub(predicted, targetPos)) < 220 then
            predicted = add(targetPos, mul(forward, 240))
        end
        plan.points = {
            v(targetPos.X, targetPos.Y, targetPos.Z),
            predicted,
            add(targetPos, mul(lateral, 300)),
        }
    elseif def.id == 6 or def.id == 7 then
        local safe, reason = makeSafeRoute(def, ctx, adapter, bossPos, targetPos, radius)
        if not safe then return nil, reason end
        plan.safe = safe
    end
    return plan
end

function Graybox.Begin(action, adapter)
    local def = action.def
    local shapes = {}
    if def.id == 2 then
        -- 客户端现有灰盒画圆，保守覆盖实际的前半圆及目标胶囊膨胀。
        shapes[1] = { kind = 'front-slam', center = action.bossAtStart,
            radius = def.hitRadius + action.targetRadius,
            duration = def.windup + def.active,
            direction = action.direction }
    elseif def.id == 5 then
        for i = 1, 3 do shapes[i] = { kind = 'fixed-point', center = action.points[i],
            radius = def.hitRadius + action.targetRadius,
            duration = def.windup + def.hitWindows[i][2] } end
    elseif def.id == 6 then
        local reach = def.projectile.speed * def.projectile.life + action.targetRadius
        shapes[1] = { kind = 'fan-with-gap', center = action.bossAtStart, direction = action.direction,
            radius = reach, length = reach,
            safe = action.safe,
            duration = def.windup + def.active + def.projectile.life }
    elseif def.id == 7 then
        shapes[1] = { kind = 'split-burst', center = action.bossAtStart,
            radius = def.hitRadius + action.targetRadius,
            direction = action.direction, safe = action.safe,
            duration = def.windup + def.active }
    end
    for i = 1, #shapes do
        local handle, projected = adapter:ShowWarning(shapes[i], action.target, action.warningId, i)
        if not handle or (def.id == 5 and not validPosition(projected)) then
            if handle then adapter:HideWarning(handle) end
            for j = 1, #action.warnings do adapter:HideWarning(action.warnings[j]) end
            action.warnings = {}
            return false, 'WarningUnavailable'
        end
        if def.id == 5 then
            -- 伤害必须使用客户端实际收到的地面投影，而非角色胶囊中心。
            action.points[i] = v(projected.X, projected.Y, projected.Z)
        end
        action.warnings[#action.warnings + 1] = handle
    end
    if def.id == 2 or def.id == 5 or def.id == 6 or def.id == 7 then
        -- 一旦客户端看到落点/安全缺口，服务器命中几何也固定，不能再转向偷袭。
        action.directionLocked = true
    end
    return true
end

local function spawnProjectile(action, runtime, direction, now, ordinal)
    local adapter, def = runtime.adapter, action.def
    local life = math.min(def.projectile.life or 2, def.maxDangerLife or 2, 2)
    local origin = adapter:GetPosition(action.boss)
    local spec = { origin = origin, direction = direction, speed = def.projectile.speed,
        life = life, radius = 35, target = action.target, damage = def.hitDamage,
        skillId = action.skillId, actionId = action.id, ordinal = ordinal }
    local dangerId, handle, counted
    local function stop()
        if dangerId then
            local id = dangerId
            dangerId = nil
            runtime.state:UnregisterDanger(id)
        end
        if counted then
            counted = false
            action.liveProjectiles = math.max(0, (action.liveProjectiles or 1) - 1)
        end
        if action.terminal and (action.liveProjectiles or 0) == 0
            and action.persistentWarning then
            adapter:HideWarning(action.persistentWarning)
            action.persistentWarning = nil
        end
    end
    local function hit(target)
        if dangerId and adapter:IsServer() and adapter:IsValidTarget(target)
            and adapter:HasClearDamagePath(origin, adapter:GetPosition(target), target) then
            adapter:ApplyDamage(target, def.hitDamage, action.skillId, action.id)
        end
        if handle then handle:Stop() end
        stop()
    end
    handle = adapter:StartProjectile(spec, hit, stop)
    if not handle or type(handle.Stop) ~= 'function' then return false end
    dangerId = runtime.state:RegisterDanger(action.skillId, action.id, now + life,
        function() handle:Stop(); stop() end)
    if not dangerId then handle:Stop(); return false end
    counted = true
    action.liveProjectiles = (action.liveProjectiles or 0) + 1
    return true
end

local function projectileDirection(def, action, index)
    local count = def.projectile.count or 3
    local spread = def.projectile.spreadDeg or 0
    local offset = count > 1 and ((index - 1) / (count - 1) * 2 - 1) * spread or 0
    return rotate(action.direction, offset)
end

local function fanDirections(action)
    local out = {}
    local gap = action.safe.relativeAngle
    -- 弹体中心再让出五度余量，避免球形碰撞体擦入玩家可走的安全区。
    local half = action.safe.halfAngle + 5
    local span = (action.def.projectile.spreadDeg or 120) / 2
    local count = action.def.projectile.bulletsPerRound or 9
    -- 均匀填充安全缺口之外的两侧角带；两轮使用同一模板。
    local left = math.max(0, gap - half + span)
    local right = math.max(0, span - (gap + half))
    local total = left + right
    if total <= 0 then return out end
    for i = 1, count do
        local along = total * (i - 0.5) / count
        local angle = along <= left and (-span + along) or (gap + half + along - left)
        out[#out + 1] = rotate(action.direction, angle)
    end
    return out
end

local function damageBurst(action, adapter, key)
    damageTarget(action, adapter, action.def.hitDamage, key, function(target, origin)
        local delta = sub(target, origin)
        local distance = len(delta)
        if distance > action.def.hitRadius + (adapter:GetRadius(action.target) or 0) then return false end
        local cosGap = math.cos(math.rad(action.safe.halfAngle))
        return distance < 0.001 or dot(unit(delta), action.safe.axis) < cosGap
    end)
end

local function dashStep(action, adapter, seconds)
    if seconds <= 0 or action.dashBlocked then return end
    local remaining = math.max(0, math.min(action.def.dashMaxDistance, 1500) - action.dashDistance)
    local wanted = math.min(remaining, (action.def.graybox.dashSpeed or 2200) * seconds)
    if wanted <= 0 then return end
    local before = adapter:GetPosition(action.boss)
    local moved = adapter:MoveSwept(mul(action.direction, wanted))
    moved = isFinite(moved) and clamp(moved, 0, wanted) or 0
    local after = adapter:GetPosition(action.boss)
    action.dashDistance = action.dashDistance + moved
    if moved < wanted - 1 then action.dashBlocked = true end
    damageTarget(action, adapter, action.def.hitDamage, 'dash', function(target)
        return targetDistanceToSegment(target, before, after)
            <= (action.def.hitRadius or 180) + (adapter:GetRadius(action.target) or 0)
    end)
end

function Graybox.Tick(action, runtime, previousElapsed, elapsed, now)
    local adapter, def = runtime.adapter, action.def
    if not action.directionLocked and elapsed >= (def.aimLockAt or 0) then
        lockDirection(action, adapter)
        if def.id == 3 then
            local origin = adapter:GetPosition(action.boss)
            local lastDamageAt = action.startedAt + def.windup + def.active
            if now + 0.45 >= lastDamageAt - 0.000001 then
                -- 丢帧后不能同 Tick 画线并突进：已没有完整可见的预警窗口。
                action.warningFailure = 'DashTelegraphMissed'
            elseif not origin or not adapter:CheckDash(origin, action.direction,
                def.dashMaxDistance, action.bossRadius, action.target) then
                action.warningFailure = 'DashChannelChanged'
            else
                local shape = { kind = 'dash-line', center = origin, direction = action.direction,
                    radius = def.hitRadius + action.targetRadius, length = def.dashMaxDistance,
                    duration = lastDamageAt - now }
                local handle = adapter:ShowWarning(shape, action.target, action.warningId, 1)
                if handle then
                    action.warnings[#action.warnings + 1] = handle
                    action.dashWarningAt = now
                else action.warningFailure = 'DashWarningUnavailable' end
            end
        end
    end
    if action.warningFailure then return end
    local activeStart, activeEnd = def.windup, def.windup + def.active
    local from = math.max(previousElapsed, activeStart)
    local to = math.min(elapsed, activeEnd)
    local activeSeconds = math.max(0, to - from)
    if def.id == 1 then
        if activeSeconds > 0 and action.stepDistance < (def.maxMoveAdvance or 100) then
            local wanted = math.min((def.maxMoveAdvance or 100) - action.stepDistance,
                (def.graybox.advanceSpeed or 150) * activeSeconds)
            local moved = adapter:MoveSwept(mul(action.direction, wanted))
            if isFinite(moved) and moved > 0 then action.stepDistance = action.stepDistance + moved end
        end
        for i = 1, 2 do
            local at = activeStart + (def.hitWindows[i][1] + def.hitWindows[i][2]) / 2
            if previousElapsed < at and elapsed >= at then
                arcHit(action, adapter, 'slash-' .. i, def.hitRadius, (def.hitAngle or 120) / 2, def.hitDamage)
            end
        end
    elseif def.id == 2 then
        local at = activeStart + (def.hitWindows[1][1] + def.hitWindows[1][2]) / 2
        if previousElapsed < at and elapsed >= at then
            arcHit(action, adapter, 'slam', def.hitRadius, 90, def.hitDamage)
        end
    elseif def.id == 3 then
        local lastDamageAt = action.startedAt + activeEnd
        local telegraphGate = action.dashWarningAt and action.dashWarningAt + 0.45 or math.huge
        local moveFrom = math.max(action.startedAt + previousElapsed,
            action.startedAt + activeStart, telegraphGate)
        local moveTo = math.min(now, lastDamageAt)
        dashStep(action, adapter, math.max(0, moveTo - moveFrom))
    elseif def.id == 4 then
        if activeSeconds > 0 then
            local wanted = (def.maxAdvanceSpeed or 200) * activeSeconds
            adapter:MoveSwept(mul(action.direction, wanted))
        end
        for i = 1, def.projectile.count do
            local at = activeStart + 0.05 + (i - 1) * 0.20
            if previousElapsed < at and elapsed >= at then
                if not spawnProjectile(action, runtime,
                    projectileDirection(def, action, i), now, i) then
                    action.projectileFailure = true
                end
            end
        end
    elseif def.id == 5 then
        for i = 1, 3 do
            local at = activeStart + (def.hitWindows[i][1] + def.hitWindows[i][2]) / 2
            if previousElapsed < at and elapsed >= at then
                pointHit(action, adapter, 'point-' .. i, action.points[i], def.hitRadius, def.hitDamage)
            end
        end
    elseif def.id == 6 then
        for round = 1, 2 do
            local at = activeStart + (round == 1 and 0.05 or 0.75)
            if previousElapsed < at and elapsed >= at then
                if not adapter:CheckSafeRoute(action.targetAtStart, action.safe.endpoint,
                    action.safe.width, def.windup, action.target) then
                    action.warningFailure = 'SafeRouteChanged'
                    return
                end
                local directions = fanDirections(action)
                for i = 1, #directions do
                    local ordinal = (round - 1) * #directions + i
                    if not spawnProjectile(action, runtime, directions[i], now, ordinal) then
                        action.projectileFailure = true
                    end
                end
            end
        end
    elseif def.id == 7 then
        for i = 1, 2 do
            local at = activeStart + (def.hitWindows[i][1] + def.hitWindows[i][2]) / 2
            if previousElapsed < at and elapsed >= at then
                if not adapter:CheckSafeRoute(action.targetAtStart, action.safe.endpoint,
                    action.safe.width, def.windup, action.target) then
                    action.warningFailure = 'SafeRouteChanged'
                    return
                end
                damageBurst(action, adapter, 'burst-' .. i)
            end
        end
    end
end

function Graybox.End(action, adapter)
    action.damageEnabled = false
    for i = 1, #action.warnings do
        if action.def.id == 6 and i == 1 and (action.liveProjectiles or 0) > 0 then
            -- 最后一轮飞弹可越过后摇；安全缺口必须与实际危险一同存在。
            action.persistentWarning = action.warnings[i]
        else
            adapter:HideWarning(action.warnings[i])
        end
    end
    action.warnings = {}
end

-- 默认 UGC 适配器。安全查询异常一律返回 false；无复制警示资产时地面/弹幕拒绝。
local UGCAdapter = {}
UGCAdapter.__index = UGCAdapter
local RPCWarningProvider = {}
RPCWarningProvider.__index = RPCWarningProvider
local warningKindCode = {
    ['front-slam'] = 2, ['dash-line'] = 3, ['projectile'] = 4,
    ['fixed-point'] = 5,
    ['fan-with-gap'] = 6, ['split-burst'] = 7,
}
function Graybox.NewRPCWarningProvider(gameSystem, network)
    return setmetatable({ gameSystem = gameSystem, network = network }, RPCWarningProvider)
end
function RPCWarningProvider:GetClient(target)
    if not self.gameSystem or not self.gameSystem.GetControllerByPawn or not target then return nil end
    local ok, pc = pcall(self.gameSystem.GetControllerByPawn, target)
    return ok and pc or nil
end
function RPCWarningProvider:CanShow(target)
    if not self.network or not self.network.CallUnrealRPC then return false end
    local pc = self:GetClient(target)
    if not pc or not pc.GetAvailableClientRPCs then return false end
    local ok, a, b, c, d = pcall(pc.GetAvailableClientRPCs, pc)
    if not ok then return false end
    local show, stop = false, false
    for _, name in ipairs({ a, b, c, d }) do
        if name == 'Client_BossWarning' then show = true end
        if name == 'Client_BossWarningStop' then stop = true end
    end
    return show and stop
end
function RPCWarningProvider:Show(boss, shape, target, actionId, shapeIndex)
    if not self:CanShow(target) or not shape or not shape.center then return nil end
    local pc = self:GetClient(target)
    if not pc then return nil end
    local bossKey = tostring(boss)
    if boss and boss.GetName then
        local ok, name = pcall(boss.GetName, boss)
        if ok and name then bossKey = tostring(name) end
    end
    local direction = shape.direction or v(1, 0, 0)
    local safe = shape.safe or {}
    local kind = warningKindCode[shape.kind]
    if not kind then return nil end
    local args = { bossKey, actionId, shapeIndex, kind,
        shape.center.X, shape.center.Y, shape.center.Z,
        shape.radius or 0, shape.duration or 0,
        direction.X, direction.Y, shape.length or 0,
        safe.relativeAngle or 0, safe.halfAngle or 0 }
    for i = 1, #args do
        if type(args[i]) ~= 'string' and not isFinite(args[i]) then return nil end
    end
    local ok = pcall(self.network.CallUnrealRPC, pc, pc, 'Client_BossWarning',
        bossKey, actionId, shapeIndex, kind,
        shape.center.X, shape.center.Y, shape.center.Z,
        shape.radius or 0, shape.duration or 0,
        direction.X, direction.Y, shape.length or 0,
        safe.relativeAngle or 0, safe.halfAngle or 0)
    if not ok then return nil end
    return { pc = pc, bossKey = bossKey, actionId = actionId, shapeIndex = shapeIndex }
end
function RPCWarningProvider:Hide(handle)
    if not handle or not self.network or not self.network.CallUnrealRPC then return end
    pcall(self.network.CallUnrealRPC, handle.pc, handle.pc, 'Client_BossWarningStop',
        handle.bossKey, handle.actionId, handle.shapeIndex)
end
local function ueVector(p)
    if Vector and Vector.New then return Vector.New(p.X, p.Y, p.Z) end
    return p
end
local function ueValid(actor)
    if not actor then return false end
    if UE and UE.IsValid then
        local ok, valid = pcall(UE.IsValid, actor)
        return ok and valid == true
    end
    return false
end
local function capsuleSize(actor, getter)
    if not ueValid(actor) then return nil end
    local function read(capsule)
        if not ueValid(capsule) then return nil end
        local ok, method = pcall(function() return capsule[getter] end)
        if not ok or not method then return nil end
        local got, value = pcall(method, capsule)
        return got and isFinite(value) and value > 0 and value or nil
    end
    local ok, method = pcall(function() return actor.GetCapsuleComponent end)
    if ok and method then
        local got, capsule = pcall(method, actor)
        if got then
            local value = read(capsule)
            if value then return value end
        end
    end
    -- UGC characters expose the collision component as a property even when
    -- the standard Character getter is absent from the Lua binding.
    for _, name in ipairs({ 'CapsuleComponent', 'HitBox', 'HitBox_Stand' }) do
        local got, capsule = pcall(function() return actor[name] end)
        if got then
            local value = read(capsule)
            if value then return value end
        end
    end
    return nil
end
local function traceIgnoreList(owner, target)
    local ignored = { owner }
    if target and target ~= owner then ignored[#ignored + 1] = target end
    return ignored
end
function Graybox.NewUGCAdapter(pawn, controller, options)
    local provider = options and options.warningProvider or nil
    if provider == nil and UGCGameSystem and UnrealNetwork then
        provider = Graybox.NewRPCWarningProvider(UGCGameSystem, UnrealNetwork)
    end
    return setmetatable({ pawn = pawn, controller = controller,
        warningProvider = provider }, UGCAdapter)
end
function UGCAdapter:IsServer()
    if self.pawn and self.pawn.HasAuthority then
        local ok, authority = pcall(self.pawn.HasAuthority, self.pawn)
        return ok and authority == true
    end
    return UGCGameSystem and UGCGameSystem.IsServer and UGCGameSystem.IsServer() == true
end
function UGCAdapter:IsValidTarget(target) return ueValid(target) end
function UGCAdapter:GetPosition(actor)
    if not ueValid(actor) then return nil end
    local ok, pos = pcall(actor.K2_GetActorLocation, actor)
    return ok and pos or nil
end
function UGCAdapter:GetVelocity(actor)
    if not ueValid(actor) or not actor.GetVelocity then return v(0, 0, 0) end
    local ok, vel = pcall(actor.GetVelocity, actor)
    return ok and vel or v(0, 0, 0)
end
function UGCAdapter:GetRadius(actor)
    return capsuleSize(actor, 'GetScaledCapsuleRadius')
end
function UGCAdapter:GetSpeed(actor)
    if not ueValid(actor) or not actor.GetMovementComponent then return nil end
    local ok, movement = pcall(actor.GetMovementComponent, actor)
    return ok and movement and movement.MaxWalkSpeed or nil
end
function UGCAdapter:HasLOS(target)
    if not ueValid(target) then return false end
    local a, b = self:GetPosition(self.pawn), self:GetPosition(target)
    if not a or not b or not KismetSystemLibrary or not KismetSystemLibrary.LineTraceSingle
        or not ETraceTypeQuery or not ETraceTypeQuery.TraceTypeQuery1 then return false end
    local ok, blocked = pcall(function()
        local hit = KismetSystemLibrary.LineTraceSingle(self.pawn, ueVector(a), ueVector(b),
            ETraceTypeQuery.TraceTypeQuery1, false, { self.pawn, target },
            EDrawDebugTrace and EDrawDebugTrace.None or nil, {}, true)
        return hit == true
    end)
    return ok and not blocked
end
function UGCAdapter:HasClearDamagePath(from, to, target)
    if not from or not to or not KismetSystemLibrary or not KismetSystemLibrary.LineTraceSingle
        or not ETraceTypeQuery or not ETraceTypeQuery.TraceTypeQuery1 then return false end
    local ok, blocked = pcall(function()
        local hit = KismetSystemLibrary.LineTraceSingle(self.pawn, ueVector(from), ueVector(to),
            ETraceTypeQuery.TraceTypeQuery1, false, traceIgnoreList(self.pawn, target),
            EDrawDebugTrace and EDrawDebugTrace.None or nil, {}, true)
        return hit == true
    end)
    return ok and not blocked
end
function UGCAdapter:HasClearProjectilePath(from, to, radius, target)
    if not KismetSystemLibrary or not KismetSystemLibrary.SphereTraceSingle
        or not ETraceTypeQuery or not ETraceTypeQuery.TraceTypeQuery1 then return false end
    local ok, blocked = pcall(function()
        local hit = KismetSystemLibrary.SphereTraceSingle(self.pawn,
            ueVector(from), ueVector(to), radius, ETraceTypeQuery.TraceTypeQuery1,
            false, traceIgnoreList(self.pawn, target),
            EDrawDebugTrace and EDrawDebugTrace.None or nil, {}, true)
        return hit == true
    end)
    return ok and not blocked
end
local function capsuleClear(adapter, startPos, endPos, radius, halfHeight, target)
    if not KismetSystemLibrary or not KismetSystemLibrary.CapsuleTraceSingle
        or not ETraceTypeQuery or not ETraceTypeQuery.TraceTypeQuery1 then return false end
    local ok, blocked = pcall(function()
        local hit = KismetSystemLibrary.CapsuleTraceSingle(adapter.pawn,
            ueVector(startPos), ueVector(endPos), radius, halfHeight,
            ETraceTypeQuery.TraceTypeQuery1, false,
            traceIgnoreList(adapter.pawn, target),
            EDrawDebugTrace and EDrawDebugTrace.None or nil, {}, true)
        return hit == true
    end)
    return ok and not blocked
end
function UGCAdapter:CheckDash(startPos, direction, distance, radius, target)
    local halfHeight = capsuleSize(self.pawn, 'GetScaledCapsuleHalfHeight')
    if not halfHeight then return false end
    local endPos = add(startPos, mul(direction, distance))
    -- 整段与终点均按 Boss 的真实缩放胶囊扫掠。
    return capsuleClear(self, startPos, endPos, radius, halfHeight, target)
        and capsuleClear(self, endPos, endPos, radius + 10, halfHeight, target)
end
function UGCAdapter:CheckSafeRoute(startPos, endPos, width, seconds, target)
    local speed = self:GetSpeed(target)
    if not isFinite(speed) or speed <= 0 or len(sub(endPos, startPos)) > speed * seconds then return false end
    local radius = width / 2
    local halfHeight = capsuleSize(target, 'GetScaledCapsuleHalfHeight')
    if not halfHeight then return false end
    -- 多点采样防止单一查询在动态障碍处误判。每段按玩家半径+40 膨胀。
    local steps = math.max(1, math.ceil(len(sub(endPos, startPos)) / 150))
    for i = 0, steps - 1 do
        local a = add(startPos, mul(sub(endPos, startPos), i / steps))
        local b = add(startPos, mul(sub(endPos, startPos), (i + 1) / steps))
        if not capsuleClear(self, a, b, radius, halfHeight, target) then return false end
    end
    local navClass = NavigationSystem or UNavigationSystem
    if not UGCNavigationSystem or not UGCNavigationSystem.ProjectPointToNavigation
        or not navClass or not navClass.FindPathToLocationSynchronously then return false end
    local queryExtent = ueVector(v(radius, radius, halfHeight))
    local function project(point)
        local ok, projected, navPoint = pcall(UGCNavigationSystem.ProjectPointToNavigation,
            self.pawn, ueVector(point), queryExtent)
        if not ok or projected ~= true or not validPosition(navPoint)
            or len(sub(navPoint, point)) > radius
            or math.abs(navPoint.Z - point.Z) > halfHeight + 80 then return nil end
        return navPoint
    end
    local navStart, navEnd = project(startPos), project(endPos)
    if not navStart or not navEnd then return false end
    -- NavMesh 必须证明整条路可达；只有终点可投影不能排除断裂的岛。
    local found, path = pcall(navClass.FindPathToLocationSynchronously,
        self.pawn, ueVector(navStart), ueVector(navEnd), target, nil)
    if not found or not path or not path.IsValid or not path.IsPartial
        or not path.GetPathLength then return false end
    local okValid, valid = pcall(path.IsValid, path)
    local okPartial, partial = pcall(path.IsPartial, path)
    local okLength, pathLength = pcall(path.GetPathLength, path)
    local directLength = len(sub(navEnd, navStart))
    if not okValid or valid ~= true or not okPartial or partial ~= false
        or not okLength or not isFinite(pathLength)
        or pathLength > directLength + math.max(30, width * 0.25)
        or pathLength > speed * seconds then return false end
    return true
end
function UGCAdapter:AcquireMovement(def)
    if not self.pawn or not self.pawn.K2_AddActorWorldOffset then return nil end
    if self.controller and self.controller.StopMovement then pcall(self.controller.StopMovement, self.controller) end
    local move = self.pawn.GetMovementComponent and self.pawn:GetMovementComponent() or nil
    local token = { movement = move, speed = move and move.MaxWalkSpeed or nil }
    if move and def.id == 4 and move.MaxWalkSpeed then
        move.MaxWalkSpeed = math.min(move.MaxWalkSpeed, def.maxAdvanceSpeed or 200)
    end
    return token
end
function UGCAdapter:ReleaseMovement(token)
    if token and token.movement and token.speed then token.movement.MaxWalkSpeed = token.speed end
end
function UGCAdapter:MoveSwept(delta)
    if not self.pawn or not self.pawn.K2_AddActorWorldOffset then return 0 end
    local before = self:GetPosition(self.pawn)
    if not before then return 0 end
    local ok = pcall(self.pawn.K2_AddActorWorldOffset, self.pawn, ueVector(delta), true, {}, false)
    if not ok then return 0 end
    local after = self:GetPosition(self.pawn)
    return after and len(sub(after, before)) or 0
end
function UGCAdapter:ApplyDamage(target, amount, _skillId, _actionId)
    if not self:IsServer() or not ueValid(target) or not UGCGameSystem
        or not UGCGameSystem.ApplyDamage then return false end
    local controller = self.controller
    if not controller and UGCGameSystem.GetControllerByPawn then
        controller = UGCGameSystem.GetControllerByPawn(self.pawn)
    end
    local ok, actualDamage = pcall(UGCGameSystem.ApplyDamage,
        target, amount, controller, self.pawn, nil)
    -- LuaHelper: ApplyDamage 返回实际伤害 number；0 可是合法格挡，nil/false 是调用失败。
    return ok and isFinite(actualDamage) and actualDamage >= 0
end
function UGCAdapter:CanShowWarning(target)
    return self.warningProvider ~= nil and type(self.warningProvider.Show) == 'function'
        and type(self.warningProvider.Hide) == 'function'
        and type(self.warningProvider.CanShow) == 'function'
        and self.warningProvider:CanShow(target) == true
end
function UGCAdapter:ProjectWarningToGround(point, target)
    if not point or not KismetSystemLibrary or not KismetSystemLibrary.LineTraceSingle
        or not ETraceTypeQuery or not ETraceTypeQuery.TraceTypeQuery1 then return nil end
    local above = add(point, v(0, 0, 150))
    local below = add(point, v(0, 0, -1200))
    -- LuaHelper's out parameter can be mutated in place or returned as a second value.
    local outHit = {}
    local ok, hit, returnedHit = pcall(KismetSystemLibrary.LineTraceSingle, self.pawn,
        ueVector(above), ueVector(below), ETraceTypeQuery.TraceTypeQuery1,
        false, traceIgnoreList(self.pawn, target),
        EDrawDebugTrace and EDrawDebugTrace.None or nil, outHit, true)
    local hitResult = returnedHit or outHit
    if not ok or hit ~= true or not hitResult then return nil end
    local impact = hitResult.ImpactPoint or hitResult.Location
    if not validPosition(impact) then return nil end
    local normal = hitResult.ImpactNormal
    if not normal or not isFinite(normal.Z) or normal.Z < 0.6 then return nil end
    return v(impact.X, impact.Y, impact.Z + 5)
end
function UGCAdapter:ShowWarning(shape, target, actionId, shapeIndex)
    if self:CanShowWarning(target) then
        local location = shape.center
        if shape.kind ~= 'projectile' then
            location = self:ProjectWarningToGround(shape.center, target)
            if not location then return nil end
        end
        local projectedShape = {}
        for key, value in pairs(shape) do projectedShape[key] = value end
        projectedShape.center = location
        local ok, handle = pcall(self.warningProvider.Show, self.warningProvider,
            self.pawn, projectedShape, target, actionId, shapeIndex)
        if ok and handle then return handle, location end
    end
    return nil
end
function UGCAdapter:HideWarning(handle)
    if self.warningProvider and self.warningProvider.Hide then
        pcall(self.warningProvider.Hide, self.warningProvider, handle)
    end
end
function UGCAdapter:StartProjectile(spec, onHit, onStop)
    if not self:IsServer() or not UGCGameSystem or not UGCGameSystem.SetTimer
        or not UGCGameSystem.ClearTimer or not KismetSystemLibrary then return nil end
    local owner = self.pawn
    local projectile = { active = true, position = spec.origin, travelled = 0,
        handle = nil, delegate = nil }
    local adapter = self
    projectile.visual = self:ShowWarning({ kind = 'projectile', center = spec.origin,
        direction = spec.direction, radius = spec.radius, duration = spec.life,
        length = spec.speed * spec.life }, spec.target, spec.actionId, 100 + spec.ordinal)
    if not projectile.visual then return nil end
    function projectile:Stop()
        if not self.active and not self.handle and not self.visual then return end
        self.active = false
        if self.handle then
            local cleared, clearError = pcall(UGCGameSystem.ClearTimer, owner, self.handle)
            if not cleared then error(clearError) end -- 保留句柄和 delegate 供危险清理重试
            self.handle = nil
        end
        self.delegate = nil
        if self.visual then adapter:HideWarning(self.visual); self.visual = nil end
        if onStop and not self.stopNotified then
            self.stopNotified = true
            onStop()
        end
    end
    local interval = 0.05
    local function tick()
        if not projectile.active or not ueValid(owner) or not adapter:IsServer() then
            projectile:Stop()
            return
        end
        local old = projectile.position
        local nextPos = add(old, mul(spec.direction, spec.speed * interval))
        projectile.travelled = projectile.travelled + spec.speed * interval
        if not adapter:HasClearProjectilePath(old, nextPos, spec.radius, spec.target) then
            projectile:Stop()
            return
        end
        local targetPos = adapter:IsValidTarget(spec.target) and adapter:GetPosition(spec.target) or nil
        if targetPos and math.abs(targetPos.Z - nextPos.Z) <= 180
            and targetDistanceToSegment(targetPos, old, nextPos)
                <= spec.radius + (adapter:GetRadius(spec.target) or 0) then
            onHit(spec.target)
            projectile:Stop()
            return
        end
        projectile.position = nextPos
        if KismetSystemLibrary.DrawDebugLine then
            pcall(KismetSystemLibrary.DrawDebugLine, owner, ueVector(old), ueVector(nextPos),
                { R = 1, G = 0.5, B = 0, A = 1 }, interval * 2, 3)
        end
        if projectile.travelled >= spec.speed * spec.life then projectile:Stop() end
    end
    local ok, handle, delegate = pcall(UGCGameSystem.SetTimer, owner, tick, interval, true)
    if not ok or not handle then projectile:Stop(); return nil end
    projectile.handle = handle
    projectile.delegate = delegate
    return projectile
end
function UGCAdapter:ScheduleWatchdog(seconds, callback)
    if not UGCGameSystem or not UGCGameSystem.SetTimer then return nil end
    local ok, handle, delegate = pcall(UGCGameSystem.SetTimer,
        self.pawn, callback, seconds, false)
    return ok and handle and { handle = handle, delegate = delegate } or nil
end
function UGCAdapter:CancelWatchdog(token)
    if token and token.handle and UGCGameSystem and UGCGameSystem.ClearTimer then
        pcall(UGCGameSystem.ClearTimer, self.pawn, token.handle)
        token.handle = nil
        token.delegate = nil
    end
end

return Graybox
