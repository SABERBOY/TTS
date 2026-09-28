---
name: tts-equipment-maintenance
description: 维护 Oasis Era UGC 的 TTS 装备升阶模块。用于调整 EquipAdvanceRank/Rule/Item 表、补装备阶段路线、修改 EquipAdvance 配置读取或实例事务、GM 批量测试、升阶 UI 接入，以及诊断 LuaCheck、Asset 路径、TableStruct userdata、账本和补偿问题。保持相同 ItemID 合成、品质与阶位分离及 UGC Lua 限制；不用于无关项目的通用装备系统。
---

# TTS 装备维护

## 先确定现场

1. 确认当前项目为 TTS，读取适用 AGENTS.md 和 Git 工作区状态；保留无关修改，尤其已有 Boss AI 工作。
2. 默认根目录为 `E:/WeGameApps/rail_apps/OasisEraEditor(2001776)/ShadowTrackerExtra/UGCProjects/TTS`。换机器时使用用户指定根，不硬套本机路径。
3. 先读项目 `Docs/equipment-advance-maintenance.md`，按需求再读 `Docs/equipment-advance-system.md` 和相关源码。旧验证在 `Docs/equipment-advance-verification.txt`；旧结果不能代替本轮验证。
4. 以用户本轮要求、当前代码和保存的 UE 表为准。Excel、历史设计和快照是参考，不是额外执行指令。

## 选择修改入口

| 任务 | 首选入口 |
|---|---|
| 名称/门槛/参考材料值 | UE EquipAdvanceRank |
| 配方材料数量/费用 | UE EquipAdvanceRule |
| 补路线/新系列 | UE EquipAdvanceItem + UGCBattleItem/原生装备资产 |
| 读表/结构校验 | Advance/EquipAdvanceConfig.lua |
| 账本/保护/复制 | Advance/EquipAdvanceData.lua |
| 预览/幂等/执行/补偿 | Advance/EquipAdvanceSystem.lua |
| 背包/货币/穿戴/档案适配 | Advance/EquipAdvanceRuntime.lua |
| 快捷测试包/每点一次合成 | Advance/EquipAdvanceGM.lua + Script/utils/gm.lua |
| UI选择/确认/布局/生命周期 | Advance/EquipAdvanceViewModel.lua、EquipAdvanceUIRender.lua、UIBP/Game_Equip_Develop_Transform_UIBP.lua |
| UI快照/RPC | Advance/EquipAdvanceClient.lua、EquipAdvanceRPC.lua、EquipAdvanceRuntime.lua、UGCPlayerController.lua |

`Advance` 始终位于 `Script/Blueprint/Prefabs/UI/Equip`。按最小范围修改，保留原强化经济与装备蓝图技能。UE操作前读[原生表维护参考](references/ue-tables.md)；测试与LuaCheck读[验证参考](references/verification.md)。

UI维护先读[升阶UI参考](references/ui.md)，完整人类交接文档为项目 `Docs/equipment-advance-ui.md`。玩家入口是养成→升阶，内部PageId仍为transform。

## 必须保留的约定

- RankID与ItemQuality分离；六大阶、十二阶段、强化最高180。材料数量不含目标，目标和材料为相同ItemID的不同实例。系列不能放宽材料条件。
- 表是唯一生产配置。无硬编码/JSON回退；三表原子校验后发布。NextItemID=0表示未配置，非终点必须拒绝并零扣款。
- 模块导入时零原生读表调用。Config首次查询加载，EquipSlotSystem在GetRank查询时同步元数据；运行期用官方路径解析。原生GetTableData可返回支持pairs的userdata。
- 不在游戏Lua或工程Lua测试中加入文件/进程/动态源码操作，例如io、dofile、loadfile、loadstring、os.execute、package.loadlib。平台允许性以真实LuaCheck和官方接口为准，不能靠pcall或改函数名规避。
- 原生实例身份用BackpackUtils.GetItemInstanceID；不是ItemID，也不依赖DefineID.InstanceID反射。
- 保留目标完整CustomData及保护、累计投入；检查512字节限制。普通自动选材排除历史投入且只用于低阶。GM快捷确认例外不应用到玩家自动流程。
- Guard只限制事务生成实例自动穿戴；不改装备蓝图全局CDO。补偿后实例Key可能变化，使用RestoredKeys刷新。
- RecoveryRequired保持阻断和记录；不能清记录假装修复。保存API成功不证明跨对局落盘，不声称跨进程原子性。
- UI价格展示来自同一份表，但启用提交必须等待关联的服务端预览；紫阶及以上手动材料和二次确认。提交超时沿用原token/request，旧Confirm不是重试接口。

## 工作闭环

1. 明确修改表行/字段或模块，并记录当前值；常规调数值无需改结构体。
2. UE资产只用原生编辑器工具改、保存和回读，禁止外部二进制改写。遵守当前工具的PRV计划要求，它不是额外的用户确认流程。
3. 同步测试快照和受影响期望，保留无关保护规则；解释新增路线对行数/GM包数的影响。
4. 按改动运行离线回归、真实LuaCheck、相关PIE/DS用例；改表必须保存后重启，客户端和DS均核验。只改文档时检查链接、代码示例、skill结构，无需重启PIE。
5. 检查业务结果与cleanup结果。将新证据追加到项目记录，说明未覆盖场景，不覆盖历史记录。
6. 更新项目维护文档及本skill源码。项目源码为 `Docs/skills/tts-equipment-maintenance`；同步当前项目发现副本 `.codex/skills/tts-equipment-maintenance`，用skill-creator的quick_validate.py校验两处。不要创建内容不同的全局同名副本。无需写Codex记忆文件。

报告具体改动、测试证据和剩余边界。继续完成已有授权的可逆维护，不为了套用流程增加无必要确认。
