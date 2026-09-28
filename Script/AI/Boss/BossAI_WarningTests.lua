-- Pure Lua contract tests for UGCPlayerController's client-side Boss warnings.
-- Run outside PIE with a Lua runtime (for example, Python lupa).
local Controller = require('Script.Blueprint.UGCPlayerController')
local Graybox = require('Script.AI.Boss.BossAI_Graybox')

local Tests = {}

local function equal(actual, expected, label)
    assert(actual == expected, string.format('%s: got %s, expected %s',
        label, tostring(actual), tostring(expected)))
end

local function harness(fn)
    assert(_G.UE == nil, 'BossAI_WarningTests uses stub engine APIs; run outside PIE')
    local oldGameSystem, oldDebugSystem = _G.UGCGameSystem, _G.UGCDebugSystem
    local oldSuperClass = Controller.SuperClass
    local h = { now = 10, draws = {}, timer = nil, timersCreated = 0 }
    _G.UGCGameSystem = {
        GetTimeSeconds = function() return h.now end,
        SetTimer = function(_, callback, interval, looping)
            equal(interval, 0.1, 'warning redraw interval')
            equal(looping, true, 'warning timer repeats')
            h.timersCreated = h.timersCreated + 1
            h.timer = { callback = callback, active = true }
            return h.timer
        end,
        ClearTimer = function(_, timer)
            equal(timer, h.timer, 'cleared timer')
            timer.active = false
        end,
    }
    _G.UGCDebugSystem = {
        DrawDebugCircle = function(...)
            h.draws[#h.draws + 1] = { kind = 'circle', args = { ... } }
        end,
        DrawDebugLine = function(...)
            h.draws[#h.draws + 1] = { kind = 'line', args = { ... } }
        end,
        DrawDebugBox = function(...)
            h.draws[#h.draws + 1] = { kind = 'box', args = { ... } }
        end,
    }
    Controller.SuperClass = { ReceiveEndPlay = function() end }
    local pc = setmetatable({}, { __index = Controller })
    local ok, err = pcall(fn, pc, h)
    _G.UGCGameSystem, _G.UGCDebugSystem = oldGameSystem, oldDebugSystem
    Controller.SuperClass = oldSuperClass
    assert(ok, err)
end

local function drawOfKind(draws, kind)
    local out = {}
    for _, draw in ipairs(draws) do
        if draw.kind == kind then out[#out + 1] = draw end
    end
    return out
end

local function show(pc, bossKey, actionId, shapeIndex, kindCode, x, y, z, radius,
                    duration, dirX, dirY, length, gapCenter, gapHalf)
    pc:Client_BossWarning(bossKey, actionId, shapeIndex, kindCode, x, y, z, radius,
        duration, dirX, dirY, length, gapCenter, gapHalf)
end

local function run(name, fn, results)
    local ok, err = pcall(fn)
    results[#results + 1] = { name = name, pass = ok, detail = ok and '' or tostring(err) }
    print('[BossAI-WarningTest] ' .. name .. ' ' .. (ok and 'PASS' or ('FAIL ' .. tostring(err))))
end

function Tests.RunAll()
    local results = {}

    run('client whitelist preserves existing RPCs and registers warnings', function()
        local names = { Controller:GetAvailableClientRPCs() }
        local set = {}
        for _, name in ipairs(names) do set[name] = true end
        assert(set.Client_UpdateAttriHUD, 'existing HUD client RPC absent')
        assert(set.Client_OnPawnRespawn, 'existing respawn client RPC absent')
        assert(set.Client_BossWarning, 'warning client RPC absent')
        assert(set.Client_BossWarningStop, 'warning stop client RPC absent')
    end, results)

    run('fixed point redraws in XY and expires on local clock', function()
        harness(function(pc, h)
            show(pc, 'BossA', 7, 1, 5, 100, 200, 37, 180, 0.25, 1, 0, 0, 0, 0)
            local circles = drawOfKind(h.draws, 'circle')
            equal(#circles, 1, 'immediate circle count')
            equal(circles[1].args[1].Z, 37, 'warning ground height')
            equal(circles[1].args[2], 180, 'warning radius')
            assert(circles[1].args[4] > 0 and circles[1].args[4] <= 0.15,
                'debug stroke must expire promptly')
            equal(circles[1].args[5].X, 1, 'ground circle first axis X')
            equal(circles[1].args[5].Z, 0, 'ground circle first axis Z')
            equal(circles[1].args[6].Y, 1, 'ground circle second axis Y')
            equal(circles[1].args[6].Z, 0, 'ground circle second axis Z')
            h.now = 10.1
            h.timer.callback()
            equal(#drawOfKind(h.draws, 'circle'), 2, 'circle redraw count')
            h.now = 10.3
            h.timer.callback()
            equal(#drawOfKind(h.draws, 'circle'), 2, 'expired warning draws nothing')
            equal(h.timer.active, false, 'timer clears after expiry')
        end)
    end, results)

    run('stopping one Boss action shape leaves others visible', function()
        harness(function(pc, h)
            show(pc, 'BossA', 7, 1, 5, 100, 0, 0, 80, 1, 1, 0, 0, 0, 0)
            show(pc, 'BossA', 7, 2, 5, 200, 0, 0, 80, 1, 1, 0, 0, 0, 0)
            show(pc, 'BossB', 7, 1, 5, 300, 0, 0, 80, 1, 1, 0, 0, 0, 0)
            show(pc, 'BossA', 8, 1, 5, 400, 0, 0, 80, 1, 1, 0, 0, 0, 0)
            equal(h.timersCreated, 1, 'shared redraw timer count')
            h.draws = {}
            pc:Client_BossWarningStop('BossA', 7, 1)
            h.now = 10.1
            h.timer.callback()
            local circles = drawOfKind(h.draws, 'circle')
            equal(#circles, 3, 'other Boss/action shapes remain')
            local seen = {}
            for _, circle in ipairs(circles) do seen[circle.args[1].X] = true end
            assert(seen[200] and seen[300] and seen[400] and not seen[100],
                'wrong shape survived stop')
            h.draws = {}
            pc:Client_BossWarningStop('BossA', 7, 2)
            h.now = 10.2
            h.timer.callback()
            circles = drawOfKind(h.draws, 'circle')
            equal(#circles, 2, 'second Boss and newer action stay visible')
            seen = {}
            for _, circle in ipairs(circles) do seen[circle.args[1].X] = true end
            assert(seen[300] and seen[400], 'other Boss/action positions')
            pc:Client_BossWarningStop('BossB', 7, 1)
            equal(h.timer.active, true, 'other action keeps timer alive')
            pc:Client_BossWarningStop('BossA', 8, 1)
            equal(h.timer.active, false, 'timer clears after final stop')
        end)
    end, results)

    run('dash corridor uses rotated debug box', function()
        harness(function(pc, h)
            show(pc, 'BossA', 8, 1, 3, 0, 0, 5, 50, 1, 0, 1, 500, 0, 0)
            local boxes = drawOfKind(h.draws, 'box')
            equal(#boxes, 1, 'dash box count')
            equal(boxes[1].args[1].Y, 250, 'dash box midpoint')
            equal(boxes[1].args[2].X, 250, 'dash box half length')
            equal(boxes[1].args[2].Y, 50, 'dash box half width')
            assert(math.abs(boxes[1].args[3].Yaw - 90) < 0.001, 'dash box yaw')
        end)
    end, results)

    run('fan and split burst leave safety angle unmarked as danger', function()
        harness(function(pc, h)
            for _, kind in ipairs({ 6, 7 }) do
                h.draws = {}
                show(pc, 'BossA', kind, 1, kind, 0, 0, 0, 900, 1, 1, 0, 1000, 0, 20)
                local safeLines, dangerousInGap = 0, 0
                for _, draw in ipairs(drawOfKind(h.draws, 'line')) do
                    local a, b, color = draw.args[1], draw.args[2], draw.args[3]
                    if color.G > color.R then safeLines = safeLines + 1 end
                    if color.R > color.G then
                        for _, p in ipairs({ a, b }) do
                            if p.X > 1 and math.abs(p.Y / p.X) < 0.3 then
                                dangerousInGap = dangerousInGap + 1
                            end
                        end
                    end
                end
                assert(safeLines >= 2, 'safety gap boundaries are missing')
                equal(dangerousInGap, 0, 'danger line enters safety angle')
            end
        end)
    end, results)

    run('malformed warning does not draw or schedule', function()
        harness(function(pc, h)
            show(pc, 'BossA', 7, 1, 5, 100, 200, 0, 'bad-radius', 1, 1, 0, 0, 0, 0)
            show(pc, 'BossA', 7, 1, 5, 100, 200, 0, nil, 1, 1, 0, 0, 0, 0)
            show(pc, 'BossA', 7, 1, 5, 100, 200, 0, 80, 1, 1, 0, 0, 0, nil)
            equal(#h.draws, 0, 'malformed draw count')
            equal(h.timersCreated, 0, 'malformed timer count')
        end)
    end, results)

    run('controller EndPlay releases warning redraw timer', function()
        harness(function(pc, h)
            pc.HasAuthority = function() return false end
            show(pc, 'BossA', 7, 1, 5, 100, 200, 0, 80, 1, 1, 0, 0, 0, 0)
            pc:ReceiveEndPlay()
            equal(h.timer.active, false, 'EndPlay clears warning timer')
        end)
    end, results)

    run('malformed stop cannot clear a live warning or crash', function()
        harness(function(pc, h)
            show(pc, 'BossA', 7, 1, 5, 100, 200, 0, 80, 1, 1, 0, 0, 0, 0)
            pc:Client_BossWarningStop('BossA', 7, nil)
            h.draws = {}
            h.now = 10.1
            h.timer.callback()
            equal(#drawOfKind(h.draws, 'circle'), 1, 'warning after malformed stop')
        end)
    end, results)

    run('projectile grayboxes move on fixed trajectories and stop separately', function()
        harness(function(pc, h)
            show(pc, 'BossA', 9, 101, 4, 0, 0, 100, 35, 2, 0, 1, 2800, 0, 0)
            show(pc, 'BossA', 9, 102, 4, 100, 0, 100, 35, 2, 1, 0, 2800, 0, 0)
            local boxes = drawOfKind(h.draws, 'box')
            equal(#boxes, 2, 'initial projectile boxes')
            equal(boxes[1].args[1].Y, 0, 'initial projectile origin')
            h.draws = {}
            h.now = 10.1
            h.timer.callback()
            boxes = drawOfKind(h.draws, 'box')
            equal(#boxes, 2, 'both projectiles before stop')
            assert(math.abs(boxes[1].args[1].Y - 140) < 0.001,
                'first projectile moves 140 cm in 0.1 s')
            pc:Client_BossWarningStop('BossA', 9, 101)
            h.draws = {}
            h.now = 10.2
            h.timer.callback()
            boxes = drawOfKind(h.draws, 'box')
            equal(#boxes, 1, 'second projectile remains')
            assert(math.abs(boxes[1].args[1].X - 380) < 0.001,
                'second projectile follows its own direction')
            pc:Client_BossWarningStop('BossA', 9, 102)
            equal(h.timer.active, false, 'projectile timer stopped')
        end)
    end, results)

    run('projectile visuals reject index collision and lifetime above two seconds', function()
        harness(function(pc, h)
            show(pc, 'BossA', 9, 1, 4, 0, 0, 100, 35, 2, 1, 0, 2800, 0, 0)
            show(pc, 'BossA', 9, 101, 4, 0, 0, 100, 35, 2.1, 1, 0, 2800, 0, 0)
            equal(#h.draws, 0, 'invalid projectile visuals')
            equal(h.timersCreated, 0, 'invalid projectile timer')
        end)
    end, results)

    run('server provider delivers 14 primitive projectile fields and Stop to client', function()
        harness(function(pc, h)
            local target = {}
            local boss = { GetName = function() return 'BossA' end }
            local calls = {}
            local game = { GetControllerByPawn = function(pawn)
                equal(pawn, target, 'warning target')
                return pc
            end }
            local net = { CallUnrealRPC = function(source, destination, method, ...)
                equal(source, pc, 'RPC source controller')
                equal(destination, pc, 'RPC destination controller')
                local args = { ... }
                calls[#calls + 1] = { method = method, count = select('#', ...), args = args }
                destination[method](destination, ...)
            end }
            local provider = Graybox.NewRPCWarningProvider(game, net)
            local handle = provider:Show(boss, {
                kind = 'projectile', center = { X = 0, Y = 0, Z = 100 },
                radius = 35, duration = 2, direction = { X = 0, Y = 1, Z = 0 },
                length = 2800,
            }, target, 9, 101)
            assert(handle, 'server projectile visual handle missing')
            equal(calls[1].method, 'Client_BossWarning', 'show RPC method')
            equal(calls[1].count, 14, 'show RPC data parameter count')
            equal(calls[1].args[4], 4, 'projectile kind code')
            for i = 1, 14 do
                local value = calls[1].args[i]
                assert(type(value) == 'number' or type(value) == 'string',
                    'show RPC contains a non-primitive value')
            end
            equal(#drawOfKind(h.draws, 'box'), 1, 'client drew delivered projectile')
            provider:Hide(handle)
            equal(calls[2].method, 'Client_BossWarningStop', 'stop RPC method')
            equal(calls[2].count, 3, 'stop RPC data parameter count')
            equal(h.timer.active, false, 'client stopped delivered projectile')
        end)
    end, results)

    return results
end

return Tests
