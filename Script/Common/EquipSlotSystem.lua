---装备槽位系统数据层（装备系统最终确认稿，2026-08-04 确认）
---核心规则：
---  六槽位（头盔/衣服/首饰/手套/腰带/鞋子）各保存一个永久强化等级（1-180），账号内四职业共享。
---  强化对象是"槽位（装备框）"，不是装备本体；实际生效等级 = min(槽位永久等级, 当前装备品阶强化上限)。
---  强化成功率 100%；槽位从 L-1 升到 L 消耗：金币 = 30 + 3*L，装备零件 = 1 + floor((L-1)/15)。
---  服务端权威：等级存 Character 属性集 EquipSlotLv_* 自定义属性（复制），经 ServerRPC_StrengthenEquipSlot 事务修改。
---数值已对照《装备系统-策划配置表.xlsx》校验：
---  单槽 1-180 总消耗 = 54270 金币 / 1170 零件；180 级攻击槽累计 +1000、生命槽累计 +3300。
local EquipSlotSystem = {}

EquipSlotSystem.MAX_LEVEL = 180

-- 消耗公式常量（配置表"说明与常量"页：GOLD_BASE/GOLD_PER_LEVEL/PARTS_BAND）
EquipSlotSystem.GOLD_BASE = 30
EquipSlotSystem.GOLD_PER_LEVEL = 3
EquipSlotSystem.PARTS_BAND = 15

-- 装备零件物品 ID 接入点：项目物品表尚未定义"装备零件"，定义后在此填入 ItemID。
-- 为 nil 时零件校验与扣除跳过（只扣金币），并打印警告。
EquipSlotSystem.PartsItemID = nil

-- 六槽位定义（SlotIdx 从 1 起；AttrType: Atk=固定攻击 / Hp=固定生命值上限）
EquipSlotSystem.Slots = {
    [1] = { Key = 'Helmet',    Name = '头盔', AttrType = 'Atk' },
    [2] = { Key = 'Chest',     Name = '衣服', AttrType = 'Hp' },
    [3] = { Key = 'Accessory', Name = '首饰', AttrType = 'Atk' },
    [4] = { Key = 'Glove',     Name = '手套', AttrType = 'Atk' },
    [5] = { Key = 'Belt',      Name = '腰带', AttrType = 'Hp' },
    [6] = { Key = 'Shoes',     Name = '鞋子', AttrType = 'Hp' },
}

-- 十二品阶表（配置表"品阶属性"页）：Cap=强化上限, Atk/Hp=单件本体属性, SpecialRate=特殊属性倍率, RecycleParts=基础回收零件
EquipSlotSystem.Ranks = {
    { RankID = 'R01_WHITE',   Order = 1,  Name = '白',   Cap = 10,  Atk = 24,  Hp = 120, SpecialRate = 0.20,  RecycleParts = 12 },
    { RankID = 'R02_GREEN',   Order = 2,  Name = '绿',   Cap = 20,  Atk = 33,  Hp = 180, SpecialRate = 0.28,  RecycleParts = 30 },
    { RankID = 'R03_BLUE',    Order = 3,  Name = '蓝',   Cap = 30,  Atk = 45,  Hp = 240, SpecialRate = 0.36,  RecycleParts = 70 },
    { RankID = 'R04_PURPLE',  Order = 4,  Name = '紫',   Cap = 45,  Atk = 57,  Hp = 300, SpecialRate = 0.45,  RecycleParts = 140 },
    { RankID = 'R05_PURPLE_1', Order = 5, Name = '紫+1', Cap = 60,  Atk = 69,  Hp = 360, SpecialRate = 0.50,  RecycleParts = 180 },
    { RankID = 'R06_PURPLE_2', Order = 6, Name = '紫+2', Cap = 75,  Atk = 78,  Hp = 420, SpecialRate = 0.55,  RecycleParts = 230 },
    { RankID = 'R07_ORANGE',  Order = 7,  Name = '橙',   Cap = 90,  Atk = 90,  Hp = 480, SpecialRate = 0.65,  RecycleParts = 340 },
    { RankID = 'R08_ORANGE_1', Order = 8, Name = '橙+1', Cap = 105, Atk = 102, Hp = 540, SpecialRate = 0.70,  RecycleParts = 430 },
    { RankID = 'R09_ORANGE_2', Order = 9, Name = '橙+2', Cap = 120, Atk = 114, Hp = 600, SpecialRate = 0.75,  RecycleParts = 520 },
    { RankID = 'R10_RED',     Order = 10, Name = '红',   Cap = 140, Atk = 135, Hp = 720, SpecialRate = 0.85,  RecycleParts = 760 },
    { RankID = 'R11_RED_1',   Order = 11, Name = '红+1', Cap = 160, Atk = 159, Hp = 840, SpecialRate = 0.925, RecycleParts = 950 },
    { RankID = 'R12_RED_2',   Order = 12, Name = '红+2', Cap = 180, Atk = 180, Hp = 960, SpecialRate = 1.00,  RecycleParts = 1200 },
}

