local UGCGameData = {}

function UGCGameData.GetLevelConfig(Lv)
    return UGCGameSystem.GetTableDataByRowName(UGCGameSystem.GetUGCResourcesFullPath(
        'Asset/Data/Level/UGCLevelConfig.UGCLevelConfig'), tostring(Lv))
end

function UGCGameData.GetGlobalLevelConfig()
    return UGCGameSystem.GetTableDataByRowName(UGCGameSystem.GetUGCResourcesFullPath(
        'Asset/Data/Level/UGCLevelGlobal.UGCLevelGlobal'), "Global")
end

function UGCGameData.GetMonsterConfig(MonsterID)
    return UGCGameSystem.GetTableDataByRowName(UGCGameSystem.GetUGCResourcesFullPath(
        'Asset/Data/Table/DT_MonsterDetails.DT_MonsterDetails'), tostring(MonsterID))
end

function UGCGameData.GetEquippmentAffixConfig(EquippmentID)
    return UGCGameSystem.GetTableDataByRowName(UGCGameSystem.GetUGCResourcesFullPath(
        'Asset/Data/Table/UGCEquippmentRandomAffix.UGCEquippmentRandomAffix'), tostring(EquippmentID))
end

function UGCGameData.GetAffixDetailsAllConfig()
    return UGCGameSystem.GetTableData(UGCGameSystem.GetUGCResourcesFullPath(
        'Asset/Data/Table/UGCAffixDetails.UGCAffixDetails'));
end

function UGCGameData.GetAffixDetailsConfig(AffixID)
    return UGCGameSystem.GetTableDataByRowName(UGCGameSystem.GetUGCResourcesFullPath(
        'Asset/Data/Table/UGCAffixDetails.UGCAffixDetails'), tostring(AffixID))
end

function UGCGameData.GetSkillDetailsConfig(SkillID)
    return UGCGameSystem.GetTableDataByRowName(UGCGameSystem.GetUGCResourcesFullPath(
        'Asset/Data/Table/UGCSkillDetails.UGCSkillDetails'), tostring(SkillID))
end

function UGCGameData.GetRespawnConfig(ModeID)
    local RespawnConfigTable = {}
    local GameModeConfigTable = UGCGameSystem.GetTableData(UGCGameSystem.GetUGCResourcesFullPath(
        'Asset/Data/Table/UGCGameModeConfig.UGCGameModeConfig'))
    for _, GameModeConfig in pairs(GameModeConfigTable) do
        if GameModeConfig.ModeID == ModeID then
            if GameModeConfig.FreeReviveCount then
                RespawnConfigTable.TotalFreeReviveCount = GameModeConfig.FreeReviveCount
                RespawnConfigTable.CurrentFreeReviveCount = GameModeConfig.FreeReviveCount
            else
                print("Warning: UGCGameData.GetRespawnConfig(ModeID) Table not found FreeReviveCount")
                RespawnConfigTable.TotalFreeReviveCount = 0
                RespawnConfigTable.CurrentFreeReviveCount = 0
            end

            if GameModeConfig.PaidReviveCount then
                RespawnConfigTable.TotalPaidReviveCount = GameModeConfig.PaidReviveCount
                RespawnConfigTable.CurrentPaidReviveCount = GameModeConfig.PaidReviveCount
            else
                print("Warning: UGCGameData.GetRespawnConfig(ModeID) Table not found PaidReviveCount")
                RespawnConfigTable.TotalPaidReviveCount = 0
                RespawnConfigTable.CurrentPaidReviveCount = 0
            end

            if GameModeConfig.Price then
                RespawnConfigTable.CurrencyID = GameModeConfig.Price[1]
                RespawnConfigTable.Price = GameModeConfig.Price[2]
            end
            if not RespawnConfigTable.CurrencyID then
                print("Warning: UGCGameData.GetRespawnConfig(ModeID) Table not found CurrencyID")
                RespawnConfigTable.CurrencyID = 0
            end
            if not RespawnConfigTable.Price then
                print("Warning: UGCGameData.GetRespawnConfig(ModeID) Table not found Price")
                RespawnConfigTable.Price = 0
            end
        end
    end
    return RespawnConfigTable
end

