# BOSS AI 验证记录（VERIFICATION）

> 规格：`Docs/Codex_UE_Boss_BehaviorTree_Prompt.md`　方案：**A（UGC 原生：Lua 核心 + 原生 BT/BB + 蓝图/Lua BT 节点）**
> 记录时间：2026-09-22　执行人：AI（UGC MCP 自动化）

---

## 一、验证环境（真实）

| 项 | 值 |
|---|---|
| 引擎 | UE **4.18.1** 定制版（OasisEraEditor 2001776 / ShadowTrackerExtra） |
| UGC 项目 | `UGCProjects/TTS` |
| 执行通道 | UGC MCP：`ue_read` / `ue_py` / `ue_pie`（DS 侧 Lua 注入） |
| PIE 会话 | `debug_id = _dkfffpllhxaow5`（DS 日志：`Saved/Logs/TTS/DSlog/FullLog/2026.09.22-20.56.38_ds__dkfffplhhxaow5_realtime.log`） |
| 被测代码 | `Script/AI/Boss/BossAI_{Types,Config,Random,State,Decision,Tests}.lua` |
| 执行方式 | `UGCGameSystem.UGCRequire('Script.AI.Boss.BossAI_Tests')` → `RunAll()` |

> 环境限制（已确认）：仓库无 C++ 工程/编译环境（详见 `IMPLEMENTATION_PLAN.md` §0-1），因此 C++ 类、Editor 模块与 UE Automation Test Framework 不在交付范围；本记录仅覆盖 **Lua 纯逻辑** 验证。

---

## 二、测试结果（真实输出，2026-09-22 20:56）

```
[BossAI-Test] cases count = 8
[BossAI-Test] ===== TOTAL 29, PASS 29, FAIL 0 =====
BOSS_TEST_SUMMARY total=29 pass=29 fail=0
```

逐项明细（关键行摘录）：

| 用例 | 断言 | 结果 | 证据 |
|---|---|---|---|
| Case4 | 相同种子可复现 | PASS | 固定种子(777) 30 次决策序列完全一致 |
| Case4 | 候选遍历顺序稳定 | PASS | 两次构建候选/拒绝列表逐项一致 |
| Case5 | 无视线时 S1-S4 全部拒绝 | PASS | 拒绝原因均为 `NoLOS` |
| Case5 | 超距拒绝 S1 / 过近拒绝 S3 | PASS | 距离边界（320 / 550-1500）判定正确 |
| Case5 | 冷却中拒绝 / 冷却结束放行 | PASS | `Cooldown` → 4.0s 后放行 |
| Case6 | 权重 20/30 → 40%/60% ±2pp | PASS | **A=0.3955 / B=0.6045**（10000 次独立抽样） |
| Case7 | 连续计数=2 / 第三次禁止 | PASS | `RepeatBan` |
| Case7 | 只剩该技能时非攻击回退 | PASS | `kind=2 (Chase)` |
| Case8 | 站桩候选为空 → 意图移除并归一化 | PASS | 池内无 StationaryCast，池仍非空 |
| Case8 | 单次规划返回（不死循环） | PASS | 单次调用返回 |
| Case9 | 三次承诺 → GiveSpace | PASS | `kind=4 (GiveSpace)` |
| Case9 | Pressure 无技能 → 降级 Chase | PASS | `kind=2 (Chase)`（**本轮修复项**） |
| Case9 | 追击不重置预算 | PASS | burstStart / committedCount 不变 |
| Case11 | 喘息 A→B→结束 | PASS | `breathingStarted` → `finished` |
| Case11 | 结束后 0.8s 内拒绝 S3 | PASS | `GapCloseBlocked`；0.9s 放行 |
| Case11 | GapClose 不影响其他技能 | PASS | S1 正常放行 |
| Case12 | 预测超预算 → 提前喘息 | PASS | 7.5s 已用 + 2.0s 候选 = 9.5s > 8.0s |
| Case12 | 预测未超预算 → 不触发 | PASS | 0.3s 候选不触发 |
| Case12 | 不切断已承诺动作 | PASS | 决策不改 `activeAction` |

### 本轮发现并修复的缺陷

