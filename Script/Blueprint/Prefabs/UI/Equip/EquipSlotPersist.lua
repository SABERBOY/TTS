---装备强化等级存档（服务端持久化）
---只入库 6 个槽位的永久强化等级（EquipSlotLv_*）。BaseAttack/BaseHealth 等都是穿戴时
---按 EquipStrengthenLevel 表 + 装备品阶实时算出来的派生值，不入库。
---运行时权威源仍是 Character 属性集：登录时存档灌回属性，强化成功时属性落盘。
---
---【为什么不存装备 / 背包物品 / 货币】这些由引擎原生负责，不要在这里再造一套：
---  · 物品编辑器（wiki catalog/20101）里每个物品有「是否持久化」属性 = BP 上的 `ShouldPersist`，
---    勾选后该物品**可以跨对局存储**；实例化数据 CustomData 会随背包/仓库一同持久化
---    （wiki catalog/20104「背包系统」）。运行时可用 `UGCItemSystemV2.IsShouldPersist(ItemID)` 查询。
---  · 引擎侧走 `BP_BackpackComponentV2:InitPersistDataAfterPlayerEnter` → `SaveBackpackPersistData`
---    → `UGCDataPersistence.SavePlayerInnerDataByKey`（Key=4），阈值：总量 256KB / 背包 200 件 /
---    仓库 200 件 / 单物品实例数据 0.5KB；分析用 `UGCBackpackSystemV2.GetBackpackPersistData`。
---  · 自己再存一份会和引擎双重持久化、互相覆盖，并且实测会诱发编辑器崩溃：
---    引擎那份 chunk 数据在编辑器 `UGCSaveDataServiceObject.SaveSaveDataFile` 里转 JSON 时
---    偶发 `Assertion failed: CanWriteValueWithoutIdentifier()`（JsonWriter.h:133），fatal，整个编辑器退出。
---  · 注意 PIE 下两套存储行为不同：`SavePlayerArchiveData` 写的 `Saved/ArchiveData/<项目>/<UID>.json`
---    **能**跨 PIE 重启读回；引擎的 inner/chunk 数据（Key=4）**每次重启调试都会重置**
---    （与 wiki「存档调试」一节一致）。所以在 PIE 里验不出引擎的背包持久化，别据此判定它没生效。
---
---存档写法参照 TopDownProject UGCPlayerState:ReadHeroID / SaveHeroID
---（权威端守卫 + GetUIDBy* + 整档读改写，只动自己的 key，不覆盖其他系统数据）。
local EquipSlotSystem = require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotSystem')

local EquipSlotPersist = {}

EquipSlotPersist.ARCHIVE_KEY = 'EquipSlotLevels'
EquipSlotPersist.SLOT_COUNT = 6

-- 已注册过读取钩子的 Pawn，避免重复监听
local HookedPawns = {}
-- 每个 Pawn 的待执行重试定时器句柄，Unbind 时清理
local RetryTimers = {}

-- 存档要等 PostLogin 才就绪，读取按 0.25s 间隔重试，最多 40 次（10s）后放弃
EquipSlotPersist.LOAD_MAX_RETRIES = 40
EquipSlotPersist.LOAD_RETRY_INTERVAL = 0.25

---服务端 + 权威端校验（HasAuthority 取不到时以 IsServer 为准，不阻断）
function EquipSlotPersist.IsAuthoritative(PlayerPawn)
    if not UGCGameSystem.IsServer() or not PlayerPawn then
        return false
    end
    local OK, Has = pcall(UGCActorComponentUtility.HasAuthority, PlayerPawn)
    return (not OK) or Has == true
end

---取玩家 UID：Pawn -> PlayerState -> Controller 依次兜底；未就绪返回 nil
---（BeginPlay 早期玩家信息可能还没初始化完，UID 为 0）
function EquipSlotPersist.GetUID(PlayerPawn, PlayerState)
    local UID = nil
    if PlayerPawn then
        pcall(function()
            UID = UGCGameSystem.GetUIDByPlayerPawn(PlayerPawn)
        end)
    end
    if (not UID or UID == 0) and PlayerState then
        pcall(function()
            UID = UGCGameSystem.GetUIDByPlayerState(PlayerState)
        end)
    end
    if (not UID or UID == 0) and PlayerPawn then
        pcall(function()
            local PC = PlayerPawn:GetController()
            if PC then
                UID = UGCGameSystem.GetUIDByPlayerController(PC)
            end
        end)
    end
    if not UID or UID == 0 then
        return nil
    end
    return UID
