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

### 6. 强化等级存档（当前实现，只有这一个 key）

存档文件 `ShadowTrackerExtra/Saved/ArchiveData/TTS/10001.json`（**游戏工程** Saved，不是 UGCProjects/TTS）。可以直接改它造脏存档，但**改前必须 stop PIE**，否则 DS 内存里的档会在退出时回写覆盖你的手改。

| 步骤 | 操作 | 期望 / 实测 |
| --- | --- | --- |
| 登录灌回 | 重启 PIE | `[EquipSlotPersist] 登录灌回强化等级 UID=10001 levels=9,3,1,1,1,11 tries=N` |
| 强化落盘 | `ServerTryStrengthen(PS,Pawn,1,1)` | `已保存强化等级 UID=10001 levels=...` |
| 形状损坏兜底 | 手改 json 把 `EquipSlotLevels` 写成非数组 | `NormalizeLevels` 返回 nil → 不灌回、不报错 |
| 只动自己的 key | 存档里另有别的系统数据 | 整档读改写后其他 key 原样保留 |

当前存档形状（物品 / 装备 / 货币都**不再**入库，交给引擎 `ShouldPersist`）：

```json
{"1":{"EquipSlotLevels":[9,3,1,1,1,11]}}
```

> 历史：2026-09-20 曾自研 `EquipSlots` / `Currencies` / `BackpackItems` 三个 key 并验证通过，后因与引擎原生背包持久化职责重复、且触发编辑器崩溃（见第 7 节）已**整体回退删除**。清理前的存档备份：`TEMP/10001.json.bak-before-revert`。

### 7. 编辑器崩溃复盘：`CanWriteValueWithoutIdentifier`（2026-09-20，两次）

报错弹窗：`Assertion failed: CanWriteValueWithoutIdentifier() [JsonWriter.h] [Line: 133]`，fatal assert，**整个编辑器死掉**。

崩溃链（两端日志对齐后确认）：

```
DS   每 45s: BP_BackpackComponentV2:InitPersistDataAfterPlayerEnter → SaveBackpackPersistData
           → UGCDataPersistence.SavePlayerInnerDataByKey → UGCSendUserInnerDataByKey UID=[10001] Key=[4]
编辑器      [UGCSaveData] Received update_ugc_chunkdata
           → Script Stack: UGCSaveDataServiceObject.SaveSaveDataFile
           → Assertion failed: CanWriteValueWithoutIdentifier()   ← fatal
```

| 证据 | 结论 |
| --- | --- |
| 09-18 / 09-15 / 09-12 的历史崩溃目录里该断言 **0 次**，只有今天 2 次 | 是当天新引入的触发条件 |
| DS 的 `BackpackInstanceData` dump 里只有 3×`8310000` 与 `8310084`，4 件防具一个都没有 | 引擎按 **`ShouldPersist`** 过滤持久化物品 |
| 扫全部 98 个物品资产：`ShouldPersist=True` 仅 7 个，含 `8310000 BlazeM416`、`8310084 Coin`；`8310014~8310017` 全为 `False` | 崩溃 payload 里正是这两个 persist 物品 |
| 崩溃会话 GM 事件 0 条、`OnAddItemV2` 仅 8 次、背包始终 8 个实例、存档 1225 字节 | **不是** gm 填满背包，**不是** 256KB 超限 |
| 自研存档走 `SavePlayerArchiveData] LegacyMode`，落盘 JSON 反复读回均合法 | **不是**自研存档数据 |
| 同一份 payload：`19:48` 会话跑满 31 轮不崩，`20:47` 会话第 4 轮崩 | **偶发**，符合 `pairs()` 无序 + 空表形状歧义 |

诱因是 payload 里的**嵌套空表**（`AttachChildren: { }`、`CustomizeData: { }`）：空 Lua 表对 JSON 转换器形状歧义，在对象上下文里被当成裸值写出就命中该断言。

根因归属：断言在**引擎 C++**（`JsonWriter.h:133`）+ **打包 Lua**（`Content/Lua` 磁盘上不存在），项目侧改不了，应提单给平台。项目侧的规避＝**别在登录时补发物品**（也就是第 6 节的"用 `ShouldPersist`，不要自己写 Lua"）。

复现/排查用（target=ds）：

```lua
local Pawn=UGCGameSystem.GetPlayerPawnByUID(10001) local PC=Pawn and Pawn:GetController() for _,ID in ipairs({8310000,8310084,8310017,8310016,8310015,8310014}) do local ok,v=pcall(UGCItemSystemV2.IsShouldPersist,ID) print('PS '..ID..' shouldPersist='..tostring(ok and v)..' count='..tostring(UGCBackpackSystemV2.GetItemCountV2(PC,ID))) end local ok2,pd=pcall(UGCBackpackSystemV2.GetBackpackPersistData,PC,false) print('PS persistData ok='..tostring(ok2)..' size='..tostring(ok2 and UGCPlayerStateSystem.GetTableDataSize(pd)))
```

## 调试期排障顺序

1. 属性读回恒为默认值/0 → 属性不在 Pawn 的组（`ugc-game-attributes` skill 的迁移流程）。
2. 强化成功但 BaseAttack 没变 → 看有没有 `[EquipSlotAttrApplier] Slot=` 日志；没有就是没 BindPlayer 或 RefreshSlot 早退（IsServer/Pawn/nil SlotDef）。
3. 穿上装备 BaseAttack 加了但数值不对 → 检查是否有非头盔槽（如手套）也打了 Delta 日志：说明 SLOT_NAME_MAP 误映射到同一内核槽。
4. 卸下后加成残留 → 快照轮询没跑（reloadlua 后旧闭包），重启 PIE 或 Unbind/Bind + 重置属性值再测。
5. `DefineIDs count=0` → 用了 `GetItemDefineIDsByIDV2` 的返回当 AddItemV2 参数；AddItemV2 直接吃整数 ItemID。
6. 改了 `EquipSlotPersist.lua` 但行为没变 → `reloadlua` 不传播模块级改动，必须 stop → start PIE。
7. **编辑器整个崩掉 + `CanWriteValueWithoutIdentifier`** → 见第 7 节。别在业务 Lua 里找，崩的是引擎 `SaveSaveDataFile`；触发条件是背包里出现 `ShouldPersist=True` 的物品（尤其登录时被代码补发进去）。
8. 装备/物品没跨对局保留 → **不是代码问题**，去物品编辑器勾「是否持久化」（资产属性 `ShouldPersist`）；运行时可用 `UGCItemSystemV2.IsShouldPersist(ItemID)` 确认。
9. PIE 里原生背包持久化"看起来没生效" → 正常现象。引擎那条 inner-data（Key=4）每次重启调试都会重置，只有 `Saved/ArchiveData/*.json` 跨重启保留，两者是不同载体。
10. 背包持久化数据过大/保存失败 → 用 DS 端 GM 的【V2背包持久化数据大小分析】或 `GetBackpackPersistData` + `GetTableDataSize` 自查，对照 256KB / 200 件 / 单物品 0.5KB 阈值。