---
name: ugc-equip-system
description: >-
  Equipment slot permanent-strengthening system in this TTS project: six slots
  (Helmet/Chest/Accessory/Glove/Belt/Shoes) with levels stored as EquipSlotLv_* custom
  attributes on UGCAttributeGroup_Character, bonus applied via EquipSlotAttrApplier with
  EffectiveLevel = min(slot level, equip rank cap), delta-applied to BaseAttack/BaseHealth.
  Use when working on EquipSlotSystem.lua, EquipSlotAttrApplier.lua,
  UGC_Equip_Develop_Strengthen_UIBP, UGC_Equip_Basics_Main_UIBP, ServerRPC_StrengthenEquipSlot,
  EquipSlotLv_*, slot strengthening costs, or re-running the PIE strengthen/equip/unequip
  verification checklist.
---

# 装备槽位强化系统（TTS 项目）

强化的是**槽位（装备框）**而不是装备本体。六槽永久等级存 Character 属性集，穿戴装备后按 `min(槽位等级, 装备品阶上限)` 把加成叠到 `BaseAttack`/`BaseHealth`。

## 架构与文件

| 角色 | 文件 |
| --- | --- |
| 数据层：槽位/品阶/消耗/强化事务 | `Script/Blueprint/Prefabs/UI/Equip/EquipSlotSystem.lua` |
| 运行时：装备+等级 → 属性加成 | `Script/Blueprint/Prefabs/UI/Equip/EquipSlotAttrApplier.lua` |
| 面板打开/关闭（GM 与槽位点击共用） | `Script/Blueprint/Prefabs/UI/Equip/EquipPanelManager.lua` |
| 强化面板 UI（无 Tick，属性委托刷新） | `Script/Blueprint/Prefabs/UI/Equip/UIBP/Game_Equip_Develop_Strengthen_UIBP.lua` |
| 装备面板（读属性显示等级） | `Script/Blueprint/Prefabs/UI/Equip/UIBP/Game_Equip_Basics_Main_UIBP.lua` |
| 背包挂钩（换装刷新） | `Script/GamePartCustom/BackpackV2/BP_BackpackUIComponentV2_Custom.lua` |
| RPC 注册 + 自动绑定 | `Script/Blueprint/UGCPlayerController.lua`（`ServerRPC_StrengthenEquipSlot` 在 `GetAvailableServerRPCs` 白名单） |
| 属性常量（自动生成勿手改） | `Script/GameAttribute/game_attribute_type.lua` |
| 属性集蓝图 | `Asset/Blueprint/Attributes/UGCAttributeGroup_Character`（6 个 `EquipSlotLv_*` + `BaseAttack`） |

数据流：

```
客户端 UI → EquipSlotSystem.ClientRequestStrengthen(SlotIdx, Count)
  → UnrealRPC ServerRPC_StrengthenEquipSlot（服务端）
  → ServerTryStrengthen：校验金币/零件 → RemoveItemV2 扣除 → SetSlotLevel（写 EquipSlotLv_*，自动复制）
  → EquipSlotAttrApplier.RefreshSlot
属性变化委托（UI）/ 快照轮询（换装检测）→ RefreshSlot
  → EffectiveLevel = min(SlotLevel, Rank.Cap) → GetSlotBonus 按区间累计
  → 与 AppliedBonusCache 差值 → AddGameAttributeValue(Pawn, 'BaseAttack'|'BaseHealth', delta)
```

## 设计数值（对照策划配置表）

- 槽位：1头盔(Atk) 2衣服(Hp) 3首饰(Atk) 4手套(Atk) 5腰带(Hp) 6鞋子(Hp)；等级 1-180，成功率 100%。
- 单级消耗：金币 `30+3*L`，零件 `1+floor((L-1)/15)`；单槽满级共 54270 金币 / 1170 零件。
- 强化区间（每级 Atk/Hp）：1-10: 1/3；11-20: 1/5；21-30: 2/7；31-75: 3/10；76-120: 5/20；121-180: 10/30。满级攻击槽累计 +1000、生命槽 +3300。
- 品阶 1-12（白→红+2），Cap 10→180；`Ranks` 表在 EquipSlotSystem.lua。
- 攻击槽 → `BaseAttack`，生命槽 → `BaseHealth`。

## 当前实现的已知限制（TODO）

- `EquipSlotSystem.GetEquipRankOrder` **临时恒返回 1**（白装 Cap=10），正式物品表接入后按 TemplateID 精确匹配。
- `EquipSlotSystem.PartsItemID = nil`：零件物品未定义，强化只扣金币并打印警告。
- 手套/腰带无内核槽位（`SLOT_NAME_MAP[4]/[5]=nil`），其槽位加成**不会应用**（鞋子映射 BelowBody）。见 `ugc-backpack-v2` skill 的槽位表。
- `UGCPlayerState.EquipSlotLevels` 保留为冗余备份，权威源是 Character 属性；稳定后可移除。
- 换装检测靠 0.25s 快照轮询（服务端委托不广播），有 ≤0.25s 延迟。不要给 UI 加回 Tick——UI 已走属性变化委托。

## 关键实现细节（改代码前必读）

- **RefreshSlot 只做差值**：`Delta = NewBonus - AppliedBonusCache[Pawn][SlotIdx].Bonus`，`Delta~=0` 才 `AddGameAttributeValue`，避免覆盖其他系统的加成。Pawn 销毁/退出要 `UnbindPlayer` 清缓存。
- **服务端权威**：RefreshSlot/SetSlotLevel 里有 `UGCGameSystem.IsServer()` 守卫；客户端靠属性复制看结果。
- **自动绑定**：`UGCPlayerController:ReceiveBeginPlay`（服务端）带重试地 `EquipSlotAttrApplier.BindPlayer(Pawn)`（Pawn 生成晚于 PC，最多重试 40×0.25s）。`ReceiveEndPlay` 里 Unbind。
- 绑定内容：6 个 `EquipSlotLv_*` 属性变化委托 + `GetItemAttachParentChangeDelegateV2`（客户端方向有效）+ 快照轮询（服务端兜底）。
- DefineID/货币列表都是 userdata，读取方式见 `ugc-backpack-v2` skill。

## PIE 验证

完整验证证据与可复制粘贴的 doluastring 复测脚本见 [verification.md](verification.md)。基线结论（2026-09-10 通过）：

- 穿 LV7_Helmet(8310017)：BaseAttack 100→125（装备24 + 槽1级+1）
- 强化 1→2：金币-36 零件-1，BaseAttack→126
- 强化到 22：Cap10 截断，BaseAttack→134；卸下→100，槽位等级保留
- 客户端 RPC `ServerRPC_StrengthenEquipSlot` 通路正常；强化面板无 Tick 日志

## 相关

- 属性组/迁移/全局唯一：`ugc-game-attributes` skill
- 背包 API、委托不广播、userdata：`ugc-backpack-v2` skill
- doluastring/日志/reloadlua 技巧：`ugc-pie-debug` skill
- 装备槽点击弹详情：`ugc-equip-slot-click-ui` skill
