---装备槽位强化属性应用器（装备系统）
---职责：在服务端根据槽位永久等级与当前装备品阶，动态把槽位强化加成应用到角色属性。
---  - 监听装备穿戴/卸下（GetItemAttachParentChangeDelegateV2）与 EquipSlotLv_* 属性变化。
---  - 实际生效等级 = min(槽位永久等级, 当前装备品阶强化上限)。
---  - 攻击槽 -> BaseAttack；生命槽 -> BaseHealth；差值用 AddGameAttributeValue 增减，避免覆盖其他系统。
---  - 不限量额外词条（EquipAffixSystem）：实例 CustomData.ExtraAffixes 引用的模板，按同 EffectiveLevel 逐条差值应用。
local EquipSlotSystem = require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotSystem')
local EquipAffixSystem = require('Script.Blueprint.Prefabs.UI.Equip.EquipAffixSystem')
local EquipAdvanceGuard = require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceGuard')

local EquipSlotAttrApplier = {}

-- 槽位到内核 SlotName 前缀映射（与 BP_BackpackUIComponentV2_Custom 的 EquipmentSlot.Common.* 对应）
-- 内核通用装备槽有限，只有头/上身/饰品/下身有对应槽。
-- 手套/腰带/鞋子暂无独立内核槽位：置 nil，RefreshSlot 时按无装备（不应用加成）处理，
-- 避免误读其它槽位的装备。接入正式装备槽位表后补全。
local SLOT_NAME_MAP = {
    [1] = 'EquipmentSlot.Common.Head',      -- 头盔
    [2] = 'EquipmentSlot.Common.UpBody',    -- 衣服
    [3] = 'EquipmentSlot.Common.Ornament',  -- 首饰
    [4] = nil,                              -- 手套：无独立内核槽
    [5] = nil,                              -- 腰带：无独立内核槽
    [6] = 'EquipmentSlot.Common.BelowBody', -- 鞋子 -> 下身
}

-- 已应用加成缓存：PlayerPawn -> SlotIdx -> {Bonus, AttrName}
local AppliedBonusCache = {}
-- 已应用词条缓存：PlayerPawn -> SlotIdx -> AffixID -> {Bonus, AttrName}
local AppliedAffixCache = {}
-- 词条指纹缓存：PlayerPawn -> SlotIdx -> fingerprint（已穿戴下追加词条时 DefineID 不变，靠指纹触发）
local AffixFingerprintCache = {}
-- 已绑定委托的 Pawn 记录
local BoundPawns = {}
-- 装备快照缓存包含原生实例标识与阶位，同 ItemID 不同实例也触发刷新。
local EquipSnapshotCache = {}
-- 装备轮询定时器：PlayerPawn -> TimerHandle
local EquipPollTimers = {}

---获取当前装备在某槽位的 DefineID（可能为 nil/空 struct）
function EquipSlotAttrApplier.GetEquippedDefineID(PC, SlotName)
    if not PC then
        return nil
    end
    local OK, DefineID = pcall(function()
        return UGCBackpackSystemV2.GetEquippedItemBySlotName(PC, SlotName)
    end)
    if not OK then
        return nil
    end
    return DefineID
end

---DefineID 是否有效（非空）
function EquipSlotAttrApplier.IsDefineIDValid(DefineID)
    if not DefineID then
        return false
    end
    if type(DefineID) == 'number' then
        return DefineID ~= 0
    end
    -- 背包 DefineID 为 userdata struct，字段 TypeSpecificID/ItemID 可用点号读取
    if type(DefineID) == 'table' or type(DefineID) == 'userdata' then
        local OK, ID = pcall(function()
            return DefineID.TypeSpecificID or DefineID.ItemID
        end)
        if OK then
            return ID ~= nil and ID ~= 0
        end
    end
    return false
end

