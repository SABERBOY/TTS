# 虚拟货币维护参考

基线2026-09-30。先读项目 `Docs/equipment-virtual-currency.md`，再读当前代码；下面只列影响修改决策的约定。

## 定位

- 货币定义：原生 `/TTS/Asset/Data/Table/UGCObject.UGCObject`，金币1001、钻石1002。加载时使用官方 GetUGCResourcesFullPath；导入阶段零原生调用。
- 必需 GamePart：GameMode 的 ActiveGameParts 包含 VirtualItemManager。保留其他条目、编译保存、回读；改资产需新会话初始化。
- 数量/图标：GetItemNum(id,pc)、GetItemData(id).ItemIcon；Pawn通过官方接口转Controller。
- 装备仍使用原生背包实例，不把虚拟货币当作DefineID，也不通过GetCurrencyIDList的顺序找金币。
- 当前无UGCObjectMapping，两币图标都是已保存的金条图。改映射/图标需原生回读和重启，不擅自重做用户的表。

## 修改入口

| 范围 | 源码 |
|---|---|
| ID、表定义、API、账户互斥、恢复阻断 | EquipCurrency.lua |
| 槽位强化异步扣款/补偿 | EquipStrengthenTransaction.lua + EquipSlotSystem.lua |
| 升阶事务/RPC/恢复 | Advance/EquipAdvanceSystem.lua、Runtime.lua、RPC.lua |
| UI货币图标/金额/订阅 | EquipAdvanceUIRender.lua、Main/Strengthen UIBP、EquipPanelManager.lua |
| GM发放 | EquipAdvanceGM/Runtime、UGCPlayerController、Script/utils/gm.lua |

日常费用仍改 EquipAdvanceRule/EquipStrengthenLevel；迁币不代表改费用曲线。PartsItemID仍nil，不擅自让强化扣钻石。

## 异步与恢复

生产支出用ChangeAsync。AddVirtualItem文档返回boolean且本轮即时增量已实测；RemoveItem没有移除数量返回值，必须检查回调bSucceeded、实际数量和最终余额。失败可能已部分扣款，按快照恢复。不要把当前PIE同帧回调推断成所有云服都同步。

Acquire(owner)后每笔收支传同owner，直到全部提交/补偿完成才Release。共享锁覆盖本装备模块，不能阻止其他直接使用官方接口的系统。Pending不能触发新请求或超时释放；UI超时沿用原token/request。完成请求缓存是会话内有界缓存，不保证跨重启幂等。

EquipCurrencyRecovery与旧EquipAdvanceRecovery均阻断收支。存量旧币恢复记录按旧现场处理，不能用新币自动补偿。保留记录、核对实例/余额/等级，不直接清档放行。即使档案保存失败也保留内存阻断；不宣称跨进程原子性。

历史Gold/Diamond投入仍累计数量；未做回收和旧币兑换。以后回收必须设计历史币种版本，不能直接把所有旧投入当成新币奖励。

## 验证

- 离线：runner当前64组，17配置+27升阶+9 UI+6 Currency+5强化事务。延迟两币扣款、重复回调、同请求等待、第二币失败、延迟退款及恢复阻断要继续覆盖。
- 原生：优先 Tests/EquipCurrencyPIE.lua 的Run(pc)，10组回调验收与异步cleanup；只操作标记实例，恢复原货币/穿戴/六槽及强化存档字段。
- Tests不保证可被运行require。宿主读取已审阅源码并通过官方控制台投递字面代码，禁止游戏Lua读取文件/loadstring。见[验证参考](verification.md)。
- 检查实际callback结果与cleanup=true，再做客户端GM发钱、预览/确认、新实例/账本读回、金额委托、关闭重开。
- 原生LuaCheck必须有passed日志。扫描无敏感调用或普通语法通过不能替代它。
- 云持久化、重连、真实云延迟、跨系统并发和进程崩溃需独立验收。
