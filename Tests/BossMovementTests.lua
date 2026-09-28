-- Pure Lua movement contract tests. Run explicitly; this file is not a BT node.
local K = setmetatable({}, { __index = function(_, key) return key end })
package.loaded['Script.AI.Boss.BossAI_Types'] = { BBKeys = K }
package.loaded['Script.AI.Boss.BossAI_Config'] = {
    Pressure = { ChaseSliceSeconds = 0.8 },
}
package.loaded['Script.AI.Boss.BossAI_SkillRuntime'] = {}

local now, reachable, actorCalls, locationCalls = 0, true, 0, 0
local actorResult = 0
local lastLocation
local lastActorRadius, lastActorStopOnOverlap
local lastLocationRadius, lastLocationStopOnOverlap
local pawnLocation = { X = 0, Y = 0, Z = 0 }
local pawnHalfHeight = 0
UE = { IsValid = function(object) return object ~= nil end }
UGCGameSystem = {
    IsServer = function() return true end,
    GetTimeSeconds = function() return now end,
}
Vector = { New = function(x, y, z) return { X = x, Y = y, Z = z } end }
EPathFollowingRequestResult = { Failed = 0, AlreadyAtGoal = 1, RequestSuccessful = 2 }
EPathFollowingStatus = { Idle = 0, Moving = 3 }
ugcprint = function() end
UGCNavigationSystem = {
    ProjectPointToNavigation = function(_, point)
        return true, { X = point.X, Y = point.Y, Z = 0 }
    end,
}
NavigationSystem = {
    FindPathToLocationSynchronously = function()
        return {
            IsValid = function() return reachable end,
            IsPartial = function() return not reachable end,
        }
    end,
}

local board = { GetValueAsBool = function() return true end }
local pawn = {
    GetBlackBoardComponent = function() return board end,
    K2_GetActorLocation = function() return pawnLocation end,
    CapsuleComponent = {
        GetScaledCapsuleHalfHeight = function() return pawnHalfHeight end,
    },
}
local airborneTarget = {
    K2_GetActorLocation = function() return { X = 1000, Y = 0, Z = 400 } end,
}
local controller = {
    K2_GetPawn = function() return pawn end,
    LineOfSightTo = function() return true end,
    MoveToActor = function(_, _, radius, stopOnOverlap)
        actorCalls = actorCalls + 1
        lastActorRadius, lastActorStopOnOverlap = radius, stopOnOverlap
        return actorResult
    end,
    MoveToLocation = function(_, location, radius, stopOnOverlap)
        locationCalls = locationCalls + 1
        lastLocation = location
        lastLocationRadius, lastLocationStopOnOverlap = radius, stopOnOverlap
        return EPathFollowingRequestResult.RequestSuccessful
    end,
    GetMoveStatus = function() return EPathFollowingStatus.Moving end,
    HasPartialPath = function() return false end,
    StopMovement = function() end,
}

local Move = require('Script.AI.BT.BTTask_BossChaseSlice').Move
Move.StopForPawn(nil)
local run = Move.Begin(controller, pawn, 'Chase', airborneTarget, 100, 0.8, true)
assert(run and actorCalls == 0 and locationCalls == 1 and lastLocation.Z == 0,
    'airborne visible actor must be chased via a projected nav location')
assert(lastLocationRadius == 100 and lastLocationStopOnOverlap == false,
    'MoveToLocation must honor the explicit 100 cm radius without capsule overlap')
Move.Stop(run)

local groundedTarget = {
    K2_GetActorLocation = function() return { X = 1000, Y = 0, Z = 90 } end,
}
actorResult = EPathFollowingRequestResult.RequestSuccessful
run = Move.Begin(controller, pawn, 'Chase', groundedTarget, 100, 0.8, true)
assert(run and run.mode == 'actor' and actorCalls == 1,
    'grounded reachable target must retain continuously updated MoveToActor')
assert(lastActorRadius == 100 and lastActorStopOnOverlap == false,
    'MoveToActor must honor the explicit 100 cm radius without capsule overlap')
local nextSlice = Move.Begin(controller, pawn, 'Chase', groundedTarget, 100, 0.8, true)
assert(nextSlice and actorCalls == 1 and nextSlice.marker == run.marker,
    'consecutive chase slices must reuse the live MoveToActor request')
assert(Move.Advance(nextSlice, 0.1) == 'running')
Move.Stop(nextSlice)

-- The tall Boss actor origin is 310 cm above its feet; the projected floor
-- is still adjacent to the feet and native MoveTo must be attempted.
pawnLocation = { X = 0, Y = 0, Z = 312 }
pawnHalfHeight = 310
local beforeActor = actorCalls
run = Move.Begin(controller, pawn, 'Chase', groundedTarget, 100, 0.8, true)
assert(run and not run.backoff and actorCalls == beforeActor + 1,
    'tall Boss near nav must let native MoveTo decide whether the path is valid')
