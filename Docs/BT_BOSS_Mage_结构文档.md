# BT_BOSS_Mage 行为树结构文档

> 数据来源：编辑器内 `ue.load_object(BehaviorTree, '/TTS/Asset/AI/BT/BT_BOSS_Mage')` 读取**运行时树**（RootNode → Children/Decorators/Services 递归，含每个节点的全部可读属性）导出后整理。
> 读取时间：2026-09-22。树大小 **56 个节点**（复合/任务），绑定黑板 **BB_BOSS_Mage**，使用怪物：`MagicMonster`（`Asset/Blueprint/Prefabs/Monsters/MagicMonster`）。

- 资产路径（Lua 内）：`UGCGameSystem.GetUGCResourcesFullPath('Asset/AI/BT/BT_BOSS_Mage.BT_BOSS_Mage')`
- 根节点对象：`BTComposite_Selector_23`（display 名：`Selector`）
- 引用的子行为树：`BTTask_RunBehavior` → `BT_BOSS_Trans`（多个 `Run Behavior` 节点复用同一子树）
- 说明：本文档只描述结构与参数，不涉及任何代码实现。

---

## 一、整体结构大纲

> 缩进 = 层级；`<Dec: X>` = 挂在该分支（父节点子项）上的装饰器；`<Svc: X>` = 挂在节点自身上的服务；`[INVERSE]` 表示取反。

```
Selector                                                    ← 根
├─ Sequence                                    <Dec: [Generic]属性比较> <Dec: Blackboard Based Condition>
│  ├─ 释放转阶段技能  [BTTask_Generic_CastSkill]                 Slot4, SkillTarget=SelfActor
│  ├─ 修改技能        [BTTask_Generic_SetSkill]                  SkillInfos ×6
│  ├─ 设置转阶段完成  [BTTask_UGC_ModifyBBValue]                 bHasChangeStage = true
│  └─ [Generic]发送通知 [BTTask_Generic_SendNotify]              NotifyMsg=ChangeStage
└─ Selector                                    <Svc: [Generic]寻敌>        ← 战斗/移动主分支（服务挂在这里，无门控）
   ├─ Sequence                                  <Dec: Blackboard Based Condition( Target 已设置 )>
   │  ├─ Selector
   │  │  ├─ Sequence                            <Dec: 状态检查 [INVERSE]( PawnState.Action.Battle )>
   │  │  │  ├─ [Generic]发送通知                 NotifyMsg=EnterBattle
   │  │  │  └─ [Generic]设置AI状态               Operation=1, State=PawnState.Action.Battle
   │  │  └─ Selector                            <Dec: 概率 80%>
   │  │     ├─ Selector                         <Dec: CheckDistance( SelfActor vs Target, Greater )>
   │  │     │  └─ Sequence
   │  │     │     ├─ [Generic]寻找指定方向上的可达位置  Center=Target, Distance=1750, SerachRange=250, OutputLocation=TargetPosition
   │  │     │     ├─ Run Behavior                        → BT_BOSS_Trans（移动到该点）
   │  │     │     └─ [Generic]等待                       TrueWaitTime=1
   │  │     ├─ [Generic]指定速度移动到            <Dec: CheckDistance( Greater )>   BlackboardKey=Target, StopRadius=100
   │  │     └─ Selector                         <Dec: CheckDistance( Greater )>
   │  │        ├─ Selector                      <Dec: 概率> <Dec: TimeCheck>
   │  │        │  ├─ [Generic]多方向移动         <Dec: 概率 50%>   SidesShift
   │  │        │  └─ [Generic]多方向移动         SideWay=1          SidesShift
   │  │        └─ Selector
   │  │           ├─ Sequence
   │  │           │  ├─ [Generic]寻找指定方向上的可达位置  Center=Target, Distance=1500(键), SerachRange=500
   │  │           │  └─ Run Behavior                        → BT_BOSS_Trans
   │  │           └─ [Generic]等待               TrueWaitTime=1, RandomWaitTime=0.4
   │  │     ├─ Sequence                         <Dec: CheckDistance( Less )>
   │  │     │  ├─ [Generic]寻找指定方向上的可达位置  Center=Target, Distance=1800, SerachRange=400
   │  │     │  └─ Run Behavior                        → BT_BOSS_Trans
   │  │     ├─ Sequence                         <Dec: 概率 30%>
   │  │     │  ├─ [Generic]寻找指定方向上的可达位置  Center=Target, Distance=2500, SerachRange=1000
   │  │     │  └─ Run Behavior                        → BT_BOSS_Trans
   │  │     └─ [Generic]等待                     TrueWaitTime=0.5
   │  ├─ [Generic]等待                           TrueWaitTime=0.5
   │  └─ Sequence                                <Dec: TimeCheck( LastTime, Greater )>
   │     ├─ [Generic]转向                        TurnAroundTarget=Target, bTurnInstantly=true, MinAngle=135
   │     ├─ [Generic]等待                        TrueWaitTime=0.5, RandomWaitTime=0.2
   │     ├─ Selector
   │     │  ├─ 施放技能组  [BTTask_Generic_CastSkillGroup]   Slot0/1/2 三组数据（见 §3.2）
   │     │  └─ 释放火球术  [BTTask_Generic_CastSkill]        Slot=Skill.Slot.Main, SkillTarget=Target
   │     ├─ BTTask_Generic_RecordTime_2          TimeRecord=LastSkillTime
   │     └─ [Generic]转向                        TurnAroundTarget=Target, bTurnInstantly=false
   └─ Selector                                  <Dec: Blackboard Based Condition( Target 未设置 )>   ← 无目标分支
      ├─ Sequence                               <Dec: 状态检查( PawnState.Action.Battle )>
      │  ├─ [Generic]发送通知                    NotifyMsg=ExitBattle
      │  └─ [Generic]设置AI状态                  Operation=2 (清除 Battle)
      ├─ Sequence                               <Dec: CheckDistance( SelfActor vs SpawnLoc, Greater )>   ← 回巢
      │  ├─ [Generic]寻找可达位置                FindCenter=SpawnLoc, OutFindLoc=TargetPosition
      │  └─ [Generic]指定速度移动到              <Dec: Blackboard( TargetPosition 已设置 )> BlackboardKey=TargetPosition, StopRadius=100
      └─ Sequence                                                                                        ← 巡逻
         ├─ [Generic]等待                        TrueWaitTime=2, RandomWaitTime=0.5
         └─ Sequence
            ├─ [Generic]寻找可达位置              FindCenter=SpawnLoc, OutFindLoc=TargetPosition
            └─ [Generic]指定速度移动到            <Dec: Blackboard( TargetPosition 已设置 )> BlackboardKey=TargetPosition, StopRadius=100
```

