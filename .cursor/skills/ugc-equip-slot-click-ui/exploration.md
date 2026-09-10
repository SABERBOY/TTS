# 通用装备槽点击弹自定义 UI：探索经过

本文记录 TTY 项目里「已装备的通用装备槽点击为何不弹详情、如何挂钩」的试错。**当前弹窗**是官方 `UGC_ItemDetail_UIBP`，见 [SKILL.md](SKILL.md)。自制 `WBP_EquipDetail_Custom` 已删除，不要再接回去。

Wiki `catalog/20210`、`catalog/20104` 是 SPA（`https://developer.gp.qq.com/wikieditor/#/catalog/...`），WebFetch 超时或 404，正文未拿到。对照以 MCP 读出的 `EquipSlotsConfig` 与 LuaHelper stub 为准。

## 要回答的问题

1. 已装备后点击装备槽，默认会不会弹自定义 UI？
2. `BP_BackpackComponentV2_Custom` 里武器槽和装备槽怎么配？
3. 日志 `Depot_EquipType_CommonEquipment_UIBP:OnDragClicked` 对应哪条路径？
4. 能否挂钩点击/选中并弹出装备详情？

## 探索时间线

| 阶段 | 做了什么 | 结果 |
| --- | --- | --- |
| 1. 文档与组件 | 抓 wiki 20210/20104；MCP 读 `EquipSlotsConfig`、UI 组件 CDO | Wiki SPA 抓不到正文；确认 11 槽，目标是 `Common.*` 不是 `AvatarHelmet` |
| 2. 点击路径 | 对照日志与 LuaHelper stub；PIE 扫 live widget 字段 | 通用槽只进 `OnDragClicked`，不创建 ItemDetails；可读写 `W.data` |
| 3. 官方委托 | `GetUISelectItemChangeDelegate():Add` | 战斗内点装备/武器/背包格子均不广播 |
| 4. 补丁内核 Lua | `require` 模块改 `OnDragClicked` | 打印 applied，点击仍走内核原函数（独立 LuaMainCache） |
| 5. 改 userdata | 赋 `W.OnDragClicked` / 只赋 `W.OnClickCallback` | UMG 捕获旧函数；内核读的是 `data.OnClickCallback` |
| 6. 空子类替换装备栏 | `WBP_EquipWepEquip_Custom` 清空树接到 `EquipmentFullScreenUI` | 打开背包 `LuaInit` / `InjectBackpackContext` nil 崩溃 |
| 7. 换成 Open 装备栏 | CDO 指向 `UGC_WeaponEquip_Open_UIBP`（clone SoftClassPath） | 槽仍是 `Depot_EquipType_02`；`OnDragClicked` 开始调 `data.OnClickCallback` |
| 8. 打开后包装 | `OnOpenBattleMainPanel` wrap live `data.OnClickCallback` + `InitData` | `[EquipClick]` 出现；仅拦截 `Common.*` |
| 9. 详情面板 | `WBP_EquipDetail_Custom` + `pcall` 读属性 | 用户 PIE 确认头盔槽弹出面板 |

## 组件数据（UGC MCP）

`BP_BackpackComponentV2_Custom` 的 Lua 未覆写槽位逻辑。槽位全在蓝图 `EquipSlotsConfig`（`TArray<FBackpackComponentV2_EquipSlot>`），MCP 读到 11 条：

| SlotName | 显示名 | ConstraintTypes |
| --- | --- | --- |
| `EquipmentSlot.Core.MainSlot1` | 武器一 | ShootWeapon |
| `EquipmentSlot.Core.MainSlot2` | 武器二 | ShootWeapon |
| `EquipmentSlot.AvataEquipmentSlot.AvatarHelmet` | 头盔 | AvatarHelmet |
| `EquipmentSlot.AvataEquipmentSlot.AvatarBag` | 背包 | AvatarBag |
| `EquipmentSlot.AvataEquipmentSlot.AvatarArmor` | 防弹衣 | AvatarArmor |
| `EquipmentSlot.Core.SubSlot` | 手枪 | Pistol |
| `EquipmentSlot.Core.MeleeSlot` | 近战武器 | Melee |
| `EquipmentSlot.Common.Head` | 头上装备 | Helmet, Hat |
| `EquipmentSlot.Common.UpBody` | 上身装备 | Armor |
| `EquipmentSlot.Common.BelowBody` | 下身装备 | Kneepads |
| `EquipmentSlot.Common.Ornament` | 饰品 | Ring |

用户说的「头上装备」是 `EquipmentSlot.Common.Head`，不是空的形象槽 `AvatarHelmet`。PIE 里两者都会出现在装备栏，点空的形象槽会被误判成「头盔槽是空的」。

`BP_BackpackUIComponentV2_Custom` 改之前的关键 CDO：

