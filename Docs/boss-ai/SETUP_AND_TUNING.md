# BOSS AI 接入与调参指南（SETUP_AND_TUNING）

> 面向：在本项目中接入 / 调试 BOSS AI 的开发者
> 前置阅读：`IMPLEMENTATION_PLAN.md`（环境结论与方案）、`VERIFICATION.md`（当前验证状态）

---

## 一、代码结构（已交付）

| 文件 | 职责 | 关键接口 |
|---|---|---|
| `Script/AI/Boss/BossAI_Types.lua` | 枚举 / 黑板 Key 定义（含 `BBKeyDefs` 生成表） | `Types.ActionKind / SkillID / Intent / SkillMove / BreathingPhase / BBKeys / RejectReason` |
| `Script/AI/Boss/BossAI_Config.lua` | 七技能与全局参数（唯一数值来源） | `Config.Skills / SkillById / IntentWeights / PhaseSkillFactor / Pressure / Perception / Graybox` |
| `Script/AI/Boss/BossAI_Random.lua` | 确定性随机流（LCG） | `Random.New(seed)` → `Next / Range / Int / PickWeighted` |
| `Script/AI/Boss/BossAI_State.lua` | 每实例战斗状态（严禁共享） | `State.New(config, seed)`；`CommitSkill / EndAction / IsSkillReady / ShouldGiveSpace / StartBreathing / TickBreathing / RegisterDanger / PredictThreatFreeTime / RequestPhaseTransition / DebugSnapshot` |
| `Script/AI/Boss/BossAI_Decision.lua` | 两级带权随机决策（纯逻辑） | `Decision.ComputeEdgeDistance / CheckSkillLegal / ComputeSkillWeight / PickSkillFrom / BuildIntentPool / PlanNextAction(state, ctx)` |
| `Script/AI/Boss/BossAI_Tests.lua` | 纯逻辑自测（8 组 29 断言） | `Tests.RunAll()` |

**加载方式**：`UGCGameSystem.UGCRequire('Script.AI.Boss.BossAI_XXX')`（与项目现有 `Script.*` 约定一致）。

---

## 二、在黑板上创建 BB_Boss（14 键）

用 `Types.BBKeyDefs` 逐项创建（名称 / 类型 / 不启用 Instance Synced）：

| Key | 类型 | Key | 类型 |
|---|---|---|---|
| TargetActor | Object(Actor) | IsDead | Bool |
| CombatActive | Bool | MustReset | Bool |
| HasLineOfSight | Bool | CanApplyHardStagger | Bool |
| LastKnownTargetLocation | Vector | HomeLocation | Vector |
| DistanceToTarget | Float | MoveGoal | Vector |
| ActionKind | **Native Enum**(ActionKind) | CurrentPhase | Int |
| SelectedSkill | **Native Enum**(SkillID) | PhaseTransitionReady | Bool |

> 在 UGC 编辑器内可用 MCP `bb_*` 接口批量创建与校验（`bb_add_key / bb_query`）。

---

## 三、BT 节点接线（阶段 B 待实施）

UGC 提供 Lua BT 基类，接线映射如下（已确认接口存在）：

| BT 节点 | 基类 | Lua 回调映射 |
|---|---|---|
| `BTTask_BossPlanNextAction` | `UBTTask_LuaBase` | `ReceiveExecuteAI(ctrl, pawn)` → 组装 ctx → `Decision.PlanNextAction(state, ctx)` → 写黑板 `ActionKind/SelectedSkill` → `FinishExecute(true)` |
| `BTTask_BossExecuteSkill` | `UBTTask_LuaBase` | `ReceiveExecuteAI` 启动技能运行时（Windup→Active→Recovery），完成/中止时 `FinishExecute(bSuccess)` / `FinishAbort()`；`ReceiveAbortAI` 中必须幂等清理 |
| `BTService_BossUpdateContext` | `UBTAttachment_LuaBase` | `ReceiveTickAI` 内按 0.2s（RandomDeviation 0.03）更新感知/距离/视线上下文；`ReceiveDeactivationAI` 清理 |
| 高优先级条件（IsDead / MustReset / PhaseTransitionReady / CombatActive） | `UBTCondition_LuaBase` | `PerformConditionCheckAI` 读取黑板/状态；按规格 §8 使用观察式中止（Both/低优先级） |

**状态归属**：`State` 实例必须挂在 `pawn`（或每 BOSS 的组件）上，**不得**放入 BT 节点共享模板或静态变量。

**ctx 字段约定**（`PlanNextAction` 入参）：

```lua
ctx = {
  now           = 服务器时间（秒）,
  targetValid   = 目标有效,
  hasLOS        = 当前视线,
  centerDistance= 水平中心距, bossRadius = 胶囊半径, targetRadius = 目标半径,
  -- 或直接给出 edgeDistance（优先）
  heightDiff    = 目标与自身高度差,
  pathOk        = 突进/地面技的通道与落点校验结果,
  dangerConflict= 是否与残留危险冲突（S6/S7 安全区校验失败时置 true）,
  canChase      = 是否可接近,
  canReposition = 是否存在可达站位目标,
  candidateSeconds = 候选动作（前摇+有效+后摇）总时长（用于预算预测）,
  isDead        = 死亡标记,
}
```

---

## 四、Sky 技能运行时的接入约定（阶段 C 待实施）

- 每次执行分配递增 `ActionInstanceID`（`State:CommitSkill` 内已实现），**进入前摇才计冷却与承诺**（规格 §9）。
- 所有伤害/预警必须登记为"危险"：`State:RegisterDanger(skillId, actionInstanceId, expireAt)`，结束/销毁时 `UnregisterDanger`；超时由 `SweepDangers` 关闭并计数。
- Abort / EndPlay / UnPossess / Reset 必须：关伤害窗、撤未生成、清 Timer/Delegate、释放移动/朝向所有权、标记终止（幂等）。
- 旧回调（Timer / 动画通知）必须校验 `actionInstanceId`，`State:EndAction(id)` 已内置该守卫。

---

## 五、调参与实机测试顺序（建议）

1. **先跑纯逻辑自测**（不依赖引擎对象）：
   ```
   local Tests = UGCGameSystem.UGCRequire('Script.AI.Boss.BossAI_Tests'); Tests.RunAll()
   ```
   预期 `29/29 PASS`（修改 Lua 后务必**重启 PIE** 再验证）。
2. **感知与距离**：先确认 `DistanceToTarget`/`HasLineOfSight` 更新正确，再调 `Config.Perception`（2500/3000/85°）。
3. **意图手感**：调 `Config.IntentWeights`（P1 65/25/10，P2 75/20/5）与 `Config.PhaseSkillFactor`（P2: S2/S3/S7=1.2）。
4. **节奏与喘息**：调 `Config.Pressure`（3 次 / 8s / 2s / 0.8s）；观察 `DebugSnapshot()` 的 `committed/burstElapsed/breathingPhase`。
5. **技能数值**：逐条调 `Config.Skills[i]` 的 `minDist/maxDist/windup/active/recovery/cd/baseWeight`。
6. **灰盒伤害**：`Config.Graybox`（不改动玩家数值体系；正式接入时替换为项目伤害接口）。

`State:DebugSnapshot(now)` 返回的字段可直接用于规格 §13 的调试显示（Phase / ActionKind / SkillID / 冷却 / 预算 / 危险数 / 喘息 / GapClose）。
