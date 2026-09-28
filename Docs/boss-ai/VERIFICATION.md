# BOSS AI 验证记录（VERIFICATION）

## 2026-09-23 当前证据快照（以本节为准）

本节区分**纯 Lua、资产/Cook/DS 加载、实际 PIE 战斗**。`140/140` 是独立 Lua 解释器中的模拟与逻辑测试，不是 24 项战斗验收全通过。下方折叠的旧记录保留历史证据；其中 `29/29`、`125/125`、资产“未创建”及旧手工重建结论均不能代表当前状态。

| 层面 | 当前结果 | 可复核证据与边界 |
|---|---|---|
| 项目/引擎 | TTS，ShadowTrackerExtra 定制 UE4.18.1；Lua + UGC 原生 BT/BB | 没有本项目 C++ `Source`/编译工程。方案 A 已由用户确认；Native Enum 原规格在此 UGC 资产中尚未实现。 |
| §13 测试地图 | 当前只有 `UGCmap.umap`，`StartMapName=/TTS/UGCmap` 和 `Navmesh/UGCmap.navmesh` | 用户此前确认复用现有地图划区并做双 Boss 首轮验收；原 prompt 的独立 `L_BossAITest` 未创建，相关场景也未全部验证。 |
| 配置/纯 Lua | `pwsh -NoProfile -Command "python Docs/boss-ai/run_lua_tests.py"` 退出码 **0**：核心 **140/140**，另有 `Tests/BossMovementTests.lua` 和 `Tests/SuperMonsterIcePassiveTests.lua` 均 **PASS** | Config 16、Decision/State 67、SkillRuntime 37、Warning 11、Lifecycle 9；两个独立脚本已纳入同一命令的失败门禁，但不计入 140 项。被动测试用 Lupa 替身验证仅 `BT_Boss` 跳过旧冰墙被动、其他树照旧附加。 |
| 最近灰盒修复 | `Graybox.Prepare` 已把 `ctx.target` 传给 `HasClearDamagePath`；目标胶囊/世界墙阻挡与完整导航路径回归纳入 Runtime `37/37` | 干净 PIE **L4** 已读到 S2 活动状态，但尚未隔离证明该路径的真实命中或七个灰盒技能全部执行。 |
| BB_Boss | MCP `bb_query`：总键数 15，其中 `Types.BBKeyDefs` 的 14 个自定义键另加引擎自动 `SelfActor`；全部 `IsInstanceSynced=false` | `SelfActor` 的回读 `IsInherited=false`，不能写成“继承键”。`ActionKind`、`SelectedSkill`、`CurrentPhase` 实际是 **Int**；前两项与原规格 Native Enum 有差异，Lua 数值枚举和 `SetValueAsInt` 与资产对齐。 |
| BT_Boss 源资产 | 修复脚本的保存后、卸载重载后目标结构回读：26 个全连通图节点、17 个子边条件、1 个挂在无门控 `BossPriority` 的服务；七条技能子边齐全 | [repair_bt_boss_route.py](repair_bt_boss_route.py) 的 `BT_ROUTE_MODE='verify'` 是只读校验；不要对现有树执行旧的全删重画步骤。 |
| LinuxServer Cook | `../../Saved/UGCLinuxDebug/TTS/Asset/AI/BT/BT_Boss.uasset`：**10,410 B**，SHA256 `C71CBB43279C7330D1C7016DB9F56AEE55CA2C9F91A7837B9C0376DA27E55E4B`；44 个运行相关导出，0 个编辑器图类导入、0 个图节点导出，RootNode 导出 #5，17 个 Decorator | 本机文件 `LastWriteTime=2026-09-23 18:54:28`；导入/导出数来自本轮包表回读。Cook 可加载不证明任务会按预期执行。 |
| DS 加载 | 显式 `UE.LoadObject`：`RootNode.NodeName=BossPriority`；该次 DS 日志无旧 `UGCBehaviorTreeGraphNode_*` 缺类错误 | 日志 **L1** 第 14653 行 `[BOSS_ROUTED_DS] load=true ... name=BossPriority`。这证明包加载和根节点，不证明每条路由或七技能战斗。 |
| DS 感知 | 有效目标出现后 AIPerception 当前感知与黑板 LOS、目标、CombatActive 同步为真 | L1 第 60992、61373、65563–65564、65896 行。已看到 `perceivedAt=1`、`bbLOSAt=1`、`target=true combat=true`；柱子遮挡/脱战时序未实测。 |
| 测试玩家保护 | 干净 PIE L4/L5/L6/L7 均对当前测试玩家执行 `SetInvincible(true)`；最新 L7 回读 `flag=true count=1`，传送及 Boss 状态探针再次读到 `inv=true` | L7 第 14484–14485、17357、19961 行；L4–L6 证据见各自日志。无敌仅作用于对应 PIE 会话，重启后须重新开启，未永久改玩家数值/玩法。L3 `_finalDamage=0` 记录未隔离命中对象。 |
| Boss 生成与移动 | **默认配置局部通过，完整追击未通过。** L7 原生管理器生成一只 Boss；Chase `MoveTo` 返回成功码 2，Boss X 从 22175.89 移至 22534.78，约前进 359 cm | L7 第 14938–14939、18088、19960 行。L7 未通过控制台手动卸载被动；当前 `SuperMonster.lua` 对精确 `BT_Boss` 路径在 BeginPlay 自动跳过旧冰墙被动，第 15123、16137–16138 行回读 `ice=false`。Chase 后仍反复 `path-stopped`（如第 18176 行），未证明持续稳定到达。L4 手动卸载后曾推进约 440 cm；L3 旧逻辑下有冰墙碰撞。 |
| 默认 Boss 配置回读 | L7 原生 Boss 生成时记录 `BT_Boss 跳过旧冰块墙被动技能`；实例回读 `ice=false`、BT 路径精确为 `/TTS/Asset/AI/BT/BT_Boss.BT_Boss`。在玩家 `inv=true` 时读到 `combat=true LOS=true action=1 skill=2 actionId=7 radius=180` | L7 第 15123、16137–16138、19960–19961 行。这证明当前源码的 Boss 专用被动门控进入 DS，且 BT/BB 技能路由有活动状态；不证明伤害/预警正确、其他树的真实 PIE 兼容或七技能完整验收。 |
| 技能运行与合法性 | L4 读到黑板 `combat=true LOS=true action=1 skill=2`，Runtime `committed=2 active=2`；适配器半径 Boss=180、目标=40。之后测试玩家仍 `inv=true` | L4 第 20126–20127、22112 行；第 24518–24525 行同一实时观测下 S1/S2 合法，S3–S6 为 `OutOfRange`，S7 为 `NoSafeRoute`。证明技能状态与逐招预检确实在 DS 运行，**不证明**七招都已分发、命中、动画/预警/伤害正确或完整双 Boss 隔离。 |
| S7 全路径安全检查 | DS Lua 环境中 `NavigationSystem`、`UNavigationSystem` 全局均不可用；当前 `CheckSafeRoute` 要求原生全路径查询及非 Partial 路径，缺失时保守返回 false | [BossAI_Graybox.lua](../../Script/AI/Boss/BossAI_Graybox.lua) 第 642–680 行；L4 第 24525 行 `S7 ... NoSafeRoute`。这避免了仅凭终点投影放行 S7，但 S7 真实安全通道仍待补可用的全路径预检并在 PIE 测试。 |
| 双 Boss 共享 BT | L4 在已有一只 Boss 时生成第二只，测试玩家仍 `inv=true`；两个 Boss 的被动冰墙均在此会话临时卸载。回读 `count=2`、`separateRuntime=true`、`separateState=true`；ActionID 为 54/10，黑板路由分别为 `action=1 skill=1` 与 `action=2 skill=0` | L4 第 33589、33784、37284–37303、41595–41598 行。这只证明两个实体的 Runtime/State 对象及该时刻状态互相独立；巨型胶囊近距离碰撞，位置 Z 读到 603/422，未验同动画 Notify/Task、冷却/危险/喘息全过程不串扰。 |
| L5 远距预检 | 会话内临时卸载冰墙并将无敌玩家传至远处；手动重定位 Boss、同一 DS tick 刷新上下文，动作锁解除后读到 `LOS=true edge=1192.23`。S1 `OutOfRange`、S2 `Cooldown`、S3 `NoSafeDashChannel`、S4/S5 `PressureBudget`、S6 `NoSafeRoute`、S7 `OutOfRange` | L5 第 16716、17879、24952–24959 行。这是人为构造的预检快照，所有七招均未在该时刻合法；**不能声称远距技能起手或命中成功**。此前第 22520–22527 行因 `Busy` 全部拒绝。 |
| L6 会话边界 | 干净 PIE 中玩家无敌与传送成功；DS 日志止于 20:15:08，未见后续 Boss 生成命令在 DS 执行。客户端日志在约 20:17:13 记录 `LongTimeNoReceived`，客户端日志仍继续输出；随后停止 PIE | L6 DS 第 14858–14859、15132 行及末尾时间；**C6** 第 249944–249976 行。仅记录此次验证中断，不能推断 Boss 生成失败或连接中断原因。 |
| DS 诊断探针 | L3 第 17648 行一次临时探针将不支持的 `b:GetName()` 当作 Lua 方法调用，返回 DoString 错误；第 37220 行起另一次临时探针调用 `ProjectPointToNavigation(p)` 时缺少 World Context，DS 于 19:48:36 在 `K2_ProjectPointToNavigation` 处 SIGSEGV | 第 37217–37243 行可见注入命令、Lua 栈和原生栈。崩溃来自该次控制台诊断调用，不是 Boss 项目代码自身的调用栈；后续已启动干净 PIE **L4** 验证。 |

