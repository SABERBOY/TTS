# 验证与排错参考

先读项目手册第7—9节；这里保留可复用的执行细节。基线为2026-09-24，不把数量和费用写成永久不可变规则。

## 离线与导入检查

项目根运行 `python -X utf8 Tests/run_equipment_tests.py`。依赖lupa.lua51，基线17组配置、23组业务、9组UI测试及所有规范化字段一致。Runner用宿主Python读源文件/JSON；Lua内不读文件。UI原生fixture与交互维护见[UI参考](ui.md)。

Lua测试导入只能返回模块。修改后确认导入没有调用原生表、执行测试或修改背包。普通Lua语法编译只是一层检查；真实编辑器LuaCheck必须有明确passed日志，check.json更新并非检查通过。

文件/进程/动态源码调用可用rg扫描设备模块和测试，作为审查线索，不声称正则能证明平台全部合规。不要把现有合法时间函数与进程执行混为一谈，更不要据此添加未经验证的系统库。

## 原生测试源码如何投递

Tests目录的模块不保证能被运行打包环境require。本次真实DS里require Tests返回nil。严禁通过游戏Lua文件读取或动态加载解决它。

使用宿主Python读取**已审阅**的固定测试文件并拼成字面Lua代码；随后通过官方编辑器控制台在已就绪的测试DS运行。下面只组装并进行离线语法编译，不连接编辑器、不执行测试：

```python
from pathlib import Path
from lupa.lua51 import LuaRuntime

project = Path.cwd()  # 先确认是TTS项目根
test_file = project / 'Tests/EquipAdvanceTablePIE.lua'
source = test_file.read_text(encoding='utf-8-sig')
expected_gold = 100  # 使用本轮保存表中的预期值
assert isinstance(expected_gold, int) and expected_gold >= 0
code = ('local T = (function()\n' + source + '\nend)()\n'
        + 'T.Run(UGCGameSystem.GetAllPlayerController()[1], '
        + str(expected_gold) + ')')
LuaRuntime().compile(code)  # 仅宿主验证语法，不执行游戏逻辑
# 将code作为结构化工具字符串传给当前官方DS Lua控制台接口。
```

这里只用于隔离单玩家测试会话；多人会话明确找到测试Controller。不要把code插入未转义的shell命令，不把Test源码写成游戏内loadstring。若工具一次代码长度有限，使用当前官方支持的控制台方式；不得回退为游戏读取本地文件。

切换至EquipAdvancePIE或EquipAdvanceGMPIE时使用各自完整源码，末尾为T.Run(pc)，没有expectedGold参数。所有测试只由明确入口执行，不能修改为导入即执行。

测试投递前：确认PIE已完成启动、角色存在、服务端GM开启、服务未Busy/Blocked。初始云下载或控制台未注册可能先于业务执行失败；确认当前会话状态再启动/重试，避免重复创建会话。读取 `ugc://pie/session/current` 使用服务器 `ugc-mcp`。操作参数遵循实时ue_pie文档。

## 必查结果

- EquipAdvancePIE：6项原生案例，业务通过与清理通过均需看到。
- EquipAdvanceGMPIE：基线57件、27次合成、剩27件；同请求重放不重复扣款；cleanup=true。
- EquipAdvanceTablePIE：白阶预览/扣款一致；8310102→8310101需材料2、槽4等级60、金币650钻石1；缺失下一阶零扣款；cleanup=true。
- 改费用：保存表100→137，重启；新客户端读137，新DS实际扣137，无配置代码替换；最后恢复100、保存、回读。
- 客户端RPC：结果回调及背包新ID/CustomData、旧输入消失；不是只有DS日志。

修改路线/经济后先审核固定断言。TablePIE目前含39条映射和12项Missing等基线检查，增加资产后需同步合法预期；不为让测试通过而放宽生产校验。

原生日志通常位于编辑器 `ShadowTrackerExtra/Saved/Logs/TTS` 下DSlog/Clientlog目录，实际路径从当前环境核对。按 `[AdvancePIE]`、`[AdvanceGMPIE]`、`[AdvanceTablePIE]`、`[EquipAdvance]` 等标记检索，避免整段输出可能包含敏感网络参数的无关日志。print用单一拼接字符串。

## 故障判断

| 现象 | 定位 |
|---|---|
| LuaCheck Asset路径错误 | 检查顶层原生调用和间接C.Ranks访问，不用硬编码路径规避 |
| 原生表存在仍加载失败 | 检查userdata与pairs、RowName和字段类型、缓存的第一次失败 |
| 历史账本测试找不到材料 | 正常自动排除历史材料；显式指定，断言只累计一次 |
| GM有物品仍不能合成 | Reasons中的保护、钱、等级、相同ID数量和缺路线 |
| TransactionFailed | 补偿完成后按RestoredKeys更新实例引用 |
| RecoveryRequired | 停止测试，留存记录并核对资源，禁止清记录盲重试 |

真实满包故障、多客户端、重连、跨对局落盘和崩溃原子性未由原单客户端验收证明。需要这些结论时设计并运行专项用例。新增验证记录包括版本/改动、会话、日志时间、状态读回、清理情况和未覆盖项；不要伪造未运行结果。
