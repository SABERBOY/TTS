# BOSS AI 实施计划（基于真实仓库审查）

## 2026-09-23 当前实施基线

用户已确认在 **TTS** 使用方案 A：Lua 核心、UGC 原生 BT/BB、Lua BT 节点、灰盒七技能，复用 `SuperMonster` 与 `UGCmap`，双 Boss 隔离纳入最终验收。这个项目是定制 UE4.18.1 UGC Lua 工程，没有可编译的 C++ `Source`/`Build.cs`；因此原规格的 Native Enum/C++ 类与 Editor 模块需作为环境差异记录，不能写成已实现。Git 工作树有并行用户/agent 改动，保留现状。

### 当前交付与证据

| 阶段 | 当前状态 | 证据及尚缺内容 |
|---|---|---|
| A：配置、决策、状态 | 七技能配置和 `Config.Validate(skills)`、权重/重复/预算/喘息、危险登记与有限寿命已落地；纯 Lua 用例通过 | [VERIFICATION.md](VERIFICATION.md) 的最新本地测试结果；纯逻辑不能替代 DS 战斗。 |
| B：BB、BT、感知 | `BB_Boss` 14 个自定义键及引擎自动 `SelfActor`；`BT_Boss` 26 个全连通图节点、17 条子边 Decorator、7 条技能路由，服务挂在无门控 `BossPriority`；Cook 与 DS 根节点加载、玩家感知入战已读回 | `ActionKind`/`SelectedSkill` 为 UGC **Int**，不是原规格 Native Enum。DS 已执行 Chase/Search 分支，但移动请求失败；柱子遮挡与 Idle 全时序未验。 |
| C：动作生命周期和移动 | `BossAI_SkillRuntime`、`BossAI_Graybox`、BT Task、清理/看门狗和每 Pawn 状态在代码及替身测试中存在 | 干净 DS 的 Chase/Search 曾反复 `move-request-failed`。正在诊断导航与有界退避；Windup/Active/Recovery 各阶段真实 Abort 和移动所有权未完成 PIE 验收。 |
| D：七技能与表现 | 七槽配置、灰盒预警/投射/地面安全通道逻辑和客户端警示代码存在，独立 Lua 用例覆盖多个几何及清理边界 | 最近 `Graybox.Prepare` 已补传 `ctx.target` 给 `HasClearDamagePath`，本地回归通过；**修复后 PIE 尚未重启验证**。现有 DS `TakeDamage` 行不能直接归因新七技能。 |
| E：资产和双 Boss 验收 | `repair_bt_boss_route.py` 只读目标结构校验、LinuxServer Cook 和 DS `BossPriority` 加载已有证据；验证矩阵已列出 24 项 | 还需单 Boss 七技能/遮挡/阶段/喘息/清理的真实 PIE，再做两只 Boss 共用 BT 的隔离测试。新测试地图未创建；按用户已接受的 `UGCmap` 划区执行。 |

`BTService_BossUpdateContext` 放在 `BossPriority`，使 `CombatActive=false` 时仍能发现目标；这是对原规格中 Combat 挂点的 UGC 适配。`repair_bt_boss_route.py` 的 `verify` 只核结构与对象归属，不替代 BB 全字段、Service 间隔、Task 参数及 DS 行为逐项回读。不要对当前已修复的树运行旧的全删重画步骤。

**§13 测试地图差异**：用户此前已确认使用现有 `UGCmap` 划区并把双 Boss 纳入首轮验收。当前地图只读审计仅见 `UGCmap.umap`，`StartMapName=/TTS/UGCmap`，对应唯一 `Navmesh/UGCmap.navmesh`；原 prompt 提议的独立 `L_BossAITest` 地图尚未创建，不能在交付中写成已完成。

### 下一段可执行工作