日志路径（从 TTS 根目录）：

- **L1**：`../../Saved/Logs/TTS/DSlog/FullLog/2026.09.23-18.57.24_ds__dkfffpmd2g33km_realtime.log`
- **L2**：`../../Saved/Logs/TTS/DSlog/FullLog/2026.09.23-19.08.59_ds__dkfffpmd2g3hb9_realtime.log`
- **L3**：`../../Saved/Logs/TTS/DSlog/FullLog/2026.09.23-19.41.49_ds__dkfffpmd2g4j2b_realtime.log`
- **L4**：`../../Saved/Logs/TTS/DSlog/FullLog/2026.09.23-19.58.43_ds__dkfffpmd2g50my_realtime.log`
- **L5**：`../../Saved/Logs/TTS/DSlog/FullLog/2026.09.23-20.07.42_ds__dkfffpmd2g5ah1_realtime.log`
- **L6**：`../../Saved/Logs/TTS/DSlog/FullLog/2026.09.23-20.13.33_ds__dkfffpmd2g5e8x_realtime.log`
- **C6**：`../../Saved/Logs/TTS/Clientlog/FullLog/2026.09.23-20.12.09_client__dkfffpmd2g5e8x_1.log`
- **L7**：`../../Saved/Logs/TTS/DSlog/FullLog/2026.09.23-20.23.26_ds__dkfffpmd2g5oru_realtime.log`

