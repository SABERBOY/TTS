# BOSS AI 实施计划（基于真实仓库审查）

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
