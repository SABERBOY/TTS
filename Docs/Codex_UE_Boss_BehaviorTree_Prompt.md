# Codex 实现 Prompt：UE4 / UE5 七技能 Roguelike BOSS 行为树

你是当前 Unreal Engine 项目的高级 AI / Gameplay 程序员。请在当前仓库中实际实现本规格，不要只返回建议、伪代码、空类或待办清单。

交付目标：能在 Behavior Tree 编辑器中检查和调试的原生 BOSS 行为树、Blackboard、AIController、战斗组件、七技能接入、配置资产、灰盒测试场景和验证记录。

设计意图已经确定：未发现玩家时待机；发现后持续保持战斗目标，以追压为主，按局面带权随机选招；部分技能原地施放；技能具有前摇、动作承诺和后摇；定期给玩家真实的脱离机会。不要把“始终追随”解释为每个状态都执行 MoveTo，也不要改为固定技能循环或每帧随机技能。

默认是 3D 俯视角 Roguelike，以地面走位应对攻击，不依赖无敌翻滚、跳跃或盾反。默认单 BOSS 对单玩家，但不同 BOSS 实例不能共享运行状态。已有多人框架时接入服务器权威执行；没有时不要扩建完整联网系统。

以下技能和数值是本项目灰盒设计，不是《艾尔登法环》等商业游戏的内部实现。初始数值均应可配置，并以实机测试调整。

## 0. 先检查工程，再实施

1. 阅读适用的 AGENTS.md、README、.uproject、Build.cs、Target.cs、Source、Plugins、Config，以及现有角色、AI、技能、动画、伤害和测试代码；检查 git status，保留用户已有改动。
2. 根据工程和本机安装确认实际 UE 版本、模块名称、构建目标、编辑器和工具链。面向当前版本实现，不自动升级引擎。
3. 架构兼顾 UE4.27 / UE5，但当前工程版本才是实现依据。没有另一版本的构建环境，不得声称已验证双版本兼容；必要版本差异集中封装。
4. 优先复用现有 Character、AIController、生命值、阵营、伤害、技能与动画系统。已有 GAS 时接入现有 Ability 生命周期；没有时不要为一个 BOSS 强行引入 GAS、StateTree、Mass AI 或第三方插件。
5. 默认采用 C++ 核心 + 原生可视化 BT / BB + Blueprint 可调参数。纯蓝图项目可添加最小 C++ 模块或项目内插件，但保留现有地图、角色和启动流程。
6. 写出基于真实仓库的简短实施计划，保存到 docs/boss-ai/IMPLEMENTATION_PLAN.md，随后按阶段继续实施。不要重新询问已经写明的设计问题；不影响核心目标的小项采用明确、可回退的默认值并记录。
7. 不删除无关文件，不修改引擎源码，不下载付费素材，不自动提交或推送，不执行破坏性 Git 操作；遵守工作区审批和安全规则。
8. 没有工程、引擎或编译器时，明确报告缺失项。未运行的代码、构建和测试标为未验证；不得编造工程名、资产文件或通过记录。

## 1. 不可违反的战斗约束

- 未感知到合法玩家：Idle，不无目标攻击或移动。
- 保持战斗目标不等于始终移动。站桩、承诺动作、后摇、硬直、喘息不得被普通追击覆盖。
- 在安全动作边界进行决策；感知更新只能更新上下文，不能在技能中途反复抽招。
- 先筛选合法技能，再带权随机；处理冷却、重复、距离、视线、路径和压制预算。
- 玩家走位成功后允许 BOSS 打空，不瞬间换招、无限转向、延长射程或移动已锁定的落点。
- 站桩施法是移动机会，不等于完整喘息；随机连续偏向进攻也不能绕过喘息保障。
- 死亡、确认脱战和合法硬直可中止相应动作；距离变化、短暂丢失视线不能随意取消已承诺技能。
- 缺少动画 / 特效时有可运行灰盒模式，不能只打印“释放技能”。

