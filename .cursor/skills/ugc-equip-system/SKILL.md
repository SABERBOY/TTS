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
| 强化逐级曲线表（每级属性与消耗，180 行） | `Asset/Data/Table/Customized/EquipStrengthenLevel`（行结构 `EquipStrengthenLevelRow`，行名=等级） |
| 运行时：装备+等级 → 属性加成 | `Script/Blueprint/Prefabs/UI/Equip/EquipSlotAttrApplier.lua` |
| 存档：**只有**六槽强化等级 | `Script/Blueprint/Prefabs/UI/Equip/EquipSlotPersist.lua`（派生属性不入库；物品/货币交给引擎原生持久化） |
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
  → EffectiveLevel = min(SlotLevel, Rank.Cap) → GetSlotBonus 读 EquipStrengthenLevel 表累计列
  → 与 AppliedBonusCache 差值 → AddGameAttributeValue(Pawn, 'BaseAttack'|'BaseHealth', delta)
强化成功 → EquipSlotPersist.SaveLevels（整档读改写，只动 EquipSlotLevels 一个 key）
登录 UGCPlayerController:ReceiveBeginPlay → Applier.BindPlayer(Pawn)
  → EquipSlotPersist.BindLoadHooks（带重试读档）→ ApplyLevels（写 EquipSlotLv_*）→ RefreshAllSlots
