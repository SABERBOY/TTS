---
name: ugc-backpack-v2
description: >-
  UGC Backpack V2 / equipment runtime API guide for this project: AddItemV2 auto-equip,
  EquipItemV2/UnEquipItemV2 signatures, DefineID userdata structs (TypeSpecificID/ItemID/InstanceID),
  GetCurrencyIDList returning userdata arrays, common equipment slot names
  (EquipmentSlot.Common.Head/UpBody/BelowBody/Ornament), and the verified fact that
  GetItemAttachParentChangeDelegateV2 does NOT broadcast on the DS (use a snapshot-poll
  fallback server-side). Use when adding/equipping items, reading equipped state, handling
  currency, or reacting to equip/unequip on the server.
---

# UGC 背包 V2 / 装备运行时 API

API stub 源：`Content/LuaHelper/Source/Lua/ugc/UGCAPI/UGCBackpackSystemV2.lua`（签名权威来源，写代码前先查）。

## 结论（先读这个）

- **加物品**：`AddItemV2(Player, ItemID, Count)` 的 ItemID 是**整数**（如 `8310017`），不是 DefineID struct。可装备物品会自动穿上（日志 `TryAutoEquip ... bEquipResult=1`，触发 `OnEquip_Implementation`）。
- **DefineID 是 userdata struct**：`type()` 为 `userdata`，字段 `TypeSpecificID`/`ItemID`/`InstanceID` 用点号读，但要 `pcall` 包。空槽返回 `TypeSpecificID=0` 的空 struct，不是 nil。
- **`GetItemAttachParentChangeDelegateV2` 在 DS（服务端）不广播**：equip/unequip 时内核有 `SetItemAttachParent`/`ClearItemAttachParent`/`OnEquip_Implementation`/`OnUnEquip_Implementation` 日志，但 Lua 委托回调在服务端**不会被调**（2026-09-10 用探针委托实测）。客户端可用（UI 刷新）。服务端要感知换装 → 用快照轮询（见下）。
- 货币列表 `GetCurrencyIDList(Player)` 返回 **userdata（TArray）**，判断要 `(type=='table' or type=='userdata') and #IDs>0`，取 `IDs[1]`。

## 通用装备槽位（内核只有这些 Common 槽）

| SlotName | 装备类型 |
| --- | --- |
| `EquipmentSlot.Common.Head` | Helmet, Hat |
| `EquipmentSlot.Common.UpBody` | Armor |
| `EquipmentSlot.Common.BelowBody` | Kneepads |
| `EquipmentSlot.Common.Ornament` | Ring |

**没有**手套/腰带/鞋子独立内核槽。设计上有这些槽位时要按"无内核槽"处理（读装备返回空），别映射到 Head/UpBody 否则会把同一件装备算两次。

## 常用函数签名与实测行为

```lua
UGCBackpackSystemV2.AddItemV2(Player, ItemID, Count, PresetIdx)   -- ItemID 整数；可装备则自动装备
UGCBackpackSystemV2.RemoveItemV2(Player, ItemID, Count)
UGCBackpackSystemV2.GetItemCountV2(Player, ItemID)               -- number
UGCBackpackSystemV2.EquipItemV2(Player, SlotName, DefineID)      -- DefineID 是实例 struct
UGCBackpackSystemV2.UnEquipItemV2(Player, SlotName)
UGCBackpackSystemV2.EquipItemToAnySlotV2(Player, DefineID)
UGCBackpackSystemV2.GetEquippedItemBySlotName(Player, SlotName)  -- userdata struct；空槽 TypeSpecificID=0
UGCBackpackSystemV2.GetItemDefineIDsByIDV2(Player, ItemID)       -- userdata 集合，pairs 迭代
UGCBackpackSystemV2.GetCurrencyIDList(Player)                    -- userdata 数组，# 取长度
UGCBackpackSystemV2.GetBackpackComponentV2(PC)                   -- 组件，委托在它上面
```

`Player` 参数在服务端传 **PlayerController**（`Pawn:GetController()`）。传错参数时内核日志形如 `[EquipItemV2:1210] SlotName:8310017 DefineID:Type=[0]`。

DefineID 安全读取模板：

```lua
local function GetDefineItemID(DefineID)
    if DefineID == nil then return nil end
    if type(DefineID) == 'number' then return DefineID ~= 0 and DefineID or nil end
    if type(DefineID) == 'table' or type(DefineID) == 'userdata' then
        local OK, V = pcall(function() return DefineID.TypeSpecificID or DefineID.ItemID end)
        if OK and type(V) == 'number' and V ~= 0 then return V end
    end
    return nil
end
```

从 ItemID 拿 DefineID 实例（用于 EquipItemV2）：

```lua
local ids = UGCBackpackSystemV2.GetItemDefineIDsByIDV2(PC, 8310017)
local defineID
for k, v in pairs(ids) do defineID = v break end
```

## 服务端感知换装：快照轮询（替代不广播的委托）

`GetItemAttachParentChangeDelegateV2` 只在客户端广播。服务端用这个模式（ EquipSlotAttrApplier 实测可用）：

```lua
-- 每 0.25s 对比每槽 TypeSpecificID，变了才 RefreshSlot；平时零开销
UGCGameSystem.SetTimer(Pawn, function()
    for SlotIdx, SlotName in pairs(SLOT_NAME_MAP) do
        local d = UGCBackpackSystemV2.GetEquippedItemBySlotName(PC, SlotName)
        local id = GetDefineItemID(d) or 0
        if Snapshot[SlotIdx] ~= id then
            Snapshot[SlotIdx] = id
            RefreshSlot(SlotIdx)
        end
    end
end, 0.25, true)
```

注意 reloadlua 后旧 timer 闭包仍按旧代码跑——改了轮询逻辑要重启 PIE 或先清 timer（见 `ugc-pie-debug` skill）。

## 物品 Handle 事件

内核注释：装备/卸下触发物品 Handle 的 `OnEquip`/`OnUnEquip` 事件；附加到已装备物品上的物品也算进入装备状态。DS 日志可见 `UGCBattleItemHandle: [OnEquip_Implementation:483] DefineID:...` / `[OnUnEquip_Implementation:534] ...`。Lua 侧若需挂这些事件，目前项目里没有现成 stub，用快照轮询替代。

## 本项目的已知物品 ID

| ItemID | 物品 |
| --- | --- |
| 8310017 | LV7_Helmet（AttrModifyItemSimpleList: BaseAttack +24） |
| 8310084 | 金币（第一货币，`GetCurrencyIDList()[1]`） |

## 相关

- 装备槽点击弹详情 UI（客户端挂钩）：`ugc-equip-slot-click-ui` skill
- 装备加成随槽位等级变化（）：`ugc-equip-system` skill
- doluastring 在 DS 加物品的完整流程：`ugc-pie-debug` skill
