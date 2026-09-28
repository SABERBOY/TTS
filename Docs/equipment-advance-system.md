# 装备升阶系统与 GM 验证

更新：2026-09-24。实现范围为独立升阶逻辑、原生背包适配、实例数据继承、Controller RPC 和 GM。未修改 UIBP、装备蓝图属性/技能、掉落、商店或原槽位强化的消耗规则。

后续调整请从[维护手册](equipment-advance-maintenance.md)进入；可复用 Codex skill 的项目源码见[tts-equipment-maintenance](skills/tts-equipment-maintenance/SKILL.md)。

## 规则与配置来源

以本次确认的实施方案为准：**目标和材料必须是相同 ItemID 的不同实例**。参考 `TEMP/装备系统-策划配置表.xlsx`、`TEMP/equipment-system-design-confirmed.md` 的阶位、强化门槛、数量和费用；文档旧规则不覆盖本次确认规则。现有装备映射经过编辑器 `UGCBattleItem` 和物品资产读取核对。

物品品质仍读取原生 ItemQuality。升阶使用独立的 RankID、Major、Minor 和 Order，不通过品质、显示名称或 ID 加减推算。系列仅用于验证下一阶段配置，不能作为材料匹配条件。

配置数据现存于UE的 `Asset/Data/Table/Customized` 目录。`Script/Blueprint/Prefabs/UI/Equip/Advance/EquipAdvanceConfig.lua` 仅负责读表、转换字段、校验和构建原有接口，不再内置三组配置数据。材料数量不含目标。

### UE表格维护

| 表格 / 行结构体 | 行名 | 字段（UE类型） |
|---|---|---|
| EquipAdvanceRank / EquipAdvanceRankRow | RankID，例如R05_PURPLE_1 | RankID(Name)、Order(Integer)、DisplayName(String)、Major(Integer)、Minor(Integer)、Cap(Integer)、RecycleParts(Integer) |
| EquipAdvanceRule / EquipAdvanceRuleRow | 当前RankID，例如R05_PURPLE_1 | RankID(Name)、Materials(Integer)、Gold(Integer)、Diamond(Integer) |
| EquipAdvanceItem / EquipAdvanceItemRow | ItemID，例如8310102 | ItemID(Integer)、Series(Name)、SlotIdx(Integer)、RankID(Name)、NextItemID(Integer) |

初始数据量分别为12、11、39行。阶位表的DisplayName转换为Lua的Name；映射表的RankOrder通过RankID自动取得，不需要人工填写；NextItemID=0转换为nil。RankID、ItemID必须与行名一致。固定六大阶、十二阶段，Order为连续1—12，Major/Minor保留原阶段含义；Cap必须逐阶增加且不超过180，末阶Cap=180。材料数量为正整数，货币和回收参考值为非负整数。红+2不配置消耗规则。

修改费用：在EquipAdvanceRule找到当前阶位行，改Gold/Diamond/Materials。修改门槛/显示名：在EquipAdvanceRank改Cap/DisplayName。补充装备路线：在EquipAdvanceItem新增行，并修改前一件的NextItemID。物品品质、属性和技能仍在现有装备资产中维护。

保存三张表后重新启动PIE。客户端与服务端各自在首次实际查询时通过GetTableData读取保存的UE资产，每次运行缓存一次；不支持正在运行中的热换表。任何一张表缺失或结构不合法，整个升阶配置保持为空，日志输出 `[EquipAdvanceConfig] DISABLED`，GM自检的Errors显示原因，不会静默使用旧的硬编码费用。

LuaCheck会在游戏世界尚未初始化时导入所有脚本。配置模块因此不在导入时调用原生接口；原槽位模块的阶位元数据复制也从导入阶段移到GetRank实际查询时执行。这是唯一额外的原系统加载时机调整，业务规则和Controller RPC不变。游戏内只使用官方UGC资源/数据表API；工程Lua测试也不使用io、dofile、loadfile或动态源码加载，离线测试由Python读取快照和源码。

`Tests/Fixtures/EquipAdvanceTables.json` 是原值迁移及回归测试快照，**不是运行时备用配置**。有意调整配置后，需要更新对应测试期望；不能把修改测试快照当成修改游戏数据。

