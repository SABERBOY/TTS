--- BOSS AI 配置（规格 §4 / §5 / §6 / §7）
--- 全部数值集中于此，便于实机调整；灰盒伤害不侵入现有玩家数值体系。
local Types = require('Script.AI.Boss.BossAI_Types')

local Config = {}

-- =========================================================================
-- 一、全局参数
-- =========================================================================

Config.Pressure = {
    MaxCommittedSkillsPerBurst    = 3,   -- 本轮压制最多承诺的技能次数
    PressureBudgetSeconds         = 8.0, -- 事前规划目标（不是硬定时器）
    GuaranteedBreathingSeconds    = 2.0, -- 完整喘息窗口
    GapCloseDelayAfterBreathing   = 0.8, -- 喘息结束后禁 S3 的时长
    ChaseSliceSeconds             = 0.8, -- Chase / Reposition 决策片段
    ChaseSpeedDefault             = 600, -- cm/s（无项目现有值时）
}

Config.Context = {
    ServiceInterval        = 0.2,
    ServiceRandomDeviation = 0.03,
}

Config.Repeat = {
    RepeatFactor             = 0.2, -- 最近一次已承诺技能被再次选中时的权重系数
    BanAfterConsecutiveCount = 3,   -- 连续两次相同后，第三次直接禁止（即使只剩该技能）
}

Config.Decision = {
    FailBackoffSeconds = 0.2, -- 规划失败后的有界退避，避免高速失败循环
}

-- =========================================================================
-- 二、感知（规格 §4）
-- =========================================================================

Config.Perception = {
    SightRadius               = 2500, -- cm
    LoseSightRadius           = 3000, -- cm
    PeripheralVisionHalfAngle = 85,   -- 度
    HeightToleranceForSkill   = 300,  -- 高度差独立检查：超出则拒绝需要视线/落点的技能
}

-- =========================================================================
-- 三、一级意图权重（规格 §6）
-- =========================================================================

Config.IntentWeights = {
    [Types.Intent.Pressure] = {
        [1] = 65, -- Phase 1
        [2] = 75, -- Phase 2
    },
    [Types.Intent.StationaryCast] = {
        [1] = 25,
        [2] = 20,
    },
    [Types.Intent.Reposition] = {
        [1] = 10,
        [2] = 5,
    },
}

Config.PressureChaseSpeed = nil      -- nil = 沿用项目现有追击速度
Config.RepositionMinDistance = 600   -- Reposition 目标点距目标的最小距离（cm）

-- =========================================================================
-- 四、七技能定义（规格 §5）
-- 字段：id / name / intent / move / dist / windup / active / recovery / cd /
--       baseWeight / aimLock / hitWindows(相对有效段) / damage / 投射参数 /
--       maxDangerLife / 视线与路径要求 / 灰盒执行配置
-- =========================================================================