## 2. 代码职责与模块边界

沿用工程命名；以下名称表示职责，不要求重复创建项目已有等价模块：

- BossAIController：感知、目标维护、启动行为树、协调移动请求。
- BossCombatComponent：每只 BOSS 的冷却、动作锁、动作实例、历史、随机流、压制预算、喘息、阶段和危险对象登记。
- BossDecisionPolicy：依据固定上下文和配置计算合法候选、权重与下一动作，尽量隔离为可单独测试的逻辑。
- BossCombatConfig / BossSkillDefinition：编辑器可调配置。
- BTTask_BossPlanNextAction：完成一次规划，写入 ActionKind / SelectedSkill。
- BTTask_BossExecuteSkill：通用异步技能 Task，以 SkillID 参数复用七次。
- BTTask_BossGiveSpace、BossChaseSlice、BossReposition、BossSearch、BossHardStagger、BossPhaseTransition、BossReturnHome、BossDeath：执行对应动作。
- BTService_BossUpdateContext：低频更新上下文，不释放技能。
- 必要的灰盒投射物、地面预警、伤害范围和测试适配器。
- 必要的独立 Editor 模块：生成资产、构建编辑器图、校验和保存。

按实际用量添加 Core、CoreUObject、Engine、AIModule、GameplayTasks、NavigationSystem 等运行时依赖。UnrealEd、BehaviorTreeEditor、AssetTools 等编辑器依赖不得进入运行时模块。

组件可以管理技能内部阶段，但不得用一个 Tick 大循环替代真正的 BT 调度。

## 3. Blackboard：BB_Boss

以下控制键为每个 AI 独立数据，不启用 Instance Synced：

| Key | 类型 | 用途 |
| --- | --- | --- |
| TargetActor | Object，Actor 类型 | 当前目标 |
| CombatActive | Bool | 本轮遭遇是否仍在战斗 |
| HasLineOfSight | Bool | 当前视线 |
| LastKnownTargetLocation | Vector | 最近一次确认的位置 |
| DistanceToTarget | Float | 已知位置对应的水平胶囊边缘间距 |
| ActionKind | Native Enum | None / Skill / Chase / Reposition / GiveSpace / Search |
| SelectedSkill | Native Enum | None / S1 / S2 / S3 / S4 / S5 / S6 / S7 |
| CurrentPhase | Int | 1 或 2 |
| PhaseTransitionReady | Bool | 已请求转阶段且到达合法切换点 |
| IsDead | Bool | 死亡 |
| MustReset | Bool | 需要归位 |
| CanApplyHardStagger | Bool | 待处理的合法硬直 |
| HomeLocation | Vector | 归位点 |
| MoveGoal | Vector | 搜索 / 站位目的地 |

统一定义 Key，初始化校验键名、类型、枚举绑定，禁止各类散落不一致字符串。

冷却表、ActionInstanceID、动作目标快照、随机流、历史、剩余喘息时间、GapCloseAllowedTime 和危险对象集合放在本 BOSS 组件中，不放到共享资产或静态变量。

## 4. 感知、距离和目标生命周期

使用本引擎版本的 AI Perception Sight 和感知事件，接入现有阵营 / 可攻击对象判断。注册玩家刺激源，确认 affiliation 设置能感知玩家，不能遗漏被归类为 Neutral 的目标。

没有现有配置时，原型默认：SightRadius = 2500 cm，LoseSightRadius = 3000 cm，PeripheralVisionHalfAngle = 85 度；均可调整。

