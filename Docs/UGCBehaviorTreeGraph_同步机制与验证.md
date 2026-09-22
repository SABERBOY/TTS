# UGCBehaviorTreeGraph 行为树图/树同步机制与验证报告

> 适用项目：TTS（ShadowTrackerExtra / UE4.18 UGC）
> 编写时间：2026-09-22
> 验证对象：`/TTS/Asset/AI/CCP`（超级怪行为树，42 个图节点 / 43 个运行时复合与任务节点）
> 验证手段：UGC MCP（`ue_read` / `ue_py` / `ue_pie` 只读与事务化写操作）

---

## 一、整体架构与设计思路

### 1.1 双表示模型

UGC 行为树资产（`UBehaviorTree`）在编辑器内同时存在两份表示：

| 表示 | 载体 | 用途 | 权威性 |
|---|---|---|---|
| **编辑器图（Graph）** | `UBehaviorTree.BTGraph`（`UGCBehaviorTreeGraph`，编辑器内置 C++ 类） | BT 编辑器中的可视化编辑（节点框、连线、装饰器/服务挂件、位置） | `bt_*` 编辑接口与编辑器保存操作以**图**为准 |
| **运行时树（Runtime Tree）** | `UBehaviorTree.RootNode` → `UBTCompositeNode.Children` → `FBTCompositeChild{ChildComposite/ChildTask/Decorators}` | PIE / 打包后游戏**实际执行**的数据 | 运行时执行以**树**为准 |

> `UGCBehaviorTreeGraph` 属于编辑器插件（无项目源码、Python 反射层未暴露同步函数），因此无法"改造/替换"其同步实现，只能**按既有机制正确使用**。

### 1.2 同步方向（实测结论）

| 触发动作 | 同步方向 | 实测证据 |
|---|---|---|
| Python 直接修改运行时树 + `save_package()` | **无覆盖**（树保持） | 结构修改后保存，再次读取结构不变（见 §5-T3） |
| `ue.bt_remove_node(...)` | **图 → 树（整体重写）** | 删除测试节点后，运行时树被重写为图中的旧结构（CombatGate/接近分支丢失）（见 §5-T4） |
| `ue.bt_add_node(...)` | 仅改图（树暂不变） | 图节点 41→42，运行时树 `Children` 未变 |
| `ue.editor_save_all()`（资产不脏时） | 无操作 | 保存前后树/图完全一致 |
| 打开 BT 编辑器（推断） | 树 → 图（按树重建视图） | 图节点 `NodeInstance` 与运行时节点一一对应；图节点数组为树的先序序列 |

### 1.3 设计结论（工程指引）

1. **运行时行为**只取决于**运行时树**；脚本改树 + `save_package()` 可安全持久化。
2. **不要**用 `bt_remove_node` / `bt_link` 等图编辑接口去"顺手改树"——它们会以**图**为源重写运行时树，把脚本改动回退。
3. 需要"图与树严格一致"时，**优先在 BT 编辑器 UI 内完成结构修改**（图与树天然同步）；纯脚本路径只能保证运行时树。
4. 结构改动前后务必**备份资产**（见 §6.3）。

---

## 二、核心数据结构与接口

### 2.1 编辑器图（`UGCBehaviorTreeGraph`）

关键属性（实测可读）：

| 属性 | 类型 | 说明 |
|---|---|---|
| `Nodes` | `TArray<UEdGraphNode*>` | 图节点数组，顺序 ≈ 运行时树的**先序遍历** |
| `ModCounter` | int | 修改计数器（实测 14，随编辑递增） |
| `bIsUsingModCounter` | bool | 是否启用修改计数（实测 True） |
| `GraphVersion` | int | 图版本号（实测 2） |

图节点（`UGCBehaviorTreeGraphNode_Root / _Composite / _Task / _Decorator / _Service`）关键属性：