function UGCGameData.GetGameModeName(ModeID)
    local GameModeConfigTable = UGCGameSystem.GetTableData(UGCGameSystem.GetUGCResourcesFullPath(
        'Asset/Data/Table/UGCGameModeConfig.UGCGameModeConfig'))
    for _, GameModeConfig in pairs(GameModeConfigTable) do
        if GameModeConfig.ModeID == ModeID then
            return GameModeConfig.ModeName
        end
    end
end

function UGCGameData.GetGameModeActorMgrConfig(ModeID)
    local GameModeConfigTable = UGCGameSystem.GetTableData(UGCGameSystem.GetUGCResourcesFullPath(
        'Asset/Data/Table/UGCGameModeConfig.UGCGameModeConfig'))
    for _, GameModeConfig in pairs(GameModeConfigTable) do
        if GameModeConfig.ModeID == ModeID then
            return GameModeConfig.GameModeActorMgr
        end
    end
end

---------------------------------------------------------------------------
-- 物品实例数据系统
--
-- 核心思路：同类型物品只创建一个 ItemID，通过 DataID 区分不同实例的差异化属性
--
-- 实现步骤：
--   1. 提取实例数据有哪些，工程里配表，提供一个 DataID
--   2. 获取不同实例时，通过 SaveItemCustomData 将 DataID 记录下来
--   3. 重写物品属性读取接口，在接口里根据 DataID → 查表 → 读取对应属性
--
-- 数据来源：Asset/Data/Table/Customized/BattleItemInstance 数据表
--           行结构体：UGCTemplateRowStruct_InstanceDataTable
--           字段：ItemName / ItemDetail / ItemQuality 等
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- 一、实例数据表读取
---------------------------------------------------------------------------

--- 根据 DataID 获取实例数据行
---@param DataID string @实例数据ID，格式 "ItemID_Level"（如 "8310048_2"）
---@return table|nil @实例数据行
function UGCGameData.GetItemInstanceData(DataID)
    if not DataID or DataID == "" then
        ugcprint("UGCGameData.GetItemInstanceData DataID is nil")
        return nil
    end
    ugcprint("UGCGameData.GetItemInstanceData DataID=" .. tostring(DataID))
    return UGCGameSystem.GetTableDataByRowName(
        UGCGameSystem.GetUGCResourcesFullPath('Asset/Data/Table/Customized/InstanceData.InstanceData'),
        DataID)
end

---------------------------------------------------------------------------
-- 二、通过接口添加带实例数据的物品
--
-- 流程：AddItemV2 → 拿到 DefineIDs → SaveItemCustomData({DataID})
-- SaveItemCustomData 在 DS 端写入，CustomData 会自动复制到客户端
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- 三、物品属性读取重写
--
-- 使用 RegisterItemPropertyGetOverride 注册属性读取回调，
-- 当引擎查询物品属性（名称、图标等）时，先走回调，由我们决定返回什么值。
--
-- 核心逻辑：LoadItemCustomData → DataID → 查实例数据表 → 返回对应字段
---------------------------------------------------------------------------

UGCGameData._bItemOverrideRegistered = false

--- 内部：根据 ItemDefineID 获取实例数据行
--- 实例数据（CustomData.DataID）规范只存后缀（如 "1"），
--- 读取时用 ItemID（ItemDefineID.TypeSpecificID）拼成完整 DataID（如 "8310048_1"）再查表。
local function GetInstanceRow(ItemDefineID)

    local TypeSpecificID = ItemDefineID and ItemDefineID.TypeSpecificID
    print(string.format("[GetInstanceRow] TypeSpecificID=%s", tostring(TypeSpecificID)))

    local CustomData = UGCItemSystemV2.LoadItemCustomData(ItemDefineID)
    print(string.format("[GetInstanceRow] LoadItemCustomData result: %s",
        (CustomData == nil and "nil" or "exists")))

    if not CustomData or not CustomData.DataID then
        print("[GetInstanceRow] CustomData.DataID is empty, return nil ===== END =====")
        return nil
    end

    local Suffix = tostring(CustomData.DataID)
    local DataID = tostring(TypeSpecificID) .. "_" .. Suffix
    local Row = UGCGameData.GetItemInstanceData(DataID)
    return Row
end

