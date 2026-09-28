# TTS 装备升阶维护手册

维护基线：2026-09-28（配置与事务基线保持2026-09-24）。本文用于后续改表、补装备路线、调整 GM/UI、排查事务和 LuaCheck 问题。实际修改前应读取当前代码与保存的 UE 表，行数、费用和验证结果不是永久固定值。

## 1. 入口与资料分工

| 资料 | 用途 |
|---|---|
| [系统说明](equipment-advance-system.md) | 完整规则、字段、39件装备路线、事务、GM操作及接口 |
| 本手册 | 调整步骤、故障排查、测试方式与交接要求 |
| [验证证据](equipment-advance-verification.txt) | 已执行测试的时间、会话、日志标记和验证边界 |
| [升阶 UI 维护](equipment-advance-ui.md) | 玩家操作、控件绑定、请求状态机、生命周期、原生布局与交互测试 |
| [维护 skill 源码](skills/tts-equipment-maintenance/SKILL.md) | 让 Codex 按本项目约束开展后续工作 |
| [测试快照](../Tests/Fixtures/EquipAdvanceTables.json) | 三张 UE 表的迁移/回归基线，不参与游戏运行 |

项目根目录：`E:/WeGameApps/rail_apps/OasisEraEditor(2001776)/ShadowTrackerExtra/UGCProjects/TTS`。本文未带根的路径均相对该目录。

生产配置的唯一来源是**保存后的 UE DataTable**。Excel、旧设计文档和 JSON 快照供核对使用，不能覆盖已确认规则，也不能作为读表失败后的备用数值。

## 2. 不应在维护中改变的约定

- 升阶模块位于 `Script/Blueprint/Prefabs/UI/Equip/Advance`，不恢复旧的 `Script/Equipment` 目录。
- 相同 ItemID 的不同实例才能合并。系列、原生品质、显示名称相同均不足以作为材料条件。
- 六大阶、十二阶段、强化最高180是现有代码契约。物品品质 ItemQuality 与装备 RankID 分开维护。
- 材料数量不含目标。使用金币8310084、钻石8310132；不顺带修改原槽位强化经济。
- 保留装备蓝图配置的属性和技能；本系统生成下一阶段原生物品，不复制旧装备的蓝图配置替代新物品。
- 游戏 Lua 及工程内 Lua 测试禁止引入文件读写、进程执行和动态源码加载，例如 `io.*`、`dofile`、`loadfile`、`loadstring`、`os.execute`、`package.loadlib`。不要用这些方法绕过 UGC 资源接口或调试装载限制。离线 Python 读取源码/快照与游戏 Lua 是不同执行环境。
- `.uasset`、结构体、DataTable 由 UE 编辑器/原生编辑器工具维护，不能用外部二进制写入替代原生保存。
- 不把 `pcall` 当作非法 API 或过早原生调用的解决办法；它不能撤销引擎已经记录的错误。

## 3. 需求到修改位置

| 需要调整 | 首选位置 | 一般是否需要业务代码 |
|---|---|---|
| 名称、当前阶强化门槛、回收参考值 | EquipAdvanceRank | 否，仍须满足固定结构约束 |
| 材料数量、金币、钻石费用 | EquipAdvanceRule | 否 |
| 增加某系列的下一阶段、增加新系列 | EquipAdvanceItem + 对应原生装备/UGCBattleItem | 通常否，需新增有效资产 |
| 原生品质、装备属性、技能 | 原物品资产及对应配置 | 不在升阶表中修改 |
| 阶段超过12或等级超过180 | Config + 原槽位系统 + 调用方 + 测试 | 是，另做整体设计 |
| 更换货币 ItemID | EquipAdvanceConfig 及 GM/测试中引用 | 是，不能只改费用表 |
| 一键发放数量、自动合成选择顺序 | EquipAdvanceGM | 是 |
| 玩家侧自动选择/确认规则 | EquipAdvanceData、EquipAdvanceSystem | 是，不能照搬 GM 特例 |
| 背包原生 API 或装备槽变化 | EquipAdvanceRuntime、原生背包/槽位接入 | 是 |
| 自定义字段、投入账本、恢复逻辑 | EquipAdvanceData、EquipAdvanceSystem、Runtime | 是，需故障测试 |
| 升阶 UI | EquipAdvanceViewModel/UIRender/Client + Transform UIBP | 已接入，不把事务放在 UI |