1. 完成 `MoveToActor`/`MoveToLocation` 失败原因与失败退避诊断；在新干净 PIE/DS 记录请求返回、导航路径、位置变化、失败频率。**最终移动结果待主任务补录。**
2. 重新 Cook/启动干净 PIE，复验最近 `Graybox.Prepare` 目标过滤修复及警示/实际伤害归属；避免把原有 `SuperMonster` 攻击日志记为七技能证据。
3. 按 [VERIFICATION.md](VERIFICATION.md) 的 24 项矩阵补真实场景：无目标 Idle、感知与遮挡、七技能预警和命中、各阶段 Abort、危险清理/喘息、一次性转阶段、目标失效和双 Boss 隔离。每项记录新日志、时刻、实际输出与失败原因。
4. 资产变动后重新卸载/加载并执行 `BT_ROUTE_MODE='verify'`；Cook 重新计算哈希并在 DS 读回根与具体路由。当前保存的资产不要因旧文档手工步骤被删除。

<details>
<summary>历史计划与阶段记录（2026-09-22 至 2026-09-23 较早快照；不作为当前操作指令）</summary>

## 2026-09-23 当前执行计划

本节是本次执行的当前基线；下方 2026-09-22 记录保留为历史。用户已要求在当前 TTS 项目执行原规格，并允许使用 UGC MCP。当前工程是定制 UE4.18.1 UGC 项目，交付方式沿用已选定的 Lua 核心 + 原生 BT/BB + Lua BT 节点。原规格中的 C++ 模块和 UE4.27/UE5 构建不适用于此工程，不能据此宣称已完成。

### 已核实的现状

- 当前目录是 Git 仓库；Boss AI、SuperMonster、法师树、CCP、Navmesh 均有用户未提交改动，包含暂存与未暂存内容。以下只改本任务所需文件，不提交或还原现有内容。
- `Script/AI/Boss/BossAI_{Types,Config,Random,State,Decision,Tests}.lua` 已存在。旧记录的 29/29 仅证明 2026-09-22 的纯逻辑测试，不能证明当前代码或战斗集成。
- `BB_Boss`、`BT_Boss` 和 Boss BT 节点资产已创建。当前 `BT_Boss` 图节点由脚本创建，历史 DS 日志显示编辑器图类加载失败，尚不能视为可运行树。
- `BTTask_BossPlanNextAction.lua` 尚未调用决策模块；`BTTask_BossExecuteSkill.lua` 与 `BTTask_BossGiveSpace.lua` 仍是立即完成的占位实现；感知服务以距离近似视线且遮挡后读取目标实时位置。

### 阶段与完成判据

1. **A：决策和状态修正。** 在 `BossAI_State.lua`、`BossAI_Decision.lua` 与对应测试中修复追击计入预算、按候选技能预测危险失效时刻、喘息中止/恢复与危险超时等边界；用本地 Lua 或 DS 重新运行测试，记录新输出。
2. **B：真实资产与感知入口。** 用 UGC MCP 回读 `BB_Boss`、`BT_Boss`、节点绑定与 SuperMonster。修复 BT 运行节点对编辑器图对象的依赖，保存重载并在 DS 证明能启动。将目标发现放在不受 `CombatActive` 门控的位置；视线、最后已知位置、距离分别按实际观察更新。
3. **C：动作生命周期。** 每 BOSS 独立状态、异步 Windup/Active/Recovery、Abort/死亡/归位清理、移动所有权和真正的 DrainThreats → 2 秒 Breathing。先让 S1/S3/S5 在灰盒中产生可躲避的实际伤害。
4. **D：补齐七技能。** 实现 S2/S4/S6/S7 的预警、命中、有限危险寿命、安全通道拒绝、阶段切换和调试信息；不以日志输出代替伤害与位移。
5. **E：集成验证。** 保存重载读回 BT/BB/蓝图连接，运行单 BOSS 与双 BOSS PIE/DS，覆盖遮挡、撞墙、打空、喘息、Abort、阶段、重置；更新 `SETUP_AND_TUNING.md`、`VERIFICATION.md`、必要手工资产步骤。

所有阶段以真实回读和运行结果为完成依据。现有编辑器图可能触发 DS 加载失败；若 UGC MCP 无法安全修复编辑器专属资源，交付已验证代码、精确的编辑器操作步骤和未通过项，不把脚本图或占位任务算作完成。