**关键结构点（本次重点）**：
1. `[Generic]寻敌`（BTService_Generic_ChooseEnemy）挂在**战斗主分支的 Selector 本身上**，而这个 Selector **没有装饰器门控**；"Target 已设置" 的门控在其**内部第一层 Sequence** 上。→ 因此**即使当前没有目标，寻敌服务也一直在跑**，能主动发现玩家；这是 CCP 目前最关键的差异（CCP 把门控挂在了 Selector 上，导致没目标时服务根本不运行）。
2. 所有移动都是"**先找可达点（或直接以 Target 为点）→ MoveToEx**"的组合，移动速度用**键模式**（`Value=-1, ValueType=1`，键未显式指定 → 使用怪物身上行为树参数的默认速度，即 `PursuitSpeed`/`PatrolSpeed`）。→ 参数为 0 时速度为 0，怪物原地不动。
3. 接近/绕后使用 `FindAReachablePosByDirection`（以 **Target 为中心**、指定距离 1500/1750/1800/2500 + 搜索半径 250~1000）再交给子树 `BT_BOSS_Trans` 移动；撤退/巡逻使用 `FindAReachablePos`（以 **SpawnLoc 出生点为中心**）。

---

## 二、移动相关节点详解（参考重点）

### 2.1 `BTTask_Generic_MoveToEx`（"指定速度移动到"）
树中共 5 处，参数一致：

| 字段 | 值 | 说明 |
|---|---|---|
| `BlackboardKey` | `Target`（追击）/ `TargetPosition`（巡逻与回巢） | 目标点来源：**跟随 Actor** 或 **到达一个坐标点** |
| `NewMaxSpeedValue` | `Value=-1, ValueType=1` | **键模式**：速度取自黑板键（未显式指定键时用默认移动速度，由怪物反射参数提供） |
| `StopRadius` | `100` | 距离目标 100 停止 |
| `StopRadiusIncludesAgentRadius` | `true` | 停止半径包含自身胶囊半径 |
| `StopRadiusIncludesGoalRadius` | `false` | |
| `StuckLimitTime` | `3` | 卡住 3 秒判定失败 |
| `BlockStateTags` | 空 | 不屏蔽任何状态 |

> 对比：CCP 的 `ApproachFar/MoveApproach` 用了固定数值速度（ValueType=0）。建议对齐法师：改为键模式（或确保怪物参数 `PursuitSpeed/PatrolSpeed` 有值，两者配合才能动）。

### 2.2 `BTTask_Generic_FindAReachablePosByDirection`（"寻找指定方向上的可达位置"）
树中共 4 处（接近/绕行，均以 **Target 为中心**）：

| 使用场景 | Distance | SerachRange | OutputLocation |
|---|---|---|---|
| 远距离侧向接近（在 Selector/概率 80% 下） | 1750 | 250 | `TargetPosition` |
| 中距离（概率分支内，Distance 为**键模式**） | 1500 | 500 | `TargetPosition` |
| 中距离（CheckDistance Less 分支） | 1800 | 400 | `TargetPosition` |
| 远距离（概率 30% 分支） | 2500 | 1000 | `TargetPosition` |

公共字段：`Center=Target`、`Target=SelfActor`、`TargetRange=-1`、`MaxSearchTime=10`。
→ 语义：**在目标周围指定距离/半径里找一个"可达点"**，输出到 `TargetPosition`，随后交给 `Run Behavior(BT_BOSS_Trans)` 走过去。这样能避免直接冲目标导致的卡位/穿墙。

### 2.3 `BTTask_Generic_FindAReachablePos`（"寻找可达位置"）
巡逻/回巢使用：`FindCenter=SpawnLoc`、`OutFindLoc=TargetPosition`、`MinPatrolDistance`、`SearchDistance_Min/Max`（部分为键模式）、`MaxSearchTime=10`。
→ 语义：**以出生点为中心**找可达点，配合 `MoveToEx(TargetPosition)` 实现"在出生点周围游走/回巢"。

### 2.4 `BTTask_Generic_SidesShift`（"多方向移动"，侧移）
| 字段 | 值 |
|---|---|
| `TargetKey` | `Target` |
| `MoveSpeed` | `Value=0, ValueType=1`（键模式 → 默认移动速度） |
| `MoveFactor` | 100 |
| `MoveStep` | 2 |
| `SideWay` | 0 / 1（两侧各一个任务） |
| `RandomSide` | false |
| `StuckLimitTime` | 3 |

树中两处，分别被 `概率 50%` 装饰；上层还有一个 `概率 + TimeCheck` 的组合 → 用于**战斗中随机侧向拉扯走位**。

### 2.5 `BTTask_Generic_TurnAround`（"转向"）
`TurnAroundTarget=Target`、`bTurnInstantly=true/false`、`MinAngleForInterpTurnAround=135`。
→ 战斗循环里"放技能前先瞬间转向目标"，放完技能再插值转身（第二次 bTurnInstantly=false）。