原生资产目录为 `/TTS/Asset/Data/Table/Customized`，磁盘对应 `Asset/Data/Table/Customized`。

## 4. 表格调整流程

### 4.1 改一次费用或材料数量

1. 在编辑器打开 `EquipAdvanceRule`，选择**升阶前**的 RankID 行。
2. 修改 Materials/Gold/Diamond。Materials 必须为正整数，货币必须为非负整数；材料不包含目标。
3. 保存资产并重新读取该行，核对字段和数值。不要把编辑器 UI 未保存状态当作运行配置。
4. 停止当前 PIE，重新启动，等客户端角色和 DS 就绪。配置在每个运行端首次访问时加载并缓存，不热更新；一次加载失败也会缓存失败，需要修复后重启。
5. GM 自检，查看 Errors 与 Missing；预览检查费用，执行后检查真实扣款和新实例。客户端和 DS 都需读取新值。
6. 有意长期调整时，同步测试快照、相关断言和设计说明；临时验收调整则恢复原值、保存并回读。

示例：`R05_PURPLE_1` 对应紫+1升紫+2，基线 Materials=2、Gold=650、Diamond=1。它不表示升到紫+1。红+2没有规则行。

已验证的改表验收方式：把 `R01_WHITE.Gold` 从100临时改为137，保存、重启，检查客户端读取137且 DS 预览/扣款137；验收后恢复100并保存。无需替换运行中的 Lua 配置模块。

### 4.2 改名称、强化门槛或回收参考值

在 `EquipAdvanceRank` 修改 DisplayName/Cap/RecycleParts。

- DisplayName 会转换成旧调用方使用的 `Name`。
- Cap 既是当前阶段强化上限，也是升到下一阶段的门槛；十二个值必须严格递增、最大180、末阶180。
- RecycleParts 仅影响后续合成时新增的材料投入参考账本，不会发放资源，也不会自动回写已经保存的历史账本。
- RankID、Order、Major、Minor 保持结构含义；只改显示文字无需改 RankID。不要通过重命名 RankID 来“换颜色”。

维护门槛后测试门槛以下一级的拒绝和正好达标的成功；测试时目标所属逻辑槽位必须正确。已有角色永久强化等级不会随改表自动迁移，跨越新上限的存量数据处理应单独评估。

### 4.3 补齐下一阶段资产

1. 先在编辑器创建/确认下一阶段装备资产及 `UGCBattleItem` 行；它必须有独立 ItemID，资产可加载，持久化开启，堆叠上限1。
2. 在 `EquipAdvanceItem` 新增行，RowName=ItemID十进制文本；填 ItemID、Series、SlotIdx、RankID、NextItemID。
3. 将前一阶段的 NextItemID 填为新ID。两行必须同Series、同SlotIdx，阶位 Order 恰好相差1。
4. 新阶段尚无后续资产时填 NextItemID=0；不要填虚构ID，也不要跳过缺失阶段。
5. 保存资产、回读表格、重启PIE、自检；检查 Missing 中原缺口是否移动到新末端。新增行后39件、12项Missing、57件包等基线断言需要按实际新路线复核。
6. 实测前一阶段生成新物品、账本继承和属性/技能切换；新末端应拒绝升阶且零扣款。

新增系列同样处理。系列每个阶段只能有一行，同系列不跨逻辑槽位。不能根据ID差值推导关系。例 `8310102 → 8310101` 是表中显式配置，不是所有装备均遵循的数学规则。

逻辑槽位：1头盔、2胸甲、3饰品、4手套、5腰带、6鞋。手套/腰带目前只有背包升阶和门槛测试；填表不会自动增加原生穿戴槽。

### 4.4 改结构体字段

日常改数值不用改 RowStruct。确需改字段时，应同步评估加载器转换、所有调用接口、测试快照和旧数据兼容，再在编辑器修改结构体、保存、检查受影响表的所有行。不能只改一张表的列名。

保留 RowName 校验：Rank/Rule 行名等于 RankID，Item 行名等于 ItemID。原生 JSON 导出的 `Name` 是行名；阶位显示字段是 `DisplayName`。Item 表没有人工 RankOrder，它由 RankID 查表产生。

