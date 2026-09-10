---
name: ugc-game-attributes
description: >-
  UGC GameAttribute system guide for this project: editor-side ga_* MCP APIs
  (ga_add_attr/ga_remove_attr/ga_query_attr/ga_list_groups/ga_init_group), runtime Lua APIs
  (GetGameAttributeValue/SetGameAttributeValue/AddGameAttributeValue/AddGameAttributeChangedDelegate),
  attribute groups (Character/Weapon/Vehicle/Basic vs unattached sample groups like
  CustomAttribute_Example), global name uniqueness, replication, and the symptom where
  setting an attribute succeeds but reads back 0 because the group is not on the player Pawn.
---

# UGC 游戏属性系统（GameAttribute）

## 结论（先读这个）

- 自定义属性归属**属性集（group）**；属性只有挂在目标 Actor 实际使用的 group 上才会生效。玩家 Pawn 用 `Character` 组（`Asset/Blueprint/Attributes/UGCAttributeGroup_Character`）。
- **属性名全局唯一**（跨所有 custom group + native 名集合），重名报 `ATTR_DUPLICATE_CROSS_GROUP`。
- 典型症状：`SetGameAttributeValue`/`AddGameAttributeValue` 返回 ok 但读回永远是默认值，且 DS 日志有 `UAttrModifyComponent::CreateUnregisterAttr, Cannot Find AttrPropertyChainDataPtr ... AttrName[XXX]` 或 `EnableByConfig, Can not find correct property ... AttrName[XXX]` → **该属性不在 Pawn 的 group 里**，用 `ga_query_attr('XXX')` 查它属于哪个组。
- `CustomAttribute_Example`（UGC自定义属性集样例）是**样例组，不在运行时 group_configs 里，不挂到任何 Pawn**。里面的属性（BaseAttack/BaseMagic/BaseDefence/AttackRatio/...）要用了必须先迁到 Character。

## 编辑器侧 MCP API（ue_py 里 `ue.ga_*`）

全部返回 JSON 字符串 `{ok, data|error}`。写操作（add/remove/modify/reorder）自动 ScopedTransaction+编译+保存，需 PRV plan（ue_plan_submit 或 ue_py 带 plan）。

| API | 用途 | 备注 |
| --- | --- | --- |
| `ga_list_groups()` | 列出所有属性集 | 运行时配置只有 Basic/Character/Weapon/Vehicle/Vehicle_Internal |
| `ga_get_attrs(group, 'custom')` | 列出组内自定义属性 | group 用英文名如 `'Character'` |
| `ga_query_attr(name)` | 跨组查属性详情 | 返回 `group_enum_name`，撞名感知 |
| `ga_add_attr(group, json)` | 新增属性 | json 必含 `name/type`；`description` **不能为空**，否则 `ATTR_VALIDATION_FAILED` |
| `ga_remove_attr(group, attr)` | 删除属性 | 组未初始化报 `GROUP_NOT_INITIALIZED` |
| `ga_modify_attr` / `ga_reorder_attrs` / `ga_validate_attr` | 改字段/排序/预校验 | |
| `ga_init_group(group)` | 初始化组蓝图 | **只支持 'Character'/'Weapon'/'Vehicle'**，不能初始化 Example 组 |
| `ga_export_lua()` | 重新生成 `Script/GameAttribute/game_attribute_type.lua` | add/remove 后一般会自动导出 |

新增属性示例（Character 组，int32，复制）：

```python
import unreal_engine as ue, json
ue.ga_add_attr('Character', json.dumps({
    'name': 'EquipSlotLv_Helmet', 'type': 'int32',
    'default_value': 1, 'min_value': 0, 'max_value': 180,
    'description': '槽位强化等级-头盔',
    'attr_category': 'Character', 'enable_replicate': True,
}))
```

## 运行时 Lua API（UGCAttributeSystem）

```lua
UGCAttributeSystem.GetGameAttributeValue(Pawn, 'BaseAttack')          -- 读（number）
UGCAttributeSystem.SetGameAttributeValue(Pawn, 'BaseAttack', 100)     -- 写（服务端权威）
UGCAttributeSystem.AddGameAttributeValue(Pawn, 'BaseAttack', 5)       -- 增减（推荐做差值调整）
UGCAttributeSystem.AddGameAttributeOperation(AttrOwner, AttrName, EAttrOperator[Op], Value)
-- 变化委托（Bind 后属性变化即回调；返回 handle）：
local h = UGCAttributeSystem.AddGameAttributeChangedDelegate(Pawn, 'EquipSlotLv_Helmet', function() ... end)
UGCAttributeSystem.RemoveGameAttributeChangedDelegate(Pawn, 'EquipSlotLv_Helmet', h)
```

- `enable_replicate=true` 的属性服务端写、客户端自动同步，UI 端直接 `GetGameAttributeValue` 即可。
- Lua 常量表在 `Script/GameAttribute/game_attribute_type.lua`：`UGCCustomGameAttributeType.UGCAttributeGroup_Character_XXX = 'XXX'`（自动生成，别手改，改了就重导）。

## 迁移属性到另一组（没有 move API）

1. `ga_query_attr(name)` 记录完整定义（type/default/min/max/description/enable_replicate）。
2. `ga_remove_attr(old_group, name)` —— 若报 `GROUP_NOT_INITIALIZED`，说明该组蓝图不在项目里（如 Example 组），**删不掉但也没关系**：运行时 group_configs 不含它，Pawn 解析走 Character 组即可。残留样例数据无害。
3. `ga_add_attr(new_group, ...)` 用原定义添加（全局唯一约束：旧组删不掉时新组仍能加成功，query 可能仍显示旧组名，以 `ga_get_attrs('Character','custom')` 实际列表为准）。
4. PIE 里验证：`GetGameAttributeValue(Pawn, name)` 读出 default 而不是 0/报错。

> 2026-09-10 实例：`BaseAttack`（float, 100, 0-1500, 基础攻击力）从 `CustomAttribute_Example` 加到 `Character` 组后，Pawn 上读/写/装备 AttrModify 全部生效；Example 组残留定义无法删除（组未初始化），不影响运行。

## PRV（Plan-Resolve-Verify）速记

`ue_py` 只要**改编辑器状态**（含 ga_add/remove）就要 plan：

1. `ue_plan_submit {plan: <yaml>}` → 拿 `plan_id`（TTL 15 分钟，同资产可复用）。
2. `ue_py {code, plan_id}` 执行。

plan YAML 最小可用格式（注意 mutations 必须是**非空列表项**，值里别带 `:` 否则解析失败）：

```yaml
intent: Migrate BaseAttack attr to Character group
asset_path: /TTS/Asset/Blueprint/Attributes/UGCAttributeGroup_Character.UGCAttributeGroup_Character
apis_to_call:
  - py:ga_remove_attr
  - py:ga_add_attr
mutations:
  - property: NewGameAttributeDefinitions
    value: add BaseAttack float default 100
```

纯查询代码不需要 plan。`asset_path` 用 `/TTS/Asset/...`，`/Game/` 会被拒。

## 相关

- 属性变化的实际应用案例（装备加成差值增减）：`ugc-equip-system` skill
- PIE 里验证属性读写：`ugc-pie-debug` skill
