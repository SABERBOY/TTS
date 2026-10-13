# TTS 装备虚拟货币接入与维护

更新：2026-09-30。项目根目录为 `E:/WeGameApps/rail_apps/OasisEraEditor(2001776)/ShadowTrackerExtra/UGCProjects/TTS`，下文路径相对项目根。装备整体维护入口为[维护手册](equipment-advance-maintenance.md)。

## 1. 当前实现与数据归属

装备系统的金币和钻石统一使用官方 **VirtualItemManager**。旧的背包货币 ID 不再用于装备强化、升阶、余额展示和装备 GM 发钱。

| 项目 | 当前来源 |
|---|---|
| 金币 | UGCObject 的 ItemID=1001；当前 ItemName 为“黄金” |
| 钻石 | UGCObject 的 ItemID=1002；当前 ItemName 为“钻石” |
| 货币定义 | 保存的 `/TTS/Asset/Data/Table/UGCObject.UGCObject` |
| 运行时表路径 | `UGCGameSystem.GetUGCResourcesFullPath('Asset/Data/Table/UGCObject.UGCObject')` |
| 数量/图标 | VirtualItemManager 的 GetItemNum / GetItemData |
| 收入/支出 | AddVirtualItem / RemoveItem；支出等待结果回调 |
| 装备及材料 | 原生背包 DefineID 实例，仍按实例增减、保存 CustomData 与穿戴 |
| 升阶数量/价格 | EquipAdvanceRule，数值未改变 |
| 槽位强化价格 | EquipStrengthenLevel，曲线未改变；PartsItemID 仍为 nil |

旧的金币8310084、钻石8310132没有自动兑换、销毁或清零。本轮没有改商店、掉落、其他系统的经济，不能把其他模块继续发旧货币理解为给装备系统充值。需要兑换存量余额时另行制定幂等迁移规则，避免重进一次就重复兑换。

当前会话确认 `GetMappedItemID(1001)==nil`，官方日志确认 `UGCObjectMapping` 不存在、映射关闭。两行 UGCObject 当前均使用金条图标；这是已保存的数据，本次没有擅自替换钻石图标。若要修改显示名称/图标，在编辑器改 UGCObject 并保存后重新启动。

虚拟余额由官方系统持有，本项目没有把完整余额再存进玩家档案。失败记录里的 Balances 是一次事务的恢复参考值，不能当作玩家账户权威余额。

## 2. 必需的编辑器配置

1. 打开 `Asset/Blueprint/UGCGameMode`，在默认属性 **ActiveGameParts** 中保留原有条目，并加入 `VirtualItemManager`。当前保存值为单个 VirtualItemManager。
2. 编译、保存 GameMode，再读回确认。该属性没有 EditCondition。它是本轮唯一必须修改的蓝图资产；没有改物品蓝图自动穿戴配置或 UI 布局资产。
3. 打开 `Asset/Data/Table/UGCObject`，确认 ItemID 1001、1002 存在、无重复，名称和图标正确。该表是原生 UGCObjectDataTable，不是 UGCBattleItem 或三张升阶表的 RowStruct。
4. 停止并重新启动 PIE，让官方 GamePart 从 BeginPlay 初始化。Lua 热重载不会让新启用的 GamePart 自动完成第一次加载。
5. 客户端和 DS 分别确认 GamePart 已加载、两项 GetItemData 有值、GetItemNum 返回非负整数。只看到 GameMode 保存成功不足以确认运行时启用。

修改 UE 资产只能走原生编辑器/工具保存，不通过外部程序写 uasset。TTS.ugcproj 也不是可直接编辑的普通 JSON。

## 3. 模块与调用接口

以下脚本均位于 `Script/Blueprint/Prefabs/UI/Equip`。

| 文件 | 职责 |
|---|---|
| EquipCurrency.lua | 固定货币 ID、惰性读取 UGCObject、官方 GamePart 获取、余额/图标、异步收支、共享互斥、货币恢复阻断 |
| EquipStrengthenTransaction.lua | 可注入适配器的槽位强化扣款、等级修改和故障补偿 |
| EquipSlotSystem.lua | 原强化预览/曲线/等级接口；通过上述两个模块使用虚拟金币 |
| Advance/EquipAdvanceConfig.lua | 引用统一货币 ID；三张业务表的加载与校验保持原契约 |
| Advance/EquipAdvanceRuntime.lua | 背包实例适配、共享货币锁、GM与恢复档案 |
| Advance/EquipAdvanceSystem.lua | 预览校验、回调驱动执行、请求幂等和实例/货币补偿 |
| Advance/EquipAdvanceRPC.lua | 扣款等待期间保持请求，最终结果才回传客户端 |
| Advance/EquipAdvanceGM.lua | 正式适配器上的测试发钱、发装备、一次合成 |
| UIBP/Game_Equip_Main_UIBP.lua | 1001/1002 顶部金额、官方图标、余额变化委托 |
| Advance/EquipAdvanceUIRender.lua | 升阶成本栏的虚拟货币图标 |
| UIBP/Game_Equip_Develop_Strengthen_UIBP.lua | 原强化金币余额和虚拟金币图标 |