end

---读当前 6 槽等级（运行时权威源：Character 属性集 EquipSlotLv_*）
function EquipSlotPersist.CollectLevels(PlayerPawn)
    local Levels = {}
    for SlotIdx = 1, EquipSlotPersist.SLOT_COUNT do
        Levels[SlotIdx] = EquipSlotSystem.GetSlotLevel(nil, SlotIdx, PlayerPawn)
    end
    return Levels
end

---把存档原始值规范化为 {1..6} 的整数等级数组（截断到 0..MAX_LEVEL）；形状不对返回 nil
function EquipSlotPersist.NormalizeLevels(Raw)
    if type(Raw) ~= 'table' then
        return nil
    end
    local Levels = {}
    for SlotIdx = 1, EquipSlotPersist.SLOT_COUNT do
        local Value = tonumber(Raw[SlotIdx]) or 0
        Value = math.floor(Value)
        Levels[SlotIdx] = math.max(0, math.min(EquipSlotSystem.MAX_LEVEL, Value))
    end
    return Levels
end

---读存档中的六槽强化等级；无存档 / UID 未就绪 / 形状损坏返回 nil
function EquipSlotPersist.ReadLevels(PlayerPawn, PlayerState)
    if not EquipSlotPersist.IsAuthoritative(PlayerPawn) then
        return nil
    end
    local UID = EquipSlotPersist.GetUID(PlayerPawn, PlayerState)
    if not UID then
        return nil
    end
    local OK, Archive = pcall(UGCPlayerStateSystem.GetPlayerArchiveData, UID)
    if not OK or type(Archive) ~= 'table' then
        return nil
    end
    return EquipSlotPersist.NormalizeLevels(Archive[EquipSlotPersist.ARCHIVE_KEY])
end

---把当前六槽等级写入存档（整档读改写，只动 ARCHIVE_KEY）
---@return boolean 是否保存成功
function EquipSlotPersist.SaveLevels(PlayerPawn, PlayerState)
    if not EquipSlotPersist.IsAuthoritative(PlayerPawn) then
        return false
    end
    local UID = EquipSlotPersist.GetUID(PlayerPawn, PlayerState)
    if not UID then
        print('[EquipSlotPersist] 保存跳过：UID 未就绪')
        return false
    end
    local OK, Archive = pcall(UGCPlayerStateSystem.GetPlayerArchiveData, UID)
    if not OK then
        return false
    end
    if Archive == nil then
        Archive = {}
    end
    if type(Archive) ~= 'table' then
        -- 存档根节点形状损坏时整档覆盖会清掉其他系统的数据，宁可本次不保存
        print('[EquipSlotPersist] 存档根节点非 table，拒绝覆盖 UID=' .. tostring(UID))
        return false
    end
    local Levels = EquipSlotPersist.CollectLevels(PlayerPawn)
    Archive[EquipSlotPersist.ARCHIVE_KEY] = Levels
    local OKSave, Saved = pcall(UGCPlayerStateSystem.SavePlayerArchiveData, UID, Archive)
    if not OKSave or Saved == false then
        print('[EquipSlotPersist] SavePlayerArchiveData 失败 UID=' .. tostring(UID))
        return false
    end
    print('[EquipSlotPersist] 已保存强化等级 UID=' .. tostring(UID) .. ' levels=' .. table.concat(Levels, ','))
    return true
end

---把等级数组写入 Character 属性集（之后由 EquipSlotAttrApplier 换算成属性加成）
function EquipSlotPersist.ApplyLevels(PlayerPawn, Levels)
    for SlotIdx = 1, EquipSlotPersist.SLOT_COUNT do
        local Lv = Levels and Levels[SlotIdx]
        if Lv and Lv > 0 then
            EquipSlotSystem.SetSlotLevel(PlayerPawn, SlotIdx, Lv)
        end
    end
end

---一次性读档并灌回；读不到存档返回 false
---@return boolean 是否读到并应用了存档
function EquipSlotPersist.LoadToAttributes(PlayerPawn, PlayerState)
    local Levels = EquipSlotPersist.ReadLevels(PlayerPawn, PlayerState)
    if not Levels then
        return false
    end
    EquipSlotPersist.ApplyLevels(PlayerPawn, Levels)
    print('[EquipSlotPersist] 已从存档恢复强化等级 levels=' .. table.concat(Levels, ','))
    return true