| 当前阶→下一阶 | 当前阶强化门槛 | 材料 | 金币 8310084 | 钻石 8310132 |
|---|---:|---:|---:|---:|
| 白→绿 | 10 | 1 | 100 | 0 |
| 绿→蓝 | 20 | 1 | 200 | 0 |
| 蓝→紫 | 30 | 1 | 400 | 1 |
| 紫→紫+1 | 45 | 1 | 500 | 1 |
| 紫+1→紫+2 | 60 | 2 | 650 | 1 |
| 紫+2→橙 | 75 | 1 | 800 | 2 |
| 橙→橙+1 | 90 | 1 | 950 | 2 |
| 橙+1→橙+2 | 105 | 2 | 1100 | 2 |
| 橙+2→红 | 120 | 1 | 1400 | 4 |
| 红→红+1 | 140 | 2 | 1700 | 4 |
| 红+1→红+2 | 160 | 3 | 2200 | 6 |

红+2的强化上限为180，也是升阶终点。单条路线逐次升阶直接费用为10000金币、23钻石，不包含制造材料装备的投入。

## 已接入资产

以下顺序是**显式配置的路径**，不是运行时计算规则。共39件、12个系列。目前12条路线均在红+2之前缺少下一阶段。

| 系列 | 策划槽位 | 白开始的已配置 ItemID 顺序 | 当前末端 |
|---|---:|---|---|
| EQ_SHOES_02 | 6 | 8310093 | 白 |
| EQ_SHOES_01 | 6 | 8310095 → 8310094 | 绿 |
| EQ_HEAD_02 | 1 | 8310097 → 8310096 | 绿 |
| EQ_HEAD_01 | 1 | 8310099 → 8310098 | 绿 |
| EQ_GLOVE_02 | 4 | 8310106 → 8310105 → 8310104 → 8310103 → 8310102 → 8310101 → 8310100 | 橙 |
| EQ_GLOVE_01 | 4 | 8310113 → 8310112 → 8310111 → 8310110 → 8310109 → 8310108 → 8310107 | 橙 |
| EQ_CHEST_02 | 2 | 8310115 → 8310114 | 绿 |
| EQ_CHEST_01 | 2 | 8310117 → 8310116 | 绿 |
| EQ_BELT_02 | 5 | 8310119 → 8310118 | 绿 |
| EQ_BELT_01 | 5 | 8310121 → 8310120 | 绿 |
| EQ_ACCESSORY_02 | 3 | 8310128 → 8310127 → 8310126 → 8310125 → 8310124 → 8310123 → 8310122 | 橙 |
| EQ_ACCESSORY_01 | 3 | 8310131 → 8310130 → 8310129 | 蓝 |

缺失阶段返回 `NextItemMissing`，不扣资源。配置存在但原生资产不可用返回 `NextAssetUnavailable`。配置自检的 `Errors` 表示错误；`Missing` 列出尚未补齐的路线。因此 `ConfigCheck OK=true` 可以同时出现12项 Missing，不能据此理解为全路线资产已齐。

补充资产时通过编辑器创建并保存装备及数据表行，再明确填写 `EquipAdvanceItem` 的新行和前一阶段 `NextItemID`，重启PIE并执行 GM 自检。适配层要求装备 `ShouldPersist=true` 且 `MaxNumberOfStacks=1`。不要通过外部脚本改写 uasset。

槽位编号：1头盔、2胸甲、3饰品、4手套、5腰带、6鞋。手套和腰带本轮没有新增原生穿戴槽，仅支持背包升阶及对应强化门槛测试。

## 模块边界

| 模块 | 职责 |
|---|---|
| EquipAdvanceConfig | 阶位、费用、ItemID路径和配置自检 |
| EquipAdvanceData | CustomData复制、签名、保护/安全选材规则、账本合法性 |
| EquipAdvanceSystem | 可注入背包适配器的纯 Lua 预览、执行、幂等和补偿事务 |
| EquipAdvanceRuntime | 原生背包实例、CustomData、货币、穿戴、属性和 GM 服务 |
| EquipAdvanceGuard | 仅对事务中新建实例限制自动穿戴 |
| EquipAdvanceRPC | Controller薄转发和结果回复 |
| EquipAdvanceClient | 客户端预览/确认桥接、结果日志，预留UI回调 |
| EquipAdvanceGM | 批量货币/装备包、明确确认的一次合成选择与结果汇总 |

原系统的必要接入：

