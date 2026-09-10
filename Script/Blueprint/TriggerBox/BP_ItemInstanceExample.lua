---@class BP_ItemInstanceExample_C:ActivityBaseActor
---@field Box UBoxComponent
---@field StaticMesh2 UStaticMeshComponent
---@field StaticMesh UStaticMeshComponent
---@field ParticleSystem UParticleSystemComponent
---@field UGCPresetCommonDropItemComponent UGCPresetCommonDropItemComponent_C
---@field Widget2 UWidgetComponent
---@field Widget1 UWidgetComponent
---@field BoxCollision UBoxComponent
---@field ClickActorComponentBase UClickActorComponentBase
---@field Widget UWidgetComponent
---@field DefaultSceneRoot USceneComponent
---@field DataID FString @物品实例数据ID，格式 "ItemID_Level"（如 "8310000_1"），在编辑器中配置。ItemID 从 DataID 自动解析，无需单独配置
-- Edit Below--
local BP_ItemInstanceExample = {
    bResetItemID = false
}

function BP_ItemInstanceExample:GetReplicatedProperties()
    return "DataID"
end

function BP_ItemInstanceExample:CheckCanActive(ClickParam)
    return true;
end
function BP_ItemInstanceExample:OnActive(ClickParam)
    print(string.format("[ItemInstanceExample] OnActive DataID=%s", tostring(self.DataID)))
    self:JumpToState("Running")
end

--- 从 DataID 解析出 ItemID（DataID 格式为 "ItemID_Level"）
---@return number|nil @解析出的 ItemID
function BP_ItemInstanceExample:ParseItemID()
    if not self.DataID or self.DataID == "" then
        return nil
    end
    local UGCGameData = require('Script.Blueprint.UGCGameData')
    local Parsed = UGCGameData.ParseItemIDFromDataID(self.DataID)
    if Parsed then
        return tonumber(Parsed)
    end
    return nil
end

function BP_ItemInstanceExample:ReceiveBeginPlay()
    print(string.format("[ItemInstanceExample] ReceiveBeginPlay DataID=%s IsServer=%s",
        tostring(self.DataID), tostring(UGCGameSystem.IsServer())))

    UnrealNetwork.RepLazyProperty(self, "DataID")
    self.bResetItemID = false
    self.SuperClass.ReceiveBeginPlay(self)

    -- 服务器端：从 DataID 解析 ItemID，用于 DropItemComponent 等需要
    if UGCGameSystem.IsServer() then
        local ParsedItemID = self:ParseItemID()
        if ParsedItemID then
            self.ItemID = ParsedItemID
            print(string.format("[ItemInstanceExample] Server: parsed ItemID=%d from DataID=%s",
                ParsedItemID, tostring(self.DataID)))
        else
            print(string.format("[ItemInstanceExample] Server: DataID is empty or invalid, DataID=%s",
                tostring(self.DataID)))
        end
        return
    end

    -- 客户端：统一设置字体大小
    self.Widget.Widget.TextBlock_Title.Font.Size = 20
    self.Widget1.Widget.TextBlock_Title.Font.Size = 10
    self.Widget2.Widget.TextBlock_Title.Font.Size = 20
end

--- DataID 同步回调，客户端根据 DataID 解析 ItemID 并更新显示
function BP_ItemInstanceExample:OnRep_DataID()
    if UGCGameSystem.IsServer() then
        return
    end

    local UGCGameData = require('Script.Blueprint.UGCGameData')
    local DataID = self.DataID
    local ItemID = self:ParseItemID() or 0

    print(string.format("[ItemInstanceExample] OnRep_DataID Client: DataID=%s parsedItemID=%d",
        tostring(DataID), ItemID))

    -- 获取物品基础信息
    local bV2Item = UGCItemSystemV2.IsObjEditorItemV2(ItemID)
    local ItemName = UGCItemSystemV2.GetItemNameV2(ItemID)
    local ItemDetails = self:wrap_text(UGCItemSystemV2.GetItemDetailV2(ItemID), 50)

    -- 用实例数据覆盖显示
    if DataID and DataID ~= "" then
        local InstanceRow = UGCGameData.GetItemInstanceData(DataID)
        if InstanceRow then
            print(string.format("[ItemInstanceExample] OnRep_DataID: instance data found, ItemName=%s ItemDetail=%s",
                tostring(InstanceRow.ItemName), tostring(InstanceRow.ItemDetail)))
            if InstanceRow.ItemName then
                ItemName = InstanceRow.ItemName
            end
            if InstanceRow.ItemDetail then
                ItemDetails = self:wrap_text(InstanceRow.ItemDetail, 50)
            end
        else
            print(string.format("[ItemInstanceExample] OnRep_DataID: instance data NOT found for DataID=%s", tostring(DataID)))
        end
    end

    self.Widget.Widget.TextBlock_Title:SetText(ItemName)
    self.Widget1.Widget.TextBlock_Title:SetText(ItemDetails)

    if bV2Item then
        self.Widget2.Widget.TextBlock_Title:SetText("物品:"..tostring(ItemID).." DataID:"..tostring(DataID or ""))
    end

    print(string.format("[ItemInstanceExample] OnRep_DataID: display updated ItemName=%s", tostring(ItemName)))
end

