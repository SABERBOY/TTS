# 装备升阶 UI 实施与维护

更新：2026-09-28。本文对应现有 `Game_Equip_Develop_Transform_UIBP` 的升阶接入。基础规则、事务与三张配置表见[系统说明](equipment-advance-system.md)，改表流程见[维护手册](equipment-advance-maintenance.md)。所有相对路径以 TTS 项目根为准。

## 1. 玩家入口和行为

从装备主界面进入 **养成 → 升阶**。内部 PageId 仍为 `transform`，只改显示文字，不重命名已有主界面字段。调试端可通过现有管理器打开：

```lua
require('Script.Blueprint.Prefabs.UI.Equip.EquipPanelManager').Open({PageId='transform'})
```

右侧按实例显示装备，按阶位、ItemID、实例Key稳定排序；相同ID的多件装备占不同列表行。每行显示名称、逻辑部位、独立阶位、槽位强化等级、穿戴/锁定/历史投入状态。未接入升阶的原生可穿戴装备也可查看，并提示未配置路线。

选择一行后，左侧中央显示目标，周围显示需要的材料位，下方显示当前阶→下一阶、当前槽位等级/门槛、已选/所需材料数量、货币余额/消耗。消耗为0的货币控件折叠，例如白升绿仅显示金币。图标和颜色读取原生物品配置；紫、紫+1、紫+2可以同品质，必须看独立阶位文字。

- 白、绿、蓝：仅自动选取已查看、未保护、未穿戴、无历史投入的同ID实例。未知 Viewed 状态不自动消耗，可手动选材。本UI不会因为浏览而写入 Viewed。
- 紫及以上：默认不选材料。点击空材料位或“选择材料”，右侧只显示目标之外的相同ItemID实例；再次点击已选材料可取消。受保护材料变灰且不能点击。
- 选材模式点击“返回装备”或中央目标，返回完整装备列表；点击已填充的材料位会移除该材料并进入选材模式。
- 材料、强化、余额、路线满足后还要等待服务端预览成功，按钮才启用。紫及以上或任何手动选材先显示“确认升阶”，第二次点击才提交消耗。
- 成功后按服务端返回的新实例Key重新选中产物。失败补偿后按 RestoredKeys 替换目标Key，刷新背包；失败不得显示“升阶完成”。
- 缺下一阶、缺材料、余额或等级不足时按钮禁用，并显示原因。RecoveryRequired 继续阻断操作，不在UI清除恢复记录。

当前原生布局有6个材料位，现有规则最多需要3件材料。将规则调整到6件以上时应同步扩展布局；不要仅改表后假定所有材料仍能在环形区完整展示。

## 2. 模块职责与编辑位置

以下脚本位于 `Script/Blueprint/Prefabs/UI/Equip`：

| 文件 | 维护内容 |
|---|---|
| `UIBP/Game_Equip_Develop_Transform_UIBP.lua` | 生命周期、按钮/材料点击、快照轮询、列表刷新、界面文案 |
| `Item/Game_Equip_Advance_Row_UIBP.lua` | 动态列表每行展示与实例点击；复用时替换 AdvanceData |
| `Advance/EquipAdvanceViewModel.lua` | 纯Lua选择状态、自动/手动材料、确认、预览有效期、请求匹配、新实例与补偿引用 |
| `Advance/EquipAdvanceUIRender.lua` | 图标异步加载、原生品质边框、货币与控件可见性 |
| `Advance/EquipAdvanceClient.lua` | Snapshot/PreviewForUI/CommitForUI、请求编号、多订阅分发；兼容GM旧入口 |
| `Advance/EquipAdvanceRPC.lua` | 回传 ClientRequestID，包括错误结果 |
| `Advance/EquipAdvanceRuntime.lua` | UISnapshot只读投影；实际事务仍由既有System负责 |
| `UIBP/Game_Equip_Main_UIBP.lua` / `EquipPanelManager.lua` | 切页、关闭时调用升阶子页Deactivate |