---计算并应用某槽位的强化加成（服务端）
---@param PlayerPawn AActor 角色 Pawn
---@param SlotIdx number 槽位 1-6
function EquipSlotAttrApplier.RefreshSlot(PlayerPawn, SlotIdx)
    if not UGCGameSystem.IsServer() then
        return
    end
    if not PlayerPawn then
        return
    end
    local SlotDef = EquipSlotSystem.GetSlotDef(SlotIdx)
    if not SlotDef then
        return
    end

    local SlotLevel = EquipSlotSystem.GetSlotLevel(nil, SlotIdx, PlayerPawn)
    local RankOrder = nil
    local EquippedDefineID = nil
    local PC = PlayerPawn:GetController()
    if PC then
        local SlotName = SLOT_NAME_MAP[SlotIdx]
        if SlotName then
            local DefineID = EquipSlotAttrApplier.GetEquippedDefineID(PC, SlotName)
            if EquipSlotAttrApplier.IsDefineIDValid(DefineID) then
                EquippedDefineID = DefineID
                RankOrder = EquipSlotSystem.GetEquipRankOrder(DefineID)
            end
        end
    end

    local EffectiveLevel = EquipSlotSystem.GetEffectiveLevel(SlotLevel, RankOrder)
    local Bonus = EquipSlotSystem.GetSlotBonus(EffectiveLevel, SlotDef.AttrType)
    local AttrName = EquipSlotSystem.GetSlotTargetAttr(SlotDef.AttrType)

    -- 与缓存比较，只加差值
    AppliedBonusCache[PlayerPawn] = AppliedBonusCache[PlayerPawn] or {}
    local Old = AppliedBonusCache[PlayerPawn][SlotIdx]
    local OldBonus = Old and Old.Bonus or 0
    local Delta = Bonus - OldBonus
    if Delta ~= 0 then
        UGCAttributeSystem.AddGameAttributeValue(PlayerPawn, AttrName, Delta)
        print(string.format('[EquipSlotAttrApplier] Slot=%d(%s) Level=%d Rank=%s Eff=%d Bonus=%d Delta=%d Attr=%s',
            SlotIdx, SlotDef.Name, SlotLevel, tostring(RankOrder), EffectiveLevel, Bonus, Delta, AttrName))
    end
    AppliedBonusCache[PlayerPawn][SlotIdx] = { Bonus = Bonus, AttrName = AttrName }

    -- 不限量额外词条：同 EffectiveLevel，按条差值应用；卸下时 Eff=0 自动扣回
    AppliedAffixCache[PlayerPawn] = AppliedAffixCache[PlayerPawn] or {}
    AffixFingerprintCache[PlayerPawn] = AffixFingerprintCache[PlayerPawn] or {}
    local OldAffixes = AppliedAffixCache[PlayerPawn][SlotIdx] or {}
    local NewAffixes = {}
    if EquippedDefineID then
        local OK, Rows = pcall(EquipAffixSystem.ResolveAffixes, EquippedDefineID)
        if OK and type(Rows) == 'table' then
            for _, Row in ipairs(Rows) do
                local NewBonus = EquipAffixSystem.GetAffixBonus(Row, EffectiveLevel)
                NewAffixes[Row.AffixID] = { Bonus = NewBonus, AttrName = Row.TargetAttr }
            end
        end
        local OKF, Fingerprint = pcall(EquipAffixSystem.GetFingerprint, EquippedDefineID)
        AffixFingerprintCache[PlayerPawn][SlotIdx] = (OKF and Fingerprint) or ''
    else
        AffixFingerprintCache[PlayerPawn][SlotIdx] = ''
    end
    for AffixID, OldEntry in pairs(OldAffixes) do
        if NewAffixes[AffixID] == nil then
            if OldEntry.Bonus ~= 0 then
                UGCAttributeSystem.AddGameAttributeValue(PlayerPawn, OldEntry.AttrName, -OldEntry.Bonus)
                print(string.format('[EquipAffix] 移除 Slot=%d Affix=%s Attr=%s -%s',
                    SlotIdx, tostring(AffixID), tostring(OldEntry.AttrName), tostring(OldEntry.Bonus)))
            end
        end
    end
    for AffixID, NewEntry in pairs(NewAffixes) do
        local OldBonus = OldAffixes[AffixID] and OldAffixes[AffixID].Bonus or 0
        local AffixDelta = NewEntry.Bonus - OldBonus
        if AffixDelta ~= 0 then
            UGCAttributeSystem.AddGameAttributeValue(PlayerPawn, NewEntry.AttrName, AffixDelta)
            print(string.format('[EquipAffix] Slot=%d Affix=%s Attr=%s Eff=%d Bonus=%s Delta=%s',
                SlotIdx, tostring(AffixID), tostring(NewEntry.AttrName),
                EffectiveLevel, tostring(NewEntry.Bonus), tostring(AffixDelta)))
        end
    end
    AppliedAffixCache[PlayerPawn][SlotIdx] = NewAffixes
