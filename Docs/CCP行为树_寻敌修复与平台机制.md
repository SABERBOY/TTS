# CCP 行为树寻敌失效排查与 UGC 平台怪物机制

> 记录日期：2026-09-23
> 涉及会话：CCP 行为树修复（restructure-tree → 寻敌服务挂载 → 平台机制定位）
> 相关文档：`Docs/BT_BOSS_Mage_结构文档.md`、`Docs/UGCBehaviorTreeGraph_同步机制与验证.md`

---

## 一、问题现象

| 对象 | 绑定树 | 表现 |
|---|---|---|
| `SuperMonster.SuperMonster_C` | `/TTS/Asset/AI/CCP`（后期换成 `CCPS` 对照） | **完全不动**：不索敌（`Target` 恒为空）、不移动、不放主动技能 |
| `MagicMonster.MagicMonster_C` | `/TTS/Asset/AI/BT/BT_BOSS_Mage` | 正常：自动索敌、追击走动、按槽放技能 |
| `RangedTank`（基座 `BP_UGCMobSpawner10` 生成） | 未绑定（`BehaviorTreePath = None`） | 正常：自动寻敌走动 |

**关键对照**：同一 PIE 场景、同一时刻，法师怪与基座怪都正常，只有绑 CCP 的超级怪完全不动。

---

## 二、根本原因（三个独立问题叠加）

### 2.1 【主因】寻敌服务被 Target 门控 → 冷启动死锁

`[Generic]寻敌`（`BTService_Generic_ChooseEnemy`）原本挂在 `CombatSel`（`[1]` 槽）上，而该槽的进入门控是 `DecHasTarget`（`Target` IsSet）：

```
Target 为空 → DecHasTarget 失败 → [1] 分支不进入 → 服务不 Tick → Target 永远为空   ✗ 死锁
```

**UE 服务 Tick 语义**：服务只在其宿主节点被进入/执行时才会 Tick。

**法师树为什么正常**：它把服务挂在**无装饰器的 `[0.1] Selector`** 上，"Target 已设置"门控放在**内层 Sequence** 里 → 服务常驻 Tick → 能发现玩家。

**实测证据**：
- 修复前：`Target=nil`，且 `[2]` 巡逻分支在执行（`TargetPosition` 被 `FindAReachablePos` 持续刷新）→ 证明树在跑、但 `[1]` 战斗分支从未进入
- 修复后（服务移到无门控节点）：**`Target=SET`**（服务自动写入）

### 2.2 【次因】平台参数值为 0（换黑板导致）

怪物平台参数（`PursuitRadius` / `AttackDistance` / `PatrolMinRange` 等平台标准键）**只在"同名黑板键"上迁移**。把怪物黑板从 `BB_UGC_Generic_Base` 换成 `BB_SUPER_MONSTER` 后：

| 键 | 是否有值 | 说明 |
|---|---|---|
| `PatrolSpeed=600`、`PursuitSpeed=1200`、`MinPatrolDistance=300`、`MaxPatrolRange=3000` | ✓ 有值 | 新黑板里**本来就存在**的同名键，值保留 |
| **`PursuitRadius=0`、`AttackDistance=0`、`PatrolMinRange=0`** | ✗ **为 0** | 新黑板里**原本不存在**的键，值丢失 |

**注意**：`ue.bb_add_key` 只能补"键"，**无法补"值"**（黑板键没有默认值字段，`bb_query` 只返回 Name/Type/IsInstanceSynced/IsInherited）。**值必须在实体编辑器的"行为树属性配置"面板中写入**。

**平台参数语义**（文档 §八.3）：
- `PursuitRadius`：追击距离，**距离大于该值则持续追击**（优先级高于攻击距离）→ 设为 5000 时，2500 距离的怪不会主动追击（属正常行为）
- `AttackDistance`：进入攻击的距离
- `bAssailant`（可攻击）：不开则不追击也不攻击
- `bPatrol`（巡逻）：不开则永远待机

### 2.3 【观测噪声】脚本生成方式不完整初始化

`UGCGenericCharacterSystem.SpawnGenericCharacter(Pawn, Class, Loc, Rot)` 生成的怪物：

| 观测项 | 实测 |
|---|---|
| 树是否执行 | ✓ 执行（`TargetPosition` 被 `FindAReachablePos` 持续刷新） |
| AI 是否接管 | ✓ `ctrl=AI` |
| 是否索敌 | ✓ `Target=SET`（服务修复后） |
| **是否产生位移** | ✗ **`vel=0,0,0`，长时间位置不变** |

对照：**基座生成的怪 `vel=411,245`（正在巡逻走动）**。