- 首次感知到合法玩家：设置目标、已知位置，CombatActive = true。
- 短暂失去视线：HasLineOfSight = false，保留最后已知位置，不立即退战。
- 本版七技能开始前均需有效视线；无视线时搜索或重新站位，不隔墙精准施法。
- 已承诺技能可按锁定方向 / 落点完成，但安全处理目标销毁与失效。
- 无视线时不得读取 TargetActor 的实时 Transform / Velocity 偷看玩家。搜索使用最后已知位置，区分当前感知数据与历史缓存。
- 玩家绕柱子不能触发回血。脱战仅由目标全部失效、离开有效战斗区域等明确规则触发。
- 归位采用寻路，处理不可达和超时，不默认瞬移。
- 重置期间停止战斗并保持归位状态；归位结束后清理目标、阶段请求、冷却、历史、压制和喘息数据。是否恢复生命值沿用项目明确的遭遇重置规则。

统一选招距离：
EdgeDistance = Max(0, HorizontalCenterDistance - BossScaledCapsuleRadius - TargetScaledCapsuleRadius)

高度差独立检查。选招距离不等于命中判定，禁止仅凭水平距离跨楼层或穿墙扣血。无胶囊目标通过现有接口或记录过的回退半径处理。

## 5. 七技能配置与实现

已有技能时接入下列槽位与生命周期，不推翻美术或伤害系统；不存在时实现可运行灰盒。

距离单位 cm，时间单位秒；BaseWeight 是已选意图内部的技能权重。

| ID | 名称 | 意图组 | 移动策略 | 距离 | 前摇 | 有效段 | 后摇 | CD | BaseWeight |
| --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| S1 | 裂刃连斩 | Pressure | AttackStep | 0–320 | 0.65 | 0.80 | 0.80 | 3 | 30 |
| S2 | 蓄力重砸 | Pressure | Stationary | 0–450 | 1.20 | 0.25 | 1.30 | 7 | 20 |
| S3 | 突进穿刺 | Pressure | CommittedDash | 550–1500 | 0.95 | 0.50 | 1.10 | 9 | 20 |
| S4 | 行进飞刃 | Pressure | SlowAdvance | 450–1800 | 0.70 | 0.60 | 0.60 | 4 | 30 |
| S5 | 定点三连轰 | StationaryCast | Stationary | 650–2400 | 1.15 | 1.20 | 1.20 | 9 | 40 |
| S6 | 扇形弹幕 | StationaryCast | Stationary | 450–2000 | 1.00 | 1.60 | 1.00 | 12 | 35 |
| S7 | 裂隙爆发 | StationaryCast | Stationary | 0–1100 | 1.60 | 1.00 | 1.60 | 18 | 25 |

S1：固定两段攻击，不随机追加第三刀。前摇末尾锁定主要方向，每段有独立伤害窗口和命中去重，不逐帧重复伤害同一目标。灰盒总攻击前移不超过 100 cm，位移受碰撞约束。

S2：原地蓄力，提前显示前方打击范围，完整保留后摇。命中检查实际区域、障碍和高度，不能仅判断目标距离。

S3：前摇最后 0.45 秒锁定方向，突进最长 1500 cm；不拐弯、不延长、不穿墙，允许冲空。用有碰撞的移动方式；起手前检查通道和安全停止空间，遇障碍安全停止，禁止无碰撞 SetActorLocation 瞬移。

S4：移动速度上限默认 200 cm/s，有效段内释放三枚非追踪飞刃，发射后不修正方向。灰盒速度 1600 cm/s，最大伤害寿命 2 秒。技能拥有移动控制权，不能同时运行另一个追击任务。

S5：开始时按当前可见玩家位置确定三个落点，立即显示预警。允许使用当时已观测速度预测不超过 0.6 秒；预警后落点固定。有效段内依次轰击，单点灰盒半径 180 cm。全程站桩，伤害脉冲有限，不默认留下持续火池。

S6：原地两轮非追踪扇形弹幕，两轮共用清晰安全缺口；不能第二轮无预警封死第一轮唯一出口。采用有限方向模板，每枚弹体伤害寿命不超过 2 秒。

S7：长前摇、原地分区爆发，采用预验证模板，至少留一条可达安全区的连续路线。禁止覆盖整个圆盘却要求玩家必须有无敌翻滚。采用有限伤害脉冲，不是无限持续伤害。