### §14 的 24 项验收矩阵

“Lua 通过”只表示当前独立 Lua 测试覆盖的条件；需要地图、导航、动画、复制或双实例的整项验收，仍须以干净 PIE/DS 记录完成。

| # | 验收点 | 已取得的证据 | 当前验收边界 |
|---:|---|---|---|
| 1 | 无合法玩家 Idle，无攻击/目标移动 | `BossAI_Tests` 无目标决策为 None；L1 第 26737 行黑板 `target=nil combat=false` | **部分**：未连续观察真实 Idle 分支下的无攻击、无移动。 |
| 2 | 感知后 Combat 和目标更新 | L1 的 AIPerception/BB 窗口 `target=true combat=true` | **DS 局部通过**：目标获取已观察；完整战斗接续未验。 |
| 3 | 遮挡后保持战斗且不读取实时位置 | Service 仅确认 LOS 后读取目标位置，丢 LOS 用 `LastKnownTargetLocation` | **未验 PIE**：缺柱子遮挡与搜索时序记录。 |
| 4 | 同快照同种子、候选遍历稳定 | Decision/State 纯 Lua Case4 通过 | **Lua 通过**；BT 多实例重放未验。 |
| 5 | 冷却/距离/路径/视线非法不入池 | Case5、Case18 覆盖拒绝及逐技能安全预检；L4 近距回读 S1/S2 合法，其余拒绝；L5 远距回读 `OutOfRange`、`Cooldown`、`NoSafeDashChannel`、`PressureBudget`、`NoSafeRoute` | **部分**：真实 DS 拒绝理由已回读；远距场景没有合法技能，冷却、遮挡及候选池是否逐项剔除仍未完整验收。 |
| 6 | 20/30 权重独立抽样 10000 次 | Case6：A=0.3955、B=0.6045，均在 ±2pp 内 | **Lua 通过**；仅固定候选抽样，不外推动态战斗分布。 |
| 7 | 禁止连续三次；只剩同技能非攻击回退 | Case7 已在新压制窗口隔离预算，证实第三次 `RepeatBan`；只剩 S1 时 `S1RepeatBan=true` 且回退 Chase | **Lua 通过，PIE 未验**：当前测试不再被 `pressure-budget` 提前遮挡。 |
| 8 | 站桩空池移除意图并归一化 | Case8 移除 StationaryCast，单次规划返回 | **Lua 通过**；真实 BT 高频行为未观测。 |
| 9 | 三承诺 GiveSpace，追击不重置预算 | Case9、Case13 等状态/决策断言；L4 Chase 已实际移动约 440 cm，Runtime 曾读到 `committed=2` | **Lua 通过，PIE 未验整体规则**；未观察三次承诺后真实 GiveSpace，也未证明追击期间预算保持。 |
| 10 | 残留弹体结束后才计完整 2 秒 | State/Runtime 测试覆盖 DrainThreats、危险失效后 Breathing 与新危险重计 | **Lua 通过，PIE 未验**：尚无真弹体与两秒计时录像/DS 轨迹。 |
| 11 | 喘息后 0.8 秒拒绝 S3 | Case11 0.4 秒拒绝、0.9 秒放行 | **Lua 通过，PIE 未验**。 |
| 12 | 下一动作超预算提前喘息，不截断承诺动画 | Case12/14 验证预测与 `activeAction` 保留 | **部分**：真实 Montage/后摇不中断未验。 |
| 13 | 危险超时/漏注销后关闭伤害并恢复 | State/Runtime 测试覆盖超时关闭、清理失败保留与有界重试 | **部分**：禁伤清理持续失败会停车阻止新攻击，不能写成已恢复；引擎危险对象与回调链未实测。 |
| 14 | 三阶段分别 Abort、无 Timer/Delegate/伤害窗/移动锁残留 | Runtime/Lifecycle 测试覆盖 Abort、watchdog、释放与部分清理失败 | **部分**：未对 Windup/Active/Recovery 各阶段做干净 PIE 中止和资源读回。 |
| 15 | 旧 ActionID 回调不终止新动作、不重复命中 | State/Runtime 覆盖 stale ID、旧 watchdog、S1 每段命中去重 | **Lua 通过，PIE 未验**：真实 Notify/网络回调未验证。 |
| 16 | 两 Boss 同动画时 Notify/Task 不串扰 | 两个 Runtime 对象的 Lua 隔离测试；L4 两只真实 Boss 的 Runtime/State 对象不同，ActionID 54/10 | **DS 局部隔离已证实**；未构造同动画 Notify/Task 同时触发，不能据此断言回调绝不串扰。 |
| 17 | 全 CD/零权重/不可达有界回退、无高速循环 | Decision 有空池/退避逻辑与局部测试；L7 默认配置的导航失败日志出现 `retry in 0.2s` | **部分**：相较 L2 每约 0.133 秒重试已有退避，L7 仍反复 `path-stopped`；未验证全 CD/零权重及长时间无高速循环。 |
| 18 | 距离边缘无连续起手取消/顿挫/瞬转 | L7 未手动卸被动，Boss 位置实测推进约 359 cm，黑板 `action=1 skill=2` | **部分**：默认配置下移动和技能路由状态已验证；边缘起手、取消、转向与稳定到达时序仍未测。 |
| 19 | S3 撞墙、S5 固定落点、S6/S7 安全通道 | Runtime/Warning 替身测试分别覆盖；L4 S7 实时预检 `NoSafeRoute`；L5 远距 S3 `NoSafeDashChannel`、S6 `NoSafeRoute` | **Lua 通过，PIE 未验**：DS 缺可用的全路径查询全局，安全通道当前保守拒绝；真碰撞、导航、预警与伤害需逐招复核。 |
| 20 | 二阶段仅一次，不跳后摇/抹喘息 | State/Decision 有请求式阶段与动作/喘息守卫 | **部分**：缺真实血量阈值、动画与喘息交互 PIE 记录。 |
| 21 | 目标销毁、UnPossess、退出、死亡清理 | Lifecycle 替身测试覆盖死亡、UnPossess、EndPlay；State 危险重试 | **部分**：真对象销毁/关卡退出/DS 生命周期未完整实测。 |
| 22 | 共用 BT 双 Boss 全状态互不污染 | Runtime 测试证明两个 Lua 实例的动作锁/CD 独立；L4 两只真实 Boss `separateRuntime=true separateState=true`，ActionID 54/10，黑板路由不同 | **DS 局部通过**：仅单次对象/状态快照；巨型胶囊相互碰撞且位置 Z 异常，历史、随机、危险、喘息与双动画回调未全量验收。 |
| 23 | 起手前失败不扣 CD；承诺后打断不退款 | Runtime 测试覆盖预检失败不承诺，State 提交时计 CD/次数 | **部分**：真硬直/死亡中断时的 CD 与次数未做 PIE。 |
| 24 | 保存重载 BT 非空、七槽、Key/Enum/Decorator/Service 与图运行树一致 | Editor `verify`、Cook 包表、L1 RootNode=BossPriority；14 定义键 + 自动 SelfActor；L7 精确 BT 路径、Chase Task 和 `action=1 skill=2` 已实际回读 | **资产/加载局部通过**：原规格 Native Enum 在 UGC 为 Int，唯一 Service 位于 BossPriority 而非原示意 Combat；脚本不校验 Interval/Task 参数，七条技能子路由尚未逐一实测。 |