**结论**：`SpawnGenericCharacter` 只是"把怪物 Actor 放进世界"，**缺少平台完整生成流程的初始化（导航代理/移动链路）**，树能跑但 `MoveToEx`（基于导航）推不动它。

**项目内佐证**（`Script/Blueprint/UGCPlayerController.lua`）：

```218:262:Script/Blueprint/UGCPlayerController.lua
function UGCPlayerController:ServerRPC_GMSummonMonster()
    ...
    -- 优先把场景里已有的 SuperMonster 传送到玩家脚下；没有则直接在玩家位置生成一只
    Monster:K2_SetActorLocation(SpawnLoc)
    ...
    Monster = UGCGenericCharacterSystem.SpawnGenericCharacter(PlayerPawn, MonsterClass, SpawnLoc, Rotation)
    ...
    BB:SetValueAsObject('Target', PlayerPawn)   -- 并直接写 Target
```

即 GM 召唤之所以"看起来能用"，是因为它**优先传送场景里已有的怪**（那些是基座生成的、初始化完整）；只有"没有怪"时才走不完整的生成路径。

> **重要**：此前用 `SpawnGenericCharacter` 生成怪得到的"不动""Target 时有时无"等观测**全部不可信**，属生成方式引入的噪声。

---

## 三、修复步骤（均在编辑器 UI 内完成）

> **前提认知**：脚本改树（`bt_add_node` / 直接改运行时树 + `save_package`）**不会被编译执行**，只有"在 BT 编辑器内编辑并 Ctrl+S"的运行时树才会被编译（详见 `Docs/UGCBehaviorTreeGraph_同步机制与验证.md` §九）。

### 3.1 BT 编辑器：调整寻敌服务挂载（决定性问题）

1. 打开 `/TTS/Asset/AI/CCP`（行为树编辑器）
2. **右键 `CombatRoot`（无装饰器的 Selector）→ 添加服务 → `[Generic]寻敌`**
3. 选中该服务，确认：**目标键 = `Target`**、**间隔 ≈ 0.3**（对齐法师）
4. 选中 `CombatSel`，**删除其上的原服务** `SvcChoose`（避免重复）
5. **Ctrl+S 保存**

修复后的结构（图与运行时树一致）：

```
[Root] 根 → CombatRoot (Selector)  <Svc:SvcChoose([Generic]寻敌)>   ← 服务在无门控节点
  ├─ StageSeq   <DecHP, DecNoPhase>
  ├─ CombatSel  <DecHasTarget>          ← 门控保留在内层
  │    ├─ BattleSeq（进战斗）
  │    └─ TacticSel（技能/走位/追击分支）
  └─ PatrolSel  <DecNoTarget>（巡逻）
```

### 3.2 实体编辑器：补齐平台参数值

打开 `SuperMonster` 的**实体编辑器** → **"行为树属性配置"面板**：

| 参数 | 建议值 |
|---|---|
| `PursuitRadius`（追击距离） | 5000（如需主动贴脸可调 1500~2000） |
| `AttackDistance`（攻击距离） | 500 |
| `PatrolMinRange`（最小巡逻距离） | 500 |
| 核对项 | `PursuitMoveSpeed=1200`、`PatrolMoveSpeed=600`、`PatrolRange_Min/Max=500/3000`、`AttackIntervalMin/Max=2.5/1.5` |

---

## 四、验证结果（PIE 实测）

| 验证项 | 结果 | 证据 |
|---|---|---|
| **自动索敌** | ✓ | 黑板 `Target=SET`（服务自动写入，无需人工注入） |
| **进入战斗** | ✓ | `PawnState.Action.Battle` |
| **移动** | ✓ | `PawnState.Movement.Walking` 与 `Idle` 交替 |
| **转向** | ✓ | `PawnState.Action.Turning` |
| **技能释放** | ✓ | `BossPassiveSkill_FireBall`、伤害光环 |
| **参数生效** | ✓ | `PursuitRadius=5000`、`AttackDistance=500` |

**遗留可选项**：
1. `PursuitRadius=5000` 时 2500 外的怪不会主动追击（符合"距离大于该值才追击"的语义），要贴脸可调到 1500~2000
2. 超级怪目前只装备**被动技能**（`BossPassiveSkill_FireBall`/伤害光环），树里的 `CastMelee`/`CastIce` 等主动技能分支实际无技可放；需要真实攻击表现应补 `Skill.Slot.Main` 主动技能

---

## 五、UGC 平台怪物机制（重要参考）

1. **`BehaviorTreePath = None` → 走平台默认行为树**（`BT_UGC_GenericMob_MainTree`，含寻敌/巡逻/追击/攻击全套）。基座生成、蓝图默认配置的怪属此类，**它们能自动寻敌不能作为"自定义树可用"的证据**。

