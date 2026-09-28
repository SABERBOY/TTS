---装备槽位系统数据层（装备系统最终确认稿，2026-08-04 确认）
---核心规则：
---  六槽位（头盔/衣服/首饰/手套/腰带/鞋子）各保存一个永久强化等级（1-180），账号内四职业共享。
---  强化对象是"槽位（装备框）"，不是装备本体；实际生效等级 = min(槽位永久等级, 当前装备品阶强化上限)。
---  强化成功率 100%；每级属性与消耗读 EquipStrengthenLevel 表（源：《装备系统-策划配置表.xlsx》"强化逐级"页）。
---  服务端权威：等级存 Character 属性集 EquipSlotLv_* 自定义属性（复制），经 ServerRPC_StrengthenEquipSlot 事务修改。
---表数据已对照策划配置校验：180 行逐级，单槽 1-180 总消耗 = 54270 金币 / 1170 零件；累计 +1000 攻击 / +3300 生命。
local EquipSlotSystem = {}

EquipSlotSystem.MAX_LEVEL = 180

-- 强化逐级曲线表：行名 = 等级(1-180)，列见 EquipStrengthenLevelRow
-- （Level/ColorStage/AtkPerLevel/HpPerLevel/CumAtk/CumHp/GoldCost/PartsCost/CumGold/CumParts/RankCap）
EquipSlotSystem.STRENGTHEN_TABLE_PATH = 'Asset/Data/Table/Customized/EquipStrengthenLevel.EquipStrengthenLevel'

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
    local Rank = EquipSlotSystem.Ranks[RankOrder]
    if Rank then
        -- Query after world initialization: LuaCheck imports must not read tables.
        local Config = require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceConfig')
        local AdvanceRank = Config.Ranks[RankOrder]
        if AdvanceRank then
            for Key, Value in pairs(AdvanceRank) do Rank[Key] = Value end
        end
    end
    return Rank
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

-- 策划六槽 → 内核通用装备槽。手套/腰带暂无独立内核槽，读装备时按空处理。
EquipSlotSystem.KernelSlotNames = {
    [1] = 'EquipmentSlot.Common.Head',
    [2] = 'EquipmentSlot.Common.UpBody',
    [3] = 'EquipmentSlot.Common.Ornament',
    [4] = nil,
    [5] = nil,
    [6] = 'EquipmentSlot.Common.BelowBody',
}

function EquipSlotSystem.GetKernelSlotName(SlotIdx)
    return EquipSlotSystem.KernelSlotNames[SlotIdx]
end

function EquipSlotSystem.GetSlotIdxByKernelName(SlotName)
    if not SlotName or SlotName == '' then
        return nil
    end
    for SlotIdx, Name in pairs(EquipSlotSystem.KernelSlotNames) do
        if Name == SlotName then
            return SlotIdx
        end
    end
    return nil
end

---背包 DefineID（userdata struct / table / number）→ 物品 ID，空槽返回 nil
function EquipSlotSystem.GetDefineItemID(DefineID)
    if DefineID == nil then
        return nil
    end
    if type(DefineID) == 'number' then
        return DefineID ~= 0 and DefineID or nil
    end
    if type(DefineID) == 'table' or type(DefineID) == 'userdata' then
        local OK, Value = pcall(function()
            return DefineID.TypeSpecificID or DefineID.ItemID
        end)
        if OK and type(Value) == 'number' and Value ~= 0 then
            return Value
        end
    end
    return nil
end

function EquipSlotSystem.IsDefineIDValid(DefineID)
    return EquipSlotSystem.GetDefineItemID(DefineID) ~= nil
end

--==================== 强化逐级表读取（带缓存） ====================

-- 逐级行缓存：Level -> 行数据；false 表示已查过但表中缺失（避免重复失败查询与日志刷屏）
local LevelRowCache = {}