### 复现与继续验收

1. 在 TTS 根目录用 PowerShell 7 执行 `pwsh -NoProfile -Command "python Docs/boss-ai/run_lua_tests.py"`。本快照实测 Config `16/16`、Decision `67/67`、Runtime `37/37`、Warning `11/11`、Lifecycle `9/9`，核心合计 `140/140`；同一命令再运行 `Tests/BossMovementTests.lua` 与 `Tests/SuperMonsterIcePassiveTests.lua`，两者均 `PASS`，整体退出码 0。独立脚本不计入 140 项；这些测试不启动 Editor。
2. `pwsh -NoProfile -Command "(Get-FileHash '../../Saved/UGCLinuxDebug/TTS/Asset/AI/BT/BT_Boss.uasset' -Algorithm SHA256).Hash"` 核对上述 Cook 包。若资产之后又保存/Cook，应记录新哈希和时间，不沿用本快照。
3. 对源资产，在 UGC Editor **卸载并重新加载** `/TTS/Asset/AI/BT/BT_Boss` 后，以 UGC MCP `ue_py` 只读执行 [repair_bt_boss_route.py](repair_bt_boss_route.py)，传 `BT_ROUTE_MODE='verify'`，预期 `VERIFY_OK`。不要运行默认 `apply`，也不要全删重建。
4. 在干净 PIE 的 DS 日志中检索 `BOSS_ROUTED_DS`、`BOSS_LOS_WINDOW`、`BossMove`。旧日志可用上述 L1–L7 行号复核；新会话必须重新记录实际输出。每次重启 PIE 都先对测试玩家执行 `SetInvincible(true)` 并读回 `flag=true`，再生成 Boss；退出 PIE 或明确恢复 `SetInvincible(false)`。L6 的 DS 会话在 Boss 生成命令执行前失去响应，不能作为 Boss 行为验收。
5. 先验证 Chase/Search 持续导航、到达和失败退避，再按矩阵逐项补单 Boss 七技能、障碍遮挡、Abort/阶段/喘息及双 Boss 隔离。L7 无需手动卸载冰墙被动，Boss 按当前 `BT_Boss` 专用门控直接生成并移动约 359 cm，黑板有 S2 路由状态；反复 `path-stopped` 仍在，不能推断完整追击、七技能或双实例完整验收通过。