S6 / S7 的缺口按玩家半径膨胀检查，局部有效通行宽度至少为玩家直径 + 80 cm，考虑障碍及预警时间内是否来得及到达。检查失败则扩大安全区、换安全模板或拒绝技能；只在图上画一条缝不算验证，更不能宣称全地形保证可躲。

复用项目伤害体系。灰盒无既有体系时可用玩家 MaxHP = 100、BOSS MaxHP = 1000；S1 每段 8，S2 为 20，S3 为 16，S4 每枚 5，S5 每点 10，S6 每枚 5，S7 每脉冲 15。全部集中配置，不侵入现有玩家数值。

每个 SkillDefinition 至少包含：ID、意图组、移动策略、最小 / 最大距离、基础权重、阶段系数、前摇 / 有效段 / 后摇、冷却、AimLock、伤害窗口、投射参数、最大危险寿命、视线 / 路径要求、Montage 或灰盒执行配置。

## 6. 两级带权随机

普通 Selector 只做优先级与路由，随机放在 PlanNextAction / DecisionPolicy。

第一级意图权重：
- Phase 1：Pressure 65，StationaryCast 25，Reposition 10。
- Phase 2：Pressure 75，StationaryCast 20，Reposition 5。

欠下喘息时优先 GiveSpace；无视线时 Search；两者不参与普通随机。
Pressure 有合法 S1–S4 时抽技能，否则可合理接近时 Chase。
StationaryCast 只有存在合法 S5–S7 时进入意图池，否则移除并归一化剩余权重。
Reposition 必须存在可达目标。空池采用有界等待，不能同帧无限重抽。

第二级：先筛合法技能，再按以下公式抽样：
Weight = BaseWeight × DistanceFactor × PhaseFactor × RepeatFactor

合法性包含目标、感知、冷却、距离、高度、路径 / 落点、危险区域冲突、阶段、突进解禁时间、重复限制和压制预算。

原型 DistanceFactor 合法距离内先用 1.0，范围外直接拒绝；提供可配置距离偏好曲线入口，不强行扩展复杂评分。
Phase 1 系数均为 1.0；Phase 2 的 S2 / S3 / S7 默认 1.2，其余 1.0。
最近一次已承诺技能再次被选时 RepeatFactor = 0.2；连续两次相同后第三次直接禁止，即使只剩该技能也不能绕过，改用非攻击行为。

每只 BOSS 独立使用 FRandomStream，固定种子便于测试；候选按 SkillID 稳定顺序遍历，不依赖 Map 无序遍历。相同快照和种子应可复现，特效随机不能消耗 AI 随机流。

安全处理零权重、负权重、非有限权重和空候选。失败使用约 0.2 秒退避，不反复起手或高速失败循环。

## 7. 压制预算与真正的喘息

默认参数：
```text
MaxCommittedSkillsPerBurst = 3
PressureBudgetSeconds = 8.0
GuaranteedBreathingSeconds = 2.0
GapCloseDelayAfterBreathing = 0.8
Chase / Reposition 决策片段约 0.8 秒
普通追击速度沿用项目，无现有值时灰盒默认 600 cm/s
Context Service Interval = 0.2 秒，RandomDeviation = 0.03 秒
```

本轮压制在进入追压或上次完整喘息结束时开始。追击、侧移、远程施法不重置预算。进入前摇即计为一次承诺，被硬直打断不退还本轮次数。

开始下一动作前计算：
PredictedThreatFreeTime = Max(当前登记危险的最晚失效时刻, 候选动作后摇结束时刻, 候选技能最后危险预计失效时刻)

已承诺三次，或下一动作将令本轮压制超过约 8 秒，则优先 GiveSpace。追击片段同样受时间预算约束。因预算被拒绝的技能不能通过反复 Chase / Reposition 绕过限制。8 秒是事前规划目标，不是用来突然取消已承诺动作的硬定时器。

