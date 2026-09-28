# BOSS AI 接入与调参指南（SETUP_AND_TUNING）

## 当前接入方式（2026-09-23）

本指南以 **TTS 定制 UE4.18.1 UGC Lua 项目**的现有资产为准。`SuperMonster` 的 BehaviorControlComp 已绑定 `/TTS/Asset/AI/BT/BT_Boss`，该树绑定 `/TTS/Asset/AI/BB_Boss`。已保存的树有 26 个全连通图节点、7 个技能子分支与 17 个子边条件。**先只读回查，不要按历史章节删除/重建 BT。** 实际 Cook、DS 与 PIE 边界见 [VERIFICATION.md](VERIFICATION.md)。

### 模块与资产

| 路径 | 当前用途 |
|---|---|
| `Script/AI/Boss/BossAI_Types.lua` | 数字枚举、`BBKeys` 与 14 个自定义 `BBKeyDefs`。 |
| `Script/AI/Boss/BossAI_Config.lua` | 七技能、感知/预算/灰盒数值；模块加载时 `Config.Validate(Config.Skills)`，失败报 `BossAI_Config invalid: ...`，成功后才建立 `SkillById`。 |
| `Script/AI/Boss/BossAI_{Random,State,Decision,Observed,SkillRuntime,Graybox}.lua` | 随机流、每 Pawn 战斗状态与上下文、选招、技能阶段和灰盒实现。 |
| `Script/AI/BT/BTService_BossUpdateContext.lua`、`BTTask_Boss*.lua` | 服务和任务 Lua 回调；对应 `/TTS/Asset/AI/BT/` 下的节点蓝图。 |
| `/TTS/Asset/AI/BB_Boss` | MCP 回读总计 15 键：14 个自定义键 + 引擎自动 `SelfActor`（其回读 `IsInherited=false`）；所有键不启用 Instance Synced。 |
| `/TTS/Asset/AI/BT/BT_Boss` | 根 `BossPriority`，唯一 `BossUpdateContext` 服务挂在根层以允许未入战时感知；已修复的七技能路由。 |
| `/TTS/Asset/AI/BP_BossAIController`、`/TTS/Asset/Blueprint/Prefabs/Monsters/SuperMonster` | 当前控制器与 Boss 实体绑定；复用现有 `UGCmap` 做灰盒区域测试。 |

黑板路由键 `ActionKind` 和 `SelectedSkill` **实际类型是 Int**，`CurrentPhase` 也是 Int。Lua 的 `Types.ActionKind`/`Types.SkillID` 仍为数字枚举；使用 `SetValueAsInt`/`GetValueAsInt`。原 prompt 的 Native Enum 是设计目标，不是该 UGC 资产的当前类型。不要仅为匹配文字说明替换二进制黑板键。

### 当前树的接线读法

```text
BossPriority (Selector) [Service: BossUpdateContext]
├─ BossDeathTask             [IsDead]
├─ BossReturnHomeTask        [MustReset]
├─ BossHardStaggerTask       [CanApplyHardStagger]
├─ BossPhaseTransitionTask   [PhaseTransitionReady]
├─ Combat (Selector)         [CombatActive]
│  ├─ OneDecision (Sequence)
│  │  ├─ BossPlanNextActionTask
│  │  └─ ActionRouter (Selector)
│  │     ├─ BossGiveSpaceTask     [ActionKind = 4]
│  │     ├─ BossSearchTask        [ActionKind = 5]
│  │     ├─ SkillRouter           [ActionKind = 1]
│  │     │  └─ BossExecuteSkillTask1..7 [SelectedSkill = 1..7]
│  │     ├─ BossChaseSliceTask    [ActionKind = 2]
│  │     └─ BossRepositionTask    [ActionKind = 3]
│  └─ WaitCombat
└─ Idle (Sequence)
   ├─ BossSetIdleStateTask
   └─ WaitIdle
```