<details>
<summary>历史记录：2026-09-22 至 2026-09-23 较早快照（可能与当前实现冲突）</summary>

## 2026-09-23 当前轮验证状态

以下为本轮重新回读的事实。下方 2026-09-22 的 `29/29` 是历史纯逻辑结果，不能代表本轮代码或 PIE 集成状态。

| 检查 | 本轮结果 | 证据/边界 |
|---|---|---|
| 当前编辑器 | TTS，ShadowTrackerExtra 定制 UE4.18.1，UGCmap | UGC MCP `ue_read` 的 `ctx:`；不是 UE4.27/UE5 C++ 工程 |
| Git/工作树 | 当前目录是 Git 仓库；Boss 资产和 Lua 存在暂存及未暂存改动 | `git rev-parse --show-toplevel`、`git status --porcelain=v1`；2026-09-22 计划中“非 Git 仓库”的旧结论已过时 |
| 黑板 | `BB_Boss` 有 15 键，全部未启用 Instance Synced；`ActionKind`、`SelectedSkill` 当前实际为 Int | UGC MCP 反射回读；与原规格要求的 Native Enum 不一致，运行时 `SetValueAsInt` 是否生效仍需 PIE |
| 行为树资产 | 原先的运行根/辅助节点 Outer 错误已修复并保存；43 个编辑器图节点标志重新加载后全部为 `0x280008` | 备份在 `ShadowTrackerExtra/Saved/BossAIBackups/`；MCP 关闭/卸载/重载读回 RootNode Outer 是 `BT_Boss`，图节点低 4 位均为 `0x8` |
| 行为树路由 | 五个优先级条件同挂根，五个 `ActionKind` 条件同挂一个分支，七个 `SelectedSkill` 条件同挂一个分支；运行时子边未分别挂条件 | UGC MCP 运行树递归回读；当前互斥条件使路由不可按规格执行 |
| Boss 绑定 | `SuperMonster` 的 BehaviorControlComp 指向 `BT_Boss`，`BT_Boss` 指向 `BB_Boss` | UGC MCP CDO/资产回读；不代表树已在 DS 执行 |
| LinuxServer Cook | 编辑器图包导入、图节点导出均为 0；运行时 43 个导出保留 | 2026-09-23 18:22 Cook 文件 10,285 B，SHA256 `3C5BF46D32C8669A1CED490EB507867289E90409C0CD66A933C20A2B3DB84D5A`；解析导入/导出表对照旧包 44 个图导出 |
| DS 加载 | 显式 `UE.LoadObject` 返回 `BT_Boss.RootNode` 非空；该次日志没有 `UGCBehaviorTreeEditor` 或 `Could not find class UGCBehaviorTreeGraphNode_*` | PIE `_dkfffpmd2g1ht5`，`Saved/Logs/TTS/DSlog/FullLog/2026.09.23-18.24.08_ds__dkfffpmd2g1ht5_realtime.log:14837`；仅证明加载，未证明分支执行 |
| 纯 Lua 回归 | 当前五套合计 125/125 通过 | `python Docs/boss-ai/run_lua_tests.py`；包含配置、决策、运行时、预警与生命周期 mock，不代表 PIE |