### 2.6 移动行为的组合链路（照抄即可）
- **发现战斗**：`状态检查[INVERSE](Battle)` → `发送通知 EnterBattle` → `设置AI状态 Battle(OP=1)`
- **远距离接近**：`概率 80%` → `CheckDistance(Greater)` → `FindAReachablePosByDirection(Target, 1750±250)` → `RunBehavior(BT_BOSS_Trans)` → `Wait 1s`
- **直线追击**：`MoveToEx(BlackboardKey=Target, StopRadius=100)`（带 `CheckDistance(Greater)` 门控）
- **近身走位**：`CheckDistance(Greater)` → 概率/时间门控下 `SidesShift(50%)`；或 `FindAReachablePosByDirection(Target,1500±500)` + `RunBehavior`
- **中/远距离走位**：`CheckDistance(Less)` + `FindAReachablePosByDirection(1800±400)`；`概率 30%` + `FindAReachablePosByDirection(2500±1000)`
- **攻击循环**：`TimeCheck(LastSkillTime, Greater)` → `转向` → `Wait 0.5` → `CastSkillGroup` / `CastSkill(Slot.Main)` → `RecordTime(LastSkillTime)` → `转向(插值)`
- **丢失目标**：`Target 未设置` → `状态检查(Battle)` → `发送通知 ExitBattle` → `设置AI状态(OP=2)`；随后 `CheckDistance(SelfActor vs SpawnLoc, Greater)` → `FindAReachablePos(SpawnLoc)` + `MoveToEx(TargetPosition)` 回巢；否则 `Wait 2±0.5` → `FindAReachablePos(SpawnLoc)` + `MoveToEx(TargetPosition)` 巡逻

---

## 三、战斗 / 技能 / 状态节点

### 3.1 `BTTask_Generic_CastSkill`（"释放技能"）
- 转阶段技能：`SlotGameplayTag = Skill.Slot.Slot4`，`SkillTarget = SelfActor`，`bCanCastWithoutTarget = true`
- 火球术：`SlotGameplayTag = Skill.Slot.Main`，`SkillTarget = Target`，`bCanCastWithoutTarget = true`
- 槽位标签约定：`Skill.Slot.Main`、`Skill.Slot.Slot0 ~ Slot4`。

### 3.2 `BTTask_Generic_CastSkillGroup`（"施放技能组"）— 3 组数据
| # | Slot | Weight | DistanceMin~Max | CDMin~Max | SkillTarget | bCanCastWithoutTarget |
|---|---|---|---|---|---|---|
| 1 | `Skill.Slot.Slot0` | 80 | 500 ~ 1500 | 8 ~ 12 | `Target` | true |
| 2 | `Skill.Slot.Slot1` | 80 | 300 ~ 2000 | 6 ~ 13 | `Target` | true |
| 3 | `Skill.Slot.Slot2` | 120 | 0 ~ 3000 | 10 ~ 15 | `Target` | true |

→ 技能组 = **按权重随机 + 距离/冷却过滤** 的技能选择器；与怪物反射参数里的 `Skill_1/2/3_*` 一一对应（参数表控制距离与 CD，Weight 在 Int 表里）。

### 3.3 状态与通知
- `BTTask_Generic_SetAIState`：`Operation=1` 设置 / `Operation=2` 清除，`StateGameplayTag = PawnState.Action.Battle`
- `BTTask_Generic_SendNotify`：`ChangeStage` / `EnterBattle` / `ExitBattle`（怪物 Lua 的 `OnBehaviorNotify_BP` 可接收）
- `BTTask_Generic_RecordTime`：写入 `LastSkillTime` 等时间键供 `TimeCheck` 使用
- `BTTask_Generic_SetSkill`（"修改技能"）：`SkillInfos` ×6（`Generic_SetSkillTask_SkillInfo`）
- `BTTask_UGC_ModifyBBValue`：`bHasChangeStage = true`
- `BTTask_RunBehavior`：运行子行为树 `BT_BOSS_Trans`

### 3.4 转阶段分支
根 Selector 的第一分支（`Sequence <Dec: 属性比较> <Dec: Blackboard(BHasChangeStage 未设置)>`）：
1. `[Generic]属性比较`：`ObserveObject=SelfActor`、`Attribute=Health`、`ArithmeticOperation=3（≤）`、`CompareValue` 为**键模式**（读取怪物参数 `ChangeStagetHP`，MagicMonster 值=5000）、`FlowAbortMode=Self`
2. → `释放转阶段技能(Slot4)` → `修改技能` → `设置转阶段完成(bHasChangeStage=true)` → `发送通知 ChangeStage`

---

## 四、装饰器 / 服务语义（本树用到的全部）

| 类型 | 关键参数 | 语义 |
|---|---|---|
| `BTDecorator_Generic_CheckDistance` | `CenterActorBlackBoardKey=SelfActor`、`TargetActorBlackBoardKey=Target`、`ArithmeticOperation`（2=Less、4=Greater）、`TestDistance`（可为键模式）、`IgnoreZOffset`、`OverlapAgentAndGoal`、`FlowAbortMode=2(Self)` | 距离条件；观察者中止=Self（条件翻转立即中止自身分支） |
| `BTDecorator_Generic_TimeCheck` | `LastTime`（键模式，如 `LastSkillTime`）、`ArithmeticOperation`（2=Less、4=Greater）、`CheckDiffMin/Max` | 距上次记录时间的时间窗判断 |
| `BTDecorator_Generic_Probability` | `ExecuteProbability`（如 80 / 50 / 30） | 概率通过 |
| `Blackboard Based Condition` | `BlackboardKey`（`Target` / `bHasChangeStage`）、`OperationType`（1=IsNotSet）、`NotifyObserver=1`、`FlowAbortMode=2` | 黑板键条件 + 观察者中止 |
| `状态检查` (`BTDecorator_Generic_CheckState`) | `BBKeyTargetActor=SelfActor`、`TargetDynamicState=PawnState.Action.Battle`、`OP=1`、可 `bInverseCondition` | 角色动态状态判断（战斗/非战斗） |
| `[Generic]属性比较` (`BTDecorator_Generic_AttrObserve_New`) | `Attribute=Health`、`ArithmeticOperation=3(≤)`、`CompareValue` 键模式 | 属性阈值（转阶段） |
| `[Generic]寻敌` (`BTService_Generic_ChooseEnemy`) | 挂在战斗主 Selector 上；魔法师怪物参数：`EnableEnemyDistanceStrategy=false`（三套策略全关） | 周期性寻找敌人并写入 `Target` |

