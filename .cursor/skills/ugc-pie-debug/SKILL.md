---
name: ugc-pie-debug
description: >-
  PIE debugging playbook for this UGC project via the user-ugc-mcp MCP server.
  Use when starting/stopping PIE, running doluastring on client or DS, hot-reloading Lua
  with reloadlua, reading DS/client realtime logs, acquiring PlayerPawn/PlayerController
  on the DS, or when you see "No PIE client window is registered with the Lua console",
  missing print output, or stale module state after reloadlua.
---

# UGC PIE 调试手册

## 结论（先读这个）

- 所有 PIE 操作走 MCP 命名空间 `user-ugc-mcp`：`ue_pie` / `ue_py` / `ue_read` / `ue_plan_submit`。
- `doluastring` 是**单向**派发：工具返回空 `{}` 不代表执行成功，必须读 DS/客户端实时日志确认输出。
- Lua `print(a, b)` 多参数**只输出第一个**，必须 `..` 拼接成单字符串。
- 只改 Lua → `reloadlua`；改了蓝图资产（CDO、属性集、物品配置）→ **停 PIE 再开**。
- `reloadlua` 后旧模块的定时器闭包/模块局部缓存仍以旧 upvalue 继续跑，会造成"幽灵逻辑"。彻底清理要重启 PIE。

## MCP 工具速查

### ue_pie

`action` ∈ `start` / `stop` / `reloadlua` / `doluastring`（`dostring`、`reload_lua` 是别名）。

- start：`{"action":"start","submode_id":0,"team_count":1,"players_per_team":1,"spectators_per_team":0}`，启动要 1-2 分钟。
- doluastring：`{"action":"doluastring","target":"ds","code":"..."}`；`target` 默认 `client`，`ds`/`server` 经客户端 RPC 转发到 DS（客户端必须在线）。
- 可选 `client_hwnd`（十进制窗口句柄字符串）指定客户端。
- 所有 action 都是单向触发，立即返回 `{}`。

### 会话状态资源

`FetchMcpResource(server="user-ugc-mcp", uri="ugc://pie/session/current")` 返回：

```json
{ "phase": "running", "debug_id": "_dkfffpaynm3mgt",
  "editor":  { "log_path": ".../Saved/Logs/ShadowTrackerExtra.log" },
  "clients": [ { "log_path": ".../Clientlog/FullLog/<ts>_client_<debugid>_1.log" } ],
  "dedicated_servers": [] }
```

注意：该资源里 `dedicated_servers` 常为空，DS 日志路径要自己按 debug_id 拼（见下）。

## 日志路径与读取

- DS：`Saved/Logs/TTS/DSlog/FullLog/<时间戳>_ds_<debug_id>_realtime.log`
- 客户端：`Saved/Logs/TTS/Clientlog/FullLog/<时间戳>_client_<debug_id>_<n>.log`
- 取最新 DS 日志：

```bash
cmd /c "dir /b /o-d E:\WeGameApps\rail_apps\OasisEraEditor(2001776)\ShadowTrackerExtra\Saved\Logs\TTS\DSlog\FullLog"
```

- 用 `rg` 按 marker 搜输出（PowerShell 里管道/引号容易出问题，套 `cmd /c` 最稳）：

```bash
cmd /c "rg --no-messages -n MYMARK <ds日志路径>"
```

## Marker 约定（强烈建议）

每段 doluastring 的 print 都带**唯一前缀**（如 `TEST` / `DBG` / `MYFEATURE_`），一次性代码用一次即弃：

```lua
print('MYTEST BaseAttack='..tostring(v)..' SlotLv='..tostring(lv))
```

日志里同一条 doluastring 会出现 3 次（PassMessageToServer / HandleConsoleCommand / 实际输出），取 `LogNula: LuaLog:` 前缀的才是真输出。doluastring 发完后 `AwaitShell` 睡 3-6 秒再读日志。

## DS 端拿玩家对象（已验证可用）

```lua
local GS   = UGCGameSystem.GetGameState()
local PS   = GS and GS.PlayerArray and GS.PlayerArray[1]
local Pawn = PS and PS:GetPlayerCharacterSafety()
local PC   = Pawn and Pawn:GetController()
```

**不存在**的接口（别再试）：`UGCGameSystem.GetPlayerControllerByIndex`、`UGCGameSystem.GetPlayerControllerByPawn`、`PlayerState:GetPlayerController()`。Pawn→PC 唯一可靠路径是 `Pawn:GetController()`。

已知 UID 时更短：`UGCGameSystem.GetPlayerPawnByUID(10001)`（PIE 单人房 UID 恒为 `10001` = TeamId*10000+ClientId）。

## 玩家存档（ArchiveData）本地调试