end

---登录初始化：把存档里的强化等级灌回 Character 属性，并触发属性重算。
---存档要等 PostLogin 才就绪——就绪前 UID 取不到、GetPlayerArchiveData 返回 nil，
---所以按 LOAD_RETRY_INTERVAL 间隔带重试地读，灌回成功或确认无存档即停（最多 LOAD_MAX_RETRIES 次）。
---注：不用 UGCGenericMessageSystem 监听 UGC.Player.PlayerEnter 补读。本钩子由
---UGCPlayerController:ReceiveBeginPlay 等到 Pawn 生成后才调用，注册晚于该广播约 43ms，
---DS 日志显示广播时 Listener[None]，永远收不到；改用与本项目 TryBind 一致的重试轮询
---（参照 TalentTreeComponent 延迟到 PostLogin 再 LoadData 的思路）。
---@param OnLoaded function|nil 成功灌回后的回调（用于触发 RefreshAllSlots 重算加成）
function EquipSlotPersist.BindLoadHooks(PlayerPawn, OnLoaded)
    if not UGCGameSystem.IsServer() or not PlayerPawn then
        return
    end
    if HookedPawns[PlayerPawn] then
        return
    end
    HookedPawns[PlayerPawn] = true

    local Tries = 0
    local Attempt
    local function ScheduleRetry()
        if not UGCGameSystem.SetTimer then
            return
        end
        local OK, Handle = pcall(function()
            return UGCGameSystem.SetTimer(PlayerPawn, Attempt, EquipSlotPersist.LOAD_RETRY_INTERVAL, false)
        end)
        if OK then
            RetryTimers[PlayerPawn] = Handle
        end
    end

    Attempt = function()
        -- Unbind 之后不再继续（Pawn 可能已销毁）
        if not HookedPawns[PlayerPawn] then
            return
        end
        Tries = Tries + 1
        if not EquipSlotPersist.IsAuthoritative(PlayerPawn) then
            return
        end
        local Exhausted = Tries >= EquipSlotPersist.LOAD_MAX_RETRIES
        local UID = EquipSlotPersist.GetUID(PlayerPawn)
        if not UID then
            if Exhausted then
                print('[EquipSlotPersist] 放弃读档：UID 始终未就绪 tries=' .. tostring(Tries))
            else
                ScheduleRetry()
            end
            return
        end
        local OK, Archive = pcall(UGCPlayerStateSystem.GetPlayerArchiveData, UID)
        if not OK or Archive == nil then
            -- 存档尚未加载出来，或该玩家首次进入；重试到上限再判定为无存档
            if Exhausted then
                print('[EquipSlotPersist] UID=' .. tostring(UID) .. ' 无存档（首次进入），无需灌回')
            else
                ScheduleRetry()
            end
            return
        end
        if type(Archive) ~= 'table' then
            print('[EquipSlotPersist] 存档根节点非 table，拒绝使用 UID=' .. tostring(UID))
            return
        end
        local Levels = EquipSlotPersist.NormalizeLevels(Archive[EquipSlotPersist.ARCHIVE_KEY])
        if not Levels then
            print('[EquipSlotPersist] UID=' .. tostring(UID) .. ' 存档无 ' .. EquipSlotPersist.ARCHIVE_KEY .. ' 字段，无需灌回')
            return
        end
        EquipSlotPersist.ApplyLevels(PlayerPawn, Levels)
        if OnLoaded then
            OnLoaded(PlayerPawn)
        end
        print(string.format('[EquipSlotPersist] 登录灌回强化等级 UID=%s levels=%s tries=%d',
            tostring(UID), table.concat(Levels, ','), Tries))
    end

    Attempt()
end

---解绑（角色销毁/退出时调用）：停掉待执行的重试
function EquipSlotPersist.UnbindPawn(PlayerPawn)
    HookedPawns[PlayerPawn] = nil
    if RetryTimers[PlayerPawn] then
        if UGCGameSystem.ClearTimer then
            pcall(function()
                UGCGameSystem.ClearTimer(PlayerPawn, RetryTimers[PlayerPawn])
            end)
        end
        RetryTimers[PlayerPawn] = nil
    end
end

return EquipSlotPersist