2. **绑自定义树 = 平台那套行为被整体替换**，之后**寻敌与移动必须由该自定义树自己实现**（法师树正是自己实现了 `[Generic]寻敌` 服务 + `FindAReachablePos*` + `MoveToEx`）。

3. **`[Generic]寻敌` 服务必须挂在"无装饰器节点"上**：挂在带 `DecHasTarget` 门控的节点上会死锁（本问题主因）。

4. **平台逻辑部件链**（与树无关的底层感知/索敌设施）：
   `LogicPartManagerComp` → `LogicPartConfigs[0]` = `ChooseEnemyPart_0` → `TargetProducers` =
   `[BP_UGCTargetProducer_EnemyHatred_C, TargetProducer_AllyForHelp]`（两键均为平台蓝图实现类；曾把超级怪的 `[0]` 从 C++ 基类 `UGCTargetProducer_EnemyHatred` 替换为 BP 子类并配置 `MaxSenseRadius=1000`/`MaxViewRadius=4000`）。

5. **`bAssailant` / `bPatrol` 属"自定义树参数体系"**：平台默认树的寻敌**不依赖**它们（实测 `RangedTank` 的 `bAssailant=false` 仍能寻敌）。

6. **怪物参数 ↔ 黑板键的迁移规则**：换绑树 → 按新树黑板重建 `BehaviorTreeSetting.BTReflectProp_Int/_Float/_Bool/_String` 四张表；键名列表会更新、**同名键的值保留**、新键值为默认（0/false）。

---

## 六、排查弯路与教训（避免重复）

| # | 弯路 | 教训 |
|---|---|---|
| 1 | 曾判断"服务被门控=死锁"，又因 CCPS 对照被推翻，最终**再次证实成立** | 对照必须验证"对照样本本身是否可用"（CCPS 同样是门控结构，实测它也不寻敌） |
| 2 | 以为脚本改树 + `save_package()` 能生效 | 脚本改树不会被编译执行；结构改动必须在 BT 编辑器 UI 完成并 Ctrl+S |
| 3 | 用 `SpawnGenericCharacter` 生成的怪做行为观测 | 该方式生成的怪未完整初始化（`vel=0` 不动），观测不可信；应用基座或传送已有怪 |
| 4 | 期望"换黑板只影响树" | 换黑板会连带丢失平台参数值，必须在实体面板补齐 |
| 5 | 在 PIE 运行中做 `all_objects()` / CDO 全属性遍历 | 会导致编辑器无响应甚至崩溃（详见记忆 `feedback_mcp_heavy_query.md`） |

---

## 七、涉及资产与备份

**资产清单**：
| 资产 | 路径 | 说明 |
|---|---|---|
| CCP | `/TTS/Asset/AI/CCP` | 本次修复树（服务已移至 `CombatRoot`） |
| CCPS | `/TTS/Asset/AI/CCPS` | 修改前备份（结构同原 CCP，未含服务位置修正） |
| BT_BOSS_Mage | `/TTS/Asset/AI/BT/BT_BOSS_Mage` | 法师树（可工作参照） |
| BB_SUPER_MONSTER | `/TTS/Asset/AI/BB_SUPER_MONSTER` | 超级怪黑板（已补齐 28 个平台标准键，共 67 键） |
| SuperMonster | `/TTS/Asset/Blueprint/Prefabs/Monsters/SuperMonster` | 怪物（`BehaviorTreePath` 指向 CCP） |

**备份**（`Docs/_backup/`）：
```
BB_SUPER_MONSTER.uasset.20260922.bak
CCP.uasset.20260922.bak
CCP.uasset.fixed-20260922.bak
CCP.uasset.pre-restructure-20260922.bak
SuperMonster.uasset.20260922.bak
SuperMonster.uasset.pre-targetproducer-20260922.bak
SuperMonster.uasset.pre-producer-swap-20260922.bak
```

---

## 八、结论

**"CCP 行为树无法生效"已解决**，由三个独立问题叠加造成：

1. **寻敌服务挂在带 `DecHasTarget` 门控的节点上 → 冷启动死锁**（主因，编辑器内把服务移到无门控的 `CombatRoot` 修复）
2. **换黑板导致平台参数值为 0**（实体面板补齐 `PursuitRadius`/`AttackDistance`/`PatrolMinRange`）
3. **`SpawnGenericCharacter` 生成的怪不完整初始化**（仅影响测试观测；正式用法应使用基座生成）

修复后 PIE 实测：**自动索敌 → 进战斗 → 移动 → 转向 → 技能释放全链路通过**。
