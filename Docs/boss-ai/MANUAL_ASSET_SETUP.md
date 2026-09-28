# BT_Boss 资产核验与历史装配记录

## 当前资产操作边界（2026-09-23，先读此节）

**现有 `/TTS/Asset/AI/BT/BT_Boss` 已修复并保存；无需手工重新装配。不要全选删除、重画或运行本文历史章节的重建步骤。** 本文现在用于核验现有资产及在确有差异时定位子边。旧草案完整保留在文末折叠区，仅为事故追溯，不能直接照做。

本轮 UGC Editor 只读回查：`RootNode=BossPriority`，26 个连通图节点、0 orphan，七个 `BossExecuteSkillTask1..7` 齐全，17 个 Decorator 各在对应子边，唯一 `BossUpdateContext` Service 挂在不受 `CombatActive` 门控的 `BossPriority`。`repair_bt_boss_route.py` 的 `BT_ROUTE_MODE='verify'` 返回 `VERIFY_OK`；保存、卸载/重载后的目标结构曾读回。当前 LinuxServer 包有 44 个运行相关导出、0 个编辑器图类导入/图节点导出，DS 根节点读取为 `BossPriority`。这证明结构与加载，不证明七技能战斗完成；详见 [VERIFICATION.md](VERIFICATION.md)。

### 只读复核顺序

1. 在 UGC Editor 打开 `/TTS/Asset/AI/BT/BT_Boss`，查看树及黑板 `/TTS/Asset/AI/BB_Boss`。不要因为下方旧文档而保存“空白重建树”。
2. 用 UGC MCP `bb_query` 核对：总 15 键（14 个 `Types.BBKeyDefs` 自定义键 + 引擎自动 `SelfActor`，该键回读 `IsInherited=false`），全部 `IsInstanceSynced=false`；`ActionKind`、`SelectedSkill`、`CurrentPhase` 均为 **Int**。原 prompt 的 Native Enum 不是当前 UGC 资产类型。
3. 要证明磁盘资产仍相同，先在 Editor 卸载/重载 BT（必要时重启 Editor），再通过 UGC MCP `ue_py` 执行下列**只读** Python；预期 `VERIFY_OK`。它核图/运行节点对象、父子顺序和 Decorator/Service 归属，但不核 Service Interval、Task 选项与所有 BB 值。

   ```python
   BT_ROUTE_MODE = 'verify'
   exec(compile(open(
       r'E:\WeGameApps\rail_apps\OasisEraEditor(2001776)\ShadowTrackerExtra\UGCProjects\TTS\Docs\boss-ai\repair_bt_boss_route.py',
       encoding='utf-8').read(), 'repair_bt_boss_route.py', 'exec'))
   ```

4. 源资产变更后重新以 LinuxServer 保存/Cook，并重算包的长度、SHA256 和导入/导出数。在**干净** PIE/DS 用 `UE.LoadObject('/TTS/Asset/AI/BT/BT_Boss.BT_Boss')` 读回非空 RootNode 与 `NodeName=BossPriority`；再逐条实测路由，而非只看 LoadObject 成功。旧 Cook 哈希和 DS 日志行号见 [VERIFICATION.md](VERIFICATION.md)。
5. `VERIFY_OK` 失败时保留现有文件和输出、比对实际差异；不要盲跑脚本默认的 `apply`，也不要先全删再问原因。若确需修复，应先备份、审查差异及脚本的旧/目标前置条件，再按新的资产状态制定操作。

### 当前路由的人工核对表

| 父节点 | 子节点顺序 | 条件/附属 |
|---|---|---|
| `BossPriority` | Death → ReturnHome → HardStagger → PhaseTransition → Combat → Idle | 前五个子边分别为 `IsDead`、`MustReset`、`CanApplyHardStagger`、`PhaseTransitionReady`、`CombatActive`；唯一 `BossUpdateContext` 服务挂父节点。 |
| `Combat` | OneDecision → WaitCombat | `CombatActive` 条件在进入 Combat 的子边，不把唯一服务埋入 Combat。 |
| `OneDecision` | BossPlanNextActionTask → ActionRouter | 决策后按路由运行。 |
| `ActionRouter` | GiveSpace → Search → SkillRouter → ChaseSlice → Reposition | 各子边 `ActionKind` 值依次 **4、5、1、2、3**。 |
| `SkillRouter` | BossExecuteSkillTask1..7 | 各子边 `SelectedSkill` 值依次 **1..7**，共用执行任务类。 |
| `Idle` | BossSetIdleStateTask → WaitIdle | 无目标时空闲；该行为仍需真实 PIE 时序验收。 |