Move.Stop(run)
pawnLocation = { X = 0, Y = 0, Z = 0 }
pawnHalfHeight = 0

-- A genuinely airborne Boss still backs off before requesting a walk path.
pawnLocation = { X = 0, Y = 0, Z = 400 }
pawnHalfHeight = 88
run = Move.Begin(controller, pawn, 'Chase', groundedTarget, 100, 0.8, true)
assert(run and run.backoff and actorCalls == beforeActor + 1,
    'Boss feet far above nav must not issue a walk request')
Move.StopForPawn(pawn)
pawnLocation = { X = 0, Y = 0, Z = 0 }
pawnHalfHeight = 0

local tallGroundedTarget = {
    K2_GetActorLocation = function() return { X = 1000, Y = 0, Z = 400 } end,
    CapsuleComponent = {
        GetScaledCapsuleHalfHeight = function() return 390 end,
    },
}
beforeActor = actorCalls
run = Move.Begin(controller, pawn, 'Chase', tallGroundedTarget, 100, 0.8, true)
assert(run and run.mode == 'actor' and actorCalls == beforeActor + 1,
    'a tall grounded target must use MoveToActor based on feet, not origin')
Move.Stop(run)

pawnLocation = { X = 50, Y = 0, Z = 310 }
pawnHalfHeight = 310
local arrived, arrivedReason = Move.Begin(controller, pawn, 'Search',
    { X = 0, Y = 0, Z = 0 }, 100, 0.8, true)
assert(not arrived and arrivedReason == 'arrived',
    'a tall Boss already at its projected destination must arrive by feet distance')
pawnLocation = { X = 0, Y = 0, Z = 310 }
run = Move.Begin(controller, pawn, 'Search', { X = 500, Y = 0, Z = 0 }, 100, 0.8, true)
assert(run and not run.backoff)
pawnLocation = { X = 500, Y = 0, Z = 310 }
assert(Move.Advance(run, 0.1) == 'arrived',
    'a moving tall Boss must detect destination arrival by feet distance')
Move.Stop(run)
pawnLocation = { X = 0, Y = 0, Z = 0 }
pawnHalfHeight = 0

-- Accepted requests can stop immediately on an unsuitable path. Keep the
-- task latent through bounded backoff rather than reentering every BT tick.
run = Move.Begin(controller, pawn, 'Chase', groundedTarget, 100, 0.8, true)
assert(run and not run.backoff)
controller.GetMoveStatus = function() return EPathFollowingStatus.Idle end
assert(Move.Advance(run, 0.2) == 'running' and run.backoff,
    'path-stopped must become an in-progress retry backoff')
local callsAfterStopped = actorCalls
Move.Stop(run)
local retry = Move.Begin(controller, pawn, 'Chase', groundedTarget, 100, 0.8, true)
assert(retry and retry.backoff and actorCalls == callsAfterStopped,
    'backoff must suppress immediate native request after a stopped path')
Move.StopForPawn(pawn)
controller.GetMoveStatus = function() return EPathFollowingStatus.Moving end

local beforeLocation = locationCalls
run = Move.Begin(controller, pawn, 'Search', { X = 1000, Y = 0, Z = 400 }, 100, 0.8, true)
assert(run and locationCalls == beforeLocation + 1 and lastLocation.Z == 0,
    'Search must project only its cached last-known location')
Move.Stop(run)

reachable = false
local before = locationCalls
run = Move.Begin(controller, pawn, 'Search', { X = 1200, Y = 0, Z = 400 }, 100, 0.8, true)
assert(run and run.backoff and locationCalls == before,
    'unreachable cached goal must enter bounded backoff without MoveTo')
assert(Move.Advance(run, 0.1) == 'running')
assert(Move.Advance(run, 0.2) == 'slice', 'backoff must complete after a finite interval')
Move.Stop(run) -- BT abort/re-entry must not reset the hard retry deadline.
run = Move.Begin(controller, pawn, 'Search', { X = 1200, Y = 0, Z = 400 }, 100, 0.8, true)
assert(run and run.backoff and locationCalls == before,
    'immediate retry must not issue another native MoveTo')

now = 1
reachable = true
run = Move.Begin(controller, pawn, 'Search', { X = 1200, Y = 0, Z = 400 }, 100, 0.8, true)
assert(run and not run.backoff and locationCalls == before + 1,
    'a reachable goal must retry after backoff and start movement')
Move.Stop(run)

print('Boss movement projection/backoff tests PASS')