GiveSpace 必须分为两个阶段：
A. DrainThreats：停止追击和新攻击，等本 BOSS 已发出的有效危险结束。
B. GuaranteedBreathing：确认本 BOSS 有效伤害全部消失后，开始完整 2 秒静止且不发起新攻击的窗口。

区分“尚未消失的特效”和“仍可伤害的攻击”。投射物 / 地面攻击登记所属 BOSS、ActionInstanceID、最晚失效时间，禁用伤害或销毁时注销。所有危险有有限最大寿命，超时关闭伤害并记录错误，不无限等待。

喘息结束：GapCloseAllowedTime = ActualBreathingEndTime + 0.8；该时间前禁止 S3，可恢复普通观察、站位或接近。下一压制段从实际喘息结束开始。

欠下或正在执行的喘息不能被转阶段、重新决策、切目标或普通硬直抹掉。必须中止时保存剩余时长，随后恢复；死亡 / 确认脱战重置可清空。喘息不默认无敌，允许玩家输出。

本组件只控制本 BOSS 的伤害，不清除无关小怪或其他 BOSS 的攻击。提供喘息开始 / 结束事件供遭遇控制器协调，不声称一个行为树就能保证全场安全。

## 8. 原生行为树 BT_Boss

绑定 BB_Boss。Service 挂在 Combat Composite 上，不是可选子动作。

```text
ROOT
└─ Selector: BossPriority
   ├─ [IsDead] BossDeath
   ├─ [MustReset] BossReturnHome
   ├─ [CanApplyHardStagger] BossHardStagger
   ├─ [PhaseTransitionReady] BossPhaseTransition
   ├─ [CombatActive] Selector: Combat
   │  │  Service: BossUpdateContext
   │  ├─ Sequence: OneDecision
   │  │  ├─ BossPlanNextAction
   │  │  └─ Selector: ActionRouter
   │  │     ├─ [ActionKind == GiveSpace] BossGiveSpace
   │  │     ├─ [ActionKind == Search] BossSearch
   │  │     ├─ [ActionKind == Skill] Selector: SkillRouter
   │  │     │  ├─ [SelectedSkill == S1] BossExecuteSkill(S1)
   │  │     │  ├─ [SelectedSkill == S2] BossExecuteSkill(S2)
   │  │     │  ├─ [SelectedSkill == S3] BossExecuteSkill(S3)
   │  │     │  ├─ [SelectedSkill == S4] BossExecuteSkill(S4)
   │  │     │  ├─ [SelectedSkill == S5] BossExecuteSkill(S5)
   │  │     │  ├─ [SelectedSkill == S6] BossExecuteSkill(S6)
   │  │     │  └─ [SelectedSkill == S7] BossExecuteSkill(S7)
   │  │     ├─ [ActionKind == Chase] BossChaseSlice
   │  │     └─ [ActionKind == Reposition] BossReposition
   │  └─ Wait 0.2
   └─ Sequence: Idle
      ├─ SetIdleState
      └─ Wait 0.5
```

IsDead / MustReset / CanApplyHardStagger / PhaseTransitionReady / CombatActive 使用观察式黑板条件，根据当前引擎合法配置应用 Both 中止自身和低优先级分支。ActionKind / SelectedSkill 路由条件使用 None，不因普通上下文变化中途换招。

CanApplyHardStagger 表示当前规则允许的硬打断，不等于“刚受到伤害”。默认普通扣血不触发硬直；已有韧性 / 霸体则接入。
PhaseTransitionReady 仅在没有活动技能、没有待兑现喘息且允许切换时置真，不能直接绑定 HealthRatio <= 0.5。
高优先级请求单次消费并正确清理，避免反复执行硬直或转阶段。
死亡清理幂等，随后停止 Brain / BT，不能每帧重新播死亡。归位无论成功或失败都要有明确且有界的后续。

## 9. 技能 Task、实例隔离与 Abort