- `EquipSlotSystem.GetEquipRankOrder` 优先读新配置；未接入装备仍走原品质映射，但不能参与新升阶。既有阶位数值列保留，阶位名称/门槛元数据共用新配置。
- `EquipSlotAttrApplier` 的装备快照加入完整实例身份和阶位，避免同 ItemID 换实例时漏刷新。
- `BP_BackpackComponentV2_Custom.CanAutoEquip` 仅检查事务的新实例守卫，其他物品走原父类行为；不改蓝图CDO的自动穿戴开关。
- `UGCPlayerController` 注册预览、执行、GM RPC及结果回调，结束时释放该Controller的服务。
- `Script/utils/gm.lua` 增加“装备系统 → 装备升阶”。

## 实例数据与事务

实例 Key 格式为 `Type:TypeSpecificID:InstanceID`，例如 `831:8310131:94`。最后一段必须通过原生 `BackpackUtils.GetItemInstanceID` 读取；不能把 ItemID 当实例身份，也不能依赖未反射的 `DefineID.InstanceID` 字段。

正常数据沿用原生背包和 CustomData，不保存第二份完整背包。升阶命名空间如下：

```lua
CustomData.EquipAdvance = {
    Version = 1,
    Gold = 0, Diamond = 0, MaterialParts = 0,
    Locked = false, Tracked = false, Reserved = false, InTrade = false,
    Viewed = true,
}
```

保留目标的全部自定义字段（包含词条）和保护状态；材料的普通词条不覆盖目标。累计账本 = 目标历史 + 本次费用 + 所有材料历史；`MaterialParts` 还增加每件材料当前阶位的基础回收材料参考值，仅为后续回收预留，不发放资源。账本非负整数、有版本和范围校验。读取时超过512字节的原实例拒绝参与；新实例保存后也检查大小和字段读回，失败进入补偿。

白/绿/蓝可省略材料自动选择，但仅选择已标记 `Viewed=true`、未穿戴、未保护、未占用、无历史投入的相同ID实例。旧UI目前没有可靠的Viewed写入，所以未知状态默认不自动消耗；可显式传材料，或者由GM设置Viewed。GM生成的测试装备默认Viewed=true。紫及以上必须显式传材料并确认。

已穿戴、Locked、Tracked、Reserved、InTrade以及有原生父/子物品附加关系的材料不可消耗。目标允许Locked/Tracked并继承，Reserved/InTrade和附加关系阻止操作。根级兼容保护字段也会检查。

执行顺序：服务端重新读取归属/数量/保护/槽位等级/余额/下一阶；加玩家互斥；保存快照；先逐实例移除材料腾空背包，再卸下/移除目标；扣款；分配下一阶实例、保存CustomData、加入背包；恢复目标原穿戴槽；刷新属性。背包目标仍留背包。每一步检查返回值和关键原生读回。

预览有效期120秒，最多保留32份；请求缓存最多128项。请求号复用同token返回原结果，换token返回冲突。执行会重验当前状态与实例数据签名。成本和目标ItemID均由服务端产生。

失败时先清理已生成输出，再以新实例恢复已销毁输入、原穿戴状态和确切货币余额。返回 `RestoredKeys[旧Key]=新Key`，调用端必须刷新旧引用。补偿失败返回 `RecoveryRequired` 并阻断后续升阶；失败参与者和错误记录进入 `EquipAdvanceRecovery` 玩家档案键及内存缓存，记录保存失败也会明确返回。没有自动清除恢复记录的GM命令，需根据原生背包与记录核对后人工修复。成功的CustomData/API返回不代表已经验证跨对局落盘。

## GM 操作

### 一键测试（2026-09-24补充）

打开“装备系统 → 装备升阶”，按顺序点击：

1. **一键添加升阶货币**：每次增加100000金币和1000钻石；任何时候都可再点，不是补到固定余额。
2. **一键添加升阶装备**：每条已配置且存在下一阶段的配方，添加一组目标加材料。当前27条可用配方共57件，覆盖低阶与紫色小阶；末端缺少下一阶的物品不单独批量发放。可重复点；背包满或保存/添加失败则停止，返回实际添加数量，已添加的装备保留。新装备不会自动穿戴。
3. **全部测试槽位强化至180**：一次设置6槽运行时强化等级，满足现有升阶门槛；不主动保存等级，测试后按需恢复。
4. **自动合成一次（确认消耗材料）**：每次只执行一次合成；可反复点击直到返回“当前背包没有满足条件的升阶组合”。优先低阶，然后按ItemID和实例Key排序，在整个背包中选择相同ID的一组。不会自动补货币、补材料或提高等级。

