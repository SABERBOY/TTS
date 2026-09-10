---@class BP_ItemSingleExample_C:ActivityBaseActor
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
---@field ItemID int32
--Edit Below--
---@class BP_ItemSingleExample_C:ActivityBaseActor
---@field StaticMesh2 UStaticMeshComponent
---@field UGCPresetCommonDropItemComponent UUGCPresetCommonDropItemComponent_C
---@field Widget2 UWidgetComponent
---@field Widget1 UWidgetComponent
---@field BoxCollision UBoxComponent
---@field ClickActorComponentBase UClickActorComponentBase
---@field Widget UWidgetComponent
---@field StaticMesh UStaticMeshComponent
---@field DefaultSceneRoot USceneComponent
---@field ItemID int32
-- Edit Below--
local BP_ItemSingleExample = {
    bResetItemID = false
}

function BP_ItemSingleExample:GetReplicatedProperties()
    return "ItemID"
end

function BP_ItemSingleExample:CheckCanActive(ClickParam)
    return true;
end
function BP_ItemSingleExample:OnActive(ClickParam)
    self:JumpToState("Running")
end

function BP_ItemSingleExample:ReceiveBeginPlay()
    UnrealNetwork.RepLazyProperty(self, "ItemID")
    self.bResetItemID = false
    self.SuperClass.ReceiveBeginPlay(self)

    -- 统一设置字体大小
    if UGCGameSystem.IsServer() then
        return
    end
    self.Widget.Widget.TextBlock_Title.Font.Size = 20
    self.Widget1.Widget.TextBlock_Title.Font.Size = 10
    self.Widget2.Widget.TextBlock_Title.Font.Size = 20
end

function BP_ItemSingleExample:OnRep_ItemID()
    if UGCGameSystem.IsServer() then
        return
    end

    local ItemDetails = self:wrap_text(UGCItemSystemV2.GetItemDetailV2(self.ItemID), 50)
    local bV2Item = UGCItemSystemV2.IsObjEditorItemV2(self.ItemID)
    local ItemName = UGCItemSystemV2.GetItemNameV2(self.ItemID)

    self.Widget.Widget.TextBlock_Title:SetText(ItemName)
    self.Widget1.Widget.TextBlock_Title:SetText(ItemDetails)

    if bV2Item then
        self.Widget2.Widget.TextBlock_Title:SetText("物品："..tostring(self.ItemID))
    end
end

function BP_ItemSingleExample:Running_Entry()
    if not self.bResetItemID then
        self.UGCPresetCommonDropItemComponent.StrategySelector.DropItemStrategy_Defaults.DropItemListGeneratorSelector
            .DropItemListGenerator_BluePrint[1].CachedConfig[1].ItemID = self.ItemID
    end

    local TraceIgnoreActors = {
        [0] = self
    }
    self.UGCPresetCommonDropItemComponent:StartDrop(self, nil, TraceIgnoreActors)
    self:JumpToState("Normal")
end

function BP_ItemSingleExample:wrap_text(text, max_width)
    if not text then
        return ""
    end

    local lines = {}
    local current_line = ""
    local current_width = 0

    for char in self:iter_utf8_chars(text) do
        -- 判断字符宽度（中文占2，其他占1）
        local char_width = #char >= 3 and 2 or 1

        -- 检查是否需要换行
        if current_width + char_width > max_width then
            table.insert(lines, current_line)
            current_line = char
            current_width = char_width
        else
            current_line = current_line .. char
            current_width = current_width + char_width
        end
    end

    -- 添加最后一行
    if current_line ~= "" then
        table.insert(lines, current_line)
    end

    return table.concat(lines, "\n")
end
function BP_ItemSingleExample:iter_utf8_chars(s)
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

        if b >= 0xF0 then -- 4字节字符
            len = 4
        elseif b >= 0xE0 then -- 3字节字符
            len = 3
        elseif b >= 0xC0 then -- 2字节字符
            len = 2
        end

        local char = s:sub(i, i + len - 1)
        i = i + len
        return char
    end
end

return BP_ItemSingleExample