Controller 位于 `Script/Blueprint/UGCPlayerController.lua`：强化 RPC 通过回调记录最终结果；通用 GM 发物品的 0/1001/1002 走虚拟货币，其他装备仍走背包。虚拟货币写操作受服务端 GM 权限限制。

### 3.1 读取

```lua
local Currency=require('Script.Blueprint.Prefabs.UI.Equip.EquipCurrency')
local pc=UGCGameSystem.GetLocalPlayerController()
local amount,reason=Currency.TryBalance(pc,Currency.GoldItemID)
local itemData=Currency.GetData(Currency.DiamondItemID)
-- itemData.ItemIcon 是官方软路径；交给现有异步纹理加载接口。
```

Balance 失败会抛出明确错误；TryBalance 返回 `nil,reason`。未就绪不能作为可花费的余额。主界面显示“—”；原强化预览保守显示0并禁用不足余额操作，服务端仍重新读取真实数量。

Controller 和 Pawn 都可作为调用方，Pawn 通过官方 `GetPlayerControllerByPlayerPawn` 归一化。货币接口不根据背包货币列表的第一项推断金币，也不使用 `GetItemCountV2` 或 `GetItemIconTextureV2(1001)` 查询虚拟货币。

模块导入时不读 UE 表，不取 GamePart、不改账户。UGCObject 在第一次实际查询时读取；读取失败不发布缓存，不回退到旧 ID、JSON 或硬编码余额。

### 3.2 收支及互斥

```lua
-- 仅在服务端：最终成功以回调及余额核对为准。
Currency.ChangeAsync(pc,Currency.GoldItemID,-100,function(ok,actual,reason)
    if ok then
        -- 在此继续提交业务；不能在 ChangeAsync 的下一行就当作已扣款。
    end
end)
```

`ChangeAsync(player,id,delta,done,owner)`：正数使用 AddVirtualItem，负数使用 RemoveItem 回调，0只校验。回调的 actual 是实际观察到的增加/减少数量。即使官方返回失败，也可能发生部分变化，上层按余额快照恢复。

官方 AddVirtualItem 文档返回 boolean，本轮原生验收确认添加后 GetItemNum 立即反映增加。RemoveItem 本身不返回移除数量，不能把其调用返回值当作成功。当前 PIE 的回调在同帧完成，生产流程仍支持延迟回调；离线测试专门延迟了两笔扣款及退款。

`Currency.Change` 只用于确认立即完成的添加/兼容测试。生产支出必须使用 ChangeAsync。异步接口无结果回调时返回 Pending 并保留锁；不得为了继续操作而超时解锁、盲目重扣或重新造物。

强化、升阶和 GM 添加共用按 Controller 保存的互斥。长事务调用 Acquire(player,owner)，每次 ChangeAsync 传同一个 owner，直到提交或补偿全部完成才 Release。其他 owner 不能使用已有锁。重复原生回调只完成一次。

此锁覆盖本装备模块，不能阻止未接入的商店、官方活动等直接修改虚拟余额。事务发现实际数量与快照预期不一致时会失败补偿。后续新增装备货币写入必须复用本接口；跨系统收支需要统一锁或重新设计账户事务，不能宣称目前具备账户级跨系统原子性。

## 4. 升阶事务的异步约定

1. 按现有规则重新验证目标、相同 ID 材料、门槛、余额、下一阶及预览签名。
2. 保存目标/材料/穿戴/货币快照并取得共享锁。
3. 原生按实例移除材料、卸下目标并移除旧目标。
4. 逐项扣除虚拟金币、钻石。只有回调成功、实际数量正确、余额等于快照减费用，才进入下一项。
5. 两项成功后创建下一阶段实例，保存 CustomData、检查数量，恢复目标穿戴槽并刷新属性。
6. 完成结果缓存、释放锁，回传新实例 Key；失败则先移除部分产物，恢复装备和穿戴，再恢复两种余额。

