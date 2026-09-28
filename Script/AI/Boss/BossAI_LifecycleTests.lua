-- Pure Lua checks for the real SuperMonster lifecycle callbacks.
local Monster = require('Script.Blueprint.Prefabs.Monsters.SuperMonster')
local Tests = {}

local function equal(actual, expected, label)
    assert(actual == expected, label .. ': got ' .. tostring(actual)
        .. ', expected ' .. tostring(expected))
end

local function harness(fn)
    assert(_G.UE == nil, 'BossAI_LifecycleTests uses stub engine APIs; run outside PIE')
    local oldGame = _G.UGCGameSystem
    local oldCharacter = _G.UGCGenericCharacterSystem
    local oldObject = _G.UGCObjectUtility
    local oldPrint = _G.ugcprint
    local oldSuper = Monster.SuperClass
    local runtimeName = 'Script.AI.Boss.BossAI_SkillRuntime'
    local observedName = 'Script.AI.Boss.BossAI_Observed'
    local oldRuntime = package.loaded[runtimeName]
    local oldObserved = package.loaded[observedName]
    local h = { events = {}, tree = '/TTS/Asset/AI/BT/BT_Boss.BT_Boss',
        server = true, hasRuntime = true, hasObservation = true, releaseClean = true }
    local function event(name) h.events[#h.events + 1] = name end
    _G.UGCGameSystem = {
        IsServer = function()
            if h.throwServer then error('server check unavailable') end
            return h.server
        end,
        GetTimeSeconds = function() return 7 end,
    }
    _G.UGCGenericCharacterSystem = {
        GetBehaviorTreeSetting = function() return { BehaviorTreePath = { path = h.tree } } end,
        StopBehavior = function(_, reason) event('tree:' .. reason) end,
    }
    _G.UGCObjectUtility = { GetObjectPathName = function(object) return object.path end }
    _G.ugcprint = function() end
    package.loaded[runtimeName] = {
        Get = function() return h.hasRuntime and {} or nil end,
        Release = function(_, now, reason)
            equal(now, 7, 'release time')
            event('release:' .. reason)
            return h.releaseClean
        end,
    }
    package.loaded[observedName] = {
        Get = function() return h.hasObservation and {} or nil end,
        Clear = function() event('observation-clear') end,
    }
    Monster.SuperClass = { ReceiveEndPlay = function(_, reason)
        event('super-end:' .. tostring(reason))
    end,
        ReceiveUnpossessed = function() event('super-unpossessed') end }

    local board = { flags = {} }
    function board:SetValueAsBool(key, value)
        self.flags[key] = value
        event('bool:' .. key .. '=' .. tostring(value))
    end
    function board:SetValueAsInt(key, value) event('int:' .. key .. '=' .. tostring(value)) end
    function board:SetValueAsObject(key, value)
        event('object:' .. key .. '=' .. tostring(value))
    end
    local pawn = setmetatable({
        UGCPresetCommonDropItemComponent = {
            StartDrop = function() event('loot') end,
        },
    }, { __index = Monster })
    function pawn:HasAuthority() return h.server end
    function pawn:GetBlackBoardComponent() return board end
    local movement = { StopMovementImmediately = function() event('pawn-stop') end }
    function pawn:GetMovementComponent() return movement end
    local controller = { pawn = pawn }
    function controller:K2_GetPawn() return self.pawn end
    function controller:StopMovement() event('controller-stop') end
    controller.BrainComponent = { StopLogic = function(_, reason)
        event('brain:' .. reason)
    end }
    function pawn:GetController() return controller end

    local ok, err = pcall(fn, pawn, controller, board, h)
    _G.UGCGameSystem, _G.UGCGenericCharacterSystem = oldGame, oldCharacter
    _G.UGCObjectUtility, _G.ugcprint = oldObject, oldPrint
    package.loaded[runtimeName], package.loaded[observedName] = oldRuntime, oldObserved
    Monster.SuperClass = oldSuper
    assert(ok, err)
end

local function contains(events, value)
    for _, event in ipairs(events) do if event == value then return true end end
    return false
end

local function position(events, value)
    for i, event in ipairs(events) do if event == value then return i end end
    return nil
end

local function run(name, fn, results)
    local ok, err = pcall(fn)
    results[#results + 1] = { name = name, pass = ok, detail = ok and '' or tostring(err) }
    print('[BossAI-LifecycleTest] ' .. name .. ' ' .. (ok and 'PASS' or ('FAIL ' .. tostring(err))))
end

function Tests.RunAll()
    local results = {}
    run('death marks Blackboard before abort and stops server damage', function()
        harness(function(pawn, _, board, h)
            pawn:BPDie(5, nil, nil, nil, 0)
            equal(board.flags.IsDead, true, 'dead key')
            equal(board.flags.CombatActive, false, 'combat key')
            assert(position(h.events, 'bool:IsDead=true')
                < position(h.events, 'release:death'), 'BB flag must precede runtime release')
            assert(contains(h.events, 'observation-clear'), 'observation retained')
            assert(contains(h.events, 'tree:BossDead'), 'behavior tree still active')
            assert(contains(h.events, 'controller-stop'), 'controller move still active')
            assert(contains(h.events, 'pawn-stop'), 'pawn move still active')
            assert(contains(h.events, 'loot'), 'existing loot missing')
        end)
    end, results)

    run('non Boss tree keeps existing loot without Boss cleanup', function()
        harness(function(pawn, _, board, h)
            h.tree = '/TTS/Asset/AI/BT/BT_Other.BT_Other'
            h.hasRuntime, h.hasObservation = false, false
            pawn:BPDie(5, nil, nil, nil, 0)
            equal(board.flags.IsDead, nil, 'unrelated Blackboard mutated')
            equal(#h.events, 1, 'unrelated AI modified')
            equal(h.events[1], 'loot', 'existing loot')
        end)
    end, results)

    run('unpossess releases action but does not classify a live Boss as dead', function()
        harness(function(pawn, controller, board, h)
            pawn:ReceiveUnpossessed(controller)
            equal(board.flags.IsDead, nil, 'live Boss incorrectly marked dead')
            equal(board.flags.CombatActive, false, 'combat key')
            assert(contains(h.events, 'release:unpossess'), 'runtime not released')
            assert(contains(h.events, 'super-unpossessed'), 'parent callback skipped')
            assert(not contains(h.events, 'loot'), 'unpossess dropped loot')
        end)
    end, results)

    run('missing tree setting still cleans an active per Boss runtime', function()
        harness(function(pawn, _, board, h)
            h.tree = nil
            h.hasObservation = false
            pawn:BPDie(5, nil, nil, nil, 0)
            equal(board.flags.IsDead, true, 'active runtime did not identify Boss')
            assert(contains(h.events, 'release:death'), 'runtime did not release')
        end)
    end, results)

    run('old controller reassigned to another pawn is left untouched', function()
        harness(function(pawn, controller, _, h)
            controller.pawn = {}
            pawn:ReceiveUnpossessed(controller)
            assert(not contains(h.events, 'controller-stop'), 'new pawn movement stopped')
            assert(not contains(h.events, 'brain:Bossunpossess'), 'new pawn logic stopped')
            assert(contains(h.events, 'pawn-stop'), 'old pawn movement not stopped')
        end)
    end, results)

    run('controller pawn lookup uses K2 API and legacy fallback', function()
        harness(function(pawn, controller, _, h)
            controller.K2_GetPawn = false
            function controller:GetPawn() return self.pawn end
            pawn:ReceiveUnpossessed(controller)
            assert(contains(h.events, 'controller-stop'), 'fallback pawn lookup failed')
            assert(contains(h.events, 'brain:Bossunpossess'), 'fallback brain stop failed')
        end)
    end, results)

    run('EndPlay retries release after a failed death cleanup and calls parent', function()
        harness(function(pawn, _, board, h)
            h.releaseClean = false
            pawn:BPDie(5, nil, nil, nil, 0)
            h.releaseClean = true
            pawn:ReceiveEndPlay(3)
            equal(board.flags.IsDead, true, 'dead key lost')
            assert(contains(h.events, 'release:endplay'), 'EndPlay skipped retry')
            assert(contains(h.events, 'super-end:3'), 'EndPlay reason not forwarded')
        end)
    end, results)

    run('client BPDie does not mutate server AI or drop loot', function()
        harness(function(pawn, _, board, h)
            h.server = false
            pawn:BPDie(5, nil, nil, nil, 0)
            equal(board.flags.IsDead, nil, 'client Blackboard mutated')
            equal(#h.events, 0, 'client side effects')
        end)
    end, results)

    run('cleanup exception cannot suppress loot or superclass EndPlay', function()
        harness(function(pawn, _, _, h)
            h.throwServer = true
            pawn:BPDie(5, nil, nil, nil, 0)
            pawn:ReceiveEndPlay(3)
            assert(contains(h.events, 'loot'), 'loot suppressed by cleanup exception')
            assert(contains(h.events, 'super-end:3'), 'parent EndPlay suppressed by cleanup exception')
        end)
    end, results)

    return results
end

return Tests