物品 / 货币的跨对局保留 → 走引擎原生 V2 背包持久化（物品编辑器「是否持久化」= 资产属性 ShouldPersist），本项目不自己实现
```

## 设计数值（对照策划配置表）

- 槽位：1头盔(Atk) 2衣服(Hp) 3首饰(Atk) 4手套(Atk) 5腰带(Hp) 6鞋子(Hp)；等级 1-180，成功率 100%。
- 单级消耗与每级属性**读表** `EquipStrengthenLevel`（源自策划表"强化逐级"页，180 行）；下面公式只是该表的生成规则，已逐行校验一致，**代码不再内置**：
  - 单级消耗：金币 `30+3*L`，零件 `1+floor((L-1)/15)`；单槽满级共 54270 金币 / 1170 零件。
  - 每级 Atk/Hp：1-10: 1/3；11-20: 1/5；21-30: 2/7；31-75: 3/10；76-120: 5/20；121-180: 10/30。满级攻击槽累计 +1000、生命槽 +3300。
- `GetSlotBonus(Level,'Atk'|'Hp')` 直接取表的 `CumAtk`/`CumHp`（超过 180 按 MAX_LEVEL 饱和）；`GetBatchCost` 用累计列做差 `CumGold(Target)-CumGold(From)`，与逐级求和等价。表行经 `GetLevelRow` 带缓存读取（RefreshSlot 走 0.25s 轮询，避免重复查表）。
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
- **存档持久化（只有强化等级）**（`EquipSlotPersist.lua`）：**只入库一个 key `EquipSlotLevels`**（6 槽永久等级）。`BaseAttack`/`BaseHealth` 等派生值不存，登录后由 RefreshAllSlots 重算。写法参照 TopDownProject `UGCPlayerState:ReadHeroID/SaveHeroID`：权威端守卫 + `GetUIDBy*` + 整档读改写只动自己的 key；存档根节点非 table 时 fail-closed 拒绝覆盖。
  - **写**：`ServerTryStrengthen` 升级成功后调 `SaveLevels`。
  - **读**：`EquipSlotAttrApplier.BindPlayer` 开头（绑定属性委托与首次 RefreshAllSlots **之前**）灌回。存档要等 PostLogin 才就绪，**只读一次会拿到空**，所以按 0.25s 间隔带重试地读（最多 40 次），读到或确认无存档即停。
  - ⚠️ 别用 `UGCGenericMessageSystem` 监听 `UGC.Player.PlayerEnter` 补读：本钩子经 `ReceiveBeginPlay` + 等 Pawn 生成后才注册，实测晚于该广播约 43ms，DS 日志 `MessageImpl Key[UGC.Player.PlayerEnter] Listener[None]`，永远收不到。TalentTree 那种组件能用是因为它在自己的 BeginPlay 里就注册，并靠 `GetPlayerKeyByPlayerController(PC)==0` 判断是否延到 `OnPlayerPostLoginDelegate`。
- 🚫 **装备 / 背包物品 / 货币一律不要自己存**——引擎原生已经做了。自己再存一套会和引擎双重持久化、互相覆盖，而且实测**会把编辑器搞崩**。曾经实现过一整版（`EquipSlots` + `BackpackItems` + `Currencies` 三个 key、登录补发、事件驱动防抖落盘、Schema 规范化），已于 2026-09-21 全部撤销，别再照着旧 commit 抄回来。要点：
  - 物品编辑器（wiki `catalog/20101`）里每个物品有「**是否持久化**」属性 = BP 上的 `ShouldPersist`，勾选后该物品**可以跨对局存储**；实例化数据 `CustomData` 会随背包/仓库一同持久化（wiki `catalog/20104`「背包系统」）。运行时查询用 `UGCItemSystemV2.IsShouldPersist(ItemID)`。
  - 引擎链路：`BP_BackpackComponentV2:InitPersistDataAfterPlayerEnter` → `SaveBackpackPersistData`（约 45s 一次）→ `UGCDataPersistence.SavePlayerInnerDataByKey`（Key=4）→ 编辑器 `UGCSaveDataServiceObject.SaveSaveDataFile`。内置阈值：总量 **256KB** / 背包 **200 件** / 仓库 **200 件** / 单物品实例数据 **0.5KB**；自查用 `UGCBackpackSystemV2.GetBackpackPersistData(Player, ContainsNoPersist)`（只读）+ DS 端 GM 的「V2背包持久化数据大小分析」按钮。
  - **本项目现状**：98 个物品里 `ShouldPersist=True` 只有 7 个（`8310000 BlazeM416`、`8310001 Breaker_Scar`、`8310002 FanaticM416`、`8310024 Stamina_Small`、`8310043 Oil_Fire`、`8310048 M416`、`8310084 Coin`），**4 件测试装备 `8310014/8310015/8310016/8310017` 全是 `False`**。要让装备跨对局保留，去物品编辑器勾这个框，**不要写 Lua**。
  - 💥 **崩溃复盘**：登录时自己 `AddItemV2` 补发 `ShouldPersist=True` 的物品，会让引擎那份 chunk 数据第一次变成非空，编辑器转 JSON 时**偶发** `Assertion failed: CanWriteValueWithoutIdentifier()`（`JsonWriter.h:133`）→ fatal → 整个编辑器退出。同一份 payload 有时连跑 31 轮不崩、有时第 4 轮就崩：payload 里有 `AttachChildren: { }`、`CustomizeData: { }` 这类**嵌套空表**，配合 `pairs()` 无序遍历造成数组/对象形状歧义。断言在引擎 C++ 和打包 Lua（`Content/Lua` 磁盘上不存在）里，**项目侧无法修**。
  - 定位手法：DS 日志找 `SaveBackpackPersistData Conduct Timer` 与 `UGCSendUserInnerDataByKey Key=[4]` 的时间点，编辑器日志找 `[UGCSaveData] Received update_ugc_chunkdata` + `Script Stack: UGCSaveDataServiceObject.SaveSaveDataFile`，两边时间对上即可确认；崩溃报告在 `Saved/Crashes/UE4CC-*/ShadowTrackerExtra.log`，历史崩溃目录里 grep `CanWriteValueWithoutIdentifier` 可判断是不是同一个问题。
- **PIE 下两套存储行为不同**（曾据此误判）：`SavePlayerArchiveData` 写的 `Saved/ArchiveData/<项目名>/<UID>.json`（注意在**游戏工程** `ShadowTrackerExtra/Saved` 下，不是 `UGCProjects/TTS/Saved`）**能**跨 PIE 重启读回；引擎的 inner/chunk 数据（Key=4）**每次重启调试都会重置**（与 wiki「存档调试」一节一致）。所以 PIE 里登录时背包恒空，**不能据此判定引擎的背包持久化没生效**。可直接改那个 json 造脏存档测试，但**改前必须先 stop PIE**（DS 内存持有整档，退出时会回写覆盖你的手改）。
- ⚠️ **改完 Lua 要重启 PIE**：`reloadlua` 对模块级改动（尤其 `require` 过的表/函数、已启动的定时器闭包）不可靠，实测修完 bug 后 reload 仍报同样的错，必须 stop → start。
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
