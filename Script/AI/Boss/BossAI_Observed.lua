--- Per-boss observation cache. No mutable AI state is written onto UE UObject
--- wrappers or a shared Behavior Tree node template.
local Observed = {}
local byPawn = setmetatable({}, { __mode = 'k' })

function Observed.Get(pawn)
    return byPawn[pawn]
end

--- Replace the complete current snapshot. The caller must carry forward
--- remembered radii or home-failure status when those are still relevant.
function Observed.Update(pawn, data)
    if pawn == nil then return end
    local copy = {}
    for key, value in pairs(data or {}) do copy[key] = value end
    byPawn[pawn] = copy
end

function Observed.SetHomeFailed(pawn, failed)
    if pawn == nil then return end
    local data = byPawn[pawn] or {}
    data.homeFailed = failed == true
    byPawn[pawn] = data
end

function Observed.Clear(pawn)
    byPawn[pawn] = nil
end

return Observed