| 属性 | 说明 |
|---|---|
| `NodeInstance` | **指向对应的运行时节点对象**（`UBTCompositeNode` / `UBTTaskNode` / `UBTDecorator` / `UBTService`）；`Root` 节点为 `None` |
| `SubNodes` | 挂在当前节点上的**装饰器/服务图节点**（如 `UGCBehaviorTreeGraphNode_Service_9`） |
| `ParentNode` | 图内父节点引用；**实测全部为 `None`**（连接信息不由此字段承载） |
| `NodePosX / NodePosY` | 编辑器坐标 |
| `bIsSubNode / bInjectedNode / ClassData` | 子节点标记 / 注入标记 / 类型数据 |

> 注意：图节点**没有标准 `UEdGraphNode.Pins`**（仅保留 `DeprecatedPins`），因此不能按 UE 原生方式读连线；图连接通过 UGC 内部模型维护。

### 2.2 运行时树

```
UBehaviorTree
├─ BlackboardAsset : UBlackboardData           // 黑板绑定（资产级属性，脚本改动可持久）
├─ RootNode        : UBTCompositeNode          // 根（本例 BTComposite_Selector_9）
└─ （节点递归）
     UBTCompositeNode
     ├─ Children : TArray<FBTCompositeChild>
     │    FBTCompositeChild
     │    ├─ ChildComposite : UBTCompositeNode*   // 子复合节点
     │    ├─ ChildTask      : UBTTaskNode*        // 子任务节点（与上者互斥）
     │    ├─ Decorators     : TArray<UBTDecorator*>  // 该"边"上的门控装饰器
     │    └─ DecoratorOps   : TArray<FBTDecoratorLogic> // 实测全为空（运行时按"所有装饰器 AND"处理）
     └─ Services : TArray<UBTService*>            // 节点自身的服务（服务只在节点被进入时 Tick）
```

**服务 Tick 语义（关键）**：服务挂在不带门控的节点/分支上才会持续运行；若挂在"被 Target 门控"的分支，则在无目标时完全不 Tick（死锁）。CCP 的寻敌服务修复即基于此（详见 `BT_BOSS_Mage_结构文档.md` 第十二节）。

### 2.3 MCP 行为树接口（`ue.bt_*`）

| 接口 | 作用域 | 命名方式 | 备注 |
|---|---|---|---|
| `bt_query(bt)` | 只读 | — | 输出**图**的语义树（标题、装饰器/服务、孤立节点清单），是本机制下最可靠的"图现状"视图 |
| `bt_add_node(bt, class, title, parent_title, index)` | 图 | **Title（显示名）** | 新增节点进入"孤立节点"区，`parent_title` 实测未建立连接 |
| `bt_remove_node(bt, title)` | 图 + **树** | Title | ⚠️ 会触发"图 → 树"整体重写 |
| `bt_link / bt_unlink / bt_reorder` | 图 | Title（用运行时内部名会报 "not found"） | 未进一步验证其副作用 |
| `bt_modify_node` | 节点属性 | Title | 已弃用，建议直接用 Python 属性赋值 |

---

## 三、同步工作流程

### 3.1 脚本编辑运行时树（推荐路径，已用于 CCP 修复）

```
① 备份资产（文件级）
② bt.modify()
③ 结构/属性修改：
     - 简单属性：node.Property = value / vec.ValueKey.SelectedKeyName = 'xxx'
     - 结构：用 clone() 产生独立 FBTCompositeChild 值 → node.set_property('Children', [...])
④ bt.post_edit_change()
⑤ bt.save_package()          // 落盘；PIE 需重启才生效
⑥ 复核：dump 结构 + 键引用（见 §5 用例）
```

### 3.2 图编辑路径（bt API）

```
① bt_query(bt) 读取图的语义结构（标题 / 装饰器服务 / 孤立节点）
② bt_add_node(...) 新增节点（进入"孤立节点"）
③ 连接/迁移（bt_link / bt_unlink，使用 Title）
④ 任何写操作都可能触发"图 → 树"重写 → 必须复核运行时树
```

### 3.3 编辑器 UI 路径（图与树同时更新的唯一可靠方式）

```
打开 BT 编辑器 → 拖拉节点/装饰器/服务 → Ctrl+S
（该路径下编辑的既是图，也通过编辑器同步写入运行时树）
```

---

## 四、关键实现细节（实测坑位）