```lua
local immediate=service:Execute(token,requestID,true,function(result)
    -- 最终业务结果；这里可能在函数返回前或返回后调用。
end)
-- immediate.Code=='Pending' 只说明正在等待，不能作为失败重开一笔。
```

等待期间 Busy 和 Journal 保留。同 requestID/token 再次提交只等待同一笔结果；不同 token 是 RequestConflict，不同请求是 Busy。完成后的重复请求返回缓存，不再扣款。缓存仍为会话内最多128条，预览仍会过期；不承诺跨服务器重启的请求幂等。

客户端/UI/RPC不直接处理 Pending 作为最终失败。RPC保留关联编号，在最终完成时发送 Commit/GM；用户超时重试仍沿用原 token/requestID。调用方回调异常不能打断资源补偿、锁释放或其他等待者的结果投递。

账本 Gold/Diamond 保存的是累计投入数量，存量账本仍原样继承。本轮没有回收兑换功能，也没有把历史旧币投入转换成新币发奖。以后实现回收时必须明确历史账本的币种版本与兑换规则，不能直接把所有旧投入按1001/1002返还。

## 5. 槽位强化及恢复阻断

强化仍是永久槽位等级，价格取原表，PartsItemID 仍为 nil。因此目前只花虚拟金币，不把原 PartsCost 擅自转换为钻石消费。

ServerTryStrengthen 增加可选 Complete 回调：`Complete(OK,ErrCode,NewLevel)`。即时失败可同步返回；等待 RemoveItem 时返回 `false,'Pending'`，最终结果由回调给出。Count 要求1—180整数，原等级180上限和批次截断不变。

强化先锁定、读取全部费用余额，再依次等待扣款，最后读回槽位等级、写新等级并核验。扣款/等级写入失败会恢复旧等级和余额；补偿也必须等待回调。等级及货币恢复失败时记录并阻断后续强化/升阶/GM收支。

成功提交后保留原强化等级存档和属性刷新。存档失败会留下日志及 RefreshPending，不伪装成跨存储回滚；复制属性、档案和虚拟账户不是一个原子存储。本轮没有新增进程崩溃期间的持久化事务日志。

| 恢复位置 | 内容/意义 |
|---|---|
| EquipAdvanceRecovery | 原升阶参与实例、穿戴、金额快照和错误 |
| EquipCurrencyRecovery | 共用货币恢复阻断；包含失败升阶记录或强化槽位/等级/余额记录 |
| RecoveryByUID 内存 | 保存本会话恢复证据，即使档案保存失败也不放行 |

Currency.GetRecovery 会识别以上档案，Runtime.GetService 会同步阻断状态。出现 RecoveryRequired 时先核对真实实例、金额和等级，保留记录；禁止直接清档案后继续。迁移前旧 ID 的恢复记录也继续阻断，需要按旧币和旧实例单独人工恢复，不能用新币快照自动结算。

## 6. UI 与 GM 日常维护

主界面只显示1001/1002，其他两个模板货币控件折叠。图标从 VirtualItemManager.GetItemData 的 ItemIcon 读取。InitData 绑定 OnItemNumUpdatedDelegate，余额变化刷新金额和当前子页；关闭、外部 Close 和 Destruct 均移除订阅，重开重新绑定。

一键加货币每次增加100000金币、1000钻石，可重复点击。单独输入示例为 `1001 10000`、`1002 100`；白装备仍用 `8310131 2`。一键发装备仍按有效配方准备57件，逐次合成不会自动加钱或补装备。

变更货币 ID 时不能只改 EquipAdvanceConfig：

1. 在 UGCObject 保存有效新行，确定官方组件使用的映射、账户及图标配置。
2. 修改 EquipCurrency 的统一 ID，并检查两币 Definitions 校验、GM说明、Tests及存量恢复/账本版本。
3. 完整重启，双端读回新表，实测发放、单币扣款、双币扣款、退款、UI事件和RPC。
4. 对旧余额转换另做方案；不要靠切ID自动迁移，也不要增加旧背包余额回退。

后续要真正启用装备零件，不能仅填写原背包 ItemID：当前网关只接受已定义的两项货币，需要扩展统一定义、官方虚拟行、UI和补偿测试，再接入 PartsItemID。当前没有第三货币需求，未做这项扩展。

## 7. 验证方式与本轮证据

离线入口：`python -X utf8 Tests/run_equipment_tests.py`。当前共64组：17配置、27升阶业务（含原23组）、9 UI状态、6虚拟货币、5强化事务；所有迁移配置字段仍与 UE 三表快照一致。虚拟接口测试是宿主提供的模拟，不是生产备用配置。