遵循目标引擎 ExecuteTask / AbortTask / FinishLatentTask / FinishLatentAbort 契约。蓝图适配遵循对应 FinishExecute / FinishAbort 契约。

有运行状态的原型 C++ Task 默认 bCreateNodeInstance = true。若使用共享节点，状态必须放在正确 NodeMemory 或每个 AI 的组件中。TimerHandle、DelegateHandle、Owner、Target、ActionID 不得污染共享模板。

执行流程：
1. 最终验证目标、资源、范围、视线和路径。
2. 真正进入前摇时分配递增 ActionInstanceID，锁定本轮 SkillID、目标和变体。
3. 此时开始冷却，增加本轮承诺次数；未进入动作的资源失败不扣冷却。
4. 交接移动控制，执行 Windup → Active → Recovery。
5. 在规定时间锁方向 / 落点，锁定后不追踪最新目标位置。
6. 完整后摇结束后仅发送一次终止结果，Task 才完成。

播放 Montage 后不得立即返回 Succeeded。开始 Blend Out 不等于完整结束；结合动画事件和配置后摇确认完成。

生产模式以 Montage / AnimNotify / NotifyState 驱动命中窗口和发射；灰盒以同一生命周期接口的时间轴执行。每次动作只能有一个权威事件来源，不能 Timer 与 Notify 双重扣血。Notify 对象不存储跨角色共享的可变战斗状态。

Abort / EndPlay / UnPossess / Reset 必须：关闭伤害窗；取消未发生的生成；清理 Timer 和 Delegate；释放移动 / 朝向所有权；恢复合适设置；标记本轮已终止，保证幂等。
普通硬直默认不撤回已经发射的非追踪弹体；死亡 / 重置关闭本 BOSS 全部残留伤害。旧回调验证 ActionInstanceID，必要时验证 Montage 实例，不能结束新动作。

正常完成、失败和中止是互斥终态，每次执行最多通知一次。同步中止清理后返回 Aborted；异步清理返回 InProgress，完成后用 FinishLatentAbort，不误用 FinishLatentTask。

设置有界 watchdog 处理丢通知 / 丢回调 / 损坏资源。watchdog 只用于故障清理，不作为正常技能的第二套计时器，不能永久留下动作锁或伤害窗。

## 10. 移动、旋转和导航所有权

明确 NormalChase / Skill / Stagger / GiveSpace / Reset 的移动所有权。
Stationary：停路径和移动，不滑步追人。
SlowAdvance：技能控制低速合法移动。
AttackStep：受限、带碰撞的攻击位移。
CommittedDash：锁方向位移，不持续 MoveTo(TargetActor)。

0.8 秒 ChaseSlice 是决策周期，不意味着每 0.8 秒 StopMovement 一次；连续追击应平滑接续。进入技能 / 喘息 / 硬直才交接。
MoveTo 基于导航；搜索 / 站位点要检查可达性，不只投影到 NavMesh；失败有有界重试与退避。
前摇可转向部分有最大角速度；AimLock 后暂停强制跟踪的 Focus / Controller Rotation。正确恢复移动转向、控制器转向和 Root Motion 设置，避免瞄准已锁但角色仍瞬转。
已有 Root Motion 接入现有模型；灰盒使用 CharacterMovement / 带碰撞位移，不能叠加多个位移来源。距离边界可加迟滞减少抖动，但不得突破实际释放上限。

## 11. 第二阶段和扩展边界

血量首次 <= 50% 只设置 PhaseTransitionRequested，等待当前动作、后摇和欠下的喘息完成后切换，仅触发一次。
第二阶段只改变意图和指定技能权重；不加第八技能，不默认缩短预警，不取消后摇，不突破三次承诺与两秒喘息。
预留追猎 / 炮击 / 守区倾向配置，不扩建随机地图生成、完整小怪导演或大量词缀系统。
已有多人框架时，随机、冷却、决策和伤害在服务器执行，客户端表现必要动作和锁定数据。目标切换在下次安全决策点；防止客户端可见性优化令服务器漏掉权威伤害事件。