第四个按钮是明确授权的GM快捷确认，可自动指定紫阶及以上材料，也可继续消耗带历史投入的合成产物；正常预览/手动确认流程的安全自动选材规则不变。它跳过穿戴、锁定、追踪、占用及异常实例，保留原服务端等级、费用、相同ID校验及事务补偿。发生事务失败时本次点击立即结束，不再换一组尝试。失败原因按 `Reasons` 汇总输出；有保护装备或缺少下一阶资产时，背包中仍有装备也可能无法继续升阶。

新增逻辑在 `EquipAdvanceGM.lua`，通过既有GM RPC调用，无新Controller RPC。新增请求号防止同一次自动合成请求重复扣除资源。所有入口仍检查服务端GM权限与恢复阻断。新增纯Lua测试覆盖重复加钱、57件配方包、满背包部分添加、逐次合成至结束、紫阶快捷确认、历史投入延续、保护/余额/等级限制与GM权限。

### 手动精确测试

在开启原生服务端GM权限的 PIE/DS 中使用“装备系统 → 装备升阶”。所有新增GM写操作都检查 `UGCGameSystem.IsEnableGM(pc)`。结果输出在客户端Lua日志，前缀 `[EquipAdvance]`；实例Key从“列出装备实例”复制，不能照抄本文示例编号。

白饰品测试：

1. “添加升阶测试物品”依次输入 `8310131 2`、`8310084 1000`。
2. “设置测试强化等级”输入 `3 10`。
3. “列出装备实例”，找到两个不同的 `8310131` 实例Key。
4. “预览升阶”输入 `目标Key 材料Key`（此例可只填目标Key自动选择）。确认结果为 Ready、下一阶8310130、100金币。
5. “确认上次升阶预览”输入大写 `YES`。
6. 再列实例：原两件消失，新生成一件8310130，背包目标不会自动穿戴。已有预览失效或材料变化时重新预览。

用户示例的紫+1手套测试：

1. 添加 `8310102 3`、`8310084 650`、`8310132 1`，设置测试等级 `4 60`。
2. 列出三个不同实例Key；预览输入 `目标Key 材料Key1 材料Key2`。
3. 预览应为8310102→8310101、650金币、1钻石、需确认；输入 `YES` 后得到一个8310101背包实例。

穿戴路径可使用饰品 `8310124 3`、槽位等级 `3 60`，先用现有装备操作穿戴其中一件作为目标，再预览/确认升至8310123。材料必须都在背包且未保护。

保护测试输入 `材料Key Locked true`，预览应返回MaterialProtected；改回false才能使用。测试新GM不会主动写强化等级存档，但该等级在当前角色内真实生效，测试后应手动恢复；后续其他系统主动保存等级时仍可能保存当前值。GM添加的装备/货币是真实原生物品，不会自动清除。

## 接口与错误

服务端：

```lua
local R = require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceRuntime')
local s = R.GetService(pc)
local candidates = s:Candidates(targetKey)
local preview = s:Preview(targetKey, {materialKey1, materialKey2})
local result = s:Execute(preview.Token, requestID, true)
```

客户端应通过 `EquipAdvanceClient.Preview(targetKey, materialKeys)`、`Confirm(true)` 调用。可读取 `LastResult`、`LastPreview` 或设置 `OnResult(result)`。Controller只接受实例Key/预览token、请求号和确认状态，不接受客户端决定的消耗/下一阶ID。UI接入时应直接展示预览字段，并在失败/成功后刷新实例列表；自动重试应复用同一个请求号，不能重新生成请求号当作幂等重试。

成功预览含 TargetKey、ItemID、RankID/RankOrder/Major/Minor、NextItemID/NextRankID、SlotIdx、Level/RequiredLevel、MaterialKeys、Gold/Diamond、RequiresConfirmation、Token/Expires。失败返回OK=false和Code；强化不足附带Level和RequiredLevel。候选列表同ID，但Allowed/SafeAuto仅供选择提示，最终执行仍完整校验。

| Code | 含义/处理 |
|---|---|
| NextItemMissing / NextAssetUnavailable | 下一阶段配置/可用资产缺失，补齐后再测 |
| LevelTooLow / NotEnoughGold / NotEnoughDiamond | 门槛或余额不足，无扣除 |
| MaterialItemMismatch / DuplicateInstance | 不同ItemID、重复实例或目标充当材料 |
| MaterialProtected / TargetBusy | 穿戴、保护或占用状态阻止 |
| MaterialCountMismatch / ManualMaterialsRequired | 材料不足或必须手选；自动候选可能被安全规则排除 |
| ConfirmationRequired | 紫及以上必须明确确认 |
| PreviewExpired / PreviewMissing / PreviewStale | 重新预览 |
| TransactionFailed | 执行失败，补偿已完成；按RestoredKeys刷新 |
| RecoveryRequired | 补偿未完成，停止继续操作并查看恢复记录 |
| ReadFailed / ServerError | 原生读取/服务端异常，查看服务端日志 |