---

## 五、对 CCP（超级怪物行为树）的对照与改法建议

> 只列结构/参数差异，不涉及代码。

| # | 法师做法 | CCP 现状 | 建议 |
|---|---|---|---|
| 1 | `[Generic]寻敌` 挂在**无门控的 Selector** 上；"Target 已设置"门控在**内层 Sequence** | `DecHasTarget` 直接挂在 `CombatSel` 上，寻敌服务被门控 → **没目标时服务不运行** | 把 `DecHasTarget` 下移到 `CombatSel` 内部第一层 Sequence（或再加一个不门控的外层 Selector 承载服务） |
| 2 | 移动速度用**键模式**（默认速度来自怪物参数 `PursuitSpeed`/`PatrolSpeed`） | `MoveApproach/ApproachFar` 用固定数值 | 改键模式；并保证怪物 `BehaviorControlComp` 参数表有值（本次已补齐） |
| 3 | 接近 = `FindAReachablePosByDirection(Target)` + `RunBehavior`，带距离/概率分支 | CCP 只有直线 `MoveToEx(Target)` | 增加"先找可达点再移动"的分支（以 Target 为中心、不同距离/半径），减少卡位 |
| 4 | 巡逻/回巢以 `SpawnLoc` 为中心 | CCP 的 `FindPatrol` 以 `SelfActor` 为中心 | 改用 `SpawnLoc`（在巡逻前先用 `FindAReachablePos(SpawnLoc)`） |
| 5 | 侧移 `SidesShift` 的 `MoveSpeed` 为键模式 | CCP 用固定 500 | 改键模式（默认速度） |
| 6 | 技能用 `CastSkillGroup`（权重+距离+CD 过滤） | CCP 用多条并列 `CastSkill` 分支 | 后期可收敛为技能组（结构数组需在编辑器 UI 中配置） |
| 7 | 转阶段用 `CompareValue` 键模式读 `ChangeStagetHP` | CCP 用固定 600000 | 可选：改键模式并在怪物参数表填 `ChangeStagetHP`（当前已填 600000） |

---

## 六、附录 A：怪物行为树参数对照（MagicMonster vs SuperMonster 现值）

| 键 | MagicMonster | SuperMonster（本次填好） |
|---|---|---|
| PursuitSpeed | 1000 | 1200 |
| PursuitDistance | 2000 | 5000 |
| PatrolSpeed | 300 | 600 |
| MaxPatrolRange | 1500 | 3000 |
| MinPatrolRange | 500 | 500 |
| MinPatrolDistance | 300 | 300 |
| CloseDistance | 500 | 500 |
| StalkDistance / StalkProbability | 1000 / 60 | 1000 / 60 |
| TransmissionDistance / MinTransmission | 3000 / 600 | 3000 / 600 |
| AttackMinInterval / AttackMaxInterval | 2.5 / 1.5 | 2.5 / 1.5 |
| ChangeStagetHP | 5000 | 600000 |
| Skill_1 (MinDist/MaxDist/CDMin/CDMax) | 500/1500/12/22 | 500/1500/12/22 |
| Skill_2 | 800/2000/15/20 | 800/2000/15/20 |
| Skill_3 | 1000/3000/20/15 | 1000/3000/20/15 |
| Skill_1/2/3_Weight（Int） | 80/80/120 | 80/80/120 |
| 通用命名补充（PursuitRadius/PursuitMoveSpeed/PatrolMoveSpeed/PatrolRange_Min/Max/PatrolChance/AttackDistance/AttackIntervalMin/Max/bPatrol/bAssailant 等） | —（法师表无此项） | 本次已补齐（因为 CCP 当前绑定的黑板是 `BB_UGC_Generic_Base`） |

> 注意：怪物运行时读的是**它绑定的 BT 的黑板键**。MagicMonster 绑 `BT_BOSS_Mage` → 黑板 `BB_BOSS_Mage`，键名与参数表一一对应。CCP 当前绑 `BB_UGC_Generic_Base`（31 个通用键），所以本次参数表**两套键名都填了**，哪套绑定都能生效。

---

## 七、附录 B：逐节点清单（56 个）