## 12. 真实资产、生成器与版本兼容

验证配置：拒绝重复 ID、缺少七槽、非法范围、负冷却、非有限权重和无期限危险。
资产路径服从工程约定；无约定时使用：
/Game/AI/Boss/BB_Boss
/Game/AI/Boss/BT_Boss
/Game/AI/Boss/DA_BossCombatConfig
/Game/AI/Boss/ 下必要的蓝图和灰盒资产
/Game/Tests/BossAI/L_BossAITest

区分源代码、生成工具、已经真实生成并重新加载验证的资产。
.uasset / .umap 必须由对应 Unreal Editor 生成和保存；禁止同名 JSON、文本、零字节文件冒充，禁止假设普通 Python 的 import unreal 可用。

有编辑器时优先用工程现有自动化；必要时添加适配当前版本的 Editor 模块 / Commandlet，并检查本地头文件与官方 API。
仅通过 Factory 创建空 BT 不等于完整行为树；必须构建图节点、连接、Decorator、Service、黑板绑定和运行数据，保证编辑器图与运行时一致，保存后重新加载验证。
Python 仅用于编辑器资产自动化，不当作运行时 Gameplay。不要假设所有 BT 图字段暴露给 Python；未暴露时改用当前版本 C++ Editor 方案。
生成器可重复运行，不重复插节点，不静默覆盖用户手改资产；同名资产先验证差异。

环境确实不能生成完整资产时，继续交付代码、可运行生成方案与最少手工步骤。手工表须列出节点类型、父节点、顺序、Key、条件、Abort、Task 参数、Service 挂点与资产路径。明确标记资产生成 / PIE 验证未完成，不把回退当作已实现全功能。

## 13. 灰盒测试地图与调试

建立独立测试地图，不破坏主地图；包括可移动受伤玩家、BOSS、两只 BOSS 共用同一 BT 的隔离测试、地面 / 柱子 / 窄通道 / 边界 / 导航、七技能预警和实际伤害、遭遇重置 / 二阶段 / 硬直测试入口。

提供可关闭调试显示：Phase、ActionKind、SkillID、ActionInstanceID、动作阶段、感知、距离、各技能 CD、候选权重与拒绝原因、压制预算、连续次数、有效危险数、喘息阶段与剩余时间、突进解禁时间。
独立日志分类，默认不逐帧刷屏，记录决策、动作终态、危险登记 / 失效和喘息事件。可截图时保存真实运行截图，不可截图就用日志，不伪造画面。

## 14. 自动化和验收

先为决策与生命周期建立测试，再接入表现。使用当前引擎可用 Automation Test Framework / Functional Testing，不假设 UE5 文档中的新模块在 UE4.27 同样存在。

至少覆盖：
1. 无合法玩家时 Idle，无攻击与无目标移动。
2. 感知后进入 Combat，正确更新目标。
3. 柱子遮挡不瞬间脱战，不读取遮挡后实时位置精准攻击。
4. 相同快照和随机种子可复现，候选遍历稳定。
5. 冷却、距离、路径、视线不合法则不进入随机池。
6. 两个固定候选权重 20 / 30，独立抽样 10000 次接近 40% / 60%，容差 ±2 个百分点；隔离冷却与历史，不能要求动态战斗序列同样服从固定分布。
7. 同技能不能连续三次，即使只剩该技能也采用非攻击回退。
8. 站桩候选为空时移除意图并归一化，不死循环。
9. 三次承诺后 GiveSpace；追击片段不重置预算。
10. 残留弹体仍有效时不计满喘息，威胁消失后才计完整两秒。
11. 喘息结束后 0.8 秒内拒绝 S3。
12. 下一动作超预算时提前喘息，不切断已承诺动画。
13. 危险超时或漏注销时关闭伤害并恢复，不无限等待。
14. Windup / Active / Recovery 分别中止，无残留 Timer、Delegate、伤害窗和移动锁。
15. 旧 ActionID 回调不结束新动作，不重复伤害。
16. 两只 BOSS 使用同动画时 Notify / Task 状态不串扰。
17. 全技能冷却、零权重、不可达均有有界回退，无高频循环。
18. 距离边缘反复移动不造成连续起手取消、追击顿挫或瞬转。
19. S3 遇墙安全停；S5 落点不追人；S6 / S7 无安全通道时拒绝或降级。
20. 二阶段仅一次，不跳过后摇或抹掉喘息。
21. 目标销毁、UnPossess、关卡退出、死亡不崩溃，正确清理。
22. 共用 BT 的两只 BOSS 冷却、历史、随机流、动作锁、威胁与喘息互不污染。
23. 真正起手前失败不扣 CD，进入前摇后被打断不返还 CD 或次数。
24. 保存重载后 BT 非空，七槽齐全，Key / Enum / Decorator / Service 正确，图与运行数据一致。

