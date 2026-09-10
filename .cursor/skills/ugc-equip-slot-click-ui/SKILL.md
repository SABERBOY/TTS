---
name: ugc-equip-slot-click-ui
description: >-
  Hooks TTY backpack common-equipment slot clicks to the official item-detail panel.
  Use when working on 装备槽, 通用装备, EquipmentSlot.Common, Depot_EquipType_CommonEquipment_UIBP,
  OnDragClicked, GetUISelectItemChangeDelegate, EquipmentFullScreenUI, UGC_ItemDetail_UIBP,
  or popping item details after an equipped helmet/armor/kneepad/ring is clicked.
---

# UGC 通用装备槽点击弹官方详情 UI

## 结论（先读这个）

内核**不会**在点击已装备的通用装备槽时弹出详情。武器槽会弹内核详情；通用装备槽只走 `Depot_EquipType_CommonEquipment_UIBP:OnDragClicked`。

当前可用挂钩：

1. `BP_BackpackUIComponentV2_Custom.EquipmentFullScreenUI` 指向开放化装备栏 `UGC_WeaponEquip_Open_UIBP`（让槽位真正调用 `OnClickCallback`）。
2. `OnOpenBattleMainPanel` 里找到 live 槽位控件，包装 `data.OnClickCallback`。
3. 过滤 `EquipmentSlot.Common.*`，`CreateWidgetAsync` 官方 `UGC_ItemDetail_UIBP`，再 `InitData`。

不要再创建或引用已删除的 `WBP_EquipDetail_Custom`。

完整试错过程见 [exploration.md](exploration.md)。

## 当前实现

| 角色 | 路径 |
| --- | --- |
| 挂钩 | `Script/GamePartCustom/BackpackV2/BP_BackpackUIComponentV2_Custom.lua` |
| 详情面板 | `Asset/Blueprint/Prefabs/UI/UGC_ItemDetail_UIBP.UGC_ItemDetail_UIBP_C` |
| 详情面板 Lua | `Script/Blueprint/Prefabs/UI/UGC_ItemDetail_UIBP.lua` |
| 装备栏类（CDO） | `EquipmentFullScreenUI` = `UGC_WeaponEquip_Open_UIBP_C` |
| 闲置（勿接回） | `WBP_EquipWepEquip_Custom`（空 WidgetTree，会崩） |

`UGC_ItemDetail_UIBP:InitData` 点击装备时传入：

```lua
Widget:InitData({
    ItemData = {
        ItemDefineID = ItemDefineID,  -- 推荐，Refresh 依赖此字段
        ItemID = TypeSpecificID,      -- DefineID 为空时的降级
        ItemCount = 1,
    },
    CloseCallback = function() UGCWidgetUtility.HideWidget(Widget) end,
})
```

`CloseCallback` 由面板自己点关闭时回调，面板**不会**自己 Hide，必须外部 `HideWidget`。

`EquipmentFullScreenUI` 完整 SoftClassPath：

```
/Game/UGC/UITemplate/Asset/Backpack/Arts_UI/UIBP/UGC_Backpack_OpenAPI/UGC_WeaponEquip_Open_UIBP.UGC_WeaponEquip_Open_UIBP_C
```

运行时槽位类仍是 `Depot_EquipType_02_UIBP`（Lua 模块名 `Depot_EquipType_CommonEquipment_UIBP`）。Open 面板**不会**实例化 `UGC_BodyEquipSlot_Open_UIBP`（wrap count 曾为 0）。包装必须打在 **live widget 的 `data` 表**上，且要在背包打开之后（`OnOpenBattleMainPanel`）。`InitData` 也要包一层，避免刷新把回调冲掉。

挂钩顺序（不要拆开）：

```
点击 -> 内核 OnDragClicked
    -> W.data.OnClickCallback（包装后）
    -> 仅 EquipmentSlot.Common.* 且 TypeSpecificID ~= 0 或 ItemID ~= 0
    -> CreateWidgetAsync(UGC_ItemDetail_UIBP) -> AddToSlot -> InitData
```

`GetEquippedItemBySlotName` 空槽也会返回非 nil 的空 struct（`TypeSpecificID=0`），必须用 TypeSpecificID/ItemID 是否为 0 判断是否有装备。

背包保持打开时装备/卸下：

内核开放化装备栏只在打开时 `InjectBackpackContext` → `RefreshEquipData`。槽位数据不会随装备变更自动刷新。

客户端绑定 `BackpackComponentV2:GetItemAttachParentChangeDelegateV2()`（装备到背包槽时 AttachItem 为空、AttachSlotName 为槽名）。回调里再调 live `UGC_WeaponEquip_Open_UIBP:RefreshEquipData()`，并刷新/隐藏已打开的 `UGC_ItemDetail_UIBP`。

不要覆写 `OnAttachToSlot` / `OnDetachBySlot`：reloadlua 会 `LuaExtend_Override Function Name is not match`，把该 UFunction 绑坏。

## 槽位对照（MCP 读自 `EquipSlotsConfig`）

通用装备（本功能目标）：

- `EquipmentSlot.Common.Head` 头上装备 `Helmet, Hat`
- `EquipmentSlot.Common.UpBody` 上身装备 `Armor`
- `EquipmentSlot.Common.BelowBody` 下身装备 `Kneepads`
- `EquipmentSlot.Common.Ornament` 饰品 `Ring`

