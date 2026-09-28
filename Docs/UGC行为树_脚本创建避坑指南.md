# UGC 行为树脚本创建避坑指南（BT_Boss 打开崩溃事件复盘）

> 状态：已解决（2026-09-23 16:08 修复落盘，用户确认可正常打开）
> 适用对象：任何用 MCP/Python 脚本创建或修改 UGC 行为树（BehaviorTree）资产的工作
> 事故资产：`/TTS/Asset/AI/BT/BT_Boss`（Boss AI 25 节点骨架）
> 备份：`Docs/_backup/BT_Boss.uasset.crash-20260923.bak`（崩溃前版本，可回滚对比）

---

## 0. 结论速览：五条铁律

| # | 铁律 | 违反后果 |
|---|---|---|
| 1 | **禁止用 `ue.new_object` 手工创建树根节点**（如 `BTComposite_Selector` + `set_property('RootNode', ...)`） | 打开资产必崩（树根无对应图节点） |
| 2 | **图根（Root 图节点）下必须且只能连接唯一一个 Composite 图节点**（=树根） | 打开资产必崩（编辑器"确定树根"失败，走创建图根路径→空指针） |
| 3 | **树的连通性必须≈图实例数**（`tree_reachable == graph_instances`，正常树 39/39） | 打开崩溃 / 编辑器同步异常 |
| 4 | **禁止跨资产 clone `FBTCompositeChild` 结构体且不清 `Decorators`** | 保存时 `appError` FATAL 崩溃（Graph is linked to external private object） |
| 5 | **每次 save 前必须做 4 项校验**（见 §6） | 保存失败崩溃或留下无法打开的资产 |

---

## 1. 现象与快速识别

### 1.1 打开资产即崩（本次主症状）
崩溃日志（`Saved/Crashes/<id>/ShadowTrackerExtra.log`）末尾固定形态：

```
LogUGC: Error: FUGCObjectAssetManager::GetAssetType:/TTS/Asset/AI/BT/BT_Boss
LogUObjectGlobals: Warning: 寻找对象"Blueprint 无.UGCBehaviorTreeGraphNode_Root"失败
LogUObjectGlobals: Warning: 寻找对象"Blueprint 无.UGCBehaviorTreeGraphNode_Root"失败
（随后崩溃，无更多日志）
```

特征：**`Blueprint 无.UGCBehaviorTreeGraphNode_Root` 查找失败**（"Blueprint 无"= 以空 Blueprint 为 Outer 解析图节点类）。
- 注意：单独的 `GetAssetType` 报错**不是**充分条件（`BT_BOSS_Mage`/`BT_BOSS_Trans` 也偶发，但能正常打开）。
- 注意：`missing NodeGuid` 警告**不是**崩溃原因（`BT_SUPER_MONSTER` 累计 60 次仍正常打开；执行过一次编辑器保存后该警告消失）。

### 1.2 保存时 FATAL 崩溃
```
LogWindows: Error: appError called: Can't save .../XXX.uasset: 
Graph is linked to external private object <某装饰器> /其他资产路径 (Decorators)
```
含义：本次保存的图/树引用了**其他资产的私有对象** → 引擎拒绝保存 → fatal。

### 1.3 minidump 判据（无调试器也能取）
本次崩溃：`ExceptionCode=0xC0000005`（ACCESS_VIOLATION，读）、`ExceptionInformation[0]=0`（读）、`[1]=0x68`（访问地址 = 空指针+偏移 0x68）、崩溃模块 `ShadowTrackerExtraUGCEditor.exe`；四次"打开崩溃"的 **ExceptionAddress 完全相同**（同一指令）→ 同一崩溃点。

---

## 2. 排查时间线与证据链（可复用的排查顺序）

1. **先取崩溃日志末尾**（`Saved/Crashes/<最新id>/ShadowTrackerExtra.log`）→ 定位"崩溃前最后 3~5 行"。
2. **解析 minidump**（§7）→ 确认崩溃模块、异常类型、是否空指针。
3. **建立正常树基线**（关键步骤！）：对"能正常打开的树"（如 `BT_BOSS_Mage`、`BT_SUPER_MONSTER`、`CCP`）读取同样指标，排除"常态噪音"：
   - `missing NodeGuid` 警告 → 常态（脚本建树都有）
   - `GetAssetType` 报错 → 常态（个别正常树也有）
   - 根图节点 `BlackboardAsset` ≠ 资产黑板 → 常态（CCP/CCPS 皆如此）
   - 根图节点 `NodeInstance=None` → 常态（所有树都如此）
   - 图节点 `ParentNode` 读不出 → Python 绑定限制，非差异