Config.Skills = {
    {
        id = 1, name = '裂刃连斩',
        intent = Types.Intent.Pressure, move = Types.SkillMove.AttackStep,
        minDist = 0, maxDist = 320,
        windup = 0.65, active = 0.80, recovery = 0.80, cd = 3.0,
        baseWeight = 30,
        aimLockAt = 0.35,               -- 前摇末尾锁方向
        hitWindows = { { 0.00, 0.30 }, { 0.45, 0.75 } }, -- 两段独立伤害窗口（不随机第三刀）
        hitDamage = 8,                  -- 每段
        hitRadius = 240, hitAngle = 120,
        maxDangerLife = 1.6,
        requiresLOS = true, requiresPath = false,
        maxMoveAdvance = 100,           -- 灰盒总攻击前移不超过 100cm
        graybox = { kind = 'MeleeArc', advanceSpeed = 150 },
    },
    {
        id = 2, name = '蓄力重砸',
        intent = Types.Intent.Pressure, move = Types.SkillMove.Stationary,
        minDist = 0, maxDist = 450,
        windup = 1.20, active = 0.25, recovery = 1.30, cd = 7.0,
        baseWeight = 20,
        aimLockAt = 0.60,
        hitWindows = { { 0.00, 0.15 } },
        hitDamage = 20,
        hitRadius = 380, hitAngle = 360,
        maxDangerLife = 1.6,
        requiresLOS = true, requiresPath = false,
        warnDuringWindup = true,        -- 提前显示前方打击范围
        graybox = { kind = 'GroundSlam', warnRadius = 380 },
    },
    {
        id = 3, name = '突进穿刺',
        intent = Types.Intent.Pressure, move = Types.SkillMove.CommittedDash,
        minDist = 550, maxDist = 1500,
        windup = 0.95, active = 0.50, recovery = 1.10, cd = 9.0,
        baseWeight = 20,
        aimLockAt = 0.50,               -- 前摇最后 0.45s 锁方向
        hitWindows = { { 0.00, 0.40 } },
        hitDamage = 16,
        hitRadius = 180, hitAngle = 60,
        maxDangerLife = 1.6,
        requiresLOS = true, requiresPath = true, -- 起手前检查通道与安全停止空间
        dashMaxDistance = 1500,
        graybox = { kind = 'DashLine', dashSpeed = 2200 },
    },
    {
        id = 4, name = '行进飞刃',
        intent = Types.Intent.Pressure, move = Types.SkillMove.SlowAdvance,
        minDist = 450, maxDist = 1800,
        windup = 0.70, active = 0.60, recovery = 0.60, cd = 4.0,
        baseWeight = 30,
        aimLockAt = 0.35,
        hitWindows = { { 0.05, 0.45 } }, -- 有效段内释放三枚非追踪飞刃
        hitDamage = 5,                   -- 每枚
        maxDangerLife = 2.0,             -- 飞刃最大伤害寿命
        requiresLOS = true, requiresPath = false,
        maxAdvanceSpeed = 200,           -- cm/s（技能控制低速移动）
        projectile = { count = 3, speed = 1600, life = 2.0, spreadDeg = 8 },
        graybox = { kind = 'ProjectileSpread' },
    },
    {
        id = 5, name = '定点三连轰',
        intent = Types.Intent.StationaryCast, move = Types.SkillMove.Stationary,
        minDist = 650, maxDist = 2400,
        windup = 1.15, active = 1.20, recovery = 1.20, cd = 9.0,
        baseWeight = 40,
        aimLockAt = 0.10,                -- 开始即按当前可见位置确定三落点
        hitWindows = { { 0.10, 0.25 }, { 0.45, 0.60 }, { 0.80, 0.95 } },
        hitDamage = 10,                  -- 每点
        hitRadius = 180, hitAngle = 360,
        maxDangerLife = 2.6,
        requiresLOS = true, requiresPath = false,
        predictMaxSeconds = 0.6,         -- 允许用当时已观测速度预测的上限
        pointCount = 3,
        graybox = { kind = 'NamedGroundPoints' },
    },
    {
        id = 6, name = '扇形弹幕',
        intent = Types.Intent.StationaryCast, move = Types.SkillMove.Stationary,
        minDist = 450, maxDist = 2000,
        windup = 1.00, active = 1.60, recovery = 1.00, cd = 12.0,
        baseWeight = 35,
        aimLockAt = 0.50,
        hitWindows = { { 0.05, 0.70 }, { 0.75, 1.60 } }, -- 原地两轮，共用安全缺口
        hitDamage = 5,                   -- 每枚
        maxDangerLife = 2.0,
        requiresLOS = true, requiresPath = false,
        projectile = { rounds = 2, bulletsPerRound = 9, speed = 1400, life = 2.0, spreadDeg = 120 },
        gapMinClearWidth = 80,           -- 局部有效通行宽度 = 玩家直径 + 80cm（校验时叠加玩家半径）
        graybox = { kind = 'FanBarrage' },
    },
    {
        id = 7, name = '裂隙爆发',
        intent = Types.Intent.StationaryCast, move = Types.SkillMove.Stationary,
        minDist = 0, maxDist = 1100,
        windup = 1.60, active = 1.00, recovery = 1.60, cd = 18.0,
        baseWeight = 25,
        aimLockAt = 0.20,
        hitWindows = { { 0.10, 0.35 }, { 0.50, 0.75 } },
        hitDamage = 15,                  -- 每脉冲
        hitRadius = 900, hitAngle = 360,
        maxDangerLife = 3.2,
        requiresLOS = true, requiresPath = false,
        safePathRequired = true,         -- 至少留一条可达安全区的连续路线
        safeWidthExtra = 80,             -- 通行宽度余量（玩家直径 + 80cm）
        graybox = { kind = 'SplitBurstPulses', safeZones = 4 },
    },
}

