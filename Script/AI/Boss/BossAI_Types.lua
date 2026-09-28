--- BOSS AI 类型与常量（规格 §3 / §5 / §6）
--- 统一 Key / 枚举定义，避免散落字符串导致不一致。
local BossAI_Types = {}

--- 动作类别（写入黑板 ActionKind）
BossAI_Types.ActionKind = {
    None       = 0,
    Skill      = 1,
    Chase      = 2,
    Reposition = 3,
    GiveSpace  = 4,
    Search     = 5,
}

BossAI_Types.ActionKindName = {
    [0] = 'None', [1] = 'Skill', [2] = 'Chase',
    [3] = 'Reposition', [4] = 'GiveSpace', [5] = 'Search',
}

--- 技能槽位（写入黑板 SelectedSkill）
BossAI_Types.SkillID = {
    None = 0, S1 = 1, S2 = 2, S3 = 3, S4 = 4, S5 = 5, S6 = 6, S7 = 7,
}

BossAI_Types.SkillCount = 7

--- 一级意图组（规格 §6）
BossAI_Types.Intent = {
    Pressure       = 1, -- 贴身压力：S1-S4
    StationaryCast = 2, -- 站桩施法：S5-S7
    Reposition     = 3, -- 重新站位
}

BossAI_Types.IntentName = {
    [1] = 'Pressure', [2] = 'StationaryCast', [3] = 'Reposition',
}

--- 技能移动策略（规格 §10 移动所有权）
BossAI_Types.SkillMove = {
    AttackStep    = 1, -- 受限、带碰撞的攻击位移
    Stationary    = 2, -- 停路径和移动
    CommittedDash = 3, -- 锁方向位移
    SlowAdvance   = 4, -- 技能控制低速合法移动
}

--- 喘息阶段（规格 §7）
BossAI_Types.BreathingPhase = {
    None         = 0,
    DrainThreats = 1, -- A：等本 BOSS 已发出的有效危险结束
    Breathing    = 2, -- B：完整静止且不发起新攻击的窗口
}

--- 技能动作阶段（规格 §9 Windup → Active → Recovery）
BossAI_Types.ActionPhase = {
    None     = 0,
    Windup   = 1,
    Active   = 2,
    Recovery = 3,
    Finished = 4,
    Aborted  = 5,
}

--- 拒绝原因（调试用，规格 §13 调试显示）
BossAI_Types.RejectReason = {
    NoTarget          = 'NoTarget',
    NoLOS             = 'NoLOS',
    Cooldown          = 'Cooldown',
    OutOfRange        = 'OutOfRange',
    HeightDiff        = 'HeightDiff',
    PhaseLocked       = 'PhaseLocked',
    RepeatBan         = 'RepeatBan',
    PressureBudget    = 'PressureBudget',
    GapCloseBlocked   = 'GapCloseBlocked',
    PathBlocked       = 'PathBlocked',
    DangerConflict    = 'DangerConflict',
    IntentEmpty       = 'IntentEmpty',
    StationaryCastEmpty = 'StationaryCastEmpty', -- 站桩意图无合法技能 → 移除并归一化
    NoReachableTarget = 'NoReachableTarget',      -- Reposition 无合法可达目标
    ZeroWeight        = 'ZeroWeight',
    NotFinite         = 'NotFinite',
    Busy              = 'Busy',
    Dead              = 'Dead',
}

--- 黑板 Key（规格 §3，禁止散落不一致字符串）
BossAI_Types.BBKeys = {
    TargetActor              = 'TargetActor',
    CombatActive             = 'CombatActive',
    HasLineOfSight           = 'HasLineOfSight',
    LastKnownTargetLocation  = 'LastKnownTargetLocation',
    DistanceToTarget         = 'DistanceToTarget',
    ActionKind               = 'ActionKind',
    SelectedSkill            = 'SelectedSkill',
    CurrentPhase             = 'CurrentPhase',
    PhaseTransitionReady     = 'PhaseTransitionReady',
    IsDead                   = 'IsDead',
    MustReset                = 'MustReset',
    CanApplyHardStagger      = 'CanApplyHardStagger',
    HomeLocation             = 'HomeLocation',
    MoveGoal                 = 'MoveGoal',
}

--- 黑板 Key 定义表（生成资产时使用：名称 → { 类型, 是否 InstanceSynced }）
BossAI_Types.BBKeyDefs = {
    { name = 'TargetActor',             type = 'Object', instanceSynced = false },
    { name = 'CombatActive',            type = 'Bool',   instanceSynced = false },
    { name = 'HasLineOfSight',          type = 'Bool',   instanceSynced = false },
    { name = 'LastKnownTargetLocation', type = 'Vector', instanceSynced = false },
    { name = 'DistanceToTarget',        type = 'Float',  instanceSynced = false },
    -- 当前 UGC 项目没有可绑定的原生 C++ Enum；已保存 BB_Boss 资产以 Int 存路由值。
    -- ActionKind / SkillID 数字枚举 API 保持不变，Native Enum 目标留待真实 C++ 工程。
    { name = 'ActionKind',              type = 'Int',    instanceSynced = false },
    { name = 'SelectedSkill',           type = 'Int',    instanceSynced = false },
    { name = 'CurrentPhase',            type = 'Int',    instanceSynced = false },
    { name = 'PhaseTransitionReady',    type = 'Bool',   instanceSynced = false },
    { name = 'IsDead',                  type = 'Bool',   instanceSynced = false },
    { name = 'MustReset',               type = 'Bool',   instanceSynced = false },
    { name = 'CanApplyHardStagger',     type = 'Bool',   instanceSynced = false },
    { name = 'HomeLocation',            type = 'Vector', instanceSynced = false },
    { name = 'MoveGoal',                type = 'Vector', instanceSynced = false },
}

--- 是否属于倍率型技能（用于决策与相位系数）
function BossAI_Types.IsAttackSkill(skillId)
    return skillId ~= nil and skillId ~= BossAI_Types.SkillID.None
end

return BossAI_Types