上述 5+5+7 条正好为 17 个子边条件。真实节点/键值以 Editor 回读为准。服务从原规格树示意的 Combat 挂点移到无门控顶层，是为了 `CombatActive=false` 时仍有感知更新；现有 DS 已见目标入战，遮挡、MoveTo、七技能与双 Boss 还须继续验收。

<details>
<summary>历史手工重建草案（已失效：含“全删重画”和错误的 Combat 服务挂点）</summary>

> **2026-09-23 当前状态：以下手工重建步骤已被实际资产修复替代，仅保留作历史回退资料。** 原始 `/TTS/Asset/AI/BT/BT_Boss` 已通过 [repair_bt_boss_route.py](repair_bt_boss_route.py) 重建为 26 个全连通图节点，17 条条件分别挂在对应子边，唯一 `BossUpdateContext` 服务挂在无门控 `BossPriority` 顶层。关闭/卸载/重新加载后严格结构校验通过；LinuxServer 包有 44 个运行节点导出、0 个编辑器图类导入、0 个图节点导出。PIE DS 已读到 `RootNode.NodeName=BossPriority`，没有原先的图类缺失错误。无需在编辑器里全选删除重画，也不要对已修好的树运行下面的旧步骤。最新运行验证以 [VERIFICATION.md](VERIFICATION.md) 为准。

> 用途：阶段 B 的行为树骨架装配。资产与节点蓝图已由脚本创建完毕，**但行为树结构必须在 BT 编辑器 UI 内搭建并 Ctrl+S**——脚本 `bt_*` 接口只改图且连接不可靠（实测：`bt_add_node` 的 parent 不建立真实连接、`bt_link` 报"已连接"而图仍显示孤立），且脚本改动的树不会被编译执行。

## 一、已创建资产（无需重复创建）

| 资产 | 路径 | 说明 |
|---|---|---|
| `BB_Boss` | `/TTS/Asset/AI/BB_Boss` | 14 键黑板（已就绪） |
| `BT_Boss` | `/TTS/Asset/AI/BT/BT_Boss` | 行为树（黑板已绑 `BB_Boss`；根节点 `BossPriority` 已建） |
| 任务节点蓝图 | `/TTS/Asset/AI/BT/BTTask_Boss*` | 共 11 个，父类 `BTTask_LuaBase` |
| 服务节点蓝图 | `/TTS/Asset/AI/BT/BTService_BossUpdateContext` | 父类 `BTAttachment_LuaBase` |
| Lua 脚本 | `Script/AI/BT/BTTask_Boss*.lua`、`BTService_BossUpdateContext.lua` | 与蓝图一一对应 |

> **编辑器里可能已存在 6 个孤立节点**（`Combat` / `Idle` / `OneDecision` / `ActionRouter` / `SkillRouter` 及脚本建的根 `BossPriority`）——是脚本残留，可直接拖拽使用或选中删除重建。

## 二、目标结构（规格 §8）

```text
ROOT: BossPriority (Selector)                      ← 已存在
├─ BossDeathTask            (BTTask_BossDeath)          [Dec] IsDead 已设置
├─ BossReturnHomeTask       (BTTask_BossReturnHome)     [Dec] MustReset 已设置
├─ BossHardStaggerTask      (BTTask_BossHardStagger)    [Dec] CanApplyHardStagger 已设置
├─ BossPhaseTransitionTask  (BTTask_BossPhaseTransition)[Dec] PhaseTransitionReady 已设置
├─ Combat (Selector)                                    [Dec] CombatActive 已设置
│  │  ★ Service: BTService_BossUpdateContext（挂在 Combat 本身上，间隔 0.2 / 随机偏差 0.03）
│  ├─ OneDecision (Sequence)
│  │  ├─ BossPlanNextActionTask (BTTask_BossPlanNextAction)
│  │  └─ ActionRouter (Selector)
│  │     ├─ BossGiveSpaceTask  (BTTask_BossGiveSpace)     [Dec] ActionKind == 4
│  │     ├─ BossSearchTask     (BTTask_BossSearch)        [Dec] ActionKind == 5
│  │     ├─ SkillRouter (Selector)                        [Dec] ActionKind == 1
│  │     │  ├─ SkillS1 (BTTask_BossExecuteSkill)          [Dec] SelectedSkill == 1
│  │     │  ├─ SkillS2 … SkillS7（同一节点类 ×7，仅装饰器不同；S2–S7 对应值 2–7）
│  │     ├─ BossChaseSliceTask (BTTask_BossChaseSlice)    [Dec] ActionKind == 2
│  │     └─ BossRepositionTask (BTTask_BossReposition)    [Dec] ActionKind == 3
│  └─ Wait 0.2 (BTTask_Generic_Wait)
└─ Idle (Sequence)
   ├─ BossSetIdleStateTask (BTTask_BossSetIdleState)
   └─ Wait 0.5 (BTTask_Generic_Wait)
```