| # | 路径 | 深度 | 显示名 | 类 | 关键属性 |
|---|---|---|---|---|---|
| 0 | 0 | 0 | Selector | BTComposite_Selector | — |
| 1 | 0.0 | 1 | Sequence | BTComposite_Sequence | Dec: 属性比较(Health ≤ ChangeStagetHP键) / Blackboard(bHasChangeStage 未设置) |
| 2 | 0.0.0 | 2 | 释放转阶段技能 | BTTask_Generic_CastSkill | Slot4, Target=SelfActor |
| 3 | 0.0.1 | 2 | 修改技能 | BTTask_Generic_SetSkill | SkillInfos ×6 |
| 4 | 0.0.2 | 2 | 设置转阶段完成 | BTTask_UGC_ModifyBBValue | bHasChangeStage=true |
| 5 | 0.0.3 | 2 | [Generic]发送通知 | BTTask_Generic_SendNotify | ChangeStage |
| 6 | 0.1 | 1 | Selector | BTComposite_Selector | **Svc: [Generic]寻敌** |
| 7 | 0.1.0 | 2 | Sequence | BTComposite_Sequence | Dec: Target 已设置 |
| 8 | 0.1.0.0 | 3 | Selector | BTComposite_Selector | — |
| 9 | 0.1.0.0.0 | 4 | Sequence | BTComposite_Sequence | Dec: 状态检查[INVERSE](Battle) |
| 10 | 0.1.0.0.0.0 | 5 | [Generic]发送通知 | BTTask_Generic_SendNotify | EnterBattle |
| 11 | 0.1.0.0.0.1 | 5 | [Generic]设置AI状态 | BTTask_Generic_SetAIState | OP=1, Battle |
| 12 | 0.1.0.0.1 | 4 | Selector | BTComposite_Selector | Dec: 概率 80 |
| 13 | 0.1.0.0.1.0 | 5 | Selector | BTComposite_Selector | Dec: CheckDistance(Greater) |
| 14 | 0.1.0.0.1.0.0 | 6 | Sequence | BTComposite_Sequence | — |
| 15 | 0.1.0.0.1.0.0.0 | 7 | [Generic]寻找指定方向上的可达位置 | BTTask_Generic_FindAReachablePosByDirection | Center=Target, Dist=1750, Range=250 |
| 16 | 0.1.0.0.1.0.0.1 | 7 | Run Behavior | BTTask_RunBehavior | BT_BOSS_Trans |
| 17 | 0.1.0.0.1.0.0.2 | 7 | [Generic]等待 | BTTask_Generic_Wait | 1s |
| 18 | 0.1.0.0.1.1 | 5 | [Generic]指定速度移动到 | BTTask_Generic_MoveToEx | Key=Target, Stop=100 | Dec: CheckDistance(Greater) |
| 19 | 0.1.0.0.1.2 | 5 | Selector | BTComposite_Selector | Dec: CheckDistance(Greater) |
| 20 | 0.1.0.0.1.2.0 | 6 | Selector | BTComposite_Selector | Dec: 概率(键) / TimeCheck(键) |
| 21 | 0.1.0.0.1.2.0.0 | 7 | [Generic]多方向移动 | BTTask_Generic_SidesShift | Dec: 概率 50 |
| 22 | 0.1.0.0.1.2.0.1 | 7 | [Generic]多方向移动 | BTTask_Generic_SidesShift | SideWay=1 |
| 23 | 0.1.0.0.1.2.1 | 6 | Selector | BTComposite_Selector | — |
| 24 | 0.1.0.0.1.2.1.0 | 7 | Sequence | BTComposite_Sequence | — |
| 25 | 0.1.0.0.1.2.1.0.0 | 8 | [Generic]寻找指定方向上的可达位置 | BTTask_Generic_FindAReachablePosByDirection | Center=Target, Dist=1500(键), Range=500 |
| 26 | 0.1.0.0.1.2.1.0.1 | 8 | Run Behavior | BTTask_RunBehavior | BT_BOSS_Trans |
| 27 | 0.1.0.0.1.2.1.1 | 7 | [Generic]等待 | BTTask_Generic_Wait | 1±0.4s |
| 28 | 0.1.0.0.1.3 | 5 | Sequence | BTComposite_Sequence | Dec: CheckDistance(Less) |
| 29 | 0.1.0.0.1.3.0 | 6 | [Generic]寻找指定方向上的可达位置 | BTTask_Generic_FindAReachablePosByDirection | Center=Target, Dist=1800, Range=400 |
| 30 | 0.1.0.0.1.3.1 | 6 | Run Behavior | BTTask_RunBehavior | BT_BOSS_Trans |
| 31 | 0.1.0.0.1.4 | 5 | Sequence | BTComposite_Sequence | Dec: 概率 30 |
| 32 | 0.1.0.0.1.4.0 | 6 | [Generic]寻找指定方向上的可达位置 | BTTask_Generic_FindAReachablePosByDirection | Center=Target, Dist=2500, Range=1000 |
| 33 | 0.1.0.0.1.4.1 | 6 | Run Behavior | BTTask_RunBehavior | BT_BOSS_Trans |
| 34 | 0.1.0.0.1.5 | 5 | [Generic]等待 | BTTask_Generic_Wait | 0.5s |
| 35 | 0.1.0.0.2 | 4 | [Generic]等待 | BTTask_Generic_Wait | 0.5s |
| 36 | 0.1.0.1 | 3 | Sequence | BTComposite_Sequence | Dec: TimeCheck(LastTime, Greater) |
| 37 | 0.1.0.1.0 | 4 | [Generic]转向 | BTTask_Generic_TurnAround | Target=Target, 瞬间 |
| 38 | 0.1.0.1.1 | 4 | [Generic]等待 | BTTask_Generic_Wait | 0.5±0.2s |
| 39 | 0.1.0.1.2 | 4 | Selector | BTComposite_Selector | — |
| 40 | 0.1.0.1.2.0 | 5 | 施放技能组 | BTTask_Generic_CastSkillGroup | Slot0/1/2（§3.2） |
| 41 | 0.1.0.1.2.1 | 5 | 释放火球术 | BTTask_Generic_CastSkill | Slot.Main, Target |
| 42 | 0.1.0.1.3 | 4 | RecordTime_2 | BTTask_Generic_RecordTime | LastSkillTime |
| 43 | 0.1.0.1.4 | 4 | [Generic]转向 | BTTask_Generic_TurnAround | 插值(false) |
| 44 | 0.1.1 | 2 | Selector | BTComposite_Selector | Dec: Target 未设置 |
| 45 | 0.1.1.0 | 3 | Sequence | BTComposite_Sequence | Dec: 状态检查(Battle) |
| 46 | 0.1.1.0.0 | 4 | [Generic]发送通知 | BTTask_Generic_SendNotify | ExitBattle |
| 47 | 0.1.1.0.1 | 4 | [Generic]设置AI状态 | BTTask_Generic_SetAIState | OP=2 |
| 48 | 0.1.1.1 | 3 | Sequence | BTComposite_Sequence | Dec: CheckDistance(SelfActor vs SpawnLoc, Greater) |
| 49 | 0.1.1.1.0 | 4 | [Generic]寻找可达位置 | BTTask_Generic_FindAReachablePos | Center=SpawnLoc |
| 50 | 0.1.1.1.1 | 4 | [Generic]指定速度移动到 | BTTask_Generic_MoveToEx | Key=TargetPosition, Stop=100 | Dec: Blackboard(TargetPosition 已设置) |
| 51 | 0.1.1.2 | 3 | Sequence | BTComposite_Sequence | — |
| 52 | 0.1.1.2.0 | 4 | [Generic]等待 | BTTask_Generic_Wait | 2±0.5s |
| 53 | 0.1.1.2.1 | 4 | Sequence | BTComposite_Sequence | — |
| 54 | 0.1.1.2.1.0 | 5 | [Generic]寻找可达位置 | BTTask_Generic_FindAReachablePos | Center=SpawnLoc |
| 55 | 0.1.1.2.1.1 | 5 | [Generic]指定速度移动到 | BTTask_Generic_MoveToEx | Key=TargetPosition | Dec: Blackboard(TargetPosition 已设置) |

