-- Pure Lua regression for SuperMonster's legacy IceCubeWall equip decision.
-- Run with Lupa outside PIE: lua.execute("dofile('Tests/SuperMonsterIcePassiveTests.lua')")
local Monster = require('Script.Blueprint.Prefabs.Monsters.SuperMonster')
local BOSS = '/TTS/Asset/AI/BT/BT_Boss.BT_Boss'
local OTHER = '/TTS/Asset/AI/BT/BT_Other.BT_Other'
local equipped, loaded = 0, 0
local tree, fallbackTree

Monster.SuperClass = { ReceiveBeginPlay = function() end }
UGCGameSystem = { IsServer = function() return true end }
UGCGenericCharacterSystem = {
    GetBehaviorTreeSetting = function()
        if tree == 'error' then error('setting unavailable during BeginPlay') end
        return tree and { BehaviorTreePath = { path = tree } } or nil
    end,
}
UGCObjectUtility = { GetObjectPathName = function(object) return object.path end }
UE = { LoadClass = function() loaded = loaded + 1; return {} end }
UGCPersistEffectSystem = {
    AddSkillByClass = function()
        equipped = equipped + 1
        return { id = equipped }
    end,
}
ugcprint = function() end

local function beginPlay(systemPath, componentPath)
    tree, fallbackTree = systemPath, componentPath
    equipped, loaded = 0, 0
    local pawn = setmetatable({
        BehaviorControlComp = {
            BehaviorTreeSetting = fallbackTree and {
                BehaviorTreePath = { path = fallbackTree },
            } or nil,
        },
    }, { __index = Monster })
    pawn:ReceiveBeginPlay()
    return pawn
end

local boss = beginPlay(BOSS, BOSS)
assert(equipped == 0 and loaded == 0 and boss.IceCubeWallSkillInstance == nil,
    'BT_Boss must not equip the legacy IceCubeWall passive')

boss = beginPlay('error', BOSS)
assert(equipped == 0 and loaded == 0 and boss.IceCubeWallSkillInstance == nil,
    'BT_Boss component setting must suppress IceCubeWall when system API is unavailable')

local other = beginPlay(OTHER, OTHER)
assert(equipped == 1 and loaded == 1 and other.IceCubeWallSkillInstance ~= nil,
    'legacy behavior trees must retain IceCubeWall')

print('[SuperMonsterIcePassiveTests] PASS')