- **PIE 下存档确实会落盘、且跨会话可读回** —— API 注释里"存档数据在 PIE 下无法跨对局保存和读取"对本地调试**不成立**（2026-09-20 实测）。
- 路径：`ShadowTrackerExtra/Saved/ArchiveData/<UGC项目名>/<UID>.json`，即 `.../ShadowTrackerExtra/Saved/ArchiveData/TTS/10001.json`。**注意在游戏工程的 Saved 下，不是 `UGCProjects/TTS/Saved`**。
- ⚠️ **启动 PIE 前必须在「PIE Client Manager Toolbar」里给每个 UID 槽位选档**（下拉框会自动扫 `ArchiveData/*.json`）。官方规则（wiki `catalog/20460` §3.2）：
  - **选了本地 json** → 编辑器读它并上传到 DS，DS 端存档以该文件为初始值 → 登录能读到档；
  - **留空** → 该 UID 进「待拉取列表」，DS Ready 后**反向**由 DS 推送存档给编辑器写本地文件 → DS 端一开始是**空的**，登录读档必然拿到 nil。
  - 症状：Lua 侧一直 `无存档（首次进入）`，编辑器日志出现 `FUGCSaveDataService::UploadSaveDataForUID - UID=10001 has no local file selection; skipping upload and waiting for remote sync`。**编辑器崩溃/重启后选档会丢**，这是最常见的"存档突然读不到了"原因，别去怀疑业务代码。
  - 注意写方向不受影响：`SavePlayerArchiveData` 会自动更新本地 json（wiki §5.1），所以"能写不能读"正是选档没选的特征。
- 文件结构 `{ "<seq>": { ...你的 key... } }`，Tab 缩进，**必须 UTF-8**（中文写坏编码会读不回来）。
- 可以直接手改这个 json 造脏存档/造初始状态来测兼容性与读档分支，比在 PIE 里点 UI 快得多。**但改前必须先 stop PIE**：DS 内存里持有整档，退出/下次保存时会回写覆盖你的手改。
- 旧档不会自动清理；换玩法/改 key 后记得手动删档重测，否则会读到上一轮的残留。
- 读档要等 PostLogin：`ReceiveBeginPlay` 里 `GetUIDBy*` 可能还是 0、`GetPlayerArchiveData` 返回 nil。**只读一次必然拿到空**，要按 0.25s 间隔带重试地读（40 次 ≈ 10s 足够）。别指望 `UGC.Player.PlayerEnter` 广播补读——从 `ReceiveBeginPlay` + 等 Pawn 生成后才注册的监听晚于广播约 43ms，DS 日志会是 `MessageImpl Key[UGC.Player.PlayerEnter] Listener[None]`。
- 写档一律**整档读改写、只动自己的 key**；根节点不是 table 时 fail-closed 拒绝覆盖，否则会清掉别的系统的数据。

## reloadlua 的正确心智模型

- 派发所有**已保存到磁盘**的改动文件到 DS 和客户端；没改就不发。
- `require` 缓存的是**模块表**；reload 后新 `require` 拿到新表，但旧表上的：
  - 模块局部变量（缓存、BoundPawns 之类）→ 丢/分裂，新旧两份互不可见；
  - 已启动的 `SetTimer` 闭包 → **继续按旧代码跑**（旧 SLOT_NAME_MAP、旧逻辑），表现为改了代码行为不变；
  - 已 Add 到 UE 委托的闭包 → 不会自动移除。
- 调试属性加成/定时器类逻辑时，reload 后要 `Unbind` 再 `Bind`，并把派生属性值手动重置（如 `SetGameAttributeValue(Pawn,'BaseAttack',100)`），否则旧缓存让你觉得"没生效"。
- 改非 Lua（蓝图 CDO、属性集、物品 AttrModifyItemSimpleList）必须 stop+start。

## 常见报错

| 报错 | 原因与处理 |
| --- | --- |
| `No PIE client window is registered with the Lua console` | PIE 窗口没起好或会话已停。先查 session 资源 phase；running 则等几秒重试；stopped 则重新 start |
| doluastring 发了但日志没输出 | 多半 target 错（客户端 RPC 仅限服务端函数会 `CannotCallInClient`）或 Pawn 还没生成，加 `if Pawn then ... else print('no pawn') end` 防御 |
| `Actor Lua file ... can't find correspond Bluepirint` | `Script/Common/*.lua` 这类纯模块没对应蓝图，正常，忽略 |

## 生命周期时机坑

`UGCPlayerController:ReceiveBeginPlay`（服务端）触发时 Pawn 常**尚未生成**，`GetPlayerCharacterSafety()` 为 nil。需要在 BeginPlay 里绑 Pawn 相关逻辑时用重试：

```lua
local Retries = 0
local function TryBind()
    local Pawn = Controller:GetPlayerCharacterSafety()
    if Pawn then DoBind(Pawn) return end
    Retries = Retries + 1
    if Retries <= 40 then UGCGameSystem.SetTimer(Controller, TryBind, 0.25, false) end
end
TryBind()
```

`UGCGameSystem.SetTimer(Object, Callback, Seconds, IsLooping)` 返回 `FTimerHandle, Delegate`（两值）；`ClearTimer(Object, Handle)`。Object 用 Pawn/PC 均可。

## 相关

- 属性系统坑（属性不在 Pawn 属性集、Set 了读回 0）：见 `ugc-game-attributes` skill
- 背包/装备 API 与委托坑：见 `ugc-backpack-v2` skill
- 装备系统复测脚本：见 `ugc-equip-system` skill