新原生入口 `Tests/EquipCurrencyPIE.lua` 的 Run(pc) 使用回调连续执行10组，再异步清理。它只选择/移除带本次标记的测试装备，恢复原穿戴、六槽运行等级、强化等级存档字段和两个余额。不能同时运行其他装备测试或停止在待回调中间。

通过宿主读取已审阅源码、组装字面代码、用官方 DS Lua 控制台运行：

```text
local T=(function()
<宿主填入 Tests/EquipCurrencyPIE.lua 的完整源码>
end)()
T.Run(明确选定的GM测试Controller)
```

不得让游戏 Lua 读 Tests 文件或执行 loadstring。原 EquipAdvancePIE/GMPIE/TablePIE 同步测试保留历史用途、ID已更新；当前币种验收优先使用新的回调入口，不能在延迟回调环境用旧即时断言判定补偿完成。

本轮2026-09-30运行会话 `_dkfffpsi20lgov`：

- 11:15:34真实编辑器记录 `lua file validation passed`。
- 11:17:02客户端日志确认 VirtualItemManager、UGCObject、无映射、TableDataReady。
- 11:26:03—04 DS 10组全部通过，末行为 `completed=10 success=true cleanup=true gold=0 diamond=0`。
- 原生强化1→2按现有表扣36金币；等级写入故障退款恢复。
- `8310102→8310101` 原生扣650金币、1钻石，需要2件材料、槽4等级60；未配置下一阶零扣款。
- 测试包57件经27次合成剩27件；穿戴升阶与重复刷新无属性叠加。
- 11:29—32客户端GM RPC加钱、UI显示100000/1000；真实预览/提交后显示99900/1000，背包读回8310130、投入账本100、测试标记继承；关闭重开订阅成功。
- 最终新会话 `_dkfffpsi20mcou` 11:33:51完整LuaCheck通过；11:43:08—09十组再验收全部通过并清理。11:45—47客户端再次预览/提交，金额1000/10→900/10，原生实例与账本正确；DS明确记录 `cleanup=true removed=1 gold=0 diamond=0`。

初次客户端控制台清理曾将 `assert(state)` 的返回值当成恢复状态，发生nil引用。验收脚本改为先赋值、再独立断言并重新运行，最终清理已回读通过。后续工具脚本不依赖assert返回值传递状态，且必须等明确cleanup日志后才能停PIE。

最后保存版本会话 `_dkfffpsi20n1lw` 于11:50:43完整LuaCheck通过；11:56客户端首次初始化读取两币0/0，11:57 DS的GM发放返回值与实际增加100000/1000同时核验通过，回调清理余额0/0后停止。结果追加于[验证记录](equipment-advance-verification.txt)，完整日志路径也在那里；后续验收继续追加，不覆盖旧证据。

本轮确认单客户端PIE/DS内的数值、实例、RPC和补偿。云服真正延迟的扣款、实际云持久化、断线重连、多客户端、与其他直接收支系统并发、进程崩溃一致性仍需专项验收。离线延迟回调覆盖不能替代云环境落盘证明。

## 8. 故障排查

| 现象 | 检查/处理 |
|---|---|
| VirtualCurrencyNotReady | ActiveGameParts是否保存；运行端GamePart是否加载；GetItemData是否就绪 |
| VirtualCurrencyTableMissing/DefinitionMissing | 当前项目根、UGCObject保存状态、两行ID、官方全路径；不改成读取UGCBattleItem |
| 旧币背包有钱、界面显示0 | 新币为独立虚拟账户；核对1001/1002官方余额，不启用隐式旧币回退 |
| Add/Remove失败 | 同时核对官方返回值与实际GetItemNum；失败后可能有部分变化 |
| UI金额不更新 | 主UI是否绑定官方委托、是否仍在打开状态、关闭重开是否重绑；核对服务器与客户端同步 |
| CurrencyBusy/Busy | 升阶或强化仍等待回调；相同请求重试，不能强行释放锁 |
| Pending长期未完成 | 检查官方回调、DS日志与Journal；保留实例/余额现场，不盲目重扣 |
| RecoveryRequired | 核对恢复档案中的币种、实例和等级；人工恢复前继续阻断 |
| LuaCheck提示Asset路径 | 确认模块导入没有间接读取表；运行时仍用官方全路径解析 |
| Lua非法函数 | 不引入文件/进程/动态源码库；host Python与游戏Lua分开验证 |
