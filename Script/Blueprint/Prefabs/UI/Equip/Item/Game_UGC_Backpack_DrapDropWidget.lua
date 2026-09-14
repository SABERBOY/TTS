---@class Game_UGC_Backpack_DrapDropWidget_C:UUserWidget
---@field ItemSlot UCanvasPanel
---@field DragDrapWidget bool
--Edit Below--
---@class Game_UGC_Backpack_DrapDropWidget:UUserWidget
---@field ItemSlot UCanvasPanel
local Game_UGC_Backpack_DrapDropWidget = {
    UGC_Common_Item_UIBP = nil,     -- CommonItem弱引用
    DefineID = nil,                 -- 物品实例标识
    ItemID = nil,                   -- 物品ID
    bInitDoOnce = false,            -- 初始化标志，确保LuaInit只执行一次
}

--- 生命周期：构造时加载CommonItem子控件
function Game_UGC_Backpack_DrapDropWidget:Construct()
    self:LuaInit()
end

--- 生命周期：析构时清除引用
function Game_UGC_Backpack_DrapDropWidget:Destruct()
end

--- 初始化函数，通过bInitDoOnce确保整个生命周期只执行一次
function Game_UGC_Backpack_DrapDropWidget:LuaInit()
    if self.bInitDoOnce then
        return
    end
    self.bInitDoOnce = true
    self:LoadCommonItemWidget()
end

--- 获取CommonItem控件（弱引用安全访问）
--- @return UGC_Common_Item_UIBP_C|nil
function Game_UGC_Backpack_DrapDropWidget:GetCommonItemWidget()
    local ref = self.UGC_Common_Item_UIBP
    return ref and ref:IsValid() and ref:Get() or nil
end

--- 异步加载CommonItem子控件
function Game_UGC_Backpack_DrapDropWidget:LoadCommonItemWidget()
    -- 检查是否已存在有效的CommonItem，避免重复创建
    local ExistingWidget = self:GetCommonItemWidget()
    if UE.IsValid(ExistingWidget) then
        return
    end

    local WeakSelf = WeakObjectPtr(self)
    UGCBackpackSystemV2.CreateCommonItemWidget(self.ItemSlot, function(CommonItem)
        if not WeakSelf:IsValid() then
            return
        end

        if not UE.IsValid(CommonItem) then
            return
        end

        local Self = WeakSelf:Get()
        -- 再次检查是否已存在（防止异步回调时已有新的创建）
        local ExistingRef = Self:GetCommonItemWidget()
        if UE.IsValid(ExistingRef) then
            -- 移除重复创建的控件
            CommonItem:RemoveFromParent()
        else
            ExistingRef = CommonItem
        end

        Self.UGC_Common_Item_UIBP = WeakObjectPtr(ExistingRef)
        -- 加载完成时若已有数据，立即刷新
        local Item = Self.DefineID or (Self.ItemID and Self.ItemID > 0 and Self.ItemID)
        if Item then
            ExistingRef:SetItemInfo({Item = Item})
        end
    end)
end

--- 清空UI显示和数据
function Game_UGC_Backpack_DrapDropWidget:ClearUI()
    self.DefineID = nil
    self.ItemID = nil
    self.ItemSlot:SetVisibility(ESlateVisibility.Collapsed)

    local Widget = self:GetCommonItemWidget()
    if Widget then
        Widget:SetItemInfo()
    end
end

--- @param DragData table @拖拽数据
function Game_UGC_Backpack_DrapDropWidget:InitData(DragData)
    if not DragData then
        self:ClearUI()
        return
    end

    local ItemDefineID = DragData.ItemDefineID
    local ItemID = ItemDefineID and ItemDefineID.TypeSpecificID or DragData.ItemID
    if not ItemID or ItemID <= 0 then
        self:ClearUI()
        return
    end

    -- 保存数据并刷新显示
    self.DefineID = ItemDefineID and totable(ItemDefineID) or nil
    self.ItemID = ItemID
    self.ItemSlot:SetVisibility(ESlateVisibility.SelfHitTestInvisible)

    local Widget = self:GetCommonItemWidget()
    if Widget then
        Widget:SetItemInfo({Item = self.DefineID or self.ItemID})
    end
end

return Game_UGC_Backpack_DrapDropWidget