> 依据：`Docs/Codex_UE_Boss_BehaviorTree_Prompt.md` 规格
> 审查时间：2026-09-22
> 结论摘要：**当前仓库不包含 C++ 工程与编译环境，规格中的"C++ 核心"部分无法按原文实施**；其余目标可在 UGC 环境以 Lua + 原生 BT/BB + 蓝图任务/服务落地。**等待用户确认方案后再进入实施阶段。**

---

## 0. 工程审查结论（实测证据）

| 检查项 | 结果 | 证据 |
|---|---|---|
| 引擎/编辑器 | UE **4.18.1** 定制版（OasisEraEditor 2001776 / ShadowTrackerExtra） | MCP `ctx:` 返回 `engine_version=4.18.1-0+++UE4+Release-4.18` |
| UGC 项目 | `UGCProjects/TTS` —— **纯资产 + Lua 脚本项目** | 目录仅含 `Asset/`（484 个资产）、`Script/`（226 个 Lua）、`Docs/`、`UGCmap.umap` 等 |
| `.uproject` / `Build.cs` / `Target.cs` / `.sln` | **不存在** | workspace 全量搜索 0 命中 |
| 引擎根 `Source/` 目录 | **不存在** | `Test-Path Source` = False |
| C++ 编译能力 | **无**（无工程文件、无模块） | 同上 |
| 版本控制 | **非 git 仓库** | `git status` → `fatal: not a git repository` |
| 脚本体系 | **Lua**（`Script/**/*.lua`，216 个）+ 编辑器自动化（UGC MCP） | 项目结构 |
| `Content/LuaHelper` | 仅 **Lua 类型存根**（IDE 提示用），非可编译源码 | `Engine/NoExportTypes.lua`、`Source/**/*.lua` |
| UGC 行为树能力 | 官方 BT/BB 资产 + ~600 个 BT 节点 + **蓝图 BT 基类**（`BTTask_BlueprintBase`/`BTService_BlueprintBase`/`BTService_BlueprintBaseEx`）+ **Lua BT 基类**（`BTCondition_LuaBase`/`BTAttachment_LuaBase`） | `bt:nodes` 枚举 + `LuaHelper/Engine/.../BehaviorTree/UGC/*.lua` |
| UGC 感知能力 | 引擎含 AIModule 与 AI Perception（存在 `BTService_SensedEnemy`、`AISenseLimitVolume`、`AIWorldSoundManagerComponent` 等） | LuaHelper 搜索命中 |
| 技能/伤害体系 | `UGCPersistEffectSystem`（PESkill 资产，项目已用：`AddSkillByClass`）、`UGCGameSystem.ApplyDamage`、属性系统 `UGCAttributeSystem` | 项目 Lua 实测 |
| 运行期调试 | UGC MCP：PIE 启停、DS/客户端 Lua 注入、实时日志 | 本轮已验证 |

---

## 1. 原规格不可满足项（需用户确认后调整）

| # | 规格要求 | 状态 | 原因 / 影响 |
|---|---|---|---|
| 1 | C++ 核心：`BossAIController`、`BossCombatComponent`、`BossDecisionPolicy`、`BTTask_Boss*`、`BTService_BossUpdateContext` 等原生类 | **✗ 不可满足** | 无 C++ 工程、无 `Source/`、无编译工具链；UGC 项目不允许新增 C++ 模块 |
| 2 | 独立 Editor 模块 / Commandlet 生成与校验资产 | **✗ 不可满足** | 同上；替代：UGC MCP 编辑器自动化（已具备 BT/BB/资产操作能力） |
| 3 | UE4.27 / UE5 双版本兼容 | **✗ 不适用** | 实际引擎为 UE4.18 UGC 定制版 |
| 4 | UE Automation Test Framework / Functional Testing | **✗ 未验证可用** | 定制版未暴露该框架；替代：Lua 断言自测 + PIE 集成验证 |
| 5 | "构建 BT 图节点/连接并保证编辑器图与运行时一致" | **⚠️ 受限** | 实测 UGC 图 API 仅支持部分操作：`bt_remove_node` 会以图重写运行时树；装饰器/服务无脚本接口。详见 `Docs/UGCBehaviorTreeGraph_同步机制与验证.md` |
| 6 | git 相关约束（保留用户改动 / 不提交） | **✗ 不适用** | 非 git 仓库；改为"文件级备份 + 变更清单"策略 |