---------------------------------------------------------------------------
-- 物品实例化数据：场景拾取物产出带实例数据的物品
--
-- 参考原始 BP_ItemSingleExample 的 Running_Entry 实现，
-- 原始流程：UGCPresetCommonDropItemComponent:StartDrop → 产出 Wrapper → 玩家拾取
--
-- 实例化改造：用 UGCItemSystemV2.SpawnPickupWrapper 产出自定义 Wrapper，
-- 该 API 原生支持传入 CustomData（含 DataID），拾取时自动写入物品实例数据。
--
-- 同时保留原始 StartDrop 路径（不配 DataID 时走原逻辑）。
---------------------------------------------------------------------------

function BP_ItemInstanceExample:Running_Entry()
    print(string.format("[ItemInstanceExample] Running_Entry DataID=%s", tostring(self.DataID)))

    -- 有 DataID 才能产出实例化拾取物
    if self.DataID and self.DataID ~= "" then
        print("[ItemInstanceExample] Running_Entry: has DataID, using SpawnPickupWrapper")
        self:Running_EntryWithInstanceData()
        return
    end

    -- 无 DataID，走原始 StartDrop 逻辑（需有 self.ItemID）
    print(string.format("[ItemInstanceExample] Running_Entry: no DataID, fallback to StartDrop ItemID=%s",
        tostring(self.ItemID)))
    if not self.bResetItemID and self.ItemID then
        self.UGCPresetCommonDropItemComponent.StrategySelector.DropItemStrategy_Defaults.DropItemListGeneratorSelector
            .DropItemListGenerator_BluePrint[1].CachedConfig[1].ItemID = self.ItemID
    end

    local TraceIgnoreActors = {
        [0] = self
    }
    self.UGCPresetCommonDropItemComponent:StartDrop(self, nil, TraceIgnoreActors)
    self:JumpToState("Normal")
end

--- 产出带实例数据的拾取物
--- 使用 UGCItemSystemV2.SpawnPickupWrapper，原生支持 CustomData
--- ItemID 从 DataID 中解析，无需单独配置
function BP_ItemInstanceExample:Running_EntryWithInstanceData()
    local ItemID = self:ParseItemID()
    local DataID = self.DataID

    print(string.format("[ItemInstanceExample] Running_EntryWithInstanceData: DataID=%s parsedItemID=%s",
        tostring(DataID), tostring(ItemID)))

    if not ItemID then
        print(string.format("[ItemInstanceExample] Running_EntryWithInstanceData: ParseItemID FAILED from DataID=%s",
            tostring(DataID)))
        self:JumpToState("Normal")
        return
    end

    -- 1. 获取产出位置：以 StaticMesh 组件位置为基准，向上偏移 50
    local MeshLocation = self.StaticMesh:K2_GetComponentLocation()
    local SpawnLocation = { X = MeshLocation.X, Y = MeshLocation.Y, Z = MeshLocation.Z + 50 }

    -- 2. 构造 CustomData，包含 DataID
    local CustomData = { DataID = DataID }

    -- 3. 使用 SpawnPickupWrapper 产出拾取物，原生支持传入 CustomData
    print(string.format("[ItemInstanceExample] Calling SpawnPickupWrapper ItemID=%d Count=1 DataID=%s",
        ItemID, tostring(DataID)))
    local SpawnedWrapper = UGCItemSystemV2.SpawnPickupWrapper(SpawnLocation, ItemID, 1, CustomData)
    if SpawnedWrapper then
        print(string.format("[ItemInstanceExample] SpawnPickupWrapper SUCCESS ItemID=%d DataID=%s Wrapper=%s",
            ItemID, tostring(DataID), tostring(SpawnedWrapper)))
    else
        print(string.format("[ItemInstanceExample] SpawnPickupWrapper FAILED ItemID=%d DataID=%s, fallback to StartDrop",
            ItemID, tostring(DataID)))
        -- 降级：回退到原始 StartDrop 逻辑
        if not self.bResetItemID then
            self.UGCPresetCommonDropItemComponent.StrategySelector.DropItemStrategy_Defaults.DropItemListGeneratorSelector
                .DropItemListGenerator_BluePrint[1].CachedConfig[1].ItemID = ItemID
        end
        local TraceIgnoreActors = { [0] = self }
        self.UGCPresetCommonDropItemComponent:StartDrop(self, nil, TraceIgnoreActors)
    end

    self:JumpToState("Normal")
    print(string.format("[ItemInstanceExample] Running_EntryWithInstanceData: done, jumped to Normal"))
end

function BP_ItemInstanceExample:wrap_text(text, max_width)
    if not text then
        return ""
    end

    local lines = {}
    local current_line = ""
    local current_width = 0

    for char in self:iter_utf8_chars(text) do
        local char_width = #char >= 3 and 2 or 1

        if current_width + char_width > max_width then
            table.insert(lines, current_line)
            current_line = char
            current_width = char_width
        else
            current_line = current_line .. char
            current_width = current_width + char_width
        end
    end

    if current_line ~= "" then
        table.insert(lines, current_line)
    end

    return table.concat(lines, "\n")
end

function BP_ItemInstanceExample:iter_utf8_chars(s)
    if not s then
        return function()
            return nil
        end
    end

    local i = 1
    return function()
        if i > #s then
            return nil
        end

        local b = s:byte(i)
        local len = 1

        if b >= 0xF0 then
            len = 4
        elseif b >= 0xE0 then
            len = 3
        elseif b >= 0xC0 then
            len = 2
        end

        local char = s:sub(i, i + len - 1)
        i = i + len
        return char
    end
end

return BP_ItemInstanceExample