-- 在构建索引前检查完整配置；不能让重复 ID 在 SkillById 中静默覆盖。
local function finite(value)
    return type(value) == 'number' and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function invalid(path, requirement)
    return false, path .. ' ' .. requirement
end

local function denseCount(value, path)
    if type(value) ~= 'table' then return nil, path .. ' must be a table' end
    local count = 0
    for key in pairs(value) do
        count = count + 1
        if type(key) ~= 'number' or key % 1 ~= 0 or key < 1 then
            return nil, path .. ' must be a dense array'
        end
    end
    for i = 1, count do
        if rawget(value, i) == nil then return nil, path .. ' must be a dense array' end
    end
    return count
end

local function checkNumber(owner, key, path, minimum, positive)
    local value = owner[key]
    if not finite(value) or value < minimum or (positive and value == 0) then
        return invalid(path .. '.' .. key, positive and 'must be a finite positive number'
            or 'must be a finite nonnegative number')
    end
    return true
end

local function checkOptionalNumber(owner, key, path, minimum, integer)
    local value = owner[key]
    if value == nil then return true end
    if not finite(value) or value < minimum or (integer and value % 1 ~= 0) then
        return invalid(path .. '.' .. key, 'must be a finite number in its allowed range')
    end
    return true
end

local function validateProjectile(projectile, path, maxDangerLife)
    if type(projectile) ~= 'table' then return invalid(path, 'must be a table') end
    for _, key in ipairs({ 'speed', 'life' }) do
        local ok, reason = checkNumber(projectile, key, path, 0, true)
        if not ok then return false, reason end
    end
    if projectile.life > maxDangerLife then
        return invalid(path .. '.life', 'must not exceed maxDangerLife')
    end
    for _, key in ipairs({ 'count', 'rounds', 'bulletsPerRound' }) do
        local ok, reason = checkOptionalNumber(projectile, key, path, 1, true)
        if not ok then return false, reason end
    end
    local ok, reason = checkOptionalNumber(projectile, 'spreadDeg', path, 0, false)
    if not ok then return false, reason end
    if projectile.spreadDeg ~= nil and projectile.spreadDeg > 360 then
        return invalid(path .. '.spreadDeg', 'must be at most 360 degrees')
    end
    return true
end