4. **列出事故资产的独有差异**，逐个用脚本修复并**由用户打开验证**：
   - 树根无图节点 → 修（RootNode 切到有图节点的实例）→ **仍崩**
   - `BTGraph.ModCounter=0`（唯一为 0 的资产）→ 设 1 → **仍崩**
   - 树游离（tree_reachable=1/24，正常树全连通）→ 重组树至 24/24 → **仍崩**
   - **图根下直连 6 个节点（4 Task + 2 Composite），而正常树图根下只有唯一 Composite** → 修复 → **打开成功** ✅

---

## 3. 根因（三条独立缺陷）

### 3.0 【最严重】脚本创建的图节点在 DS/PIE 上加载失败（2026-09-23 实证）
**现象**：编辑器里一切正常（能打开、`bt_query` 结构完整、脚本校验全过），但 PIE 里行为树**完全不运行**（任务/服务 Lua 探针无任何输出、黑板未初始化）。

**实证（DS 日志）**：
```
LogStreaming: Error: Missing Dependency, request for /Script/UGCBehaviorTreeEditor.UGCBehaviorTreeGraphNode_Task but it hasn't been created yet.
LogStreaming: Error: Could not find class UGCBehaviorTreeGraphNode_Task to create UGCBehaviorTreeGraphNode_Task_8
```
统计：`Could not find class UGCBehaviorTreeGraphNode_*` 共 **44 次，全部来自 BT_Boss**（Task 19 / Decorator 17 / Composite 5 / Root 1 / Service 1 / Graph 1）——即该资产的**每一个图节点**都是脚本创建的；对照的正常树（BT_BOSS_Mage / BT_SUPER_MONSTER / CCP）**0 次**。

**机理**：DS 进程不含 `UGCBehaviorTreeEditor` 模块。编辑器原生创建的图节点在保存时被归入“编辑器专用数据”，DS 加载时整体跳过；而**脚本（`bt_add_node` / `ue.new_object`）创建的图节点未被归入该部分**，DS 会尝试实例化它们 → 类不存在 → 导出失败 → **资产加载不完整 → 行为树不启动**。

**推论（必须遵守）**：
- **行为树的“结构节点 + 装饰器 + 服务”必须在 BT 编辑器 UI 内创建**（拖拽/右键添加），脚本创建的图节点在 PIE 上不可用；
- **脚本可用于**：读取/校验、修改**属性值**（如服务策略开关、任务参数）、以及（在编辑器创建之后）微调参数；
- 编辑器“打开并 Ctrl+S”**不能**修复脚本创建的图节点。

### 3.1 打开崩溃根因：图根下多节点
- 编辑器打开行为树资产时，需要"由图确定树根"。
- 正常形态：`图根 → 唯一 Composite 图节点（= 树根）→ ...`
- BT_Boss 的错误形态：`图根 → [BossDeathTask(Task), BossReturnHomeTask(Task), BossHardStaggerTask(Task), BossPhaseTransitionTask(Task), Combat(Composite), Idle(Composite)]`（6 个并列，第一个还是 Task）
- 编辑器处理该非法形态时进入"创建/修复图根节点"路径 → 尝试解析 `UGCBehaviorTreeGraphNode_Root` 类 → UGC 行为树资产不是 Blueprint（`Cast<UBlueprint>(Graph->GetOuter())` 必为 null）→ 类解析返回 null → 调用方未判空，访问其成员（偏移 0x68）→ **空指针崩溃**。

### 3.2 保存崩溃根因：跨资产引用
- 用"从其他资产 clone 的 child 结构体"组装树时，若模板自带装饰器，`Decorators` 数组会残留**源资产的装饰器对象引用**。
- 保存校验发现"图引用了外部资产的私有对象" → 拒绝保存 → appError → FATAL。

---

## 4. 修复步骤（本次实际执行的完整流程，可复用）

```python
import unreal_engine as ue
from unreal_engine.classes import BehaviorTree

bt = ue.load_object(BehaviorTree, '/TTS/Asset/AI/BT/BT_Boss')
ROOT_GN = 'UGCBehaviorTreeGraphNode_Root_0'   # 图根图节点的对象名

# 步骤 1：把图根下多余的节点解挂（parent_name 用图节点对象名！）
for nm in ('BossDeathTask', 'BossReturnHomeTask', 'BossHardStaggerTask',
           'BossPhaseTransitionTask', 'Idle'):
    ue.bt_unlink(bt, ROOT_GN, nm)     # 图侧断开
    ue.bt_link(bt, 'Combat', nm)      # 重挂到树根 Composite 下

# 步骤 2：树侧同步（bt_link 不同步树侧！）
#   2a. 从"干净模板"（Decorators 为空的 child）clone，set_field 指到目标实例
#   2b. parent.set_property('Children', [...]) 且 child.ParentNode = parent

# 步骤 3：校验（§6）后保存
bt.modify(); bt.post_edit_change(); bt.save_package()
```