- `EquipmentFullScreenUI` = `Equip_WepEquip_UIBP`（非 Open，生成 7 个 `Depot_EquipType_02_UIBP`）
- `BodyEquipSlot` = `UGC_BodyEquipSlot_Open_UIBP`（文档写明 `OnDragClicked` 会调 `OnClickCallback`，但当时全屏装备栏没用这个类画通用槽）
- `ItemDetailsPanel` / `ItemDetailsCompare` = Open 详情面板（武器槽点击会创建它们）
- `CustomEquipUI` / `CustomDetailsWights` = 空

`EItemDataTypeStrs` 里有 `CommonEquipment` 与 `EquipWeapon`。API 注释说可用 `GetUISelectItemChangeDelegate` 的 `DataType` 区分区域，实测战斗内该委托不广播。

## 点击路径（日志）

```
点击通用装备槽
  -> 运行时类 Depot_EquipType_02_UIBP
  -> 内核 Lua Depot_EquipType_CommonEquipment_UIBP:OnDragClicked
  -> 不创建 ItemDetails 面板
```

对比：点武器槽会加载 `UGC_ItemDetailsCompare_Open_UIBP` / `UGC_ItemDetails_Open_UIBP`（日志有 Construct / SetItemInfo）。

LuaHelper 里 `Depot_EquipType_CommonEquipment_UIBP.lua` 只有 stub：`InitData(data)` 的 data 含 `OnClickCallback`，**没有** `OnDragClicked` 的实现文本。运行时内核会 print `Depot_EquipType_CommonEquipment_UIBP:OnDragClicked`。

Live widget 可读写字段（PIE 探测）：

- `SlotName`、`ItemDefineID`、`InitData`（函数）
- `data` 表：含 `OnClickCallback`、`OnDragStartedCallback`、`SlotName`、`ItemID` 等
- `OnClickCallback` 直接挂在 userdata 上时，内核点击**不走**这个字段

## 失败实验（按时间）

### 1. GetUISelectItemChangeDelegate

文档：选中变化 `{SelectData, bSelected}`，装备/武器可用 `DataType`。

PIE：`D:Add(...)` 成功，随后点头盔槽、武器槽、背包格子，**一次都没有** `[SelProbe] bSelected=` 输出。委托在这场战斗 UI 里等于死的。

### 2. require 后 monkey-patch OnDragClicked

`pcall(require, 'ugc....Depot_EquipType_CommonEquipment_UIBP')` 能拿到 table，也能替换 `M.OnDragClicked`，日志打印 `EARLY-PATCH applied`。

点击仍只出现内核那一行 `Depot_EquipType_CommonEquipment_UIBP:OnDragClicked`，没有补丁日志。内核用 `battlemodulerequire` + `LuaMainCache`，项目 `require` 是另一份表。控件创建时绑定的是内核那份函数。

### 3. 给 live widget 赋 OnDragClicked

7 个 `Depot_EquipType_02_UIBP` 实例上直接 `W.OnDragClicked = function...`。点击仍走内核原函数。UMG/Lua 绑定捕获的是旧引用。

### 4. 只改 W.OnClickCallback，不改 data

userdata 上能 set/readback 成功。点击不进包装函数。真正被调用的是 `W.data.OnClickCallback`。

### 5. 空 WidgetTree 子类替换 EquipmentFullScreenUI

创建 `WBP_EquipWepEquip_Custom`（`UGCWidgetBlueprint`，ParentClass = `UGC_WeaponEquip_Open_UIBP_C`），清空 RootWidget，把 `EquipmentFullScreenUI` 指过去，意图重写 `InjectBackpackContext`。

打开背包即崩：

- `WBP_EquipWepEquip_Custom.SuperClass.InjectBackpackContext` 为 nil（项目 Lua 的 SuperClass 不是内核 Open 模块）
- 父类 `Construct` -> `LuaInit` 因子类没有父控件树上的命名控件而 `attempt to call a nil value (method 'LuaInit')`

该类资产仍在工程里，**不要再接到 EquipmentFullScreenUI**。配套 Lua：`WBP_EquipWepEquip_Custom.lua`。

### 其它探测备忘

- `ue_pie doluastring` 默认跑客户端。`AddItemV2` 必须 `target: "ds"`，否则 `CannotCallInClient`。
- DS 上 `EquipItemV2` 常返回 false，但 `GetEquippedItemBySlotName` 随后能读到物品。
- `GetEquipSlotItemV2` 不存在，正确 API 是 `GetEquippedItemBySlotName`。
- `GetAllWidgetsOfClass` 返回 Lua table，用 `#` / `ipairs`，没有 `:Length()`。
- 写 `FSoftClassPath`：从内核 CDO `clone()` 再 `set_field('AssetPathName', path)`。对 CDO 字段直接 set 再 save，会变成 `None`（曾经把装备栏类抹掉，已从内核 CDO 恢复）。
- `create_blueprint(Equip_WepEquip_UIBP_C, ...)` 会建成普通 `Blueprint` 而不是 `UGCWidgetBlueprint`，`widget_inspect` 失败。要用 `UGCWidgetBlueprintFactory` + `ue.create_asset`。