| # | 缺陷 | 修复 |
|---|---|---|
| 1 | **实现缺陷**：`BuildIntentPool` 在 Pressure 无合法技能时直接把该意图排除，导致"应降级 Chase"的场景变成 Reposition（规格 §6 要求"Pressure 有合法 S1–S4 时抽技能，否则可合理接近时 Chase"） | 意图池条件改为 `pressureSkill ~= nil or ctx.canChase`；抽中 Pressure 后无技能则输出 Chase |
| 2 | 测试缺陷：以"不同种子序列必不同"为断言（实际大量决策受冷却门控主导，随机性被掩盖） | 移除该断言，随机分布由 Case6 独立验证 |
| 3 | 测试缺陷：Case8 以"距离"构造站桩空池（S7 下限为 0，构造失败） | 改为将 S5-S7 全部置于冷却 |
| 4 | 测试缺陷：Case9 断言 Chase，但意图池只剩 Reposition（随机抽样） | 构造 `canReposition=false` 的确定性场景 |
| 5 | 测试框架缺陷：`RunAll` 用数组字面量构造用例表，含 nil 时 `#` 断裂导致静默 0 执行 | 改为逐个 `cases[#cases+1] = ...` 追加，并为 nil 用例记录 `MISSING`；`check()` 增加即时打印 |

> 热重载（`reloadlua`）后模块函数 upvalue 存在混用旧环境的观察，故最终结论以**干净 PIE 会话**为准（重启后重跑）。该现象已记录，供后续排查。

---

## 三、已验证 / 未验证清单（诚实标注）

### ✅ 已验证（纯逻辑层）
- 两级带权随机：合法性筛选、权重公式（Base×Distance×Phase×Repeat）、10000 次分布精度
- 冷却 / 距离 / 视线 / 高度 / 路径 / 危险冲突 的拒绝逻辑
- 连续三次禁止（RepeatBan）与"只剩该技能"的非攻击回退
- 意图池归一化（站桩空池移除）与空池有界返回
- 压制预算：3 次承诺上限、8 秒预测、追击不重置预算
- 喘息：A(DrainThreats)→B(2 秒 GuaranteedBreathing)、GapClose 0.8s 禁 S3、欠喘息保存/恢复
- 阶段：请求式切换、仅一次
- 危险登记/注销/超时清理（State 层接口）

### ⛔ 未验证（尚未实现或需 BT/引擎集成）
| 项 | 状态 | 说明 |
|---|---|---|
| BB_Boss（14 键）资产 | **未创建** | 下一步（阶段 B） |
| BT_Boss 行为树资产（规格 §8 结构） | **未创建** | 需 BT/BB 资产 + Lua BT 节点接线 |
| Lua BT 节点（`BTTask_LuaBase` / `BTAttachment_LuaBase` 绑定） | **未接线** | 基类接口已确认（`ReceiveExecuteAI` / `FinishExecute` / `ReceiveActivationAI` 等） |
| 灰盒技能运行时（Windup/Active/Recovery + 预警 + 伤害） | **未实现** | `BossAI_SkillRuntime` 待写 |
| 感知接入（AIPerception Sight） | **未接入** | 引擎含 AIPerception，需 BT/Controller 层 |
| PIE 集成（Idle→Combat→七技能→双 BOSS 隔离） | **未运行** | 依赖上述资产 |
| 规格 §14 中需要引擎的用例（1/2/3/10/13/14-24） | **未运行** | 明确标记为未验证，不视为通过 |

---

## 四、复现步骤（供他人复核）

1. 打开 TTS 项目，启动 PIE（本项目 MCP：`ue_pie start`）。
2. 在 DS 执行 Lua：
   ```lua
   local Tests = UGCGameSystem.UGCRequire('Script.AI.Boss.BossAI_Tests')
   local r = Tests.RunAll()
   print('total=' .. r.total .. ' pass=' .. r.passed .. ' fail=' .. r.failed)
   ```
3. 在 `Saved/Logs/TTS/DSlog/FullLog/*.log` 中检索 `BossAI-Test` 查看逐项结果。
4. 预期：`TOTAL 29, PASS 29, FAIL 0`（若修改过模块，务必**重启 PIE** 后再验证，避免热重载 upvalue 混用）。

---

## 五、结论

- **阶段 A（数据结构 + 决策/压制预算 + 纯逻辑测试）已完成并通过 29/29**。
- 阶段 B–E（BB/BT 资产、Lua BT 节点接线、灰盒技能运行时、PIE 集成、双 BOSS 隔离）**未开始**，需后续实施；在完成 PIE 集成前，**不得声称完整战斗验证通过**（规格 §14 末段要求）。