1. **数组写回必须使用 `clone()` 副本**
   `root.Children` 在 Python 侧返回的是 **list 快照**，其中的 `FBTCompositeChild` 元素带有指向数组内存的临时代理。若直接把"未克隆的元素 + 新元素"整体 `set_property('Children', ...)`，原元素的 `ChildComposite` 会**变成 None**（实测损坏）。
   ✅ 正确写法：`vals = [c.clone() for c in list(node.Children)]` 后再增删/替换，最后写入。

2. **复合节点写 `ChildComposite`，任务节点写 `ChildTask`**
   对任务节点设置 `set_field('ChildComposite', task)` 会抛 `unable to set property ChildComposite`；应改设 `ChildTask`，同一槽位的另一字段置 `None`。

3. **`bt_remove_node` 会以图重写运行时树（高危）**
   实测：删除一个测试节点后，运行时树被重写为图中保存的旧结构，脚本修复成果被回退（磁盘未被污染，需 `unload_package` + 重新加载或重放修复）。
   ⚠️ 结论：**脚本改树期间禁止调用 bt 写接口**。

4. **`save_package()` 不会重写树**
   实验：脚本移动 `Selector_4` → `save_package()` → 结构保持。故"脚本 + 保存"是可持续的编辑路径。

5. **"图 → 树"重写会复用节点对象**
   回退实验中，装饰器/任务对象（如 `BTDecorator_Blackboard_17`）及其**属性配置全部保留**（键引用、枚举、FlowAbortMode 等），**仅树形连接被重置**。因此重建的代价主要是"结构复现"。

6. **资产脏状态与卸载**
   `ue.unload_package(pkg)` 需要传入 **UPackage**（`asset.get_outer()`），并且资产**不能处于已修改状态**，否则报："以下资产已经被修改并且无法卸载…保存这些资产即可将它们卸载"。

7. **命名体系**
   运行时对象名（如 `BTComposite_Selector_10`）与图/bt API 的 **Title**（如 `CombatSel`）是两套体系；`bt_link` 等接口只认 Title。

8. **图节点无 Pins**
   不能用 `UEdGraphNode.Pins/LinkedTo` 读取或修改连接；读图现状用 `bt_query`。

---

## 五、测试用例与验证结果

| # | 用例 | 步骤 | 预期 | 实测结果 |
|---|---|---|---|---|
| T1 | 保存后加载一致性 | `save_package()` → `unload_package(pkg)` → 重新 `load_object` | 结构/黑板绑定一致 | ✅ root=[Sequence_0, Selector_10]，sel10=[CombatGate, Selector_4]，gate=[Sequence_1, ApproachByDir, Selector_2]，黑板=BB_SUPER_MONSTER |
| T2 | 边界：空 children 节点 | 新建空 `Sequence` 挂到 sel10 末尾 → 保存 → 卸载/重载 → 删除 → 保存 | 空节点持久化且不崩溃 | ✅ 重载后 `EdgeEmptySeq` 存在；删除后 sel10 恢复 `[CombatGate, Selector_4]` |
| T3 | 图/树不一致时保存 | 脚本移动节点 → `save_package()` | 保存不以图覆盖树 | ✅ 结构保持不变 |
| T4 | 异常：bt 写操作 | `bt_remove_node(测试节点)` | 观察副作用 | ⚠️ 树被重写回图结构（作为**已知限制**记录） |
| T5 | 异常：孤立图节点 | `bt_query` + 结构比对 | 不影响运行 | ✅ 图中存在 2 个孤立节点（`Root`、`CombatGate`），运行时无异常 |
| T6 | 运行时回归（PIE） | 生成 SuperMonster（玩家附近 1.5k）→ 观察黑板与日志 | 战斗链路可用 | ✅ 注入目标后：释放主动技能（魔术粘弹/充能射线）、`PawnState.Action.Battle`、坐标持续接近、`Movement.Walking`；⚠️ 平台寻敌服务的**自动索敌存在时序不确定性**（见 §6.1） |
| T7 | 键引用完整性 | 深度扫描全树 `SelectedKeyName`/`ValueKey` | 无缺失键 | ✅ 118 处引用，0 缺失（黑板 `BB_SUPER_MONSTER`） |

---

## 六、已知限制与后续优化建议

### 6.1 已确认限制