---读强化逐级表某等级行（结果缓存；等级越界或表缺失返回 nil）
---@param Level number 强化等级 1-180
---@return table|nil Row {Level, ColorStage, AtkPerLevel, HpPerLevel, CumAtk, CumHp, GoldCost, PartsCost, CumGold, CumParts, RankCap}
function EquipSlotSystem.GetLevelRow(Level)
    Level = math.floor(Level or 0)
    if Level < 1 or Level > EquipSlotSystem.MAX_LEVEL then
        return nil
    end
    local Cached = LevelRowCache[Level]
    if Cached ~= nil then
        return Cached or nil
    end
    local Row = nil
    local OK, Raw = pcall(function()
        return UGCGameSystem.GetTableDataByRowName(
            UGCGameSystem.GetUGCResourcesFullPath(EquipSlotSystem.STRENGTHEN_TABLE_PATH), tostring(Level))
    end)
    if OK and Raw ~= nil then
        Row = {
            Level = tonumber(Raw.Level) or Level,
            ColorStage = Raw.ColorStage or '',
            AtkPerLevel = tonumber(Raw.AtkPerLevel) or 0,
            HpPerLevel = tonumber(Raw.HpPerLevel) or 0,
            CumAtk = tonumber(Raw.CumAtk) or 0,
            CumHp = tonumber(Raw.CumHp) or 0,
            GoldCost = tonumber(Raw.GoldCost) or 0,
            PartsCost = tonumber(Raw.PartsCost) or 0,
            CumGold = tonumber(Raw.CumGold) or 0,
            CumParts = tonumber(Raw.CumParts) or 0,
            RankCap = Raw.RankCap or '',
        }
    else
        print('[EquipSlotSystem] 强化逐级表读取失败 Level=' .. tostring(Level) .. '（检查 EquipStrengthenLevel 表是否存在）')
    end
    LevelRowCache[Level] = Row or false
    return Row
end

---升到目标等级 TargetLevel 的单级消耗（读表）
function EquipSlotSystem.GetGoldCost(TargetLevel)
    local Row = EquipSlotSystem.GetLevelRow(TargetLevel)
    return Row and Row.GoldCost or 0
end

function EquipSlotSystem.GetPartsCost(TargetLevel)
    local Row = EquipSlotSystem.GetLevelRow(TargetLevel)
    return Row and Row.PartsCost or 0
end

---批量强化消耗：从 FromLevel 强化 Count 级（自动截断到 MAX_LEVEL）
---用累计列做差 Gold = CumGold(Target) - CumGold(From)，与逐级求和等价
---@return number Gold 金币总消耗
---@return number Parts 装备零件总消耗
---@return number TargetLevel 实际到达等级
function EquipSlotSystem.GetBatchCost(FromLevel, Count)
    FromLevel = math.max(0, math.floor(FromLevel or 0))
    Count = math.max(1, math.floor(Count or 1))
    local Target = math.min(EquipSlotSystem.MAX_LEVEL, FromLevel + Count)
    if Target <= FromLevel then
        return 0, 0, Target
    end
    local ToRow = EquipSlotSystem.GetLevelRow(Target)
    if not ToRow then
        return 0, 0, FromLevel
    end
    local FromGold, FromParts = 0, 0
    if FromLevel > 0 then
        local FromRow = EquipSlotSystem.GetLevelRow(FromLevel)
        FromGold = FromRow and FromRow.CumGold or 0
        FromParts = FromRow and FromRow.CumParts or 0
    end
    return ToRow.CumGold - FromGold, ToRow.CumParts - FromParts, Target
end

---升至系统上限（180 级）的总消耗
function EquipSlotSystem.GetToCapCost(FromLevel)
    return EquipSlotSystem.GetBatchCost(FromLevel, EquipSlotSystem.MAX_LEVEL)
end

---槽位强化累计属性（读表累计列；超过上限按 MAX_LEVEL 饱和）
---@param Level number 槽位强化等级
---@param AttrType string 'Atk' 或 'Hp'
function EquipSlotSystem.GetSlotBonus(Level, AttrType)
    Level = math.min(EquipSlotSystem.MAX_LEVEL, math.max(0, math.floor(Level or 0)))
    if Level <= 0 then
        return 0
    end
    local Row = EquipSlotSystem.GetLevelRow(Level)
    if not Row then
        return 0
    end
    return AttrType == 'Atk' and Row.CumAtk or Row.CumHp
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