> 上述结论不包含任何推测：均为 workspace 搜索、`git` 命令与编辑器实测结果。

---

## 2. 可行方案

### 方案 A（推荐）：UGC 原生实现 —— Lua 核心 + 原生 BT/BB + 蓝图节点

| 规格角色 | UGC 落地方式 | 说明 |
|---|---|---|
| `BossAIController` | 蓝图 AI Controller（`BP_UGC_GenericAIController_C` 派生）+ Lua | 项目已有 AIController 蓝图 |
| `BossCombatComponent` | **Lua 模块**（`Script/AI/Boss/BossCombatState.lua`），状态挂在怪物实例（每实例独立） | 冷却/动作锁/历史/随机流/压制预算/喘息/阶段/危险登记 |
| `BossDecisionPolicy` | **Lua 纯函数模块**（可脱离引擎单测） | 两级带权随机、合法性筛选、RepeatFactor、预算预测 |
| `BossCombatConfig` / `BossSkillDefinition` | Lua 配置表（可选镜像为 DataTable 资产） | 七技能全字段可调 |
| `BTTask_BossPlanNextAction` | **蓝图任务**（`BTTask_BlueprintBase` 派生，调用 Lua 决策） | UGC 不支持 C++，蓝图任务为等价物 |
| `BTTask_BossExecuteSkill` | 蓝图任务 + Lua 技能生命周期（Windup/Active/Recovery） | 或接入 `UGCPersistEffectSystem` 技能 |
| `BTService_BossUpdateContext` | 蓝图服务（`BTService_BlueprintBaseEx`） | 低频 0.2s 更新上下文 |
| 其余 Bon* 任务 | 蓝图任务 / 官方节点组合 | 死亡、归位、硬直、转阶段、搜索、追击、喘息 |
| `BB_Boss` | 用 UGC `bb_*` API 创建（14 键） | 黑板资产在 TTS 项目内 |
| 灰盒表现 | Spline/Decal 预警 + `ApplyDamage` 范围伤害 + 简单弹体 | 复用项目已有特效资产 |
| 测试地图 | UGC 项目内新建地图（待确认可行性）或复用 `UGCmap` 划区 | — |
| 验证记录 | PIE + Lua 断言脚本 + 日志（`Docs/boss-ai/VERIFICATION.md`） | 无 Automation Framework |

**方案 A 的取舍（与规格的差异，实施前需你确认）**
1. 无 C++ 类名/模块；逻辑以 Lua/蓝图承载（行为语义按规格实现）。
2. 无 UE 自动化测试框架；7 项核心用例（§14）改用 Lua 断言 + PIE 实测覆盖。
3. BT 图/树通过 UGC BT API + 编辑器协作构建（受 §1.5 限制，可能需少量手工对齐）。

### 方案 B：按原规格 1:1 实施（需你补充环境）

需要你提供：
1. **含 `Source/`、`.uproject`、`Build.cs` 的 UE 工程路径**（UE4.27 或 UE5 均可，与规格 §0.3 对齐）；
2. 可用的编译环境（Visual Studio / UBT），或允许我在该工程内新增模块并标记"未编译验证"；
3. 该工程内的现有角色/AI/技能/伤害/动画系统位置（用于复用，规格 §0.4）。

---

## 3. 阶段计划（方案 A 生效后执行）

