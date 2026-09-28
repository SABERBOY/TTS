# 升阶 UI 维护参考

UI已接入，不要再新建另一套独立装备入口。先读项目 `Docs/equipment-advance-ui.md`，按具体需求查代码；三张UE表仍为生产配置唯一来源。

## 常见调整入口

- 费用/门槛/路线：改表、保存、重启PIE；不要在Panel或ViewModel写配方常量。
- 自动选择、确认、状态文案：EquipAdvanceViewModel；保留相同ItemID、精确实例和低阶安全自动规则。未知Viewed不自动填，GM快捷规则不能移入玩家UI。
- 面板行为：Transform脚本。物品行：Game_Equip_Advance_Row_UIBP。原生布局只改对应两个项目资产，不改共享模板影响强化页。
- 快照：Runtime.UISnapshot是只读投影；指纹用稳定实例Key/数据，不包含每次创建的DefineID userdata地址。否则轮询会持续取消预览/确认。
- 回包：ClientRequestID必须匹配等待请求，旧预览/GM结果不能启用当前按钮。8秒超时重试原token/request，110秒预览过期重做。
- 生命周期：InitData绑定原生委托，Deactivate释放timer/订阅，Destruct解绑；主界面切页和关闭必须调用Deactivate。不要在Construct绑定NewButton。
- 滚动复用：OnUpdateItem原生索引从0开始；点击读取当前AdvanceData。异步图标用弱引用与请求序号防串图。

## 原生UI操作陷阱

通过当前工具发现反射/API后操作，遵守工具PRV而不新增用户确认。复制Blueprint用完整源ObjectPath并核对结果类型。反射读取Font/LayoutData可能返回内存视图，不要取出、修改后再自赋值；新建独立SlateFontInfo/AnchorData等结构，填完整字段后赋值，编译/保存/回读。

共享Develop图标图片父Canvas默认Collapsed；只显示Image无效。新增Lua字段bIsVariable需编译导出。行按钮覆盖输入，关闭嵌套DragDrop接收。当前6个材料位，修改表使材料数超过6时同步扩展布局。

## 必要验证

离线runner含9组UI状态测试，另有17配置+23业务组。原生布局修改后必须实际打开检查字体、图标、材料位、货币与按钮；工具保存成功不等于视觉正确。Lua热重载后旧model/委托可能仍引用旧函数，最终验证新会话首次初始化与关闭重开。

隔离DS可用 `Tests/EquipAdvanceUIPIE.lua`，由宿主读源码后经官方控制台显式投递。Setup只执行一次，Audit查标记实例/实际扣费，Cleanup恢复余额/等级并删除仅本fixture的物品；必须确认清理成功。不能在游戏Lua读取测试文件。原生assert不要赋值接返回对象；扣币返回正的实际移除数量。

最低交互验收：白阶自动选材与单货币；紫+1两件手动材料、双货币、二次确认；缺下一阶/材料/等级/余额禁用；成功新实例自动选择；列表滚动复用；切页/关闭清理订阅。错序、超时、补偿映射用离线测试，真实网络/多客户端未测时明确记录边界。
