-- Boss 配置边界测试：用受控坏配置调用真实校验入口，不依赖引擎对象。
-- local result = require('Script.AI.Boss.BossAI_ConfigTests').RunAll()
local Config = require('Script.AI.Boss.BossAI_Config')
local Types = require('Script.AI.Boss.BossAI_Types')

local Tests = {}

local function copySkills()
    local skills = {}
    for i, skill in ipairs(Config.Skills) do
        local copy = {}
        for key, value in pairs(skill) do copy[key] = value end
        skills[i] = copy
    end
    return skills
end

local function rejects(name, change, expected)
    local skills = copySkills()
    change(skills)
    local ok, reason = Config.Validate(skills)
    assert(ok == false, name .. ': accepted invalid configuration')
    assert(type(reason) == 'string' and reason:find(expected, 1, true),
        name .. ': expected reason containing ' .. expected .. ', got ' .. tostring(reason))
end

local function rejectsGlobal(owner, key, value, expected)
    local original = owner[key]
    owner[key] = value
    local called, valid, reason = pcall(Config.Validate, Config.Skills)
    owner[key] = original
    assert(called, tostring(valid))
    assert(valid == false, key .. ': accepted invalid configuration')
    assert(type(reason) == 'string' and reason:find(expected, 1, true),
        key .. ': expected reason containing ' .. expected .. ', got ' .. tostring(reason))
end

local cases = {
    {
        'shipping configuration is valid and indexed by every slot',
        function()
            local ok, reason = Config.Validate(Config.Skills)
            assert(ok == true, tostring(reason))
            for id = 1, 7 do
                assert(Config.SkillById[id] == Config.Skills[id], 'missing indexed slot ' .. id)
            end
        end,
    },
    { 'duplicate ID cannot silently overwrite a slot', function()
        rejects('duplicate ID', function(skills) skills[7].id = 6 end, 'duplicate ID')
    end },
    { 'all seven required slots must exist', function()
        rejects('missing slot', function(skills) table.remove(skills, 7) end, 'missing skill slot 7')
    end },
    { 'skill ID must be an integer', function()
        rejects('string ID', function(skills) skills[7].id = '7' end, '.id')
    end },
    { 'explicit invalid skills argument is not treated as default', function()
        local ok, reason = Config.Validate(false)
        assert(ok == false and type(reason) == 'string' and reason:find('Skills', 1, true),
            'false skills argument was accepted')
    end },
    { 'negative and inverted distance ranges are rejected', function()
        rejects('negative minDist', function(skills) skills[1].minDist = -1 end, 'minDist')
        rejects('inverted range', function(skills) skills[1].maxDist = -1 end, 'maxDist')
    end },
    { 'distance values must be finite numbers', function()
        rejects('infinite maxDist', function(skills) skills[1].maxDist = math.huge end, 'maxDist')
        rejects('text minDist', function(skills) skills[1].minDist = 'near' end, 'minDist')
    end },
    { 'timing fields reject negative, nonfinite and text values', function()
        rejects('negative cooldown', function(skills) skills[1].cd = -0.1 end, '.cd')
        rejects('NaN windup', function(skills) skills[1].windup = 0 / 0 end, 'windup')
        rejects('text active', function(skills) skills[1].active = 'long' end, 'active')
        rejects('negative recovery', function(skills) skills[1].recovery = -0.1 end, 'recovery')
    end },
    { 'weight fields reject negative, nonfinite and text values', function()
        rejects('negative baseWeight', function(skills) skills[1].baseWeight = -1 end, 'baseWeight')
        rejects('infinite baseWeight', function(skills) skills[1].baseWeight = math.huge end, 'baseWeight')
        rejects('text baseWeight', function(skills) skills[1].baseWeight = '30' end, 'baseWeight')
    end },
    { 'every damaging action has a finite positive danger lifetime', function()
        rejects('missing danger deadline', function(skills) skills[1].maxDangerLife = nil end, 'maxDangerLife')
        rejects('infinite danger deadline', function(skills) skills[1].maxDangerLife = math.huge end, 'maxDangerLife')
        rejects('zero danger deadline', function(skills) skills[1].maxDangerLife = 0 end, 'maxDangerLife')
    end },
    { 'projectile lifetime fits its danger deadline', function()
        rejects('projectile exceeds deadline', function(skills)
            local projectile = {}
            for key, value in pairs(skills[4].projectile) do projectile[key] = value end
            projectile.life = 3.0
            skills[4].projectile = projectile
        end, 'projectile.life')
    end },
    { 'S4 projectile count is required', function()
        rejects('missing projectile count', function(skills)
            local projectile = {}
            for key, value in pairs(skills[4].projectile) do projectile[key] = value end
            projectile.count = nil
            skills[4].projectile = projectile
        end, 'projectile.count')
    end },
    { 'required skill value types are enforced', function()
        rejects('text LOS flag', function(skills) skills[1].requiresLOS = 'yes' end, 'requiresLOS')
        rejects('missing executor', function(skills) skills[1].graybox = nil end, 'graybox')
        rejects('invalid hit window', function(skills) skills[1].hitWindows = { { 0, 2 } } end, 'hitWindows')
    end },
    { 'global timing and health values reject invalid types', function()
        rejectsGlobal(Config.Pressure, 'PressureBudgetSeconds', 'eight', 'Pressure.PressureBudgetSeconds')
        rejectsGlobal(Config.Graybox, 'PlayerMaxHP', math.huge, 'Graybox.PlayerMaxHP')
    end },
    { 'global intent and phase weights must be finite', function()
        rejectsGlobal(Config.IntentWeights[Types.Intent.Pressure], 1, math.huge, 'IntentWeights')
        rejectsGlobal(Config.PhaseSkillFactor[2], 7, -0.1, 'PhaseSkillFactor')
    end },
    { 'routing blackboard keys use the saved UGC Int asset type', function()
        local routeTypes = {}
        for _, def in ipairs(Types.BBKeyDefs) do routeTypes[def.name] = def.type end
        assert(routeTypes.ActionKind == 'Int', 'ActionKind must match BB_Boss Int key')
        assert(routeTypes.SelectedSkill == 'Int', 'SelectedSkill must match BB_Boss Int key')
        assert(Types.ActionKind.Skill == 1 and Types.SkillID.S7 == 7, 'numeric route API changed')
    end },
}

function Tests.RunAll()
    local results = {}
    local passed = 0
    for _, entry in ipairs(cases) do
        local ok, err = pcall(entry[2])
        if ok then passed = passed + 1 end
        results[#results + 1] = { name = entry[1], pass = ok, detail = ok and '' or tostring(err) }
        print(string.format('[BossAI-ConfigTest] %s %s %s', ok and 'PASS' or 'FAIL', entry[1], ok and '' or tostring(err)))
    end
    return { passed = passed, total = #cases, results = results }
end

return Tests