local function validateSkill(skill, path)
    if type(skill.name) ~= 'string' or skill.name == '' then
        return invalid(path .. '.name', 'must be a nonempty string')
    end
    local expectedIntent = skill.id <= 4 and Types.Intent.Pressure or Types.Intent.StationaryCast
    if skill.intent ~= expectedIntent then
        return invalid(path .. '.intent', 'must match its seven-skill slot')
    end
    local moveValid = false
    for _, move in pairs(Types.SkillMove) do
        if skill.move == move then moveValid = true; break end
    end
    if not moveValid then return invalid(path .. '.move', 'must be a SkillMove value') end

    for _, key in ipairs({ 'minDist', 'maxDist', 'windup', 'recovery', 'cd', 'baseWeight' }) do
        local ok, reason = checkNumber(skill, key, path, 0, false)
        if not ok then return false, reason end
    end
    local ok, reason = checkNumber(skill, 'active', path, 0, true)
    if not ok then return false, reason end
    if skill.maxDist < skill.minDist then
        return invalid(path .. '.maxDist', 'must be at least minDist')
    end
    ok, reason = checkNumber(skill, 'aimLockAt', path, 0, false)
    if not ok then return false, reason end
    if skill.aimLockAt > skill.windup then
        return invalid(path .. '.aimLockAt', 'must not exceed windup')
    end
    ok, reason = checkNumber(skill, 'maxDangerLife', path, 0, true)
    if not ok then return false, reason end
    ok, reason = checkNumber(skill, 'hitDamage', path, 0, true)
    if not ok then return false, reason end
    for _, key in ipairs({ 'requiresLOS', 'requiresPath' }) do
        if type(skill[key]) ~= 'boolean' then
            return invalid(path .. '.' .. key, 'must be boolean')
        end
    end
    if not skill.requiresLOS then
        return invalid(path .. '.requiresLOS', 'must be true for all seven skills')
    end

    local windows, windowsError = denseCount(skill.hitWindows, path .. '.hitWindows')
    if windows == nil then return false, windowsError end
    if windows == 0 then return invalid(path .. '.hitWindows', 'must contain a damage window') end
    for i = 1, windows do
        local window = skill.hitWindows[i]
        local windowPath = path .. '.hitWindows[' .. i .. ']'
        local size, sizeError = denseCount(window, windowPath)
        if size == nil then return false, sizeError end
        if size ~= 2 or not finite(window[1]) or not finite(window[2])
            or window[1] < 0 or window[2] <= window[1] or window[2] > skill.active then
            return invalid(windowPath, 'must be a finite interval within active time')
        end
    end

    for _, key in ipairs({ 'hitRadius', 'hitAngle', 'maxMoveAdvance', 'dashMaxDistance',
        'maxAdvanceSpeed', 'predictMaxSeconds', 'pointCount', 'gapMinClearWidth',
        'safeWidthExtra', 'phaseLocked' }) do
        ok, reason = checkOptionalNumber(skill, key, path, 0,
            key == 'pointCount' or key == 'phaseLocked')
        if not ok then return false, reason end
    end
    if skill.hitAngle ~= nil and skill.hitAngle > 360 then
        return invalid(path .. '.hitAngle', 'must be at most 360 degrees')
    end
    for _, key in ipairs({ 'warnDuringWindup', 'safePathRequired' }) do
        if skill[key] ~= nil and type(skill[key]) ~= 'boolean' then
            return invalid(path .. '.' .. key, 'must be boolean')
        end
    end

    if skill.projectile ~= nil or skill.id == Types.SkillID.S4 or skill.id == Types.SkillID.S6 then
        ok, reason = validateProjectile(skill.projectile, path .. '.projectile', skill.maxDangerLife)
        if not ok then return false, reason end
        if skill.id == Types.SkillID.S4 and skill.projectile.count == nil then
            return invalid(path .. '.projectile.count', 'is required for S4')
        end
        if skill.id == Types.SkillID.S6 then
            if skill.projectile.rounds == nil then
                return invalid(path .. '.projectile.rounds', 'is required for S6')
            end
            if skill.projectile.bulletsPerRound == nil then
                return invalid(path .. '.projectile.bulletsPerRound', 'is required for S6')
            end
        end
    end
    if skill.graybox ~= nil then
        if type(skill.graybox) ~= 'table' or type(skill.graybox.kind) ~= 'string'
            or skill.graybox.kind == '' then
            return invalid(path .. '.graybox', 'must have a nonempty kind')
        end
        for _, key in ipairs({ 'advanceSpeed', 'warnRadius', 'dashSpeed', 'safeZones' }) do
            ok, reason = checkOptionalNumber(skill.graybox, key, path .. '.graybox', 0,
                key == 'safeZones')
            if not ok then return false, reason end
        end
    end
    if skill.montage ~= nil and (type(skill.montage) ~= 'string' or skill.montage == '') then
        return invalid(path .. '.montage', 'must be a nonempty asset path')
    end
    if skill.graybox == nil and skill.montage == nil then
        return invalid(path .. '.graybox', 'or montage is required for execution')
    end
    return true