end

---刷新玩家所有槽位
---@param PlayerPawn AActor
function EquipSlotAttrApplier.RefreshAllSlots(PlayerPawn)
    if not PlayerPawn then
        return
    end
    for SlotIdx = 1, 6 do
        EquipSlotAttrApplier.RefreshSlot(PlayerPawn, SlotIdx)
    end
end

---装备穿戴/卸下回调（服务端）
---@param SlotName string|nil 内核槽位名，如 EquipmentSlot.Common.Head
function EquipSlotAttrApplier.OnEquipChanged(PlayerPawn, SlotName)
    if not UGCGameSystem.IsServer() or not PlayerPawn then
        return
    end
    -- 找到对应 SlotIdx 并刷新；未识别时全量刷新
    local TargetSlot = nil
    for SlotIdx, Name in pairs(SLOT_NAME_MAP) do
        if Name == SlotName then
            TargetSlot = SlotIdx
            break
        end
    end
    if TargetSlot then
        EquipSlotAttrApplier.RefreshSlot(PlayerPawn, TargetSlot)
    else
        EquipSlotAttrApplier.RefreshAllSlots(PlayerPawn)
    end
end

---绑定玩家委托（服务端）
---@param PlayerPawn AActor
function EquipSlotAttrApplier.BindPlayer(PlayerPawn)
    if not UGCGameSystem.IsServer() or not PlayerPawn then
        return
    end
    if BoundPawns[PlayerPawn] then
        return
    end

    -- 登录灌回存档里的强化等级：必须在绑定属性委托与首次 RefreshAllSlots 之前，
    -- 否则首帧会按默认等级算加成。存档要等 PostLogin 才就绪，模块内按 0.25s 间隔带重试地读。
    -- 注：这里只灌强化等级。装备/背包物品/货币的跨对局保留由引擎原生负责
    -- （物品编辑器的「是否持久化」= ShouldPersist），本项目不再自己存一套。
    local OKPersist, EquipSlotPersist = pcall(require, 'Script.Blueprint.Prefabs.UI.Equip.EquipSlotPersist')
    if OKPersist and EquipSlotPersist then
        EquipSlotPersist.BindLoadHooks(PlayerPawn, function(Pawn)
            EquipSlotAttrApplier.RefreshAllSlots(Pawn)
        end)
    end

    local PC = PlayerPawn:GetController()
    if PC then
        local Comp = UGCBackpackSystemV2.GetBackpackComponentV2(PC)
        if Comp and CheckObjectContainsField(Comp, 'GetItemAttachParentChangeDelegateV2', true) then
            local Delegate = Comp:GetItemAttachParentChangeDelegateV2()
            if Delegate and Delegate.Add then
                Delegate:Add(function(SlotName)
                    EquipSlotAttrApplier.OnEquipChanged(PlayerPawn, SlotName)
                end)
                print('[EquipSlotAttrApplier] bound ItemAttachParentChangeDelegateV2 for ' .. tostring(PlayerPawn))
            end
        end
    end

    -- 绑定 6 个槽位等级属性变化
    for SlotIdx = 1, 6 do
        local AttrName = EquipSlotSystem.GetSlotAttrName(SlotIdx)
        if AttrName then
            local OK, Handle = pcall(function()
                return UGCAttributeSystem.AddGameAttributeChangedDelegate(PlayerPawn, AttrName, function()
                    EquipSlotAttrApplier.RefreshSlot(PlayerPawn, SlotIdx)
                end)
            end)
            if OK then
                print('[EquipSlotAttrApplier] bound attr delegate ' .. AttrName .. ' for ' .. tostring(PlayerPawn))
            end
        end
    end

    BoundPawns[PlayerPawn] = true

    -- 服务端装备委托不可靠（GetItemAttachParentChangeDelegateV2 不广播）。
    -- 用低频快照轮询兜底：仅在装备 DefineID 实际变化时重算，平时零开销。
    EquipSnapshotCache[PlayerPawn] = {}
    local PCForPoll = PlayerPawn:GetController()
    if PCForPoll and UGCGameSystem.SetTimer then
        local function SnapshotPoll()
            if not BoundPawns[PlayerPawn] then
                return
            end
            local PC = PlayerPawn:GetController()
            if not PC then
                return
            end
            for SlotIdx, SlotName in pairs(SLOT_NAME_MAP) do
                local DefineID = EquipSlotAttrApplier.GetEquippedDefineID(PC, SlotName)
                local ID = nil
                if DefineID and (type(DefineID) == 'table' or type(DefineID) == 'userdata') then
                    pcall(function() ID = DefineID.TypeSpecificID or DefineID.ItemID end)
                elseif type(DefineID) == 'number' then
                    ID = DefineID
                end
                ID = ID or 0
                local Snapshot = tostring(ID)
                if ID ~= 0 then
                    Snapshot = (EquipAdvanceGuard.Key(DefineID) or Snapshot) .. ':'
                        .. tostring(EquipSlotSystem.GetEquipRankOrder(DefineID))
                end
                local Changed = false
                if EquipSnapshotCache[PlayerPawn][SlotIdx] ~= Snapshot then
                    EquipSnapshotCache[PlayerPawn][SlotIdx] = Snapshot
                    Changed = true
                end
                -- 已穿戴下 CustomData.ExtraAffixes 变化时 DefineID 不变，靠指纹触发
                if not Changed and ID ~= 0 and DefineID then
                    local OKF, Fingerprint = pcall(EquipAffixSystem.GetFingerprint, DefineID)
                    local OldFingerprint = AffixFingerprintCache[PlayerPawn]
                        and AffixFingerprintCache[PlayerPawn][SlotIdx] or nil
                    if OKF and OldFingerprint ~= nil and Fingerprint ~= OldFingerprint then
                        Changed = true
                    end
                end
                if Changed then
                    EquipSlotAttrApplier.RefreshSlot(PlayerPawn, SlotIdx)
                end
            end
        end
        local OK, Handle = pcall(function()
            return UGCGameSystem.SetTimer(PlayerPawn, SnapshotPoll, 0.25, true)
        end)
        if OK then
            EquipPollTimers[PlayerPawn] = Handle
            print('[EquipSlotAttrApplier] equip snapshot poll started for ' .. tostring(PlayerPawn))
        end
    end

    -- 初始全量刷新
    EquipSlotAttrApplier.RefreshAllSlots(PlayerPawn)
end

---解绑玩家（角色销毁/退出时调用）
---@param PlayerPawn AActor
function EquipSlotAttrApplier.UnbindPlayer(PlayerPawn)
    if not PlayerPawn then
        return
    end
    BoundPawns[PlayerPawn] = nil
    AppliedBonusCache[PlayerPawn] = nil
    AppliedAffixCache[PlayerPawn] = nil
    AffixFingerprintCache[PlayerPawn] = nil
    EquipSnapshotCache[PlayerPawn] = nil
    local OKPersist, EquipSlotPersist = pcall(require, 'Script.Blueprint.Prefabs.UI.Equip.EquipSlotPersist')
    if OKPersist and EquipSlotPersist then
        EquipSlotPersist.UnbindPawn(PlayerPawn)
    end
    if EquipPollTimers[PlayerPawn] and UGCGameSystem.ClearTimer then
        pcall(function()
            UGCGameSystem.ClearTimer(PlayerPawn, EquipPollTimers[PlayerPawn])
        end)
    end
    EquipPollTimers[PlayerPawn] = nil
end

return EquipSlotAttrApplier