武器/核心槽（走内核详情，不要抢走点击）：

- `EquipmentSlot.Core.MainSlot1/2`、`SubSlot`、`MeleeSlot`

形象槽（控件类相同，但 SlotName 前缀不是 `Common.`，包装后应放行原回调）：

- `EquipmentSlot.AvataEquipmentSlot.AvatarHelmet/AvatarBag/AvatarArmor`

## 改这类功能时怎么做

1. **Lua 挂钩 / 弹窗**：改 `BP_BackpackUIComponentV2_Custom.lua`，`reloadlua` 即可。
2. **详情内容/布局**：改 `Script/Blueprint/Prefabs/UI/UGC_ItemDetail_UIBP.lua` 或其蓝图。
3. **装备栏蓝图类**：改 `EquipmentFullScreenUI` 的 `FSoftClassPath` 必须 `clone()` 内核 struct 再 `set_field('AssetPathName', path)`，然后 compile + save。直接 `set_field` 到 CDO 上会写成 `None`。改完后 **停 PIE 再开**（蓝图属性不能靠 reloadlua）。
4. **加物品/装备**：`ue_pie doluastring` 必须 `target: ds`。客户端会 `CannotCallInClient`。`AddItemV2` 在 DS 上返回 Added=1 但 `EquipItemV2` 可能返回 false，随后用 `GetEquippedItemBySlotName` 确认。

## 不要再试的路

这些都在 PIE 里证伪过，不要当主方案重做：

- `UGCBackpackSystemV2.GetUISelectItemChangeDelegate()`：战斗内装备槽/武器槽/背包格子点击都不广播。
- `require` 内核模块后改 `OnDragClicked`：内核走独立 `battlemodulerequire` / LuaMainCache，补丁表不是运行表。
- 给已创建 widget 赋 `OnDragClicked`：UMG 绑定的是创建时捕获的函数。
- 只给 `W.OnClickCallback` 赋值、不改 `W.data.OnClickCallback`：内核点装备槽读的是 `data` 表。
- 空 WidgetTree 的子类去替换 `EquipmentFullScreenUI`：父类 `LuaInit` 因找不到命名控件崩溃。`WBP_EquipWepEquip_Custom` 因此停用。
- 项目侧 `require('ugc....UGC_WeaponEquip_Open_UIBP')` 再调 `SuperClass.InjectBackpackContext`：拿到的是 LuaHelper stub，运行时 `InjectBackpackContext` 为 nil。
- 在 `BP_BackpackComponentV2_Custom` 里覆写 `OnAttachToSlot` / `OnDetachBySlot`：Lua 函数名与 UFunc 对不上，热重载会把该回调绑坏（`GetFinalFunction failed`）。用 `GetItemAttachParentChangeDelegateV2` 代替。
- 自制 `WBP_EquipDetail_Custom` 再挂内核 `UGC_ItemDetails_Open_UIBP`：已删除。弹窗用项目自带 `UGC_ItemDetail_UIBP`。

## PIE / MCP 注意

- MCP 命名空间 `user-ugc-mcp`：`ue_pie`、`ue_py`、`ue_read`。Python 里 `import unreal_engine as ue`，不是 `unreal`。
- 只改 Lua：`reloadlua`。改了蓝图 CDO（含 `EquipmentFullScreenUI`）：**停 PIE 再开**。
- 加物品：`ue_pie doluastring` 必须 `target: "ds"`。客户端 `AddItemV2` 会 `CannotCallInClient`。
- 探测头盔 ItemID 曾用 `8310011`；`EquipItemV2` 可能返回 false，用 `GetEquippedItemBySlotName` 确认。
- 新建 UGC 控件用 `UGCWidgetBlueprintFactory` + `create_asset`。`create_blueprint(parent_cls)` 会建成普通 Blueprint，不是 UGCWidgetBlueprint。
- `GetAllWidgetsOfClass` 返回 Lua table，用 `#` / `ipairs`，没有 `:Length()`。
- 客户端 `GetMousePosition` 可用；Lua 沙箱没有 `UE.EKeys` / `UE.FKey`。

## 扩展检查

改挂钩或详情面板后，在 PIE 打开背包验证：

- [ ] 已装备的 `Common.Head` 点击弹出 `UGC_ItemDetail_UIBP`，日志有 `[EquipClick] SlotName=EquipmentSlot.Common.Head` 和 `[EquipClick] UGC_ItemDetail InitData ok`
- [ ] 空的通用装备槽不弹
- [ ] 武器槽仍走内核详情
- [ ] 关背包后面板隐藏
- [ ] 背包保持打开时装备/卸下通用槽，槽位图标立刻变，不必关背包
- [ ] 已打开的详情随该槽卸下而隐藏，或随换装 `InitData` 刷新
- [ ] 日志有 `[EquipRefresh] AttachParent` 和 `RefreshEquipData count=`

## 相关资源

- 探索经过与失败实验：[exploration.md](exploration.md)
- 槽位 API stub：`Content/LuaHelper/Source/Lua/ugc/UGCAPI/UGCBackpackSystemV2.lua`
- 属性重写：`Script/Blueprint/UGCGameData.lua`（`RegisterItemPropertyGetOverride`）