## 做成的方案

两条必须同时成立：

**A. 装备栏换成 Open 版**

`EquipmentFullScreenUI` →

`/Game/UGC/UITemplate/Asset/Backpack/Arts_UI/UIBP/UGC_Backpack_OpenAPI/UGC_WeaponEquip_Open_UIBP.UGC_WeaponEquip_Open_UIBP_C`

Open 面板的 `InjectBackpackContext` 会把 `OnClickCallback` 写进子槽 `data`。非 Open 的 `Equip_WepEquip_UIBP` 生成同样的 `Depot_EquipType_02`，但 `OnDragClicked` 不调 `data.OnClickCallback`（早期注入实验已证明）。换成 Open 后，同一运行时类上包装 `data.OnClickCallback` 就会进自定义逻辑。日志顺序：

```
Depot_EquipType_CommonEquipment_UIBP:OnDragClicked
[EquipClick] SlotName=EquipmentSlot.Common.Head HasDefineID=true
```

**B. 背包打开后再包 live 控件**

`OnOpenBattleMainPanel` 时 `GetAllWidgetsOfClass`：

- `UGC_BodyEquipSlot_Open_UIBP_C`（这次 count=0）
- `Depot_EquipType_02_UIBP_C`（count=7）

对每个控件：包装 `data.OnClickCallback`、`OnClickCallback`，并包装 `InitData` 以免刷新冲掉。只拦截 `EquipmentSlot.Common.*`；其它槽调用原回调。空槽没有 DefineID 则 `GetEquippedItemBySlotName`，仍没有就不弹。

详情：`UGCWidgetUtility.CreateWidgetAsync` + `AddToSlot(..., 'UI.UISlot.MainUISlot_High', 200)`。`GetItemName/Detail/Quality/Level ByDefineID` 会打到 `UGCGameData` 的 override。`GetHeadDamageReduceV2ByDefineID` 内部会调不存在的 `GetHeadDamageReduceAttr`，必须 `pcall`。关背包 `OnCloseBattleMainPanel` / `ReceiveEndPlay` 里 `HidePanel`。

## 背包打开时装备/卸下不刷新

Open 装备栏只在 `InjectBackpackContext` 时 `RefreshEquipData`。背包保持打开再装备/卸下，槽位控件不会自己更新。

失败：在 `BP_BackpackComponentV2_Custom` 覆写 `OnAttachToSlot` / `OnDetachBySlot`。reloadlua 报 `LuaExtend_Override Function Name is not match`，随后 `GetFinalFunction[OnDetachBySlot] failed`。卸下本身仍成功，但该 UFunction 在当次 PIE 里绑坏，需下次完整进 PIE 才恢复。

做成的方案：客户端 `GetItemAttachParentChangeDelegateV2():Add`。文档写明装备到背包槽时 AttachItem 为空、AttachSlotName 为槽名。回调里对 live `UGC_WeaponEquip_Open_UIBP` 调 `RefreshEquipData`，再 `HookCommonEquipSlotClicks`，并刷新/隐藏 `WBP_EquipDetail_Custom`。

PIE：卸下 `EquipmentSlot.Common.UpBody` 后客户端立刻打出 `[EquipRefresh] AttachParent` 和 `RefreshEquipData count=3`，刷新查询到的已装备列表不再包含该上身物品。

## 验证记录

用户在 PIE 中点击已装备头盔槽后确认「弹出了装备详情面板」。客户端日志同时有 `[EquipClick] SlotName=EquipmentSlot.Common.Head HasDefineID=true` 和 `WBP_EquipDetail_Custom` Construct。

已知未打磨：详情面板子控件默认叠在 (0,0) 100x30，靠 Lua `SetWidgetSlotPosition` 排版，视觉仍挤；`WBP_EquipWepEquip_Custom` 闲置。

## 关键日志特征

| 含义 | 日志 |
| --- | --- |
| 内核收到装备槽点击 | `Depot_EquipType_CommonEquipment_UIBP:OnDragClicked` |
| 自定义包装生效 | `[EquipClick] SlotName=EquipmentSlot.Common.Head` |
| 背包打开时槽位数 | `[EquipClick] wrap class=...Depot_EquipType_02... count=7` |
| 武器槽走内核详情 | `[UGC_ItemDetails_Open] SetItemInfo` / `bIsShootWeapon=true` |
| 错误子类装备栏 | `LuaInit` nil / `InjectBackpackContext` nil |
| 详情属性接口崩 | `GetHeadDamageReduceAttr` nil（已用 pcall 兜住） |