Controller仅增加 `ServerRPC_EquipAdvanceSnapshot` 白名单与转发，Preview增加可选关联编号。UI不得提交下一阶ItemID或消耗，不得直接改背包。

原生资产：

- `Asset/Blueprint/Prefabs/UI/Equip/UIBP/Game_Equip_Develop_Transform_UIBP.uasset`：沿用原中心、材料位、货币、按钮、列表；补充状态/目标名文字、背景与布局。
- `Asset/Blueprint/Prefabs/UI/Equip/Item/Game_Equip_Advance_Row_UIBP.uasset`：专用复用行，源于项目Grade行；不修改共享模板行以影响原强化页。
- `ReuseList2_Grade.ItemClass` 指向上述新行，ItemWidth=470、ItemHeight=108；OnUpdateItem索引从0开始，Lua数组从1开始。
- 原生绑定字段：Develop_Icon_0、Develop_Icon_01至06、Common_Currency1/2、NewButton_Start、NewButton_Choice、ReuseList2_Grade、TextBlock_3、TextBlock_Grade、TextBlock_Status、TextBlock_TargetName、TextBlock_Choose。

费用/门槛/路线仍只维护三张 UE DataTable，不在UI脚本另存一套数值。布局、字号、颜色在原生UIBP维护；状态和错误提示在ViewModel/Panel维护。

## 3. 数据、请求与生命周期

### 只读快照

`Client.Snapshot(request)` → Controller → RPC.Snapshot → Runtime.UISnapshot → `Client_EquipAdvanceResult`。

快照包含 `OK/Code/Kind/ClientRequestID/Revision/Items/Levels/GoldHave/DiamondHave/Blocked`。Items中只返回显示和选择所需字段：Key、ItemID、EquippedSlot、SlotIdx、RankOrder、AllowedMaterial、SafeAuto、Locked、HasInvestment；不向UI发送整个CustomData背包副本。

Revision在服务端根据实例Key、数据、数量、穿戴、占用、数据大小、六槽等级、余额与阻断状态产生。**不能把每次重建的DefineID userdata对象地址放进指纹**，否则不变背包每秒也会失效。快照不会给GM权限，也不会标记装备已查看。

### 预览、确认、提交

UI先用缓存表和快照显示需求/明显阻止原因，再调用 `PreviewForUI(targetKey, materials, request)`；按钮启用依赖对应服务端成功预览。请求编号由Client生成；每个回复必须匹配正在等待的编号。快速切目标后的旧预览、GM的无关联预览都不能启用当前按钮。

客户端预览有效期110秒，服务端120秒；到期重新预览。选择变化或快照Revision变化会清除确认，并剔除不再合格的材料。提交时使用 `CommitForUI(token, request, true)`；提交期间冻结目标和材料选择。

8秒未收到提交结果时，按钮允许“重试原请求”，沿用同一token/request；绝不能调用旧 `Confirm(true)` 创建另一个编号当作网络重试。成功/失败回复匹配后，清除提交状态、重新请求快照。跨断线/新进程恢复不由UI实现。

### 订阅与轮询

Construct只设置轻量状态；InitData在控件可用后绑定委托、Subscribe并启动1秒轮询。**不要在Construct绑定NewButton委托**，本项目原生控件曾因此崩溃。每次InitData只保留一组绑定/一个timer；订阅以panel为key覆盖，不叠加。

Deactivate停止timer、Unsubscribe、清除快照等待；非提交状态清除旧预览。Destruct还移除全部委托。主界面切页、点击关闭、管理器直接Close都走Deactivate。保留中的提交请求在重开后仍用相同编号查询/重试，不能重新合成。

列表只有显示模式、目标、材料或Revision变化时Reload/Refresh。行点击闭包读取当前AdvanceData，而不是首次创建时的实例。异步图标加载使用弱引用及每个Image的请求序号，防止滚动复用时旧回调覆盖新图标。

## 4. 原生编辑排错经验