| 阶段 | 内容 | 交付物 | 验证方式 |
|---|---|---|---|
| A | 数据结构与决策核心：BB_Boss 键定义、Lua 配置表、`BossDecisionPolicy`（两级带权随机/合法性/RepeatFactor）、压制预算与喘息状态机 | `Script/AI/Boss/*.lua`、`Docs/boss-ai/*.md` | Lua 断言：用例 4/5/6/7/8/9/11/12（对应规格 §14） |
| B | BT_Boss 骨架 + AIController + 感知：Idle → 感知 → Combat → ChaseSlice → GiveSpace | BT/BB 资产 + 蓝图任务/服务 | PIE：用例 1/2/3 |
| C | 动作生命周期与移动所有权：ActionInstanceID、Abort 清理、Windup/Active/Recovery、S1/S3/S5 垂直切片 | 蓝图任务 + Lua | PIE：用例 14/15/19/23 |
| D | 补齐 S2/S4/S6/S7、阶段切换、灰盒预警与伤害 | 同上 | PIE：用例 19/20 |
| E | 资产复核（BT 非空、七槽齐全、图/树一致）+ 单/双 BOSS 集成 + 文档 | `VERIFICATION.md`、`SETUP_AND_TUNING.md`、`MANUAL_ASSET_SETUP.md` | 用例 21/22/24 |

> 每阶段结束即更新 `VERIFICATION.md`；未运行项一律标记"未验证"，不编造结果（规格 §0.8）。

---

## 4. 待你确认（阻塞项，确认后立即开工）

1. **是否存在另一个真正的 UE C++ 工程**（含 `Source/`）？如有请给路径（→ 走方案 B，按原规格 1:1 实施）。
2. 若没有：是否接受**方案 A**（UGC 原生：Lua 核心 + 蓝图 BT 任务/服务 + 原生 BT/BB，放弃 C++ 类名/模块与 Automation Framework）？
3. 七技能落地形态：**纯灰盒**（时间轴 + 预警 + 范围伤害）还是**接入项目现有技能系统**（`UGCPersistEffectSystem` + PESkill 资产）？
4. 目标 BOSS 实体与测试场景：复用 `SuperMonster`？测试用**现有 `UGCmap` 划区**还是**新建独立地图资产**（需先验证 UGC 是否允许新建地图）？
5. 是否需要"两只 BOSS 共用同一 BT 的隔离测试"（规格 §14.22）——方案 A 下可用同一 BT 资产挂两个怪物实例实现，请确认是否纳入首轮验收。

---

## 5. 方案确认与实施进展（2026-09-22 更新）

**用户确认**：按推荐执行 —— **方案 A**（UGC 原生：Lua 核心 + 蓝图/Lua BT 节点 + 原生 BT/BB）+ **纯灰盒技能** + **复用 `SuperMonster`** + **现有 `UGCmap` 划区测试** + **双 BOSS 隔离测试纳入首轮**。

### 已完成（阶段 A：数据结构与决策核心）
- 交付 6 个 Lua 模块（职责见 `SETUP_AND_TUNING.md` §1）：`BossAI_Types / Config / Random / State / Decision / Tests`
- 纯逻辑自测 **TOTAL 29, PASS 29, FAIL 0**（真实 PIE 运行，证据见 `VERIFICATION.md` §2）
- 本轮修复：**1 个实现缺陷**（Pressure 意图无技能时应降级 Chase，规格 §6）+ **4 个测试/框架缺陷**（详见 `VERIFICATION.md`）

### 待实施（阶段 B–E）
| 阶段 | 内容 | 状态 |
|---|---|---|
| B | BB_Boss（14 键）+ BT_Boss 骨架（规格 §8 结构）+ Lua BT 节点接线 | **未开始** |
| C | 技能运行时（灰盒 Windup/Active/Recovery、危险登记、Abort 幂等）+ S1/S3/S5 垂直切片 | **未开始** |
| D | 补齐 S2/S4/S6/S7 + 阶段切换 + 灰盒预警与伤害表现 | **未开始** |
| E | 资产复核（BT 非空/七槽/图树一致）+ 单/双 BOSS 集成测试 + 文档收尾 | **未开始** |

### 实施注意（实测经验）
- **修改 Lua 后必须重启 PIE** 再验证：热重载（`reloadlua`）后存在模块函数 upvalue 混用旧环境的观察，会导致测试静默返回 0 结果。
- BT 图/树同步受 UGC 图 API 约束，详见 `Docs/UGCBehaviorTreeGraph_同步机制与验证.md`（结构改动优先在 BT 编辑器 UI 内完成）。

> 未完成部分不得视为已验证（规格 §0.8 / §14 末段）。

</details>