当前继续修正原树的条件路由并做 PIE。技能伤害、喘息、感知、单/双 Boss 的实时战斗验收均为**未验证**；上面的资产加载与纯逻辑结果不能外推为这些验收通过。

> 规格：`Docs/Codex_UE_Boss_BehaviorTree_Prompt.md`　方案：**A（UGC 原生：Lua 核心 + 原生 BT/BB + 蓝图/Lua BT 节点）**
> 记录时间：2026-09-22　执行人：AI（UGC MCP 自动化）

---

## 一、验证环境（真实）

| 项 | 值 |
|---|---|
| 引擎 | UE **4.18.1** 定制版（OasisEraEditor 2001776 / ShadowTrackerExtra） |
| UGC 项目 | `UGCProjects/TTS` |
| 执行通道 | UGC MCP：`ue_read` / `ue_py` / `ue_pie`（DS 侧 Lua 注入） |
| PIE 会话 | `debug_id = _dkfffpllhxaow5`（DS 日志：`Saved/Logs/TTS/DSlog/FullLog/2026.09.22-20.56.38_ds__dkfffplhhxaow5_realtime.log`） |
| 被测代码 | `Script/AI/Boss/BossAI_{Types,Config,Random,State,Decision,Tests}.lua` |
| 执行方式 | `UGCGameSystem.UGCRequire('Script.AI.Boss.BossAI_Tests')` → `RunAll()` |

