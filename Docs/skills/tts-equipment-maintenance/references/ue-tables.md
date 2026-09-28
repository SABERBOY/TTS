# 原生表与资产操作参考

以下是2026-09-24在TTS编辑器验证过的接口形式。调用前用当前UGC工具文档确认能力与签名；工具升级后以实际API为准。不要猜测ue_py/ue_pie请求参数。发现工具可搜索 `ue_read`、`ue_py`、`ue_plan_submit`、`ue_pie`；原生MCP资源服务器名称为 `ugc-mcp`。

## 数据契约

资产位于 `/TTS/Asset/Data/Table/Customized`。三张表分别对应同名加Row的UserDefinedStruct：

| 表 | RowName | 字段 |
|---|---|---|
| EquipAdvanceRank | RankID | RankID:name, Order:int, DisplayName:string, Major:int, Minor:int, Cap:int, RecycleParts:int |
| EquipAdvanceRule | 当前RankID | RankID:name, Materials:int, Gold:int, Diamond:int |
| EquipAdvanceItem | ItemID十进制 | ItemID:int, Series:name, SlotIdx:int, RankID:name, NextItemID:int |

固定Rank12行/Rule11行；Item基线39行，可新增有效路线。Rank的Major/Minor对应白绿蓝各一阶、紫橙红各三阶。Cap严格递增、末阶180。Rule没有终点行。Item下一阶段同系列、同槽、Order+1；0代表缺失。加载器补RankOrder；导出Name代表行名，不是显示名称。

## 原生读回

在编辑器Python环境使用 `unreal_engine`，不要改为标准UE5的 `unreal` 包：

```python
import unreal_engine as ue
from unreal_engine.classes import DataTable
path = '/TTS/Asset/Data/Table/Customized/EquipAdvanceRule.EquipAdvanceRule'
dt = ue.load_object(DataTable, path)
assert dt is not None
print(dt.data_table_as_json())
```

返回JSON包含Name行名和友好字段名。比较时按Name建索引，忽略行显示顺序；不能忽略字段值和类型。三表JSON数组在测试快照中分别放到EquipAdvanceRank/Rule/Item键下。

修改单个值的已验证形式：

```python
dt.data_table_modify_row('R01_WHITE', 'Gold', 137)
dt.save_package()
print(dt.data_table_as_json())
```

仅在用户需求或具体测试确需修改时执行。先记录原值，临时验收后恢复原值并保存/回读。编辑器写入遵守工具原生PRV计划，计划按具体资产范围提交；不要猜测计划JSON结构，也不要每次改值都向已授权用户重复申请。

## 仅在缺少新表/结构体时创建

已有六个升阶表/Row资产应复用。此段用于新增类似表或资产恢复指导，不是常规调表步骤。

```python
from unreal_engine.classes import UserDefinedStruct, UGCStructureFactory
from unreal_engine.structs import UGCStructVariableDescription

# name应为本次明确需要创建的资产名，base应是已确认包目录。
s = ue.create_asset(name, base, UserDefinedStruct, ue.new_object(UGCStructureFactory))
v = UGCStructVariableDescription()
v.VarName = field
v.FriendlyName = field
v.Category = 'int'  # 也可为'name'或'string'，按字段契约选择
v.ToolTip = tip
s.struct_add_variable(v)
s.save_package()
```

UGCStructureFactory创建的结构体初始可为零字段；不要假设有默认字段需要删除。

```python
from unreal_engine.classes import UGCDataTableFactory, UAEDataTable
factory = ue.new_object(UGCDataTableFactory)
factory.Struct = s
dt = ue.create_asset(table_name, base, UAEDataTable, factory)
row = dt.data_table_empty_row()
row.set_field('ItemID', 8310102)  # 示例：其余必填字段也必须完整设置
dt.data_table_add_row('8310102', row)
dt.save_package()
```

`data_table_add_row`本次实际要求UScriptStruct行对象，不能传普通dict；工具概述曾与真实类型不一致。Factory使用UGCDataTableFactory并设置Struct，创建类为UAEDataTable。若发现对象类型、字段不符，先查原生文档/反射属性，再写入。

## 游戏侧读取与时机

运行期表达式：

```lua
UGCGameSystem.GetTableData(UGCGameSystem.GetUGCResourcesFullPath(
    'Asset/Data/Table/Customized/EquipAdvanceRank.EquipAdvanceRank'))
```

此调用应在运行世界就绪后的首次配置查询中发生，不得放在模块导入顶层。LuaCheck阶段根路径可能未准备好，解析后仍是Asset/...，随后原生读表报错。硬编码/TTS不是该时机问题的解决方案。

正常返回支持pairs的TableStruct userdata。先遍历为普通Lua表，再规范字段；禁止只以type==table判断有效性。每端缓存一次，修改表需保存并重启PIE，不能通过重新加载配置代码模拟“保存表生效”。