| # | 限制 | 影响 | 现状/规避 |
|---|---|---|---|
| L1 | 脚本改树**不会**更新编辑器图 | 打开 BT 编辑器看到的仍是旧结构；若在编辑器内保存，可能把旧图同步回树 | 运行时行为不受影响（已验证）；结构改动优先在编辑器 UI 完成，或在脚本改动后手工对齐图 |
| L2 | `bt_*` 接口无"装饰器/服务"操作能力 | 无法脚本化迁移门控/服务（如把 `DecHasTarget` 挪到新容器） | 装饰器迁移需在编辑器 UI 完成 |
| L3 | `bt_remove_node` 触发图→树重写 | 误用会回退脚本修复 | 脚本编辑期间禁用 bt 写接口；保留文件级备份 |
| L4 | 图节点无 Pins、`ParentNode` 为 None | 无法用标准 UEdGraph API 读写连线 | 用 `bt_query` 读图语义结构 |
| L5 | 平台寻敌服务（`BTService_Generic_ChooseEnemy`）自动索敌存在时序不确定性 | 冷启动可能数十秒不锁定目标 | 核心链路（战斗/接近/技能/巡逻）在目标确定后全部正常；如需稳定索敌可评估"入口处周期性写入 Target"的补偿逻辑 |

### 6.2 优化建议

1. **回归检查脚本化**：把 §5 的 T1/T7 做成常驻检查（结构 hash + 键引用扫描），每次改树后执行。
2. **结构改动优先 UI 化**：涉及"容器/门控/服务迁移"的改动，在 BT 编辑器内完成并保存，天然保持图树一致。
3. **脚本改树后的图对齐清单**（人工，约 5 分钟）：
   - 打开 BT 编辑器 → 对照 `BT_BOSS_Mage_结构文档.md` 第十二节的目标结构；
   - 若图与树不一致：按目标结构拖拽节点/装饰器 → 保存；
   - 保存后**立即**用 T1 用例复核运行时树未被回退。
4. **寻敌增强（可选）**：在 [0.1] 分支入口增加"周期写入 `Target`"的补偿（服务或 Lua 侧），降低对平台索敌时序的依赖。
5. **备份策略固化**：每次结构改动前复制 `Asset/AI/*.uasset` 到 `Docs/_backup/`（本次已包含 `CCP / SuperMonster / BB_SUPER_MONSTER` 三个资产）。

### 6.3 本次交付的备份文件

| 文件 | 说明 |
|---|---|
| `Docs/_backup/CCP.uasset.20260922.bak` | 修复前原始 CCP（12:17） |
| `Docs/_backup/CCP.uasset.fixed-20260922.bak` | **修复后已验证版本**（16:49） |
| `Docs/_backup/SuperMonster.uasset.20260922.bak` | 换黑板前的怪物蓝图（15:00） |
| `Docs/_backup/BB_SUPER_MONSTER.uasset.20260922.bak` | 目标黑板原始版本 |

---

## 附录 A：常用操作速查

```python
# 读取图现状（最可靠的图视图）
print(ue.bt_query(bt))

# 读取运行时树结构 / 键引用
walk(bt.RootNode)            # 见 §5 用例脚本

# 安全的结构修改（重写 Children）
vals = [c.clone() for c in list(node.Children)]
# … 增删改 vals …
node.set_property('Children', vals)

# 保存与重载
bt.modify(); bt.post_edit_change(); bt.save_package()
pkg = bt.get_outer(); ue.unload_package(pkg); bt2 = ue.load_object(BehaviorTree, '/TTS/Asset/AI/CCP')
```

## 附录 B：术语表

| 术语 | 含义 |
|---|---|
| 图 / Graph | BTGraph（编辑器可视化表示），由 bt API 与编辑器 UI 维护 |
| 树 / Runtime Tree | `RootNode.Children` 递归结构，PIE/游戏实际执行 |
| 门控 / Gate | 挂在 `FBTCompositeChild.Decorators` 的装饰器（控制分支是否可进入） |
| 服务 / Service | 挂在节点 `Services` 上、随节点被进入而周期执行的组件 |
| 图→树重写 | 以图为源重新生成运行时树的同步动作 |