> 环境限制（已确认）：仓库无 C++ 工程/编译环境（详见 `IMPLEMENTATION_PLAN.md` §0-1），因此 C++ 类、Editor 模块与 UE Automation Test Framework 不在交付范围；本记录仅覆盖 **Lua 纯逻辑** 验证。

---

## 二、测试结果（真实输出，2026-09-22 20:56）

```
[BossAI-Test] cases count = 8
[BossAI-Test] ===== TOTAL 29, PASS 29, FAIL 0 =====
BOSS_TEST_SUMMARY total=29 pass=29 fail=0
```

逐项明细（关键行摘录）：

| 用例 | 断言 | 结果 | 证据 |
|---|---|---|---|
| Case4 | 相同种子可复现 | PASS | 固定种子(777) 30 次决策序列完全一致 |
| Case4 | 候选遍历顺序稳定 | PASS | 两次构建候选/拒绝列表逐项一致 |
| Case5 | 无视线时 S1-S4 全部拒绝 | PASS | 拒绝原因均为 `NoLOS` |
| Case5 | 超距拒绝 S1 / 过近拒绝 S3 | PASS | 距离边界（320 / 550-1500）判定正确 |
| Case5 | 冷却中拒绝 / 冷却结束放行 | PASS | `Cooldown` → 4.0s 后放行 |
| Case6 | 权重 20/30 → 40%/60% ±2pp | PASS | **A=0.3955 / B=0.6045**（10000 次独立抽样） |
| Case7 | 连续计数=2 / 第三次禁止 | PASS | `RepeatBan` |
| Case7 | 只剩该技能时非攻击回退 | PASS | `kind=2 (Chase)` |
| Case8 | 站桩候选为空 → 意图移除并归一化 | PASS | 池内无 StationaryCast，池仍非空 |
| Case8 | 单次规划返回（不死循环） | PASS | 单次调用返回 |
| Case9 | 三次承诺 → GiveSpace | PASS | `kind=4 (GiveSpace)` |
| Case9 | Pressure 无技能 → 降级 Chase | PASS | `kind=2 (Chase)`（**本轮修复项**） |
| Case9 | 追击不重置预算 | PASS | burstStart / committedCount 不变 |
| Case11 | 喘息 A→B→结束 | PASS | `breathingStarted` → `finished` |
| Case11 | 结束后 0.8s 内拒绝 S3 | PASS | `GapCloseBlocked`；0.9s 放行 |
| Case11 | GapClose 不影响其他技能 | PASS | S1 正常放行 |
| Case12 | 预测超预算 → 提前喘息 | PASS | 7.5s 已用 + 2.0s 候选 = 9.5s > 8.0s |
| Case12 | 预测未超预算 → 不触发 | PASS | 0.3s 候选不触发 |
| Case12 | 不切断已承诺动作 | PASS | 决策不改 `activeAction` |

### 本轮发现并修复的缺陷