---

## 八、平台怪物行为架构（官方 Wiki《怪物行为控制组件》，2026-09-22 核对）

这一节解释"为什么法师树能动、CCP 不能动"的平台背景。

1. **寻敌/待机/巡逻/追击/攻击 = 平台"基础行为树"提供的**：怪物模板默认在 `BehaviorControlComp.行为树资产` 绑定 `BT_UGC_GenericMob_MainTree`（"UGC怪物行为树"，主树 + 多个子行为树）。**把该字段改成自定义树（BT_BOSS_Mage / CCP）= 替换掉平台这套行为**——之后寻敌与移动必须由该自定义树自己实现。
   - 法师树正是自己实现了寻敌（`[Generic]寻敌` 服务）+ 巡逻/接近（`FindAReachablePos*` + `MoveToEx`）。
   - 绑 `None` 的怪物（FastMonster/Titan 等）走平台默认。
   - ⚠️ 实测把 SuperMonster 的绑定清空 → 怪物直接没有黑板（参数读不到）→ 不能用；已恢复为 CCP。
2. **反射黑板键 = 怪物蓝图上的"行为树属性配置"参数面板**：BB 键勾选 `Is Exposure to Detail` 后暴露到怪物蓝图，落到 `BehaviorTreeSetting.BTReflectProp_Float/_Int/_Bool/_String` 四张表。**改动绑定/重编译会按"当前绑定 BT 的黑板键"重生成这四张表**（键集会变、同名键的值会保留）。
3. **参数语义（与通用黑板键对照）**：

| 面板参数 | 黑板键 | 含义 |
|---|---|---|
| 巡逻 | `bPatrol` | 不开则永远待机 |
| 巡逻范围-最小/最大 | `PatrolRange_Min/Max` | 以**出生点为圆心**的环形巡逻内外径 |
| 巡逻触发概率 | `PatrolChance` | 待机结束后进入巡逻的概率 |
| 巡逻最小/最大等待时间 | `PatrolWaitIntervalMin/Max` | 两次巡逻的时间间隔范围 |
| 巡逻移动速度 | `PatrolMoveSpeed` | 巡逻/回巡逻环的速度 |
| 最小巡逻距离 | `PatrolMinRange` | 巡逻点距自身的最小距离 |
| 追击距离 | `PursuitRadius` | 距离大于该值则持续追击（优先级高于攻击距离） |
| 追击等待时间/随机偏移 | `PursuitWaitTime` / `PursuitRandomTime` | 转向目标后等待多久开始追 |
| 追击移动速度 | `PursuitMoveSpeed` | 追击速度 |
| 攻击距离 | `AttackDistance` | 进入攻击的距离；攻击释放 `Skill.Slot.Main`；隔墙时以追击速度寻路至可见 |
| 可攻击 | `bAssailant` | 不开则不追击也不攻击 |
| 最小/最大攻击间隔 | `AttackIntervalMin/Max` | 两次攻击的时间间隔范围 |
| 平滑转向角度阈值 | `TurnAngle` | 转向插值阈值 |

4. **当前 SuperMonster 状态**：绑定 CCP；参数已填（19 个通用键：PursuitRadius=5000、PursuitMoveSpeed=1200、PatrolMoveSpeed=600、PatrolRange 500~3000、AttackDistance=500、bPatrol/bAssailant=true 等，已在运行时验证会写入黑板）。**要让怪物真正动起来，还需在 CCP 里补齐"可运行的寻敌 + 移动分支"**（对照本文件第五节对照表）。

## 九、重要更正与"编辑器保存才编译"结论（2026-09-22）

1. **更正**：`BTTask_RunBehavior` 引用的 `BT_BOSS_Trans` **不是移动子树**——实测其结构为 `Sequence【[Generic]转向 → [Generic]施放技能 → RecordTime → [Generic]转向】`（"转身—攻击—记录"序列）。法师的真实位移由 **`MoveToEx(BlackboardKey=Target)`** 与 **`MoveToEx(BlackboardKey=TargetPosition)`**（前者用于追击目标演员，后者用于去 `FindAReachablePos*` 找到的点）完成。上文中"RunBehavior(BT_BOSS_Trans)（移动）"的描述应理解为"找到可达点后执行攻击序列"，移动由紧随其后的 MoveToEx 承担。
2. **实测证据链（MCP 生成的树是"死"的）**：
   - A/B 对照：同位置生成，法师怪（BT_BOSS_Mage，**编辑器资产**）自动锁定玩家 ✓；超级怪（CCP，**MCP 脚本生成**）不锁定 ✗ —— 即使把寻敌服务对象搬到非根节点、配置与法师逐字段对齐、运行时树里确实能读到该服务。
   - 手动注入 Target 后，CCP 树能进战斗（PawnState.Action.Battle）但 `MoveToEx` 不产生任何位移；在"导航网格已被证明可用"的位置（普通怪在该处巡逻行走过）复测仍不动。
   - 平台基础行为树的普通怪：往黑板写 `bPatrol=true/PatrolMoveSpeed=600/...` 后**立刻巡逻移动** ✓（说明导航、移动组件、参数→运行时空板链路全部正常）。
   - 结论：**由 MCP 脚本（bt_add_node / 直接改对象数组）追加/生成的节点与服务，fork 在运行时不会执行；只有"在 BT 编辑器里编辑并保存过的"运行时树才是被编译执行的**（编辑器保存会把图与运行时树做一次官方同步/编译）。因此 CCP 里"手动注入目标后能观察到"的战斗状态、技能释放，很可能来自**原生层**（可攻击 bAssailant/攻击距离/攻击间隔等参数驱动），而不是 CCP 树本身。