17 个 Decorator 分别属于上图带方括号的子分支；五个优先级条件按资产允许的观察中止配置，`ActionKind`/`SelectedSkill` 的普通路由不应在已承诺动作中途抽招。服务挂 `BossPriority` 是为未入战也能获取目标的 UGC 适配，原 prompt 的 Combat 挂点在这里不使用。结构验证脚本不检查 Service Interval、每个 Task 参数或黑板全部数值，调试时仍须在 Editor/PIE 读回。

### 配置与测试的安全顺序

1. 调 `Config.Skills` 的距离（cm）、`windup/active/recovery/cd`（秒）、`baseWeight`、`maxDangerLife` 时，保留 S1–S7 唯一 ID、有限危险寿命和有效伤害窗口；`Config.Validate(skills)` 可预检候选列表，模块重新加载也会强制验证。`SkillById` 在模块加载后由已通过校验的列表构建。
2. 先在 TTS 根目录运行 `pwsh -NoProfile -Command "python Docs/boss-ai/run_lua_tests.py"`，记录五套分项/总数和退出码。它使用 Lupa 替身，**只证明纯 Lua**；最新数值以 [VERIFICATION.md](VERIFICATION.md) 为准。
3. 资产变更后在 UGC Editor 卸载并重新加载 BT，再用 [repair_bt_boss_route.py](repair_bt_boss_route.py) 的 **`BT_ROUTE_MODE='verify'`** 只读检查；预期 `VERIFY_OK`。脚本默认 `apply` 会写源资产，不用于日常调参核验。Cook 后重新记录文件哈希，再在干净 PIE/DS 读回 `BossPriority` 和黑板。
4. DS 感知使用 AIPerception 当前候选、阵营与 `LineOfSightTo`，仅确认视线后更新玩家真实位置；失去视线时保留 `LastKnownTargetLocation`。先查 `TargetActor`、`CombatActive`、`HasLineOfSight`、`DistanceToTarget`，再判断规划。默认感知 2500/3000 cm、半视角 85°；当前干净 DS 已观察到感知入战，但柱子遮挡时序未验。
5. 先按 [VERIFICATION.md](VERIFICATION.md) 的最新 DS 记录检查移动、黑板与技能状态：干净 PIE 已证明 Chase 实际位移、Boss/玩家半径读取和 S1/S2 预检，S2 已进入运行时活动状态；`path-stopped` 仍会重复出现。S3–S7 的真碰撞、安全路线、预警、命中、后摇与 Abort 尚待逐招验收，尤其 S6/S7 因当前 DS 缺少可用的完整路径查询而保守拒绝。不要把纯 Lua 灰盒测试当成实机成功。
6. **每次启动新的 PIE，生成 Boss 前先在 DS Lua 控制台给当前测试玩家开启无敌，并在 DS 日志确认 `flag=true count=1`。** 已有 PIE 的设置不会跨重启保留。测试结束可关闭 PIE；此设置只保护调试玩家，不是正式玩法数值改动。

   ```lua
   local gs = UGCGameSystem.GetGameState()
   local count = 0
   for _, ps in pairs((gs and gs.PlayerArray) or {}) do
       local player = ps:GetPlayerCharacterSafety()
       if player and UE.IsValid(player) then
           player:SetInvincible(true)
           print('[BOSS_GODMODE] flag=' .. tostring(player.bInvincible))
           count = count + 1
       end
   end
   print('[BOSS_GODMODE] count=' .. tostring(count))
   ```

调参观察顺序：感知与水平胶囊边缘距离 → `IntentWeights`（P1 65/25/10，P2 75/20/5）及 P2 S2/S3/S7 系数 1.2 → `Pressure`（3 次、8 秒预算、完整 2 秒喘息、S3 延迟 0.8 秒）→ 各技能时序/伤害 → `State:DebugSnapshot(now)` 的冷却、危险和喘息字段。修改 Lua 后以**干净 PIE**确认运行版；历史热重载曾混用旧 upvalue，不能把热重载结果当最终验收。

<details>
<summary>历史接入草案（2026-09-22；含已过时的 14 键创建和 Combat 服务挂点说明）</summary>

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

</details>