end

local function validateWeights()
    if type(Config.IntentWeights) ~= 'table' then
        return invalid('IntentWeights', 'must be a table')
    end
    for _, intent in ipairs({ Types.Intent.Pressure, Types.Intent.StationaryCast,
        Types.Intent.Reposition }) do
        local phases = Config.IntentWeights[intent]
        if type(phases) ~= 'table' then
            return invalid('IntentWeights[' .. intent .. ']', 'must be a phase table')
        end
        for phase = 1, 2 do
            local value = phases[phase]
            if not finite(value) or value < 0 then
                return invalid('IntentWeights[' .. intent .. '][' .. phase .. ']',
                    'must be a finite nonnegative weight')
            end
        end
    end
    if type(Config.PhaseSkillFactor) ~= 'table' then
        return invalid('PhaseSkillFactor', 'must be a table')
    end
    for phase, weights in pairs(Config.PhaseSkillFactor) do
        if (phase ~= 1 and phase ~= 2) or type(weights) ~= 'table' then
            return invalid('PhaseSkillFactor', 'must map phase 1 or 2 to skill weights')
        end
        for id, value in pairs(weights) do
            if type(id) ~= 'number' or id % 1 ~= 0 or id < 1 or id > Types.SkillCount
                or not finite(value) or value < 0 then
                return invalid('PhaseSkillFactor[' .. phase .. '][' .. tostring(id) .. ']',
                    'must be a finite nonnegative weight for a skill slot')
            end
        end
    end
    if type(Config.Repeat) ~= 'table' or not finite(Config.Repeat.RepeatFactor)
        or Config.Repeat.RepeatFactor < 0 then
        return invalid('Repeat.RepeatFactor', 'must be a finite nonnegative weight')
    end
    return true
end

local function validateGeneralConfig()
    local groups = {
        { 'Pressure', {
            { 'MaxCommittedSkillsPerBurst', 1, true },
            { 'PressureBudgetSeconds', 0, true },
            { 'GuaranteedBreathingSeconds', 0, true },
            { 'GapCloseDelayAfterBreathing', 0, false },
            { 'ChaseSliceSeconds', 0, true },
            { 'ChaseSpeedDefault', 0, true },
        } },
        { 'Context', {
            { 'ServiceInterval', 0, true },
            { 'ServiceRandomDeviation', 0, false },
        } },
        { 'Repeat', {
            { 'BanAfterConsecutiveCount', 2, false },
        } },
        { 'Decision', {
            { 'FailBackoffSeconds', 0, true },
        } },
        { 'Perception', {
            { 'SightRadius', 0, true },
            { 'LoseSightRadius', 0, true },
            { 'PeripheralVisionHalfAngle', 0, true },
            { 'HeightToleranceForSkill', 0, false },
        } },
        { 'Graybox', {
            { 'PlayerMaxHP', 0, true },
            { 'BossMaxHP', 0, true },
        } },
    }
    for _, group in ipairs(groups) do
        local name, fields = group[1], group[2]
        local values = Config[name]
        if type(values) ~= 'table' then return invalid(name, 'must be a table') end
        for _, field in ipairs(fields) do
            local ok, reason = checkNumber(values, field[1], name, field[2], field[3])
            if not ok then return false, reason end
        end
    end
    if Config.Pressure.MaxCommittedSkillsPerBurst % 1 ~= 0 then
        return invalid('Pressure.MaxCommittedSkillsPerBurst', 'must be an integer')
    end
    if Config.Repeat.BanAfterConsecutiveCount % 1 ~= 0 then
        return invalid('Repeat.BanAfterConsecutiveCount', 'must be an integer')
    end
    if Config.Perception.LoseSightRadius < Config.Perception.SightRadius then
        return invalid('Perception.LoseSightRadius', 'must be at least SightRadius')
    end
    if Config.Perception.PeripheralVisionHalfAngle > 180 then
        return invalid('Perception.PeripheralVisionHalfAngle', 'must be at most 180 degrees')
    end
    if Config.PressureChaseSpeed ~= nil and
        (not finite(Config.PressureChaseSpeed) or Config.PressureChaseSpeed <= 0) then
        return invalid('PressureChaseSpeed', 'must be nil or a finite positive number')
    end
    if not finite(Config.RepositionMinDistance) or Config.RepositionMinDistance < 0 then
        return invalid('RepositionMinDistance', 'must be a finite nonnegative number')
    end
    if type(Config.DistanceFactor) ~= 'function' then
        return invalid('DistanceFactor', 'must be a function')
    end
    if type(Config.Graybox.DamageType) ~= 'string' or Config.Graybox.DamageType == '' then
        return invalid('Graybox.DamageType', 'must be a nonempty string')
    end
    for _, colorName in ipairs({ 'WarnColor', 'HitColor' }) do
        local color = Config.Graybox[colorName]
        if type(color) ~= 'table' then
            return invalid('Graybox.' .. colorName, 'must be an RGBA table')
        end
        for _, channel in ipairs({ 'R', 'G', 'B', 'A' }) do
            local value = color[channel]
            if not finite(value) or value < 0 or value > 1 then
                return invalid('Graybox.' .. colorName .. '.' .. channel,
                    'must be a finite number from 0 to 1')
            end
        end
    end
    return true