--- 将 DataTable 中读取的图标值转为 FSoftObjectPath
--- UE DataTable 中 TSoftObjectPtr<UTexture2D> 字段在 Lua 端被解析为 UTexture2D*，
--- 但 GetXxxByDefineID 接口要求返回 FSoftObjectPath，必须做类型转换
---@param Value any @实例数据行中的图标字段值
---@return FSoftObjectPath|nil @转换后的软引用路径
local function ToSoftObjectPath(Value)
    if not Value or Value == "None" or Value == "" then
        return nil
    end
    local VType = type(Value)
    if VType == "string" then
        -- 字符串路径 → 构造 FSoftObjectPath
        return KismetSystemLibrary.MakeSoftObjectPath(Value)
    elseif VType == "table" then
        -- 已经是 FSoftObjectPath 结构体（table 表示），直接返回
        return Value
    elseif VType == "userdata" then
        -- UObject（如 UTexture2D*）→ 取路径名 → 构造 FSoftObjectPath
        local PathName = KismetSystemLibrary.GetPathName(Value)
        if PathName and PathName ~= "" and PathName ~= "None" then
            return KismetSystemLibrary.MakeSoftObjectPath(PathName)
        end
        return nil
    end
    return nil
end

--- 注册所有物品属性读取重写（服务器 & 客户端分别注册）
---@param bIsServer boolean|nil @可选，标记当前是否在服务器（权威）端执行；不传则尝试自动判断
function UGCGameData.RegisterItemPropertyOverrides(bIsServer)
    if UGCGameData._bItemOverrideRegistered then return end
    UGCGameData._bItemOverrideRegistered = true

    --==================== 环境判断（服务器 / 客户端） ====================
    local bServer = bIsServer
    if bServer == nil then
        -- 兜底判断：服务器上通常存在 GameMode，客户端一般没有
        bServer = (UGCGameSystem.GameMode ~= nil)
    end
    local EnvTag = bServer and "SERVER(服务器)" or "CLIENT(客户端)"

    print(string.format(
        "[ItemOverride][Register] >>> 开始注册物品属性重写 Env=%s (bIsServerArg=%s) <<<",
        EnvTag, tostring(bIsServer)))

    --==================== 按流程逐项注册，每注册一条打印一行 ====================

    --==================== 字符串类属性 ====================

    -- [01/16] 物品名称
    UGCItemSystemV2.RegisterItemPropertyGetOverride(EItemOverrideKey.ItemName, function(ItemDefineID)
        local TSID = ItemDefineID.TypeSpecificID
        local Row = GetInstanceRow(ItemDefineID)
        if Row and Row.ItemName and Row.ItemName ~= "" then
            print(string.format("[ItemOverride][ItemName] ItemID=%s source=InstanceData value=%s", tostring(TSID), tostring(Row.ItemName)))
            return Row.ItemName
        end
        print(string.format("[ItemOverride][ItemName] ItemID=%s source=DefaultV2", tostring(TSID)))
        return UGCItemSystemV2.GetItemNameV2(TSID)
    end)
    print(string.format("[ItemOverride][Register] [01/16] 已注册 ItemName Env=%s", EnvTag))

    -- [02/16] 物品详情
    UGCItemSystemV2.RegisterItemPropertyGetOverride(EItemOverrideKey.ItemDetail, function(ItemDefineID)
        local TSID = ItemDefineID.TypeSpecificID
        local Row = GetInstanceRow(ItemDefineID)
        if Row and Row.ItemDetail and Row.ItemDetail ~= "" then
            print(string.format("[ItemOverride][ItemDetail] ItemID=%s source=InstanceData", tostring(TSID)))
            return Row.ItemDetail
        end
        print(string.format("[ItemOverride][ItemDetail] ItemID=%s source=DefaultV2", tostring(TSID)))
        return UGCItemSystemV2.GetItemDetailV2(TSID)
    end)
    print(string.format("[ItemOverride][Register] [02/16] 已注册 ItemDetail Env=%s", EnvTag))

    -- [03/16] 物品拾取描述
    UGCItemSystemV2.RegisterItemPropertyGetOverride(EItemOverrideKey.ItemPickupDetail, function(ItemDefineID)
        local TSID = ItemDefineID.TypeSpecificID
        local Row = GetInstanceRow(ItemDefineID)
        if Row and Row.PickupDetail and Row.PickupDetail ~= "" then
            print(string.format("[ItemOverride][ItemPickupDetail] ItemID=%s source=InstanceData", tostring(TSID)))
            return Row.PickupDetail
        end
        print(string.format("[ItemOverride][ItemPickupDetail] ItemID=%s source=DefaultV2", tostring(TSID)))
        return UGCItemSystemV2.GetItemPickupDetailV2(TSID)
    end)
    print(string.format("[ItemOverride][Register] [03/16] 已注册 ItemPickupDetail Env=%s", EnvTag))

    -- [04/16] 背包简述名称
    UGCItemSystemV2.RegisterItemPropertyGetOverride(EItemOverrideKey.BackpackSimpleName, function(ItemDefineID)
        local TSID = ItemDefineID.TypeSpecificID
        local Row = GetInstanceRow(ItemDefineID)
        if Row and Row.ItemName and Row.ItemName ~= "" then
            print(string.format("[ItemOverride][BackpackSimpleName] ItemID=%s source=InstanceData value=%s", tostring(TSID), tostring(Row.ItemName)))
            return Row.ItemName
        end
        print(string.format("[ItemOverride][BackpackSimpleName] ItemID=%s source=DefaultV2", tostring(TSID)))
        return UGCItemSystemV2.GetBackpackSimpleNameV2(TSID)
    end)
    print(string.format("[ItemOverride][Register] [04/16] 已注册 BackpackSimpleName Env=%s", EnvTag))

    -- [05/16] 拾取物模型路径
    UGCItemSystemV2.RegisterItemPropertyGetOverride(EItemOverrideKey.PickupWrapperMeshPath, function(ItemDefineID)
        local TSID = ItemDefineID.TypeSpecificID
        local Row = GetInstanceRow(ItemDefineID)
        if Row and Row.PickupWrapperMesh and Row.PickupWrapperMesh ~= "None" and Row.PickupWrapperMesh ~= "" then
            print(string.format("[ItemOverride][PickupWrapperMeshPath] ItemID=%s source=InstanceData %s", tostring(TSID), KismetSystemLibrary.GetPathName(Row.PickupWrapperMesh)))
            return KismetSystemLibrary.GetPathName(Row.PickupWrapperMesh)
        end
        print(string.format("[ItemOverride][PickupWrapperMeshPath] ItemID=%s source=DefaultV2", tostring(TSID)))
        return UGCItemSystemV2.GetPickupWrapperMeshPathV2(TSID)
    end)
    print(string.format("[ItemOverride][Register] [05/16] 已注册 PickupWrapperMeshPath Env=%s", EnvTag))

    --==================== 图标类属性（FSoftObjectPath） ====================

    -- [06/16] 物品图标
    UGCItemSystemV2.RegisterItemPropertyGetOverride(EItemOverrideKey.ItemIconTexture, function(ItemDefineID)
        local TSID = ItemDefineID.TypeSpecificID
        local Row = GetInstanceRow(ItemDefineID)
        if Row and Row.IconTexture then
            local SoftPath = ToSoftObjectPath(Row.IconTexture)
            if SoftPath then
                print(string.format("[ItemOverride][ItemIconTexture] ItemID=%s source=InstanceData", tostring(TSID)))
                return SoftPath
            end
        end
        print(string.format("[ItemOverride][ItemIconTexture] ItemID=%s source=DefaultV2", tostring(TSID)))
        return UGCItemSystemV2.GetItemIconTextureV2(TSID)
    end)
    print(string.format("[ItemOverride][Register] [06/16] 已注册 ItemIconTexture Env=%s", EnvTag))

    -- [07/16] 物品图标（带玩家皮肤）
    UGCItemSystemV2.RegisterItemPropertyGetOverride(EItemOverrideKey.ItemIconWithPlayerSkin, function(ItemDefineID, PlayerController)
        local TSID = ItemDefineID.TypeSpecificID
        local Row = GetInstanceRow(ItemDefineID)
        if Row and Row.IconTexture then
            local SoftPath = ToSoftObjectPath(Row.IconTexture)
            if SoftPath then
                print(string.format("[ItemOverride][ItemIconWithPlayerSkin] ItemID=%s source=InstanceData", tostring(TSID)))
                return SoftPath
            end
        end
        print(string.format("[ItemOverride][ItemIconWithPlayerSkin] ItemID=%s source=DefaultV2", tostring(TSID)))
        return UGCItemSystemV2.GetItemIconWithPlayerSkinV2(TSID, PlayerController)
    end)
    print(string.format("[ItemOverride][Register] [07/16] 已注册 ItemIconWithPlayerSkin Env=%s", EnvTag))

    -- [08/16] 物品剪影图标
    UGCItemSystemV2.RegisterItemPropertyGetOverride(EItemOverrideKey.WhiteIconTexture, function(ItemDefineID)
        local TSID = ItemDefineID.TypeSpecificID
        local Row = GetInstanceRow(ItemDefineID)
        if Row and Row.WhiteIconTexture then
            local SoftPath = ToSoftObjectPath(Row.WhiteIconTexture)
            if SoftPath then
                print(string.format("[ItemOverride][WhiteIconTexture] ItemID=%s source=InstanceData", tostring(TSID)))
                return SoftPath
            end
        end
        print(string.format("[ItemOverride][WhiteIconTexture] ItemID=%s source=DefaultV2", tostring(TSID)))
        return UGCItemSystemV2.GetWhiteIconTextureV2(TSID)
    end)
    print(string.format("[ItemOverride][Register] [08/16] 已注册 WhiteIconTexture Env=%s", EnvTag))

    -- [09/16] 物品装备栏图标
    UGCItemSystemV2.RegisterItemPropertyGetOverride(EItemOverrideKey.BigIconTexture, function(ItemDefineID)
        local TSID = ItemDefineID.TypeSpecificID
        local Row = GetInstanceRow(ItemDefineID)
        if Row and Row.BigIconTexture then
            local SoftPath = ToSoftObjectPath(Row.BigIconTexture)
            if SoftPath then
                print(string.format("[ItemOverride][BigIconTexture] ItemID=%s source=InstanceData", tostring(TSID)))
                return SoftPath
            end
        end
        print(string.format("[ItemOverride][BigIconTexture] ItemID=%s source=DefaultV2", tostring(TSID)))
        return UGCItemSystemV2.GetBigIconTextureV2(TSID)
    end)
    print(string.format("[ItemOverride][Register] [09/16] 已注册 BigIconTexture Env=%s", EnvTag))

    -- [10/16] 物品装备栏图标（带玩家皮肤）
    UGCItemSystemV2.RegisterItemPropertyGetOverride(EItemOverrideKey.BigIconTextureWithPlayerSkin, function(ItemDefineID, PlayerController)
        local TSID = ItemDefineID.TypeSpecificID
        local Row = GetInstanceRow(ItemDefineID)
        if Row and Row.BigIconTexture then
            local SoftPath = ToSoftObjectPath(Row.BigIconTexture)
            if SoftPath then
                print(string.format("[ItemOverride][BigIconTextureWithPlayerSkin] ItemID=%s source=InstanceData", tostring(TSID)))
                return SoftPath
            end
        end
        print(string.format("[ItemOverride][BigIconTextureWithPlayerSkin] ItemID=%s source=DefaultV2", tostring(TSID)))
        return UGCItemSystemV2.GetBigIconTextureWithPlayerSkinV2(TSID, PlayerController)
    end)
    print(string.format("[ItemOverride][Register] [10/16] 已注册 BigIconTextureWithPlayerSkin Env=%s", EnvTag))

    --==================== 数值类属性 ====================

    -- [11/16] 物品品质
    UGCItemSystemV2.RegisterItemPropertyGetOverride(EItemOverrideKey.ItemQuality, function(ItemDefineID)
        local TSID = ItemDefineID.TypeSpecificID
        local Row = GetInstanceRow(ItemDefineID)
        if Row and Row.ItemQuality then
            print(string.format("[ItemOverride][ItemQuality] ItemID=%s source=InstanceData value=%s", tostring(TSID), tostring(Row.ItemQuality)))
            return Row.ItemQuality
        end
        print(string.format("[ItemOverride][ItemQuality] ItemID=%s source=DefaultV2", tostring(TSID)))
        return UGCItemSystemV2.GetItemQualityV2(TSID)
    end)
    print(string.format("[ItemOverride][Register] [11/16] 已注册 ItemQuality Env=%s", EnvTag))

    -- [12/16] 头部减伤属性
    UGCItemSystemV2.RegisterItemPropertyGetOverride(EItemOverrideKey.HeadDamageReduce, function(ItemDefineID)
        local TSID = ItemDefineID.TypeSpecificID
        local Row = GetInstanceRow(ItemDefineID)
        if Row and Row.HeadDamageReduce then
            print(string.format("[ItemOverride][HeadDamageReduce] ItemID=%s source=InstanceData value=%s", tostring(TSID), tostring(Row.HeadDamageReduce)))
            return Row.HeadDamageReduce
        end
        print(string.format("[ItemOverride][HeadDamageReduce] ItemID=%s source=DefaultV2", tostring(TSID)))
        return UGCItemSystemV2.GetHeadDamageReduceV2(TSID)
    end)
    print(string.format("[ItemOverride][Register] [12/16] 已注册 HeadDamageReduce Env=%s", EnvTag))

    -- [13/16] 身体减伤属性
    UGCItemSystemV2.RegisterItemPropertyGetOverride(EItemOverrideKey.BodyDamageReduce, function(ItemDefineID)
        local TSID = ItemDefineID.TypeSpecificID
        local Row = GetInstanceRow(ItemDefineID)
        if Row and Row.BodyDamageReduce then
            print(string.format("[ItemOverride][BodyDamageReduce] ItemID=%s source=InstanceData value=%s", tostring(TSID), tostring(Row.BodyDamageReduce)))
            return Row.BodyDamageReduce
        end
        print(string.format("[ItemOverride][BodyDamageReduce] ItemID=%s source=DefaultV2", tostring(TSID)))
        return UGCItemSystemV2.GetBodyDamageReduceV2(TSID)
    end)
    print(string.format("[ItemOverride][Register] [13/16] 已注册 BodyDamageReduce Env=%s", EnvTag))

    -- [14/16] 背包格子数
    UGCItemSystemV2.RegisterItemPropertyGetOverride(EItemOverrideKey.BackpackCell, function(ItemDefineID)
        local TSID = ItemDefineID.TypeSpecificID
        local Row = GetInstanceRow(ItemDefineID)
        if Row and Row.BackpackCell then
            print(string.format("[ItemOverride][BackpackCell] ItemID=%s source=InstanceData value=%s", tostring(TSID), tostring(Row.BackpackCell)))
            return Row.BackpackCell
        end
        print(string.format("[ItemOverride][BackpackCell] ItemID=%s source=DefaultV2", tostring(TSID)))
        return UGCItemSystemV2.GetBackpackCellV2(TSID)
    end)
    print(string.format("[ItemOverride][Register] [14/16] 已注册 BackpackCell Env=%s", EnvTag))

    -- [15/16] 物品等级
    UGCItemSystemV2.RegisterItemPropertyGetOverride(EItemOverrideKey.ItemLevel, function(ItemDefineID)
        local TSID = ItemDefineID.TypeSpecificID
        local Row = GetInstanceRow(ItemDefineID)
        if Row and Row.ItemLevel then
            print(string.format("[ItemOverride][ItemLevel] ItemID=%s source=InstanceData value=%s", tostring(TSID), tostring(Row.ItemLevel)))
            return Row.ItemLevel
        end
        print(string.format("[ItemOverride][ItemLevel] ItemID=%s source=DefaultV2", tostring(TSID)))
        return UGCItemSystemV2.GetItemLevelV2(TSID)
    end)
    print(string.format("[ItemOverride][Register] [15/16] 已注册 ItemLevel Env=%s", EnvTag))

    -- [16/16] 物品耐久度（无非 ByDefineID 版本，直接通过 ItemHandle 回退）
    UGCItemSystemV2.RegisterItemPropertyGetOverride(EItemOverrideKey.NewDurability, function(ItemDefineID)
        local TSID = ItemDefineID.TypeSpecificID
        local Row = GetInstanceRow(ItemDefineID)
        if Row and Row.NewDurability then
            print(string.format("[ItemOverride][NewDurability] ItemID=%s source=InstanceData value=%s", tostring(TSID), tostring(Row.NewDurability)))
            return Row.NewDurability
        end
        local ItemHandle = UGCItemSystemV2.GetConfigItemHandle(TSID)
        if ItemHandle then
            print(string.format("[ItemOverride][NewDurability] ItemID=%s source=ItemHandle value=%s", tostring(TSID), tostring(ItemHandle.NewDurability)))
            return ItemHandle.NewDurability
        end
        print(string.format("[ItemOverride][NewDurability] ItemID=%s source=Default(0)", tostring(TSID)))
        return 0
    end)
    print(string.format("[ItemOverride][Register] [16/16] 已注册 NewDurability Env=%s", EnvTag))

    print(string.format("[ItemOverride][Register] >>> 注册完成（共16项）Env=%s <<<", EnvTag))
end

return UGCGameData