区分纯逻辑测试和需要导航、动画、PIE 的集成测试；只通过逻辑测试不得声称完整战斗验证通过。

## 15. 实施顺序与交付记录

A. 工程审查 → 数据结构 → 决策 / 压制预算测试。
B. BT / BB / Controller → Idle、感知、追击、GiveSpace。
C. 动作生命周期 / 移动所有权 / Abort → S1 / S3 / S5 垂直切片。
D. 补齐 S2 / S4 / S6 / S7、阶段切换与灰盒表现。
E. 真实资产 / 编辑器验证 → 单、双 BOSS 集成测试 → 文档。

每阶段验证后继续，创建类不等于完成。新增反射结构后按工程需要做真实构建，不只依赖未经验证的热重载。

写入 docs/boss-ai/：
- IMPLEMENTATION_PLAN.md：真实文件路径、接口、阶段与进度。
- SETUP_AND_TUNING.md：资产连接、参数、动画通知接法、测试地图启动步骤。
- VERIFICATION.md：实际环境、命令、退出码、关键输出、通过 / 失败 / 未运行项及原因。
- 必要时 MANUAL_ASSET_SETUP.md：最少手动操作，不能笼统写“自行创建行为树”。

最终回复：真实修改文件、资产路径、运行方法、真实构建 / 测试结果、待接美术资源、未完成事项及原因。

成功标准：在目标工程中启动可检查的原生行为树；从待机进入战斗，条件随机使用七技能，合理追击与站桩；完整前摇 / 后摇与中止清理；随机无法绕过喘息；多实例互不污染。没实际启动或验证的部分明确标记。

现在检查当前工程，按上述顺序实施。

## 官方技术参考

查阅日期：2026-09-22。官方资料解释工具 / 引擎机制，本文战斗数值是自定义方案。API 签名以工程对应版本及本地头文件为准，不因最新文档存在某 API 就视为 UE4 / UE5 通用。

```text
UE4.27 Composite / Selector
https://dev.epicgames.com/documentation/unreal-engine/behavior-tree-node-reference-composites?application_version=4.27

Behavior Tree Quick Start
https://dev.epicgames.com/documentation/unreal-engine/behavior-tree-in-unreal-engine---quick-start-guide

Decorator / Observer Aborts
https://dev.epicgames.com/documentation/unreal-engine/unreal-engine-behavior-tree-node-reference-decorators

UBTTaskNode / 节点实例与 NodeMemory
https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/AIModule/UBTTaskNode

UE5.5 AbortTask
https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/AIModule/BehaviorTree/UBTTaskNode/AbortTask?application_version=5.5

Animation Montage Editor / 完成与混出事件
https://dev.epicgames.com/documentation/unreal-engine/animation-montage-editor-in-unreal-engine

Unreal Editor Python
https://dev.epicgames.com/documentation/unreal-engine/scripting-the-unreal-editor-using-python

Codex AGENTS.md
https://developers.openai.com/zh-Hans/docs/agent-configuration/agents-md
```