end

--- Validate(skills) returns true or false, reason. Called before SkillById is built.
--- The optional skills list permits editor/import tools to validate a proposed definition.
function Config.Validate(skills)
    if skills == nil then skills = Config.Skills end
    local count, listError = denseCount(skills, 'Skills')
    if count == nil then return false, listError end
    local seen = {}
    for i = 1, count do
        local skill = skills[i]
        local path = 'Skills[' .. i .. ']'
        if type(skill) ~= 'table' then return invalid(path, 'must be a skill definition') end
        local id = skill.id
        if not finite(id) or id % 1 ~= 0 or id < 1 or id > Types.SkillCount then
            return invalid(path .. '.id', 'must be an integer skill slot from 1 to 7')
        end
        if seen[id] then return invalid(path .. '.id', 'duplicate ID ' .. id) end
        seen[id] = true
        local ok, reason = validateSkill(skill, path)
        if not ok then return false, reason end
    end
    for id = 1, Types.SkillCount do
        if not seen[id] then return invalid('Skills', 'missing skill slot ' .. id) end
    end
    local ok, reason = validateWeights()
    if not ok then return false, reason end
    ok, reason = validateGeneralConfig()
    if not ok then return false, reason end
    return true
end

-- =========================================================================
-- 五、二级权重修正（规格 §6）
-- =========================================================================

--- Phase 2 技能权重系数（默认 1.0）
Config.PhaseSkillFactor = {
    [2] = {
        [2] = 1.2, -- S2
        [3] = 1.2, -- S3
        [7] = 1.2, -- S7
    },
}

--- 原型距离偏好：合法距离内 1.0，范围外直接拒绝（可配置曲线入口留待扩展）
Config.DistanceFactor = function(_skillDef, _edgeDistance)
    return 1.0
end

-- =========================================================================
-- 六、灰盒数值（规格 §5，独立于玩家数值体系）
-- =========================================================================

Config.Graybox = {
    PlayerMaxHP = 100,
    BossMaxHP   = 1000,
    DamageType  = 'Damage.Skill',     -- 复用项目 GameplayTag 命名
    WarnColor   = { R = 1.0, G = 0.2, B = 0.2, A = 0.35 },
    HitColor    = { R = 1.0, G = 0.6, B = 0.1, A = 0.5 },
}

local configValid, configError = Config.Validate(Config.Skills)
if not configValid then error('BossAI_Config invalid: ' .. configError, 2) end

--- 技能索引（id -> 定义）；只在校验通过后构建。
Config.SkillById = {}
for i = 1, #Config.Skills do
    local skill = Config.Skills[i]
    Config.SkillById[skill.id] = skill
end

return Config