修复后 `bt_query` 视图：
```
[Root] 根
  [Composite] Combat (BTComposite_Selector)
    [Composite] OneDecision ...
```

---

## 5. API 细节速查（踩坑点集中区）

| API / 字段 | 关键事实 |
|---|---|
| `bt_unlink(bt, parent_name, child_name)` | **parent_name 支持图节点对象名**（如 `UGCBehaviorTreeGraphNode_Root_0`）；`'Root'`/裸对象名均报 `parent not found`。这是修改"图根连线"的唯一脚本途径 |
| `bt_link(bt, parent_name, child_name)` | **只改图侧，不同步树侧**；`'already connected'` 检查的是**图侧**连接，须先 `bt_unlink` |
| `bt_get_node(bt, name)` | 按 Title/InternalName/NodeName 匹配；**裸对象（new_object 创建）找不到** |
| `bt_add_node(bt, cls, name, parent_name)` | 父为"有图节点的节点"时图连线正确；父为裸对象/无图节点时，**子图节点会挂到图根**（本次事故的来源之一） |
| `bt_remove_node` | 会"以图重写运行时树"（图是源），慎用 |
| `post_edit_change()` + `save_package()` | 持久化必需；会**丢弃不被 RootNode 引用的裸对象**（含其子节点，连接随之丢失） |
| `BTGraph.ModCounter` | 0 = 图从未被编辑器保存过（脚本建资产的特征）；正常树非 0（3~568） |
| `FBTCompositeChild` | `ChildComposite`（composite）或 `ChildTask`（task）二选一；`Decorators`/`DecoratorOps` 数组**跨资产 clone 时必须清空** |
| child 结构体读取 | 用 `set_property('Children', arr)` 写入；逐个 child 取子节点：依次尝试 `ChildComposite`/`ChildTask` |

---

## 6. 保存前四项校验（强制）

```python
# (a) RootNode 必须能在图节点 NodeInstance 集合中找到
assert bt.RootNode.get_name() in {gn.NodeInstance.get_name() for gn in bt.BTGraph.Nodes if gn.NodeInstance}

# (b) 树连通性 ≈ 图实例数
tree_reachable == graph_instances        # 正常树 39/39

# (c) 根级实例数（图节点 NodeInstance 中 ParentNode=None 的数量）应为 1
rootlevel_instances == 1

# (d) 无装饰器残留、无跨资产引用（沿 outer 链判定归属）
bad_decorators == 0 and bad_external_refs == 0
```

附：检查"根级图节点数"的替代方法（无法读 Pins 时）——统计 `NodeInstance.ParentNode == None` 的实例数量。

---

## 7. 附录：minidump 手工解析（无 WinDbg/cdb 时）

用 PowerShell 直接读 `UE4Minidump.dmp`：

```
头部：0x00 "MDMP" | 0x08 NumberOfStreams(u32) | 0x0C StreamDirectoryRva(u32)
流目录：每项 12 字节（StreamType u32, DataSize u32, Rva u32）
  type=6  ExceptionStream：+8=ExceptionCode(u32)，+16=ExceptionRecord(u64)，
          +24=ExceptionAddress(u64)，+32=NumberParameters(u32)，+36 起=ExceptionInformation[3](u64×N)
          （ExceptionInformation[0]=访问类型 0读/1写/8DEP；[1]=访问地址，如 0x68=空指针+偏移）
  type=4  ModuleList：+4 起每项 108 字节（+0 BaseOfImage u64，+8 SizeOfImage u32，+20 ModuleNameRva u32）
          模块名 = MINIDUMP_STRING @ModuleNameRva（u32 字节长度 + UTF-16LE）
定位：ExceptionAddress 落在哪个模块区间 → 崩溃模块 + 模块内偏移
```

---

## 8. 背景：为什么当时会犯这些错

BT_Boss 的 25 节点骨架完全由脚本搭建，过程中：
1. 先用 `new_object` 造了根 `BossPriority`（→ 隐患 1）
2. 后续 `bt_add_node(parent=BossPriority, ...)` 因父无图节点，把 6 个子图节点全挂到了**图根**（→ 隐患 2）
3. 修根时用"切 RootNode + 清空旧根"导致树游离（→ 隐患 3）
4. 重组树时用了带装饰器的跨资产模板（→ 隐患 4，触发保存 FATAL）

**根本教训：行为树的图（BTGraph）与树必须始终成对维护；脚本只应通过 bt_* 高层 API 变更"图"，树侧变更后必须同步校验；任何中途状态都应在保存前通过 §6 校验。**
