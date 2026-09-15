# 装备槽位系统 PIE 验证记录与复测脚本

2026-09-10 在 PIE（DS + 1 客户端）全部通过。复测前准备：PIE running、玩家已登录、拿过 Pawn/PC（拿法见 `ugc-pie-debug` skill）。

## 验证证据（实测日志摘要）

| 步骤 | 操作 | 结果 |
| --- | --- | --- |
| 基线 | 新 PIE | `BaseAttack=100.0 EquipSlotLv_Helmet=1.0` |
| 自动绑定 | ReceiveBeginPlay 重试 | 日志 `equip snapshot poll started` + 6 条 `bound attr delegate EquipSlotLv_*` |
| 穿装备 | `AddItemV2(PC, 8310017, 1)` 自动装备 | `[EquipSlotAttrApplier] Slot=1(头盔) Level=1 Rank=1 Eff=1 Bonus=1 Delta=1`；BaseAttack **125** |
| 强化 | `ServerTryStrengthen(PS,Pawn,1,1)` | `强化成功 Slot=1(头盔) 1->2 金币-36 零件-1`；BaseAttack **126** |
| Cap 限制 | `ServerTryStrengthen(...,1,20)` → 22 级 | `Level=22 Rank=1 Eff=10 Bonus=10`；BaseAttack **134** |
| 卸下 | `UnEquipItemV2(PC,'EquipmentSlot.Common.Head')` | 快照轮询检出，BaseAttack 回 **100**，SlotLv 保留 22 |
| 客户端 RPC | 客户端 `ClientRequestStrengthen(1,1)` | DS 日志 `ReceiveUnrealRPC ... ServerRPC_StrengthenEquipSlot` → `OK=true NewLevel=2` |
| 去 Tick | 客户端日志 | 强化面板只有 bind lua script 一条，无 Tick 循环 |

## 复测脚本（doluastring, target=ds）

每段独立可发；print 已用 `..` 拼接。发完等 3-6s 用 `rg V <ds日志>` 读 `LogNula: LuaLog:` 行。

### 0. 拿对象 + 读基线

```lua
local GS=UGCGameSystem.GetGameState() local PS=GS and GS.PlayerArray and GS.PlayerArray[1] local Pawn=PS and PS:GetPlayerCharacterSafety() if Pawn then print('V base BaseAttack='..tostring(UGCAttributeSystem.GetGameAttributeValue(Pawn,'BaseAttack'))..' SlotLv='..tostring(require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotSystem').GetSlotLevel(nil,1,Pawn))) else print('V no pawn') end
```

### 1. 穿 LV7_Helmet（自动装备；期望 125）

```lua
local GS=UGCGameSystem.GetGameState() local PS=GS and GS.PlayerArray and GS.PlayerArray[1] local Pawn=PS and PS:GetPlayerCharacterSafety() local PC=Pawn and Pawn:GetController() UGCBackpackSystemV2.AddItemV2(PC,8310017,1) print('V equip-called')
```

隔 1s 后读：

```lua
local GS=UGCGameSystem.GetGameState() local PS=GS and GS.PlayerArray and GS.PlayerArray[1] local Pawn=PS and PS:GetPlayerCharacterSafety() print('V after-equip='..tostring(UGCAttributeSystem.GetGameAttributeValue(Pawn,'BaseAttack')))
```

### 2. 强化头盔槽 1 级（先补金币；期望 126，金币-36 零件-1）

```lua
local GS=UGCGameSystem.GetGameState() local PS=GS and GS.PlayerArray and GS.PlayerArray[1] local Pawn=PS and PS:GetPlayerCharacterSafety() local PC=Pawn and Pawn:GetController() local E=require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotSystem') UGCBackpackSystemV2.AddItemV2(PC,E.GetGoldItemID(PC),100000) local ok,err,nl=E.ServerTryStrengthen(PS,Pawn,1,1) print('V strengthen ok='..tostring(ok)..' newlv='..tostring(nl)..' BaseAttack='..tostring(UGCAttributeSystem.GetGameAttributeValue(Pawn,'BaseAttack')))
```

### 3. Cap 限制（强化 20 级到 22；期望 134 = 100+24+10）

```lua
local GS=UGCGameSystem.GetGameState() local PS=GS and GS.PlayerArray and GS.PlayerArray[1] local Pawn=PS and PS:GetPlayerCharacterSafety() local E=require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotSystem') local ok,err,nl=E.ServerTryStrengthen(PS,Pawn,1,20) print('V cap ok='..tostring(ok)..' newlv='..tostring(nl)..' BaseAttack='..tostring(UGCAttributeSystem.GetGameAttributeValue(Pawn,'BaseAttack')))
```

### 4. 卸下（期望回 100，SlotLv 保留 22；轮询 ≤0.25s 后生效）

```lua
local GS=UGCGameSystem.GetGameState() local PS=GS and GS.PlayerArray and GS.PlayerArray[1] local Pawn=PS and PS:GetPlayerCharacterSafety() local PC=Pawn and Pawn:GetController() UGCBackpackSystemV2.UnEquipItemV2(PC,'EquipmentSlot.Common.Head') print('V unequip-called')
```

隔 1s 后读最终值。

### 5. 客户端 RPC 通路（target=client）

```lua
local E=require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotSystem') E.ClientRequestStrengthen(1,1) print('V client-sent')
```

DS 日志应出现 `ReceiveUnrealRPC UGCPlayerController_C_0:ServerRPC_StrengthenEquipSlot` 和 `强化成功`。

## 调试期排障顺序

1. 属性读回恒为默认值/0 → 属性不在 Pawn 的组（`ugc-game-attributes` skill 的迁移流程）。
2. 强化成功但 BaseAttack 没变 → 看有没有 `[EquipSlotAttrApplier] Slot=` 日志；没有就是没 BindPlayer 或 RefreshSlot 早退（IsServer/Pawn/nil SlotDef）。
3. 穿上装备 BaseAttack 加了但数值不对 → 检查是否有非头盔槽（如手套）也打了 Delta 日志：说明 SLOT_NAME_MAP 误映射到同一内核槽。
4. 卸下后加成残留 → 快照轮询没跑（reloadlua 后旧闭包），重启 PIE 或 Unbind/Bind + 重置属性值再测。
5. `DefineIDs count=0` → 用了 `GetItemDefineIDsByIDV2` 的返回当 AddItemV2 参数；AddItemV2 直接吃整数 ItemID。