-- 槽位强化每级属性（配置表"强化区间"页；按等级区间逐段累计，升颜色不重算历史等级）
EquipSlotSystem.StrengthenBands = {
    { From = 1,   To = 10,  AtkPer = 1,  HpPer = 3 },
    { From = 11,  To = 20,  AtkPer = 1,  HpPer = 5 },
    { From = 21,  To = 30,  AtkPer = 2,  HpPer = 7 },
    { From = 31,  To = 75,  AtkPer = 3,  HpPer = 10 },
    { From = 76,  To = 120, AtkPer = 5,  HpPer = 20 },
    { From = 121, To = 180, AtkPer = 10, HpPer = 30 },
}

-- 十二件固定装备模板（配置表"装备模板"页；SpecialValue 为红+2 上限，实际品阶值 = 上限 * 品阶倍率）
EquipSlotSystem.Templates = {
    { TemplateID = 'EQ_HEAD_01',      SlotName = '头盔', AttrName = '主动技能冷却缩减', SpecialMax = 0.08 },
    { TemplateID = 'EQ_HEAD_02',      SlotName = '头盔', AttrName = '对精英/Boss伤害',  SpecialMax = 0.12 },
    { TemplateID = 'EQ_GLOVE_01',     SlotName = '手套', AttrName = '基础输出频率',     SpecialMax = 0.10 },
    { TemplateID = 'EQ_GLOVE_02',     SlotName = '手套', AttrName = '职业机制伤害',     SpecialMax = 0.12 },
    { TemplateID = 'EQ_ACCESSORY_01', SlotName = '首饰', AttrName = '暴击率',           SpecialMax = 0.08 },
    { TemplateID = 'EQ_ACCESSORY_02', SlotName = '首饰', AttrName = '暴击伤害',         SpecialMax = 0.24 },
    { TemplateID = 'EQ_CHEST_01',     SlotName = '衣服', AttrName = '全局伤害减免',     SpecialMax = 0.08 },
    { TemplateID = 'EQ_CHEST_02',     SlotName = '衣服', AttrName = '护盾获得量',       SpecialMax = 0.20 },
    { TemplateID = 'EQ_BELT_01',      SlotName = '腰带', AttrName = '受到的治疗效果',   SpecialMax = 0.20 },
    { TemplateID = 'EQ_BELT_02',      SlotName = '腰带', AttrName = '清场恢复最大生命', SpecialMax = 0.12 },
    { TemplateID = 'EQ_SHOES_01',     SlotName = '鞋子', AttrName = '移动速度',         SpecialMax = 0.08 },
    { TemplateID = 'EQ_SHOES_02',     SlotName = '鞋子', AttrName = '受控持续时间缩短', SpecialMax = 0.24 },
}

function EquipSlotSystem.GetSlotDef(SlotIdx)
    return EquipSlotSystem.Slots[SlotIdx]
end

function EquipSlotSystem.GetRank(RankOrder)
    return EquipSlotSystem.Ranks[RankOrder]
end

---槽位对应的人物属性名（Character 属性集自定义属性）
function EquipSlotSystem.GetSlotAttrName(SlotIdx)
    local SlotDef = EquipSlotSystem.GetSlotDef(SlotIdx)
    if not SlotDef then
        return nil
    end
    return 'EquipSlotLv_' .. SlotDef.Key
end

