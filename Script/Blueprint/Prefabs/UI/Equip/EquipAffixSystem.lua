---装备不限量额外词条系统（实例级）
---存储：物品 DefineID 的 CustomData.ExtraAffixes = {AffixID, ...}（string 数组，不限长度）
---词条定义表：Asset/Data/Table/Customized/EquipExtraAffix（行结构 EquipExtraAffixRow，行名=AffixID）
---装备映射表：Asset/Data/Table/Customized/EquipItemAffix（行结构 EquipItemAffixRow，行名=ItemID，列 AffixIDs=Array<EEquipAffixID 枚举>）
---生效：穿戴后按 EffectiveLevel = min(槽位Lv, 品阶Cap) 计算，与槽加成同一管线（EquipSlotAttrApplier）
---算法：BandSet Atk/Hp 走 EquipSlotSystem.GetSlotBonus；Custom 走 PerLevel * EffectiveLevel
---技能预留：行内 SkillID 本期只存不执行
local EquipAffixSystem = {}

EquipAffixSystem.TABLE_PATH = 'Asset/Data/Table/Customized/EquipExtraAffix.EquipExtraAffix'
EquipAffixSystem.CUSTOM_KEY = 'ExtraAffixes'

-- 装备 -> 词条映射表（UE 表格驱动，取代原先硬编码的 ItemTemplateAffixes）。
-- 行名 = 装备 ItemID；列 AffixIDs = Array<EEquipAffixID 枚举>，枚举条目名即 EquipExtraAffix 的行名。
-- 穿戴即生效，无需写实例 CustomData；实例 CustomData.ExtraAffixes 仍可在此基础上无限追加（GetAffixIDs 去重合并）。
EquipAffixSystem.ITEM_AFFIX_TABLE_PATH = 'Asset/Data/Table/Customized/EquipItemAffix.EquipItemAffix'

-- 允许作为词条目标的人物属性（Character 组自定义属性，不含 6 个 EquipSlotLv_*）
EquipAffixSystem.ALLOWED_ATTRS = {
    BaseAttack = true,
    BaseHealth = true,
    CritChance = true,
    CritRatio = true,
    SkillDamageRatio = true,
    Defence = true,
    Magic = true,
    BreakDefenceRatio = true,
    HeadDamageBoost = true,
    FireDamageBoost = true,
    FireDamageResist = true,
    HeadDamageResist = true,
    ExtraDefenseBoost = true,
    SkillCD = true,
    HealthBoost = true,
    HealthStealRatio = true,
    CounterAttackRatio = true,
    CritDamageResist = true,
    MagicRecoverSpeed = true,
    MaxMagic = true,
    RifleDamageRatio = true,
    MachineDamageRatio = true,
    ShotgunDamageRatio = true,
    SubmachineDamageRatio = true,
    ProjDamageResist = true,
}

---从 DefineID 提取数值 ItemID（number / userdata struct / table），无效返回 nil
---@param DefineID any
---@return number|nil
function EquipAffixSystem.GetItemID(DefineID)
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

---枚举值->名 反向映射（运行时枚举数组可能回传整型索引；EEquipAffixID 为 ue_enum_custom.lua 生成的全局枚举表）
local EnumValueToNameCache = nil
local function GetAffixEnumValueToName()
    if EnumValueToNameCache then
        return EnumValueToNameCache
    end
    local Map = {}
    local EnumTable = rawget(_G, 'EEquipAffixID')
    if type(EnumTable) == 'table' then
        for Name, Value in pairs(EnumTable) do
            if type(Value) == 'number' and type(Name) == 'string' then
                Map[Value] = Name
            end
        end
    end
    -- 仅在枚举表已就绪（非空）时缓存，避免过早调用把空表永久缓存
    if next(Map) ~= nil then
        EnumValueToNameCache = Map
    end
    return Map
end