## 5. 代码边界和易破坏的机制

完整模块职责见系统说明。维护时先定位需求所属层，再修改最小范围。

### 配置加载

`EquipAdvanceConfig` 的公开数据为 Ranks[Order]、Rules[Order]、ItemRows、Items[ItemID]。`Validate(assetReady)` 返回 Errors/Missing。三表通过结构校验后才一起发布，任一失败不发布部分数据，不回退硬编码。

导入模块时不能实际读取 UE 表；首次数据查询才加载。`EquipSlotSystem.GetRank()` 的元数据同步也必须保留在查询阶段。LuaCheck 会执行模块顶层代码，此时 UGC 根路径可能尚未初始化。

运行时路径通过官方 `GetUGCResourcesFullPath` 解析，再传 `GetTableData`。原生返回 `TableStruct userdata`，需要用其支持的 `pairs` 转成普通 Lua 表。不要只接受 `type(raw)=='table'`，也不要对原生 userdata 直接使用 `next`。

### 实例身份与自动穿戴

实例Key由Type、TypeSpecificID和 `BackpackUtils.GetItemInstanceID` 组成。不同实例可能有相同ItemID，属性刷新和事务都必须按完整身份处理。原生 DefineID 的 `.InstanceID` 不是本次验证可依赖的反射字段。

生成输出和补偿输入时使用事务局部 Guard 阻止自动穿戴，再显式恢复原目标穿戴位置。不要修改所有装备蓝图的全局自动穿戴开关。守卫生命周期需在成功与失败路径都释放。

### 账本和保护字段

普通自动选材仅用于白/绿/蓝，且要求 Viewed=true、没有历史投入、未穿戴/保护/占用。紫及以上明确选材并确认。GM“一次合成”有单独的明确确认行为，可以选择历史产物；玩家流程不能借用这个例外。

目标完整CustomData继承；目标与材料的历史投入均合并一次。目标普通词条保留，材料词条不覆盖它。新增字段需检查512字节限制、读回签名、根级保护字段兼容与旧Version处理。

`merge historical ledgers exactly once` 曾因测试让自动选择消耗历史材料而失败。正确修复是测试显式选择该材料，并继续断言自动选择排除它；不能删除生产安全规则。

## 6. GM 日常验证

入口为“装备系统 → 装备升阶”。所有写操作由服务端原生 GM 权限限制，按钮可见不代表服务端允许执行。

快捷顺序：加货币 → 加装备 → 测试槽位至180 → 自动合成一次，重复第四步。

| 按钮 | 当前行为 | 维护提醒 |
|---|---|---|
| 一键添加货币 | 每次增加100000金币、1000钻石 | 可重复；真实资源，测试后按需恢复 |
| 一键添加装备 | 每个已配置有效配方添加目标+材料，基线57件 | 非完整白装培养树；满包停止并保留已成功添加的物品 |
| 测试槽位至180 | 六槽运行时等级设置为180 | 不主动存档，但后续其他系统保存可能持久化当前值 |
| 自动合成一次 | 每点最多一次事务，按阶位、ID、Key选择 | 不自动加钱/补装备/提等级；失败不换下一组继续扣 |

`NoAdvanceAvailable` 应查看 Reasons，不等于“背包为空”。保护、缺材料、缺钱、门槛、缺下一阶段均可能导致停止。基线隔离测试中57件经过27次合成后剩27件；真实有其他装备的背包不应强行断言这个数量。

手动重点用例：添加3件8310102，金币650、钻石1，槽4等级60；明确指定目标和另两件材料，预览应为8310101，确认一次只得到一件新实例。把等级改59、材料锁定、材料重复、换为别的ItemID，分别检查零扣款拒绝。

## 7. 验证操作和证据等级

### 7.1 离线回归

在项目根使用 `pwsh`，执行：

```powershell
python Tests/run_equipment_tests.py
```

依赖Python的 `lupa.lua51`。2026-09-28基线为17组配置测试+23组业务测试+9组UI状态测试，以及逐字段快照比较。运行器在宿主Python读取文件，再执行Lua；项目Lua内不自行读文件。若Python环境不匹配，先确认当前Python和Lupa安装，不在游戏脚本中加入临时加载器。

此测试验证规则和适配器故障处理，不能代替原生 userdata、真实背包、RPC或持久化验收。