---槽位加成对应的角色属性：Atk->BaseAttack, Hp->BaseHealth
function EquipSlotSystem.GetSlotTargetAttr(AttrType)
    return AttrType == 'Atk' and 'BaseAttack' or 'BaseHealth'
end

---升到目标等级 TargetLevel 的单级消耗
function EquipSlotSystem.GetGoldCost(TargetLevel)
    return EquipSlotSystem.GOLD_BASE + EquipSlotSystem.GOLD_PER_LEVEL * TargetLevel
end

function EquipSlotSystem.GetPartsCost(TargetLevel)
    return 1 + math.floor((TargetLevel - 1) / EquipSlotSystem.PARTS_BAND)
end

---批量强化消耗：从 FromLevel 强化 Count 级（自动截断到 MAX_LEVEL）
---@return number Gold 金币总消耗
---@return number Parts 装备零件总消耗
---@return number TargetLevel 实际到达等级
function EquipSlotSystem.GetBatchCost(FromLevel, Count)
    FromLevel = math.max(0, math.floor(FromLevel or 0))
    Count = math.max(1, math.floor(Count or 1))
    local Target = math.min(EquipSlotSystem.MAX_LEVEL, FromLevel + Count)
    local Gold, Parts = 0, 0
    for L = FromLevel + 1, Target do
        Gold = Gold + EquipSlotSystem.GetGoldCost(L)
        Parts = Parts + EquipSlotSystem.GetPartsCost(L)
    end
    return Gold, Parts, Target
end

---升至系统上限（180 级）的总消耗
function EquipSlotSystem.GetToCapCost(FromLevel)
    return EquipSlotSystem.GetBatchCost(FromLevel, EquipSlotSystem.MAX_LEVEL)
end

function EquipSlotSystem.GetLevelBand(Level)
    for _, Band in ipairs(EquipSlotSystem.StrengthenBands) do
        if Level >= Band.From and Level <= Band.To then
            return Band
        end
    end
    return nil
end

---槽位强化累计属性（按区间逐段累计）
---@param Level number 槽位强化等级
---@param AttrType string 'Atk' 或 'Hp'
function EquipSlotSystem.GetSlotBonus(Level, AttrType)
    Level = math.max(0, math.floor(Level or 0))
    local Total = 0
    for _, Band in ipairs(EquipSlotSystem.StrengthenBands) do
        if Level < Band.From then
            break
        end
        local Hi = math.min(Band.To, Level)
        local N = Hi - Band.From + 1
        Total = Total + N * (AttrType == 'Atk' and Band.AtkPer or Band.HpPer)
    end
    return Total
end

---实际生效强化等级 = min(槽位永久等级, 当前装备品阶强化上限)
---@param SlotLevel number 槽位永久强化等级
---@param RankOrder number|nil 当前装备品阶序号（1-12），nil 视为无装备（生效 0）
function EquipSlotSystem.GetEffectiveLevel(SlotLevel, RankOrder)
    local Rank = EquipSlotSystem.GetRank(RankOrder)
    if not Rank then
        return 0
    end
    return math.min(SlotLevel or 0, Rank.Cap)
end

---生效等级对应的实际加成属性
function EquipSlotSystem.GetEffectiveBonus(SlotLevel, RankOrder, AttrType)
    return EquipSlotSystem.GetSlotBonus(EquipSlotSystem.GetEffectiveLevel(SlotLevel, RankOrder), AttrType)
end

--==================== 等级数据存取（服务端权威：Character 属性集） ====================

---由 PlayerState 反查当前角色 Pawn（可能为 nil）
function EquipSlotSystem.GetPawnFromPlayerState(PlayerState)
    if not PlayerState then
        return nil
    end
    if PlayerState.CurrentPawn then
        return PlayerState.CurrentPawn
    end
    if CheckObjectContainsField(PlayerState, 'GetPlayerCharacterSafety', true) then
        return PlayerState:GetPlayerCharacterSafety()
    end
    return nil
end