## 已执行验证与边界

纯Lua5.1测试：`python Tests/run_equipment_tests.py`，使用已安装的Lupa（`lupa.lua51`），原23组业务测试和新增17组读表测试通过。读表测试覆盖导入阶段零原生调用、首次查询加载、乱序行、字段转换、修改费用确实生效、缺表、重复序号、错误RankID、缺失消耗规则、行名不一致、重复系列阶段、跳阶/跨系列/循环路线、非法费用/材料/门槛/槽位/大阶小阶；任何失败都原子拒绝发布三组配置。业务测试覆盖全部11条费用/数量规则、独立小阶、旧装备兼容、同ID约束、自动选材、保护/归属/等级/余额、过期/重复请求、账本、满背包及移除/扣款/保存/生成/穿戴故障补偿和补偿失败阻断。

用户报告的 `merge historical ledgers exactly once` 断言已修复：原测试带历史投入的材料被安全自动选材排除；现在明确指定材料，并额外断言自动选择会排除它。账本期望值仍为150金币、5钻石、21材料参考值，未放宽生产选材规则。测试模块只在显式 `.Run()` 时运行，导入/LuaCheck不会执行故障测试。

真实单客户端PIE/DS：`Tests/EquipAdvancePIE.lua` 的6项检查通过，测试完成清理=true。包括：强化不足零扣款；背包白→绿及重复请求；绿→蓝及缺失紫阶拒绝；穿戴紫+1→紫+2、手选确认及属性重复刷新不叠加；创建保存失败后的原生补偿；原生穿戴已经成功但适配器返回失败后的装备/金币恢复。测试需在GM服务端显式调用Run(pc)，会创建带标记测试装备并恢复测试前货币、等级、穿戴及攻击值，不在LuaCheck中自动执行。Tests不在运行模块打包路径中，真实DS不能依赖require加载它；本次通过宿主工具读取已审阅源码，再作为字面代码投递官方Lua控制台执行，具体方式见[维护手册第7节](equipment-advance-maintenance.md#73-真实-pieds-测试装载)。游戏Lua不使用文件读取或动态源码装载。

客户端→Controller RPC→服务端→客户端同步另行实测通过：调用GM配置自检和确认入口，白饰品合成绿饰品，客户端原生背包读回新ItemID、自定义标记、100金币账本及旧实例消失；测试物品和状态已清理。39件装备资产检查及两种货币ShouldPersist读回通过。

新增快捷GM的原生测试为 `Tests/EquipAdvanceGMPIE.lua`，显式 `.Run(pc)`。在DS实测重复加钱、一次57件、6槽180、逐次27次合成后无可用组合，剩27件；每次重发同请求都未多扣材料。测试选择范围隔离到新生成物品，结束已恢复货币/等级并清理全部测试装备。

DataTable迁移验收（2026-09-24）：六个原生资产已保存，三张表的12/11/39行与原配置快照逐字段一致。编辑器LuaCheck在17:27及17:31两次明确通过。原生GetTableData返回可用pairs遍历的TableStruct userdata，配置模块将其整理为普通Lua配置，不以type==table作为唯一有效条件。

`Tests/EquipAdvanceTablePIE.lua` 提供显式 `Run(pc, expectedWhiteGold)` 测试。实测原值100金币的预览/扣款、8310102→8310101的2件材料/60级/650金币/1钻石，以及缺失下一阶零扣款全部通过；迁移后的整套快捷GM测试也通过。随后只改UE表内白阶Gold为137、保存并重新启动PIE，未经模块替换的客户端读取137、GM自检通过、DS预览及实际扣款137，测试资源清理成功。验收后停止PIE、恢复表内Gold=100并保存，三张表全部重新核对原值一致。

证据摘要见 `Docs/equipment-advance-verification.txt`。真实DS未覆盖满背包故障（此项为纯Lua适配器测试）、多客户端并发、断线重连、原生跨对局恢复及进程崩溃时跨存储一致性；应作为后续验收项。属性验证检查了穿戴切换及重复刷新无叠加，未逐项遍历39件装备的每个技能效果。UIBP仍待后续接入。