快照更新必须来自**保存表的原生JSON导出**：按 EquipAdvanceRank/Rule/Item 三个键保留各表行数组（包括Name行名），比较字段、数据类型和行名后更新 `Tests/Fixtures/EquipAdvanceTables.json`。不要根据期望结果手造一份快照后声称已经核对UE。新增路线或改经济可能影响固定断言，逐项解释并调整，不批量替换所有数字以“让测试通过”。

### 7.2 LuaCheck

执行编辑器真实 LuaCheck，查看明确的 `lua file validation passed`。`luacheck` 普通语法工具、Python编译Lua成功和 `check.json update successfully` 都不等同于原生检查通过。

Tests目录也会被检查。Lua测试模块只返回对象，必须显式 `.Run()`；导入时不能运行测试、读表或读文件。只扫描到没有敏感词不是完整平台兼容证明，仍要运行真实检查。

### 7.3 真实 PIE/DS 测试装载

现有显式测试入口：

| 源码 | 入口 | 覆盖 |
|---|---|---|
| Tests/EquipAdvancePIE.lua | Run(pc) | 6组原生成功、补偿、穿戴与刷新检查 |
| Tests/EquipAdvanceGMPIE.lua | Run(pc) | 快捷货币/装备包/27次合成/幂等/清理 |
| Tests/EquipAdvanceTablePIE.lua | Run(pc, expectedWhiteGold) | 表读取、实际费用、手套小阶、缺失下一阶零扣款 |

这些文件不在 Script 的运行打包路径内；真实 DS 中不能依赖 `require('Tests.EquipAdvancePIE')`，本次实测该方式返回nil。不要为此加入 Lua 文件读取或动态加载。

已使用的方式是：宿主工具读取已审阅测试源码，将源码作为立即执行函数体，通过编辑器官方 Lua 控制台投递**字面代码**到已就绪的测试DS，再调用返回对象的Run。结构如下（尖括号是替换说明，不可原样执行）：

```text
local T = (function()
<由宿主工具填入 Tests/EquipAdvanceTablePIE.lua 的完整源码>
end)()
T.Run(UGCGameSystem.GetAllPlayerController()[1], 100)
```

只用于已启用GM权限的隔离测试角色。运行前读测试源码，检查它对当前配置的固定假设；已有多个玩家时显式选定测试Controller，不盲目取第一个。工具参数通过当前 `ue_pie` 文档确定，不猜测工具签名。此方法不把配置模块替换为测试数据，仍读取保存的UE表。

三份测试会操作真实原生资源，并尝试清理测试物品、恢复相应状态。必须同时检查业务成功和 `cleanup=true`；故障中断后先查测试标记与恢复记录再重跑。更详细的宿主组装步骤见 skill 的 [验证参考](skills/tts-equipment-maintenance/references/verification.md)。

### 7.4 客户端/RPC与持续性

DS通过之后，客户端执行GM自检和一次预览/确认，检查回调、原生背包新实例、旧实例消失及账本。配置调整需要在新启动客户端和DS分别确认读到新值。

跨对局保存要单独以正常退出、重新进入、读取原生实例/CustomData验收；仅Save成功不能证明落盘。多客户端、断线重连和进程崩溃场景也不能从单客户端成功推断。记录具体日志、时间、会话和资源清理结果，向验证证据文件追加本轮结果，不改写旧证据。

## 8. 故障速查