--==================== 物品品质 / 装备品阶识别 ====================

-- 内核物品品质（UGCItemSystemV2.GetItemQualityV2*）显示名，索引与内核 QualityRank 一致
EquipSlotSystem.QualityNames = {
    [0] = '普通',
    [1] = '优秀',
    [2] = '精良',
    [3] = '史诗',
    [4] = '传说',
    [5] = '神话',
    [6] = '至臻',
    [7] = '至臻+',
}

-- 内核品质 → 策划十二品阶序号。策划只区分 白/绿/蓝/紫/橙/红 六色，
-- 同色的 +1/+2 子阶（紫+1、橙+2 等）暂无内核字段，先落到该色的基础阶。
EquipSlotSystem.QualityToRankOrder = {
    [0] = 1,  -- 普通 → 白
    [1] = 2,  -- 优秀 → 绿
    [2] = 3,  -- 精良 → 蓝
    [3] = 4,  -- 史诗 → 紫
    [4] = 7,  -- 传说 → 橙
    [5] = 10, -- 神话 → 红
    [6] = 12, -- 至臻 → 红+2
    [7] = 12,
}

---读物品品质：优先 DefineID（走 UGCGameData 实例数据重写），其次 ItemID；读不到返回 nil
---@param DefineID any 背包 DefineID（userdata/table/number），可为 nil
---@param ItemID number|nil 物品 ID，DefineID 无效时使用
---@return number|nil Quality
function EquipSlotSystem.GetItemQuality(DefineID, ItemID)
    local Quality = nil
    if EquipSlotSystem.IsDefineIDValid(DefineID) and type(DefineID) ~= 'number' then
        local OK, Value = pcall(function()
            return UGCItemSystemV2.GetItemQualityV2ByDefineID(DefineID)
        end)
        if OK and type(Value) == 'number' then
            Quality = Value
        end
    end
    if Quality == nil then
        local ID = ItemID or EquipSlotSystem.GetDefineItemID(DefineID)
        if ID then
            local OK, Value = pcall(function()
                return UGCItemSystemV2.GetItemQualityV2(ID)
            end)
            if OK and type(Value) == 'number' then
                Quality = Value
            end
        end
    end
    if Quality == nil then
        return nil
    end
    return math.max(0, math.floor(Quality))
end

function EquipSlotSystem.GetQualityName(Quality)
    if Quality == nil then
        return ''
    end
    return EquipSlotSystem.QualityNames[Quality] or ('品质' .. tostring(Quality))
end

---物品名：优先 DefineID（实例数据重写），其次 ItemID
function EquipSlotSystem.GetItemName(DefineID, ItemID)
    local Name = nil
    if EquipSlotSystem.IsDefineIDValid(DefineID) and type(DefineID) ~= 'number' then
        pcall(function()
            Name = UGCItemSystemV2.GetItemNameV2ByDefineID(DefineID)
        end)
    end
    if (not Name or Name == '') then
        local ID = ItemID or EquipSlotSystem.GetDefineItemID(DefineID)
        if ID then
            pcall(function()
                Name = UGCItemSystemV2.GetItemNameV2(ID)
            end)
        end
    end
    return Name or ''
end