---从 EquipItemAffix 表读取某装备的默认词条 ID（AffixIDs 为 EEquipAffixID 枚举数组）
---运行时枚举数组可能以条目名（字符串）或枚举值（整型）回传，统一归一化为 AffixID 字符串数组。
---@param ItemID number|nil 装备 ItemID
---@return table AffixIDs string 数组
function EquipAffixSystem.GetTemplateAffixIDs(ItemID)
    local Result = {}
    if not ItemID then
        return Result
    end
    local OK, Row = pcall(function()
        return UGCGameSystem.GetTableDataByRowName(
            UGCGameSystem.GetUGCResourcesFullPath(EquipAffixSystem.ITEM_AFFIX_TABLE_PATH), tostring(ItemID))
    end)
    if not OK or Row == nil then
        return Result
    end
    local Raw = Row.AffixIDs
    local function Resolve(V)
        if type(V) == 'string' and V ~= '' then
            return V
        end
        if type(V) == 'number' then
            return GetAffixEnumValueToName()[V]
        end
        return nil
    end
    if type(Raw) == 'string' or type(Raw) == 'number' then
        local Name = Resolve(Raw)
        if Name then
            Result[#Result + 1] = Name
        end
        return Result
    end
    if type(Raw) ~= 'table' and type(Raw) ~= 'userdata' then
        return Result
    end
    for _, V in pairs(Raw) do
        local Name = Resolve(V)
        if Name then
            Result[#Result + 1] = Name
        end
    end
    return Result
end

---读物品全部词条 ID：模板默认词条（按 ItemID）+ 实例 CustomData，去重合并（模板在前）
---@param DefineID any 背包 DefineID（userdata/table/number）
---@return table AffixIDs string 数组
function EquipAffixSystem.GetAffixIDs(DefineID)
    if DefineID == nil then
        return {}
    end
    local Result, Seen = {}, {}
    local function Push(ID)
        if type(ID) == 'string' and ID ~= '' and not Seen[ID] then
            Seen[ID] = true
            Result[#Result + 1] = ID
        end
    end
    -- 模板级默认词条（读 EquipItemAffix 表，AffixIDs 为 EEquipAffixID 枚举数组）
    local ItemID = EquipAffixSystem.GetItemID(DefineID)
    for _, ID in ipairs(EquipAffixSystem.GetTemplateAffixIDs(ItemID)) do
        Push(ID)
    end
    -- 实例级追加词条
    local OK, CustomData = pcall(function()
        return UGCItemSystemV2.LoadItemCustomData(DefineID)
    end)
    if OK and type(CustomData) == 'table' then
        local Raw = CustomData[EquipAffixSystem.CUSTOM_KEY]
        if type(Raw) == 'string' then
            Push(Raw)
        elseif type(Raw) == 'table' then
            for _, V in pairs(Raw) do
                Push(V)
            end
        end
    end
    return Result
end

---词条指纹（已穿戴下追加词条时 DefineID 不变，靠指纹变化触发重算）
function EquipAffixSystem.GetFingerprint(DefineID)
    local IDs = EquipAffixSystem.GetAffixIDs(DefineID)
    if #IDs == 0 then
        return ''
    end
    return table.concat(IDs, ',')
end

---查单条词条模板行
---@return table|nil Row {AffixID, TargetAttr, BandSet, PerLevel, Desc, SkillID}
function EquipAffixSystem.GetAffixRow(AffixID)
    if not AffixID or AffixID == '' then
        return nil
    end
    local OK, Row = pcall(function()
        return UGCGameSystem.GetTableDataByRowName(
            UGCGameSystem.GetUGCResourcesFullPath(EquipAffixSystem.TABLE_PATH), AffixID)
    end)
    if not OK or Row == nil then
        return nil
    end
    local TargetAttr = Row.TargetAttr
    if type(TargetAttr) ~= 'string' or TargetAttr == '' then
        return nil
    end
    if not EquipAffixSystem.ALLOWED_ATTRS[TargetAttr] then
        print('[EquipAffix] 非法目标属性，已跳过 AffixID=' .. tostring(AffixID) .. ' Attr=' .. tostring(TargetAttr))
        return nil
    end
    return {
        AffixID = AffixID,
        TargetAttr = TargetAttr,
        BandSet = Row.BandSet or 'Custom',
        PerLevel = tonumber(Row.PerLevel) or 0,
        Desc = Row.Desc or '',
        SkillID = Row.SkillID or '',
    }
end

---解析实例全部有效词条（含模板合并）
---@return table Rows 有效词条行数组
function EquipAffixSystem.ResolveAffixes(DefineID)
    local Result = {}
    for _, AffixID in ipairs(EquipAffixSystem.GetAffixIDs(DefineID)) do
        local Row = EquipAffixSystem.GetAffixRow(AffixID)
        if Row then
            Result[#Result + 1] = Row
        else
            print('[EquipAffix] 词条模板缺失或非法，已跳过 AffixID=' .. tostring(AffixID))
        end
    end
    return Result
end

---单条词条在生效等级下的加成
---@param Row table GetAffixRow 返回
---@param EffectiveLevel number min(槽位Lv, 品阶Cap)，无装备时为 0
function EquipAffixSystem.GetAffixBonus(Row, EffectiveLevel)
    EffectiveLevel = math.max(0, math.floor(EffectiveLevel or 0))
    if EffectiveLevel <= 0 or not Row then
        return 0
    end
    -- Atk/Hp 显式走槽区间累计（与槽加成同公式）；其余一律 PerLevel 线性
    if Row.BandSet == 'Atk' or Row.BandSet == 'Hp' then
        local OK, EquipSlotSystem = pcall(require, 'Script.Blueprint.Prefabs.UI.Equip.EquipSlotSystem')
        if OK and EquipSlotSystem then
            return EquipSlotSystem.GetSlotBonus(EffectiveLevel, Row.BandSet)
        end
        return 0
    end
    return (Row.PerLevel or 0) * EffectiveLevel
end

---DS 端：向物品实例追加词条（幂等，去重，不限数量）
---@param DefineID any 背包 DefineID
---@param AffixIDs table|string 单个 ID 或 ID 数组
---@return boolean OK
function EquipAffixSystem.ServerAddAffixes(DefineID, AffixIDs)
    if not UGCGameSystem.IsServer() then
        return false
    end
    if not DefineID then
        return false
    end
    local ToAdd = {}
    if type(AffixIDs) == 'string' then
        ToAdd = { AffixIDs }
    elseif type(AffixIDs) == 'table' then
        ToAdd = AffixIDs
    else
        return false
    end
    local OK, CustomData = pcall(function()
        return UGCItemSystemV2.LoadItemCustomData(DefineID)
    end)
    if not OK or type(CustomData) ~= 'table' then
        CustomData = {}
    end
    local Raw = CustomData[EquipAffixSystem.CUSTOM_KEY]
    local Merged, Seen = {}, {}
    local function Push(ID)
        if type(ID) == 'string' and ID ~= '' and not Seen[ID] then
            Seen[ID] = true
            Merged[#Merged + 1] = ID
        end
    end
    if type(Raw) == 'string' then
        Push(Raw)
    elseif type(Raw) == 'table' then
        for _, ID in pairs(Raw) do
            Push(ID)
        end
    end
    for _, ID in pairs(ToAdd) do
        Push(ID)
    end
    CustomData[EquipAffixSystem.CUSTOM_KEY] = Merged
    local OK2, Err = pcall(function()
        UGCItemSystemV2.SaveItemCustomData(DefineID, CustomData)
    end)
    if not OK2 then
        print('[EquipAffix] SaveItemCustomData 失败 err=' .. tostring(Err))
        return false
    end
    print('[EquipAffix] 已写入词条 count=' .. tostring(#Merged) .. ' ids=' .. table.concat(Merged, ','))
    return true
end

return EquipAffixSystem