3. **验证协议（路线 A）**：① 在编辑器内给 CCP 的结构补一个"无装饰器的选择器 + [Generic]寻敌 服务"，Ctrl+S；② 清理暂存（把编辑器重建的图移出包）；③ PIE 中生成超级怪在玩家附近，核对：是否自动锁定（Target）、是否进战斗、是否产生位移（Walking/坐标变化）、是否按 CCP 的技能槽放技能。若①之后树仍不执行，则说明需要"整棵树都在编辑器里重建"，届时应考虑改用平台基础行为树 + 子行为树(RunBehavior)挂自定义逻辑的方案。

## 十、路线 A 操作步骤（编辑器内）与验证清单

**为什么服务必须挂"无装饰器"的节点**：fork 的服务只在"其所在节点被进入"时才会 Tick；如果服务挂在带装饰器的节点上（例如 CCP 的 `CombatSel` 带着"Target 已设置"门控），没目标时该节点不会被进入 → 服务不运行 → 永远找不到目标（死锁）。法师树正是把服务挂在**无装饰器的选择器**上（`[0.1]`），Target 门控放在它的**内层** ⇒ 抄这个结构。

**步骤**
1. 打开 `/TTS/Asset/AI/CCP`。
2. 在根选择器下新建一个 **Selector**（如 `CombatRoot`），位置放在 `StageSeq` 之后；**不要给它加任何装饰器**。
3. 把现有 `CombatSel`、`PatrolSel` 拖进 `CombatRoot`（顺序保持 CombatSel 在前）。
4. 右键 `CombatRoot` → 添加服务 → **`[Generic]寻敌`**（BTService_Generic_ChooseEnemy）。选中它确认：目标键 = `Target`、间隔 ≈0.3。
5. `Ctrl+S` 保存。

**验证清单（保存后由 AI 执行）**
| # | 检查项 | 判定依据 |
|---|---|---|
| 1 | 服务被编译执行 | PIE 中玩家在 30k 内时，怪物黑板 `Target` 自动被写入（无需人工注入） |
| 2 | 进入战斗 | 日志出现 `进入了状态 PawnState.Action.Battle` |
| 3 | 追击位移 | 日志 `PawnState.Movement.Walking` 出现 + 与玩家距离持续缩小 |
| 4 | 技能对玩家释放 | 日志 `释放了技能`（近战/冰球等）且伤害落在玩家身上 |
| 5 | 找回目标 | 玩家远离>追击距离后目标清除、回到待机/巡逻 |

> 判定提示：若第 1 项不通过，先检查服务是否真的挂在"无装饰器"节点上（见本节开头）；若第 1 项通过但第 3 项不通过，则按第五节把移动链对齐法师（`FindAReachablePos*` + `MoveToEx(TargetPosition)`、`MoveToEx(Target)` 的参数：键模式速度、`StopRadius=100`）。

## 十一、移动任务字段速查（编辑器里加/改节点时对照）

> 数据来自节点类反射（`schema:` 查询），配合第二节的法师实测取值一起看。

### `BTTask_Generic_MoveToEx`（"指定速度移动到"，继承 `BTTask_Generic_NavMoveTo` → **基于导航移动**）
| 字段 | 类型 | 说明 | 法师取值 / 建议 |
|---|---|---|---|
| `BlackboardKey` | FBlackboardKeySelector | 目标来源：Actor 键（如 `Target`）或向量键（如 `TargetPosition`） | `Target` / `TargetPosition` |
| `NewMaxSpeedValue` | FCustomBlackboardProperty_Float | 移动速度；**键模式(ValueType=1) = 使用默认速度**（由怪物参数提供） | `Value=-1, ValueType=1`（键模式/默认速度） |
| `StopRadius` | FCustomBlackboardProperty_Float | 距目标此半径内停止 | `100` |
| `StopRadiusIncludesAgentRadius` | FCustomBlackboardProperty_Bool | 停止半径是否含自身胶囊半径 | `true` |
| `StopRadiusIncludesGoalRadius` | FCustomBlackboardProperty_Bool | 是否含目标半径 | `false` |
| `StuckLimitTime` | FCustomBlackboardProperty_Float | 卡住超时判失败 | `3` |
| `bAlwaysSuccess` | bool | 失败也返回成功 | `false` |
| `BlockStateTags` | FGameplayTagContainer | 屏蔽状态标签 | 空 |

> ⚠️ 因为基于导航：**目标点必须落在导航网格上**，否则任务会失败（怪物原地不动）。`TargetPosition` 由 `FindAReachablePos*` 保证是"可达点"。

### `BTTask_Generic_FindAReachablePos`（"寻找可达位置"，绕中心找可达点）
| 字段 | 说明 | CCP 巡逻用法 | 法师用法 |
|---|---|---|---|
| `FindCenter` | 搜索中心（Actor 键） | `SelfActor` | `SpawnLoc`（以出生点为圆心） |
| `OutFindLoc` | 输出（向量键） | `TargetPosition` | `TargetPosition` |
| `SearchDistance_Min/Max` | 搜索半径范围 | 固定 400/900 | 键模式（读 `MinPatrolDistance`/`MaxPatrolRange` 参数） |
| `MinPatrolDistance` | 巡逻点距自身最小距离 | `300` | 键模式 |
| `MaxSearchTime` | 搜索超时(秒) | `3` | `10` |
| `IgnoreSoftClassPtrList` | 忽略的类列表 | 空 | 空 |

### `BTTask_Generic_FindAReachablePosByDirection`（"寻找指定方向上的可达位置"，绕目标找点——接近/绕后用）
| 字段 | 说明 | 法师实测 |
|---|---|---|
| `Center` | 中心（Actor 键） | `Target` |
| `Direction` | 搜索方向枚举 `EFindReachablePos_SearchDirection` | 默认（脚本读取时未显式设置） |
| `Distance` | 距离中心的距离（可为键模式） | 1500 / 1750 / 1800 / 2500 |
| `SerachRange` | 距离的容差半径 | 250 / 400 / 500 / 1000 |
| `Target` | 朝向参考（Actor 键） | `SelfActor` |
| `TargetRange` | 朝向参考的距离阈值 | `-1`（不限制） |
| `OutputLocation` | 输出（向量键） | `TargetPosition` |
| `MaxSearchTime` | 搜索超时(秒) | `10` |