---读取槽位永久强化等级（权威数据在 Character 属性集 EquipSlotLv_*）
---@param PlayerState APlayerState|nil 可为 nil，此时使用 PlayerPawn
---@param SlotIdx number 槽位 1-6
---@param PlayerPawn AActor|nil 可选，直接传入角色避免反查
function EquipSlotSystem.GetSlotLevel(PlayerState, SlotIdx, PlayerPawn)
    local Pawn = PlayerPawn or EquipSlotSystem.GetPawnFromPlayerState(PlayerState)
    if not Pawn then
        return 0
    end
    local AttrName = EquipSlotSystem.GetSlotAttrName(SlotIdx)
    if not AttrName then
        return 0
    end
    local OK, Value = pcall(function()
        return UGCAttributeSystem.GetGameAttributeValue(Pawn, AttrName)
    end)
    if not OK or Value == nil then
        return 0
    end
    return math.floor(Value)
end

---写入槽位永久强化等级（服务端调用；属性复制会自动同步客户端）
---@param PlayerPawn AActor 角色 Pawn
---@param SlotIdx number 槽位 1-6
---@param NewLevel number 新等级
function EquipSlotSystem.SetSlotLevel(PlayerPawn, SlotIdx, NewLevel)
    if not UGCGameSystem.IsServer() then
        return false
    end
    if not PlayerPawn then
        return false
    end
    local AttrName = EquipSlotSystem.GetSlotAttrName(SlotIdx)
    if not AttrName then
        return false
    end
    UGCAttributeSystem.SetGameAttributeValue(PlayerPawn, AttrName, NewLevel)
    return true
end

--==================== 装备品阶识别 ====================

---由背包 DefineID/物品路径识别装备品阶序号（1-12）。
---当前项目仅有 LV1-LV7 模板装备，先按名称映射；未识别时按白装(1)处理。
function EquipSlotSystem.GetEquipRankOrder(DefineID)
    if not DefineID then
        return nil
    end
    local TypeSpecificID = nil
    if type(DefineID) == 'number' then
        TypeSpecificID = DefineID
    elseif type(DefineID) == 'table' or type(DefineID) == 'userdata' then
        local OK, ID = pcall(function()
            return DefineID.TypeSpecificID or DefineID.ItemID
        end)
        if OK then
            TypeSpecificID = ID
        end
    end
    if not TypeSpecificID then
        return nil
    end
    -- TODO: 接入正式物品表后按 Template_ID 精确匹配
    -- 临时：LV1-LV7 模板按白装(1)处理，保证测试可用
    return 1
end

--==================== 货币与零件 ====================

---金币 = 游戏内第一货币（货币即背包物品，不占格子）
function EquipSlotSystem.GetGoldItemID(Player)
    if not Player then return nil end
    local IDs = UGCBackpackSystemV2.GetCurrencyIDList(Player)
    -- GetCurrencyIDList 返回 TArray(userdata)，用 # 判长度、下标取值，不能用 type=='table'
    if IDs and (type(IDs) == 'table' or type(IDs) == 'userdata') and #IDs > 0 then
        return IDs[1]
    end
    return nil
end

function EquipSlotSystem.GetItemCount(Player, ItemID)
    if not Player or not ItemID then
        return 0
    end
    return UGCBackpackSystemV2.GetItemCountV2(Player, ItemID) or 0
end

function EquipSlotSystem.GetPlayerGold(Player)
    return EquipSlotSystem.GetItemCount(Player, EquipSlotSystem.GetGoldItemID(Player))
end

function EquipSlotSystem.GetPlayerParts(Player)
    if not EquipSlotSystem.PartsItemID then
        return -1 -- 未接入零件物品
    end
    return EquipSlotSystem.GetItemCount(Player, EquipSlotSystem.PartsItemID)
end

--==================== 强化预览（UI 共用） ====================