1. 原生资产只能通过编辑器工具修改、编译、保存、回读；不能外部改写uasset。
2. `ue.duplicate_asset` 使用已验证的完整源ObjectPath（包括 `.AssetName`）。只传PackagePath曾复制出无效Package并阻止保存；必须核对结果为UGCWidgetBlueprint。
3. Python反射struct读取可能返回源属性的视图。`f=w.Font; f.Size=21; w.Font=f` 和 `d=w.Slot.LayoutData; ...; w.Slot.LayoutData=d` 曾清空字体/布局。使用独立新建的 SlateFontInfo/AnchorData/Anchors/Margin，逐项填值后赋给控件，编译前后回读。
4. 字体回读检查FontObject、TypefaceFontName、Size；布局检查Anchors、Offsets、Alignment。不要以save返回成功证明画面正确。
5. 共享Develop图标的图片父Canvas默认Collapsed。只显示Image本身无效；Render需显式显示该父级。行中的嵌套DragDrop应隐藏，由覆盖整行的NewButton接收点击，避免事件争用。
6. 新增需要Lua访问的控件设置bIsVariable，编译后检查导出字段；按钮文字实际字段是TextBlock_3。
7. UGC原生assert在本次环境即使通过也不返回被断言对象；不能写 `local state=assert(AdvanceUITestState)`。分成assert语句和赋值语句。货币扣除适配器返回正的移除数量，不是负delta。
8. 热重载不会自动替换已创建model/闭包；Lua行为可快速迭代，最终还要新会话验证首次初始化。编辑原生UI资产需要重新启动PIE。

## 5. 回归与交接

离线：`python -X utf8 Tests/run_equipment_tests.py`，基线17配置+23业务+9UI组。UI测试覆盖精确ID/保护自动选材、紫阶双确认、过期/错序回包、余额/等级/缺路线、快照变更、同请求重试、补偿引用、材料过滤。测试模块导入无副作用，宿主Python负责读文件；游戏Lua无文件读取或动态源码库调用。

真实交互使用 `Tests/EquipAdvanceUIPIE.lua` 的显式fixture。宿主读取已审阅源码，通过官方DS控制台作为字面函数执行（方法见skill验证参考），赋给AdvanceUIAcceptance，再调用Setup(pc)。仅适用于已授权隔离测试DS、GM开启、服务不Busy/Blocked；禁止Setup重复发包。

Setup保存原货币和六槽等级，添加10000金币、100钻石、14件带AdvanceUIProbe标记装备，等级置180，并确认连续快照Revision一致。验收建议：

1. 选择白饰品，自动填1件材料、只显示金币，点击后两白变一绿，实际扣100。
2. 滚动至紫+1手套8310102。选目标，点击空材料位，手选2件；双货币650/1，门槛60。第一次点按钮零扣款，第二次三件变一件8310101；两次合成累计金币750、钻石1。
3. 选择8310093缺路线鞋子，按钮禁用；临时设置目标槽位低等级、移除金币、锁定材料分别观察禁用与状态刷新。修改后恢复测试余额/等级，不要误把测试移除费用算作合成费用。
4. 切强化页和关闭页面，检查Active=false、Timer=nil、Client.Listeners[panel]=nil；重开后只有一组订阅。
5. Audit返回带标记实例计数和实际费用。Cleanup删除仅本fixture的输入/继承标记的产物，恢复原余额和六槽等级，并核对标记装备已清空。必须读到Cleanup OK=true后才能结束测试。

本次真实测试覆盖单客户端DS、白阶及紫色小阶鼠标合成、动态列表滚动/复用、费用、禁用条件、快照刷新、切页/重开/关闭。离线测试覆盖错序回复、超时重试、补偿映射；尚未实测真实丢包、断线重连、多客户端、移动端触摸和不同分辨率。持久化和跨进程原子性仍沿用原系统验收边界。详细时间与日志见[验证记录](equipment-advance-verification.txt)。