### `BTTask_Generic_SidesShift`（"多方向移动"，侧移走位）
| 字段 | 说明 | 法师/CCP |
|---|---|---|
| `SideWay` | 方向枚举 `EGenericSidesShiftSideWays`（左右两侧各一个任务） | `0` / `1` |
| `RandomSide` | 随机方向 | `false` |
| `TargetKey` | 参考目标（Actor 键） | `Target` |
| `MoveSpeed` | 移动速度（键模式=默认速度） | 键模式 |
| `MoveFactor` | 移动系数 | `100` |
| `MoveStep` | 移动步数 | `2` |
| `StuckLimitTime` | 卡住超时 | `3` |

### 接近/追击的标准组合（照抄法师）
1. **直线追击**：`MoveToEx(BlackboardKey=Target, StopRadius=100)`，可加 `CheckDistance(Greater)` 门控；
2. **绕行接近**：`FindAReachablePosByDirection(Center=Target, Distance=1500~2500, SerachRange=250~1000) → MoveToEx(BlackboardKey=TargetPosition)`；
3. **回巢/巡逻**：`FindAReachablePos(FindCenter=SpawnLoc) → MoveToEx(BlackboardKey=TargetPosition)`（+ `Blackboard(TargetPosition IsSet)` 装饰器挂在移动任务上）。

---

## 十二、CCP 修复记录（2026-09-22 执行，已 PIE 验证）

> 依据第五节"对照与改法建议"，通过 UGC MCP 脚本直接修复 CCP 运行时树与怪物参数，并完成 PIE 运行期验证。

### 12.1 修复项
| # | 问题 | 修复 |
|---|---|---|
| 1 | 寻敌服务 `SvcChoose` 被 `DecHasTarget` 门控（无目标时不 Tick，死锁） | 新建 `CombatGate`(Selector) 承载 DecHasTarget；服务所在的 `[0.1]` 去除门控；巡逻分支 `Selector_4` 并入 `[0.1]` |
| 2 | 绑平台黑板 `BB_UGC_Generic_Base`，缺 `TargetPosition/bPhase2/LastCast` 等键 | 改绑 `/TTS/Asset/AI/BB_SUPER_MONSTER` |
| 3 | 键模式引用失效（含未启用的 ValueKey 残留） | `PursuitMoveSpeed→PursuitSpeed`、`PatrolMoveSpeed→PatrolSpeed`、TimeCheck_9 `→LastCast` |
| 4 | 转阶段门控 `DecNoPhase` 键错误（`SelfActor` IsNotSet 恒不通过） | 改为 `bPhase2`（IsNotSet） |
| 5 | 战斗中只放技能不接近（技能分支总成功，走位/追击永不执行） | 新增 `ApproachByDir`（`FindAReachablePosByDirection(Target)` → `MoveToEx(TargetPosition)`，距离>1200 门控）并置于技能分支之前 |
| 6 | 寻敌服务开启 EnemyDistance 策略时不生效 | `EnableEnemyDistanceStrategy=False`（对齐法师：三套策略全关） |
| 7 | 巡逻 `FindAReachablePos` 以 `SpawnLoc`（Z≈2，低于导航面）为中心找不到点 | `FindCenter` 改 `SelfActor` |
| 8 | 换黑板后怪物参数表为空（键集未迁移） | 在 SuperMonster 蓝图 `BehaviorControlComp.BehaviorTreeSetting` 补写 `PursuitSpeed=1200 / PatrolSpeed=600 / ChangeStagetHP=600000 / Skill_1~3_* / bPatrol` 等 |

### 12.2 修复后结构（要点）
```
[0] Root
├─ [0.0] 转阶段 Sequence  gates: AttrObserve(Health ≤ ChangeStagetHP 键模式) + DecNoPhase(bPhase2 IsNotSet)
└─ [0.1] Selector_10 (Svc: 寻敌)   ← 无门控（服务常驻 Tick）
   ├─ [0.1.0] CombatGate  gates: DecHasTarget
   │    ├─ Sequence_1（发送 EnterBattle + 设置 Battle 状态）
   │    ├─ ApproachByDir（接近：FindAReachablePosByDirection → MoveToEx(TargetPosition)）
   │    └─ Selector_2（技能分支 ×6）
   └─ [0.1.1] Selector_4  gates: DecNoTarget
        ├─ Sequence_7（发送 ExitBattle + 清除 Battle）
        └─ Sequence_8（巡逻：FindAReachablePos(SelfActor) → MoveToEx(TargetPosition) → Wait）
```

### 12.3 PIE 验收结果（2026-09-22 16:29–16:57，DebugID `_dkfffplhhwy8w8` / `_dkfffplhhwyrpk`）
- 自动索敌 ✓（黑板 `Target` 被服务自动写入，无需人工注入）
- 进入战斗 ✓（`PawnState.Action.Battle`）
- 追击位移 ✓（与玩家距离 1500 → 482）
- 技能释放 ✓（魔术粘弹 / 充能射线 / BossPassive 系列）
- 脱战与巡逻 ✓（`ExitBattle` 后 `PawnState.Movement.Walking` 持续切换，`TargetPosition` 每轮刷新）

### 12.4 遗留与备份
- `UGCBehaviorTreeGraph`（BT 编辑器图）由脚本编辑的运行时树未完全同步；运行时（PIE/游戏）以运行时树为准，已验证正常。打开 BT 编辑器时如发现图与本文档结构不一致，请勿直接保存覆盖，或重新整理图后保存。
- 备份：`Docs/_backup/CCP.uasset.20260922.bak`、`SuperMonster.uasset.20260922.bak`、`BB_SUPER_MONSTER.uasset.20260922.bak`。