---由明确的 ItemID 阶位配置识别装备品阶；未接入的新旧物品保留原品质映射。
---服务端（EquipSlotAttrApplier）与客户端 UI 共用，GetItemQualityV2* 两端均可用。
function EquipSlotSystem.GetEquipRankOrder(DefineID)
    if not EquipSlotSystem.IsDefineIDValid(DefineID) then
        return nil
    end
    local AdvanceConfig = require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceConfig')
    local ItemID = EquipSlotSystem.GetDefineItemID(DefineID)
    local AdvanceItem = AdvanceConfig.Items[ItemID]
    if AdvanceItem then return AdvanceItem.RankOrder end
    local Quality = EquipSlotSystem.GetItemQuality(DefineID)
    local Order = Quality ~= nil and EquipSlotSystem.QualityToRankOrder[Quality] or nil
    if not Order then
        return 1
    end
    return math.max(1, math.min(#EquipSlotSystem.Ranks, Order))
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

---@return table Preview {Level, Target, GoldCost, PartsCost, GoldHave, PartsHave, AttrType, CurBonus, NextBonus, Maxed, Affordable,
---  DefineID, ItemID, Quality, RankOrder, Rank, Cap, EffectiveLevel, EffectiveBonus, CapReached}
---  Cap/EffectiveLevel 仅客户端可用（读本地已装备）；服务端调用时 DefineID 为 nil，Cap 字段为 nil。
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

    -- 当前装备品阶（客户端本地读取；服务端无本地 PC 时跳过）
    local DefineID, ItemID = nil, nil
    if not UGCGameSystem.IsServer() then
        DefineID, ItemID = EquipSlotSystem.GetEquippedOnSlot(SlotIdx)
    end
    local Quality = ItemID and EquipSlotSystem.GetItemQuality(DefineID, ItemID) or nil
    local RankOrder = ItemID and EquipSlotSystem.GetEquipRankOrder(DefineID) or nil
    local Rank = RankOrder and EquipSlotSystem.GetRank(RankOrder) or nil
    local EffectiveLevel = EquipSlotSystem.GetEffectiveLevel(Level, RankOrder)

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
        DefineID = DefineID,
        ItemID = ItemID,
        Quality = Quality,
        RankOrder = RankOrder,
        Rank = Rank,
        Cap = Rank and Rank.Cap or nil,
        EffectiveLevel = EffectiveLevel,
        EffectiveBonus = EquipSlotSystem.GetSlotBonus(EffectiveLevel, AttrType),
        CapReached = Rank ~= nil and Level >= Rank.Cap and not Maxed,
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

    -- 落盘：只把六槽强化等级写入玩家存档。
    -- 装备/背包物品/货币的跨对局保留由引擎原生负责（物品编辑器的「是否持久化」ShouldPersist），
    -- 本项目不再自己存一套，否则会和引擎的背包持久化重复且互相干扰。
    -- 延迟 require：EquipSlotPersist 顶层 require 了本模块，直接互相 require 会形成循环
    local OKPersist, EquipSlotPersist = pcall(require, 'Script.Blueprint.Prefabs.UI.Equip.EquipSlotPersist')
    if OKPersist and EquipSlotPersist then
        EquipSlotPersist.SaveLevels(Player, PlayerState)
    end

    -- 刷新槽位强化属性加成（服务端）
    local EquipSlotAttrApplier = require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotAttrApplier')
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

--==================== 背包/穿戴查询（客户端 UI 用） ====================

function EquipSlotSystem.GetLocalPC()
    return UGCGameSystem.GetLocalPlayerController()
end

---读当前玩家某策划槽上的已装备 DefineID / ItemID
function EquipSlotSystem.GetEquippedOnSlot(SlotIdx)
    local PC = EquipSlotSystem.GetLocalPC()
    local SlotName = EquipSlotSystem.GetKernelSlotName(SlotIdx)
    if not PC or not SlotName then
        return nil, nil, SlotName
    end
    local OK, DefineID = pcall(function()
        return UGCBackpackSystemV2.GetEquippedItemBySlotName(PC, SlotName)
    end)
    if not OK then
        return nil, nil, SlotName
    end
    return DefineID, EquipSlotSystem.GetDefineItemID(DefineID), SlotName
end

local function CollectDefineIDs(IDs, Push)
    if type(IDs) == 'table' then
        for _, DefineID in pairs(IDs) do
            Push(DefineID)
        end
        return
    end
    if type(IDs) ~= 'userdata' then
        return
    end
    local Len = 0
    pcall(function() Len = #IDs end)
    if Len > 0 then
        for i = 1, Len do
            Push(IDs[i])
        end
        return
    end
    pcall(function()
        for _, DefineID in pairs(IDs) do
            Push(DefineID)
        end
    end)
end

---收集背包里可作为装备的物品（含已穿戴；已装备物品可能不占格子，需从槽位补入）
function EquipSlotSystem.CollectBagEquipItems(PC)
    local Result = {}
    PC = PC or EquipSlotSystem.GetLocalPC()
    if not PC then
        return Result
    end
    local Seen = {}
    local function KeyOf(DefineID, ItemID)
        local InstanceID = 0
        pcall(function() InstanceID = DefineID.InstanceID or 0 end)
        return tostring(ItemID) .. '_' .. tostring(InstanceID)
    end
    local function Push(DefineID, ForcedSlotName)
        local ItemID = EquipSlotSystem.GetDefineItemID(DefineID)
        if not ItemID then
            return
        end
        local Key = KeyOf(DefineID, ItemID)
        if Seen[Key] then
            return
        end
        local CanWear = ForcedSlotName ~= nil and ForcedSlotName ~= ''
        if not CanWear then
            pcall(function()
                CanWear = UGCBackpackSystemV2.CheckCanEquipItemToAnySlotV2(PC, ItemID) == true
            end)
        end
        if not CanWear then
            for _, KernelName in pairs(EquipSlotSystem.KernelSlotNames) do
                if KernelName then
                    local OKSlot = false
                    pcall(function()
                        OKSlot = UGCBackpackSystemV2.ItemCanEquipToSlot(PC, ItemID, KernelName) == true
                    end)
                    if OKSlot then
                        CanWear = true
                        break
                    end
                end
            end
        end
        if not CanWear then
            return
        end
        local SlotName = ForcedSlotName or ''
        if SlotName == '' then
            pcall(function()
                SlotName = UGCBackpackSystemV2.GetItemEquippingSlot(PC, DefineID) or ''
            end)
        end
        local SlotIdx = EquipSlotSystem.GetSlotIdxByKernelName(SlotName)
        if not SlotIdx then
            local TargetSlots
            pcall(function()
                TargetSlots = UGCItemSystemV2.GetEquipTargetSlots(ItemID)
            end)
            CollectDefineIDs(TargetSlots, function(Name)
                if not SlotIdx then
                    SlotIdx = EquipSlotSystem.GetSlotIdxByKernelName(Name)
                end
            end)
        end
        Seen[Key] = true
        Result[#Result + 1] = {
            DefineID = DefineID,
            ItemID = ItemID,
            SlotName = SlotName,
            SlotIdx = SlotIdx,
            bEquipped = SlotName ~= nil and SlotName ~= '',
        }
    end
    local OK, IDs = pcall(function()
        return UGCBackpackSystemV2.GetAllItemDefineIDsV2(PC)
    end)
    if OK then
        CollectDefineIDs(IDs, Push)
    end
    for SlotIdx, SlotName in pairs(EquipSlotSystem.KernelSlotNames) do
        if SlotName then
            local DefineID
            pcall(function()
                DefineID = UGCBackpackSystemV2.GetEquippedItemBySlotName(PC, SlotName)
            end)
            Push(DefineID, SlotName)
        end
    end
    return Result
end

---绑定客户端装备变化委托（DS 不广播，仅客户端 UI 用）
function EquipSlotSystem.BindAttachChange(OwnerWidget, Callback)
    if not OwnerWidget or OwnerWidget.__EquipUIAttachBound then
        return
    end
    local PC = EquipSlotSystem.GetLocalPC()
    if not PC then
        return
    end
    local Comp = UGCBackpackSystemV2.GetBackpackComponentV2(PC)
    if not Comp or not CheckObjectContainsField(Comp, 'GetItemAttachParentChangeDelegateV2', true) then
        return
    end
    local OK, Delegate = pcall(function()
        return Comp:GetItemAttachParentChangeDelegateV2()
    end)
    if not OK or not Delegate or not Delegate.Add then
        return
    end
    local WeakOwner = WeakObjectPtr(OwnerWidget)
    Delegate:Add(function(...)
        if not WeakOwner:IsValid() then
            return
        end
        local SelfRef = WeakOwner:Get()
        if SelfRef and Callback then
            Callback(SelfRef, ...)
        end
    end)
    OwnerWidget.__EquipUIAttachBound = true
    print('[EquipSlotSystem] bound ItemAttachParentChangeDelegateV2')
end

return EquipSlotSystem