| 现象 | 优先核查 | 处理 |
|---|---|---|
| LuaCheck报Path starts with Asset / GetTablePtr not found | 模块导入是否触发配置读取、原槽位顶层是否访问C.Ranks | 恢复惰性读取；运行时仍通过官方路径解析，避免硬编码/TTS掩盖时机问题 |
| 游戏运行期仍报表不存在 | 表是否保存、名称/对象路径是否一致、当前项目根与启动阶段 | 在编辑器原生加载表核查，修复后重新启动 |
| 表明明存在但TableMissing/禁用 | 是否错误拒绝userdata或字段类型不匹配 | 支持原生pairs，核查原生行字段和RowName |
| 修改表后仍是旧费用 | 当前会话是否已缓存、是否只改了JSON/未保存UE表 | 保存并完整重启，分别查客户端和DS |
| Errors=0，Missing=12 | 基线12条未完整到红+2的路线 | 合法不完整状态；缺口禁止合成，不填假资产 |
| 自动选材找不到有历史投入的装备 | Viewed/保护/账本状态 | 普通流程显式选材，或明确使用GM快捷确认 |
| require Tests返回nil | Tests不在运行模块打包路径 | 使用官方控制台的显式字面测试代码，禁止游戏文件装载 |
| GM不执行或无回调 | 服务端GM开关、角色/控制台注册、Controller RPC | 等就绪后验证权限和RPC，不绕过服务端检查 |
| 属性没变/重复加成 | 完整实例快照、旧装备卸下、新装备原槽位与刷新 | 检查EquipSlotAttrApplier及原生穿戴状态 |
| TransactionFailed | 逐步返回值、补偿结果 | 按RestoredKeys刷新引用，再次预览 |
| RecoveryRequired | 记录、余额、生成输出与补回输入 | 保留阻断并人工核对，不能清记录后盲目重试 |
| 日志只有第一个参数 | 原生print参数行为 | 用字符串拼接或string.format输出单字符串 |

## 9. 补偿失败处理

1. 停止该玩家继续升阶。保存当前原生实例列表、货币余额、穿戴状态和GM恢复记录输出。
2. 对照 `EquipAdvanceRecovery` 中参与物品、原状态和失败步骤，核查哪些输出仍存在、哪些输入已补回、货币差额；考虑被销毁物品使用了新的实例Key。
3. 不重放成功扣款、不凭旧Key直接重建整包物品，也不通过删除档案记录强行解锁。
4. 明确修复方案后按实际差额和缺失实例恢复，读回CustomData与穿戴、属性；同时核对内存和档案恢复阻断状态。当前没有自动清除记录的GM命令，具体修复代码应单独审查、测试。
5. 保留处理证据。当前记录是异常参与者恢复记录，不是整个背包镜像，也没有跨存储原子性承诺。

## 10. 升阶 UI 维护

已接入装备主界面的“养成 → 升阶”，PageId仍为transform。完整操作与代码定位见[升阶UI维护](equipment-advance-ui.md)。通过只读Snapshot刷新装备实例，再用PreviewForUI/CommitForUI和ClientRequestID匹配回复；价格与下一阶段由服务端决定。

紫阶以上手动选择相同ID材料并二次确认。110秒客户端预览过期会重做；提交8秒未回包可重试相同token/request。成功/补偿后刷新实例引用。旧Confirm仍供GM使用，每次生成新编号，不能用于网络重试。

Client新增Subscribe/Unsubscribe多订阅接口并兼容旧OnResult。InitData绑定，Deactivate释放轮询/订阅，Destruct解绑委托；切页和Close均接入清理。实际单客户端鼠标交互与生命周期已验收，真实断线/丢包、多客户端和移动端仍是后续验证项。

## 11. Skill 安装、同步和交接

维护源码位于 `Docs/skills/tts-equipment-maintenance`，当前项目发现副本位于 `.codex/skills/tts-equipment-maintenance`，两处保持一致。当前不依赖用户全局技能目录；团队共享应保留项目内源码和发现副本。其他机器也可按其Codex配置安装到用户技能目录，但不要同时维护不同内容的同名副本。

调用示例：`使用 $tts-equipment-maintenance，把紫+1升阶金币调整为700，并同步测试和验收记录。`

后续先修改项目内skill，再同步安装副本，并运行系统 skill-creator 的 `quick_validate.py`。若当前会话尚未刷新skill列表，在新会话调用；也可明确提供SKILL.md路径。不要仅修改已安装副本造成项目资料落后。

Windows 中文环境用UTF-8读取校验脚本，避免Python默认GBK解码中文skill失败：

```powershell
python -X utf8 C:/Users/Kvn/.codex/skills/.system/skill-creator/scripts/quick_validate.py Docs/skills/tts-equipment-maintenance
```

SKILL.md、引用文档和agents/openai.yaml均保存为UTF-8。其他机器请把命令中的系统skill目录替换为其实际安装路径。

交接至少说明：改了哪些表行/模块、保存回读值、测试期望是否同步、LuaCheck结果、PIE客户端/DS结果、故障和清理结果、仍未覆盖场景。不要把旧基线日志当成本轮验证结果。