---@return table Preview {Level, Target, GoldCost, PartsCost, GoldHave, PartsHave, AttrType, CurBonus, NextBonus, Maxed, Affordable}
function EquipSlotSystem.GetStrengthenPreview(PlayerState, Player, SlotIdx, Count)
    local SlotDef = EquipSlotSystem.GetSlotDef(SlotIdx)
    local Level = EquipSlotSystem.GetSlotLevel(PlayerState, SlotIdx, Player)
    local GoldCost, PartsCost, Target = EquipSlotSystem.GetBatchCost(Level, Count or 1)
    local AttrType = SlotDef and SlotDef.AttrType or 'Atk'
    local GoldHave = EquipSlotSystem.GetPlayerGold(Player)
    local PartsHave = EquipSlotSystem.GetPlayerParts(Player)
    local Maxed = Level >= EquipSlotSystem.MAX_LEVEL
    local Affordable = GoldHave >= GoldCost
        and (not EquipSlotSystem.PartsItemID or PartsHave >= PartsCost)
    return {
        Level = Level,
        Target = Target,
        GoldCost = GoldCost,
        PartsCost = PartsCost,
        GoldHave = GoldHave,
        PartsHave = PartsHave,
        AttrType = AttrType,
        CurBonus = EquipSlotSystem.GetSlotBonus(Level, AttrType),
        NextBonus = EquipSlotSystem.GetSlotBonus(Target, AttrType),
        Maxed = Maxed,
        Affordable = Affordable and not Maxed,
    }
end

--==================== 服务端强化事务 ====================

---服务端执行槽位强化（原子事务：全部校验通过后才扣除与升级，任一步失败整笔不生效）
---@return boolean OK, string|nil ErrCode, number|nil NewLevel
function EquipSlotSystem.ServerTryStrengthen(PlayerState, Player, SlotIdx, Count)
    if not UGCGameSystem.IsServer() then
        return false, 'ClientForbidden'
    end
    if not PlayerState or not Player then
        return false, 'InvalidPlayer'
    end
    local SlotDef = EquipSlotSystem.GetSlotDef(SlotIdx)
    if not SlotDef then
        return false, 'InvalidSlot'
    end

    local Cur = EquipSlotSystem.GetSlotLevel(PlayerState, SlotIdx, Player)
    if Cur >= EquipSlotSystem.MAX_LEVEL then
        return false, 'MaxLevel'
    end

    local GoldCost, PartsCost, Target = EquipSlotSystem.GetBatchCost(Cur, Count)
    if Target <= Cur then
        return false, 'MaxLevel'
    end

    -- 余额校验（服务端 RPC 顺序执行，先全量校验再扣除，避免部分扣除）
    local GoldID = EquipSlotSystem.GetGoldItemID(Player)
    if not GoldID then
        return false, 'NoGoldCurrency'
    end
    if EquipSlotSystem.GetItemCount(Player, GoldID) < GoldCost then
        return false, 'NotEnoughGold'
    end
    local PartsID = EquipSlotSystem.PartsItemID
    if PartsID and EquipSlotSystem.GetItemCount(Player, PartsID) < PartsCost then
        return false, 'NotEnoughParts'
    end

    -- 扣除
    UGCBackpackSystemV2.RemoveItemV2(Player, GoldID, GoldCost)
    if PartsID then
        UGCBackpackSystemV2.RemoveItemV2(Player, PartsID, PartsCost)
    else
        print('[EquipSlotSystem] 警告：PartsItemID 未接入，本次强化未扣除装备零件（' .. tostring(PartsCost) .. '）')
    end

    -- 升级（Character 属性集 EquipSlotLv_* 为复制属性，客户端自动同步）
    if not EquipSlotSystem.SetSlotLevel(Player, SlotIdx, Target) then
        return false, 'SetLevelFailed'
    end

    -- 刷新槽位强化属性加成（服务端）
    local EquipSlotAttrApplier = require('Script.Common.EquipSlotAttrApplier')
    EquipSlotAttrApplier.RefreshSlot(Player, SlotIdx)

    print(string.format('[EquipSlotSystem] 强化成功 Slot=%d(%s) %d->%d 金币-%d 零件-%d',
        SlotIdx, SlotDef.Name, Cur, Target, GoldCost, PartsCost))
    return true, nil, Target
end

--==================== 客户端请求 ====================

---客户端发起强化请求（经 ServerRPC_StrengthenEquipSlot 白名单）
---@param SlotIdx number 槽位 1-6
---@param Count number 强化次数（+1 传 1，+10 传 10，升至上限传 MAX_LEVEL）
function EquipSlotSystem.ClientRequestStrengthen(SlotIdx, Count)
    local PC = UGCGameSystem.GetLocalPlayerController()
    if not PC then
        return
    end
    UnrealNetwork.CallUnrealRPC(PC, PC, 'ServerRPC_StrengthenEquipSlot', SlotIdx, Count or 1)
end

return EquipSlotSystem