## 三、装饰器统一配置（全部用平台标准 `BTDecorator_Blackboard`）

| 装饰器 | 黑板键 | 操作 | Notify Observer | Flow Abort Mode |
|---|---|---|---|---|
| 顶层 4 个分支 & Combat | `IsDead` / `MustReset` / `CanApplyHardStagger` / `PhaseTransitionReady` / `CombatActive` | **Is Set** | **On Value Change** | **Both**（中止自身与低优先级分支） |
| `ActionKind` 路由条件 | `ActionKind` | **Int Is Equal To** | None | **None**（不中途换招） |
| `SelectedSkill` 路由条件 | `SelectedSkill` | **Int Is Equal To** | None | None |
| `SkillRouter` 自身 | `ActionKind` | Int Is Equal To 1 | None | None |

> `ActionKind` 取值：0=None 1=Skill 2=Chase 3=Reposition 4=GiveSpace 5=Search（与 `BTTask_BossPlanNextAction.lua` 中的 `ActionKind` 表一致）。

## 四、操作步骤

> **⚠️ 2026-09-23 实证更新（必须阅读）**：BT_Boss 现存的**全部节点、装饰器与服务均为脚本创建**（`bt_add_node` / `ue.new_object`）。实测 DS/PIE 日志报 `Could not find class UGCBehaviorTreeGraphNode_*`（44 次，全部来自 BT_Boss）→ **脚本创建的图节点在 PIE（DS 进程，无编辑器模块）上无法加载 → 资产加载不完整 → 行为树完全不运行**（任务/服务 Lua 探针无输出、黑板未初始化）。编辑器“打开+Ctrl+S”**不能**修复。**因此：必须在 BT 编辑器 UI 内重建整个结构（全选删除 → 重新拖拽），装饰器与服务也必须在编辑器里添加。**

> 以下步骤以“在编辑器内重建”为准（原文“不需要再拖节点”已失效）。

1. 双击打开 `/TTS/Asset/AI/BT/BT_Boss`（BT 编辑器）。
2. 给以下节点加 **`BTDecorator_Blackboard`**（选中节点 → 右键 **Add Decorator → Blackboard**），键与操作按下表：
   - `BossDeathTask` ← `IsDead` Is Set
   - `BossReturnHomeTask` ← `MustReset` Is Set
   - `BossHardStaggerTask` ← `CanApplyHardStagger` Is Set
   - `BossPhaseTransitionTask` ← `PhaseTransitionReady` Is Set
   - `Combat` ← `CombatActive` Is Set
   - `BossGiveSpaceTask` ← `ActionKind` Int Is Equal To **4**
   - `BossSearchTask` ← `ActionKind` Int Is Equal To **5**
   - `SkillRouter` ← `ActionKind` Int Is Equal To **1**
   - `BossExecuteSkillTask1..7` ← `SelectedSkill` Int Is Equal To **1..7**
   - `BossChaseSliceTask` ← `ActionKind` Int Is Equal To **2**
   - `BossRepositionTask` ← `ActionKind` Int Is Equal To **3**
   - 中止设置：前 5 个用 **Notify Observer = On Value Change、Flow Abort Mode = Both**；所有 Int 路由条件用 **None / None**。
3. 选中 **`Combat`** 节点 → 右键 **Add Service** → `BTService_BossUpdateContext`；在细节面板设 **Interval = 0.2**、**Random Deviation = 0.03**。
4. 设置两个 Wait 的时长：`WaitCombat` = **0.2 秒**、`WaitIdle` = **0.5 秒**。
5. **Ctrl+S 保存**（关键：只有编辑器保存的树才会被编译执行）。
6. 回一句"已保存"，我立即执行 PIE 用例 1/2/3 验证。

## 五、验收（阶段 B：用例 1 / 2 / 3）

| 用例 | 期望 |
|---|---|
| 1 | 无合法玩家时进入 Idle 分支：`BossSetIdleState` 使 `CombatActive=false`，无移动、无攻击 |
| 2 | 感知到玩家后 `CombatActive=true`、`TargetActor` 被写入（由 AIController 感知完成，阶段 B-3 实施），`DistanceToTarget` 随服务刷新 |
| 3 | 玩家绕柱遮挡：`HasLineOfSight=false` 时进入 `BossSearch`（向 `LastKnownTargetLocation` 移动），**不立即脱战**、不读取遮挡后的实时位置；超过 `DisengageDistance`(6000) 才清目标 |

> 说明：阶段 B 的视线为"距离近似"（`BTService_BossUpdateContext.lua` 中 `LosApproxDistance=3000`）；阶段 C 接入 AI Perception 与射线后替换。

</details>