| # | 缺陷 | 修复 |
|---|---|---|
| 1 | **实现缺陷**：`BuildIntentPool` 在 Pressure 无合法技能时直接把该意图排除，导致"应降级 Chase"的场景变成 Reposition（规格 §6 要求"Pressure 有合法 S1–S4 时抽技能，否则可合理接近时 Chase"） | 意图池条件改为 `pressureSkill ~= nil or ctx.canChase`；抽中 Pressure 后无技能则输出 Chase |
| 2 | 测试缺陷：以"不同种子序列必不同"为断言（实际大量决策受冷却门控主导，随机性被掩盖） | 移除该断言，随机分布由 Case6 独立验证 |
| 3 | 测试缺陷：Case8 以"距离"构造站桩空池（S7 下限为 0，构造失败） | 改为将 S5-S7 全部置于冷却 |
| 4 | 测试缺陷：Case9 断言 Chase，但意图池只剩 Reposition（随机抽样） | 构造 `canReposition=false` 的确定性场景 |
| 5 | 测试框架缺陷：`RunAll` 用数组字面量构造用例表，含 nil 时 `#` 断裂导致静默 0 执行 | 改为逐个 `cases[#cases+1] = ...` 追加，并为 nil 用例记录 `MISSING`；`check()` 增加即时打印 |

> 热重载（`reloadlua`）后模块函数 upvalue 存在混用旧环境的观察，故最终结论以**干净 PIE 会话**为准（重启后重跑）。该现象已记录，供后续排查。

---

## 三、已验证 / 未验证清单（诚实标注）

### ✅ 已验证（纯逻辑层）
- 两级带权随机：合法性筛选、权重公式（Base×Distance×Phase×Repeat）、10000 次分布精度
- 冷却 / 距离 / 视线 / 高度 / 路径 / 危险冲突 的拒绝逻辑
- 连续三次禁止（RepeatBan）与"只剩该技能"的非攻击回退
- 意图池归一化（站桩空池移除）与空池有界返回
- 压制预算：3 次承诺上限、8 秒预测、追击不重置预算
- 喘息：A(DrainThreats)→B(2 秒 GuaranteedBreathing)、GapClose 0.8s 禁 S3、欠喘息保存/恢复
- 阶段：请求式切换、仅一次
- 危险登记/注销/超时清理（State 层接口）

### ⛔ 未验证（尚未实现或需 BT/引擎集成）
| 项 | 状态 | 说明 |
|---|---|---|
| BB_Boss（14 键）资产 | **未创建** | 下一步（阶段 B） |
| BT_Boss 行为树资产（规格 §8 结构） | **未创建** | 需 BT/BB 资产 + Lua BT 节点接线 |
| Lua BT 节点（`BTTask_LuaBase` / `BTAttachment_LuaBase` 绑定） | **未接线** | 基类接口已确认（`ReceiveExecuteAI` / `FinishExecute` / `ReceiveActivationAI` 等） |
| 灰盒技能运行时（Windup/Active/Recovery + 预警 + 伤害） | **未实现** | `BossAI_SkillRuntime` 待写 |
| 感知接入（AIPerception Sight） | **未接入** | 引擎含 AIPerception，需 BT/Controller 层 |
| PIE 集成（Idle→Combat→七技能→双 BOSS 隔离） | **未运行** | 依赖上述资产 |
| 规格 §14 中需要引擎的用例（1/2/3/10/13/14-24） | **未运行** | 明确标记为未验证，不视为通过 |

---

## 四、复现步骤（供他人复核）

1. 打开 TTS 项目，启动 PIE（本项目 MCP：`ue_pie start`）。
2. 在 DS 执行 Lua：
   ```lua
   local Tests = UGCGameSystem.UGCRequire('Script.AI.Boss.BossAI_Tests')
   local r = Tests.RunAll()
   print('total=' .. r.total .. ' pass=' .. r.passed .. ' fail=' .. r.failed)
   ```
3. 在 `Saved/Logs/TTS/DSlog/FullLog/*.log` 中检索 `BossAI-Test` 查看逐项结果。
4. 预期：`TOTAL 29, PASS 29, FAIL 0`（若修改过模块，务必**重启 PIE** 后再验证，避免热重载 upvalue 混用）。

---

## 五、结论

- **阶段 A（数据结构 + 决策/压制预算 + 纯逻辑测试）已完成并通过 29/29**。
- 阶段 B–E（BB/BT 资产、Lua BT 节点接线、灰盒技能运行时、PIE 集成、双 BOSS 隔离）**未开始**，需后续实施；在完成 PIE 集成前，**不得声称完整战斗验证通过**（规格 §14 末段要求）。

</details>
