---@class UGC_ItemDetail_UIBP_C:UAEUserWidget
---@field Button_CLose UButton
---@field Button_Contrast UButton
---@field Button_Mask UButton
---@field Button_SwitchWeapon UButton
---@field CanvasPanel_CommonItem UCanvasPanel
---@field CanvasPanel_MainWeaponDetail UCanvasPanel
---@field CanvasPanel_SubWeaponDetail UCanvasPanel
---@field HorizontalBox1 UHorizontalBox
---@field HorizontalBox2 UHorizontalBox
---@field Image_Quality UImage
---@field ItemDetails UCanvasPanel
---@field Panel_Accessory UCanvasPanel
---@field Panel_Btn UCanvasPanel
---@field Panel_Btn_1 UCanvasPanel
---@field Panel_Btn_2 UCanvasPanel
---@field Panel_Btn_3 UCanvasPanel
---@field Panel_Btn_4 UCanvasPanel
---@field PanelTabSwitch UCanvasPanel
---@field ReuseList2_Accessory UGC_ReuseList2_C
---@field ScrollBox_9 UScrollBox
---@field Spacer_Size USpacer
---@field Switcher_Contrast UWidgetSwitcher
---@field TextBlock_1 UTextBlock
---@field TextBlock_2 UTextBlock
---@field TextBlock_3 UTextBlock
---@field TextBlock_4 UTextBlock
---@field TextBlock_IconName UTextBlock
---@field TextBlock_Title UTextBlock
---@field Title UCanvasPanel
---@field UGC_ItemDetails_Btn_1 UGC_ItemDetails_Btn_UIBP_C
---@field UGC_ItemDetails_Btn_2 UGC_ItemDetails_Btn_UIBP_C
---@field UGC_ItemDetails_Btn_UIBP_C_1 UGC_ItemDetails_Btn_UIBP_C
---@field UGC_ItemDetails_Btn_UIBP_C_2 UGC_ItemDetails_Btn_UIBP_C
---@field UGC_ReuseList2_Fitting UGC_ReuseList2_C
---@field UGC_ReuseList2_Item UGC_ReuseList2_C
---@field UGC_ReuseList2_Tab UGC_ReuseList2_C
---@field UTRichTextBlock_describe UUTRichTextBlock
---@field VerticalBox_PropsSlot UVerticalBox
---@field VerticalBox_slot UVerticalBox
---@field WidgetSwitcher_Style UWidgetSwitcher
---@field WidgetSwitcher_Weapon UWidgetSwitcher
---@field MaxHeightDesizedSize float
--Edit Below--
local UGC_ItemDetail_UIBP =
{

    bInitDoOnce = false,

    ItemDatas = nil,
    AttachItems = {},
    AccessorySlots = {},

    UGC_Common_Item_UIBP = nil,

    MainWeaponDetailWidget = nil,
    SubWeaponDetailWidget = nil,

    -- 配件列表ItemClass路径（从BackpackUIComponent.AttachListItemWidget读取，或通过InitData参数传入）
    AttachListItemClassPath = nil,
    -- ItemClass是否已加载并设置到ReuseList2
    bAttachItemClassLoaded = false,

    -- ReuseList2_Accessory的ItemClass是否已加载
    bAccessoryItemClassLoaded = false,

    InParams = nil,

    OnContrastClickCallback = nil,      -- 对比按钮点击回调
    OnCloseClickCallback = nil,         -- 关闭按钮点击回调

    -- 武器Tab列表（通过 UGC_ReuseList2_Tab 展示）
    WeaponTabList = nil,                -- 武器槽位数据列表 {{Idx=1, Name="武器一", bHasWeapon=true}, ...}
    WeaponTabSelectedIdx = 1,           -- 当前选中的Tab索引
    OnWeaponTabClickCallback = nil,     -- 武器Tab点击回调
}


--构造函数，UI创建时自动调用
function UGC_ItemDetail_UIBP:Construct()
    self:LuaInit()
end


--Lua初始化函数
function UGC_ItemDetail_UIBP:LuaInit()
    if self.bInitDoOnce then
        return
    end
    self.bInitDoOnce = true

    -- 绑定配件列表更新回调
    if self.UGC_ReuseList2_Item then
        self.UGC_ReuseList2_Item.OnUpdateItem:Add(self.OnUpdateItem, self)
    end

    -- 绑定对比按钮点击事件
    if self.Button_Contrast then
        self.Button_Contrast.OnClicked:Add(self.OnContrastClicked, self)
        self.Button_Contrast:SetVisibility(ESlateVisibility.Hidden)
    end

    -- 绑定关闭按钮点击事件（子面板自身不隐藏，由外部容器控制显隐）
    if self.Button_Close then
        self.Button_Close.OnClicked:Add(self.OnCloseClicked, self)
    end

    -- 绑定武器Tab列表更新回调（ReuseList2 渲染武器一/武器二/...Tab）
    if self.UGC_ReuseList2_Tab then
        self.UGC_ReuseList2_Tab.OnUpdateItem:Add(self.OnUpdateItem_Tab, self)
    end

    -- 绑定通用物品配件列表更新回调（ReuseList2_Accessory）
    if self.ReuseList2_Accessory then
        self.ReuseList2_Accessory.OnUpdateItem:Add(self.OnUpdateItem_Accessory, self)
    end

    -- 默认隐藏武器Tab切换容器（PanelTabSwitch），仅在有武器Tab数据时显示
    if self.PanelTabSwitch then
        self.PanelTabSwitch:SetVisibility(ESlateVisibility.Hidden)
    end

    -- 预加载配件列表ItemClass
    self:LoadAttachListItemClass()
    self:LoadAccessoryItemClass()
    self:LoadCommonItemWidget()
end


--异步加载配件列表ItemClass
--功能：通过 GetBackpackUIComponentConfig 统一读取 AttachListItemWidget 控件路径并异步加载ItemClass
function UGC_ItemDetail_UIBP:LoadAttachListItemClass()
    local RawValue = UGCBackpackSystemV2.GetBackpackUIComponentConfig(EBackpackUIComponentConfigKey.Widget_AttachListItemWidget)
    self.AttachListItemClassPath = UGCObjectUtility.GetPathBySoftObjectPath(RawValue)

    if not self.AttachListItemClassPath or self.AttachListItemClassPath == "" then
        return
    end

    self:SetAttachItemClassAndReload(self.AttachListItemClassPath)
end


--异步加载Common_Item控件
function UGC_ItemDetail_UIBP:LoadCommonItemWidget()
    local WeakSelf = WeakObjectPtr(self)
    UGCBackpackSystemV2.CreateCommonItemWidget(self.CanvasPanel_CommonItem, function(CommonItem)
        if not WeakSelf:IsValid() then return end
        local selfRef = WeakSelf:Get()
        if not selfRef then return end
        if not CommonItem or not UE.IsValid(CommonItem) then
            return
        end
        selfRef.UGC_Common_Item_UIBP = WeakObjectPtr(CommonItem)
    end)
end


---对比按钮点击内部处理函数
function UGC_ItemDetail_UIBP:OnContrastClicked()
    if self.OnContrastClickCallback then
        self.OnContrastClickCallback()
    end
end


---关闭按钮点击内部处理函数
function UGC_ItemDetail_UIBP:OnCloseClicked()
    if self.OnCloseClickCallback then
        self.OnCloseClickCallback()
    end
end


---开放化接口：InitData

---设置对比按钮选中状态（切换颜色：0=未对比/白色，1=对比中/黄色）
---@param bSelected boolean @是否处于对比中
function UGC_ItemDetail_UIBP:SetContrastSelected(bSelected)
    if self.Switcher_Contrast then
        self.Switcher_Contrast:SetActiveWidgetIndex(bSelected and 1 or 0)
    end
end


---开放化接口：InitData
---功能：初始化并显示物品详情面板
---@param InParams table @参数表 {
---  ItemData:           table              @单个物品数据（必选）
---    ItemDefineID:     FItemDefineID     @物品实例ID（推荐，优先使用，含TypeSpecificID字段）
---    ItemID:            number            @物品配置ID（ItemDefineID为空时的降级标识）
---    ItemCount:         number            @物品数量（默认0）
---  CompareItemData:    table|nil          @对比物品数据（单个物品，当前对比面板中选中的对比物品；切换对比Tab时重新InitData并更新）
---  CloseCallback:      function|nil       @关闭按钮点击回调
---  OnContrastClick:    function|nil       @对比按钮点击回调（点击Button_Contrast时触发）
---}
function UGC_ItemDetail_UIBP:InitData(InParams)
    InParams = InParams or {}
    self.ItemDatas = InParams.ItemData
    self.InParams = InParams

    -- 根据是否有对比物品，刷新对比按钮颜色（0=未对比/白色，1=对比中/黄色）
    local CompareItemData = InParams.CompareItemData
    local bHasCompare = CompareItemData ~= nil
    self:SetContrastSelected(bHasCompare)

    -- 设置关闭按钮回调（由外部传入，点击Button_Close时触发）
    if InParams.CloseCallback then
        self.OnCloseClickCallback = InParams.CloseCallback
    else
        -- 未绑定关闭回调则隐藏关闭按钮
        if self.Button_Close then
            self.Button_Close:SetVisibility(ESlateVisibility.Collapsed)
        end
    end

    -- 设置对比按钮回调（由外部传入，点击Button_Contrast时触发）
    if InParams.OnContrastClick then
        self.OnContrastClickCallback = InParams.OnContrastClick
        self.Button_Contrast:SetVisibility(ESlateVisibility.Visible)
    else
        self.Button_Contrast:SetVisibility(ESlateVisibility.Collapsed)
    end

    self:Refresh()
end


--刷新面板内容
function UGC_ItemDetail_UIBP:Refresh()
    if self.ItemDatas == nil or not self.ItemDatas.ItemDefineID then
        return
    end

    self:InitCustomWidgets(self.ItemDatas)
    self:SetItemInfo(self.ItemDatas)
end


--清理面板内容
function UGC_ItemDetail_UIBP:Clear()
    if self.VerticalBox_slot then
        self.VerticalBox_slot:ClearChildren()
    end

    -- 清理配件列表数据
    self.AttachItems = {}
    self.AccessorySlots = {}

    if self.Title then
        self.Title:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
    end

    if self.UTRichTextBlock_describe then
        self.UTRichTextBlock_describe:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
    end

    if self.Image_Quality then
        self.Image_Quality:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
    end

    if self.ItemDetails then
        self.ItemDetails:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
    end
end


--异步创建UI控件
--@param WidgetPath string @控件蓝图路径
--@param Callback function @创建完成回调
function UGC_ItemDetail_UIBP:CreateUIWidgetAsync(WidgetPath, Callback)
    if not WidgetPath or WidgetPath == "" then
        return
    end

    if not Callback then
        return
    end

    UGCWidgetManagerSystem.CreateWidgetAsync(WidgetPath, Callback)
end


--添加自定义控件到容器
--@param CustomUI UUserWidget @要添加的控件
function UGC_ItemDetail_UIBP:AddCustomWidget(CustomUI)
    if self.VerticalBox_slot and CustomUI then
        self.VerticalBox_slot:AddChild(CustomUI)
    end
end


--初始化自定义扩展控件
--@param ItemData table @单个物品数据
function UGC_ItemDetail_UIBP:InitCustomWidgets(ItemData)
    self:Clear()

    if ItemData == nil then
        return
    end

    local ItemDefineID = ItemData.ItemDefineID
    local ItemID = ItemDefineID and ItemDefineID.TypeSpecificID or ItemData.ItemID

    if UGCItemSystemV2.ItemHasTagV2(ItemID, "Item.ShootWeapon") then
        -- 武器属性栏：根据物品数据计算五维属性值（威力、射程、稳定性、容量、射速），
        -- 通过BackpackUIComponent.WeaponAttributeBar动态创建属性面板控件，
        -- 支持属性覆盖（bIsAttributeOverride）模式
        local RawValue = UGCBackpackSystemV2.GetBackpackUIComponentConfig(EBackpackUIComponentConfigKey.Widget_WeaponAttributeBar)
        local ClassPath = UGCObjectUtility.GetPathBySoftObjectPath(RawValue)
        if ClassPath and ClassPath ~= "" then
            local CapturedItemData = ItemData
            local CompareItemData = self.InParams and self.InParams.CompareItemData

            local WidgetClass = LoadClass(ClassPath)
            local Widget = WidgetClass and UGCWidgetUtility.CreateWidget(WidgetClass) or nil
            if Widget then
                self:AddCustomWidget(Widget)
                if Widget.InitData and type(Widget.InitData) == "function" then
                    Widget:InitData({
                        {
                            ItemData = CapturedItemData,
                            ItemDefineID = CapturedItemData.ItemDefineID,
                            ItemID = CapturedItemData.ItemDefineID and CapturedItemData.ItemDefineID.TypeSpecificID or 0,
                            Count = CapturedItemData.Count,
                        },
                        {
                            CompareItemData = CompareItemData,
                        },
                    })
                end
            end
        end
    end

    -- 从BackpackUIComponent.CustomDetailsWidgets加载词条等自定义详情控件
    local PC = UGCGameSystem.GetLocalPlayerController()
    local WightPathLists = UGCBackpackSystemV2.GetDetailsWidgetCustomPathByItemID(PC, ItemID)
    if WightPathLists and #WightPathLists > 0 then
        local WeakSelf = WeakObjectPtr(self)
        for _, WightPath in ipairs(WightPathLists) do
            self:CreateUIWidgetAsync(WightPath, function(CustomUI)
                if not WeakSelf:IsValid() then
                    return
                end
                if CustomUI then
                    WeakSelf:Get():AddCustomWidget(CustomUI)
                    if CheckObjectContainsField(CustomUI, "InitData", true) then
                        -- ItemData: 单个物品数据
                        CustomUI:InitData({
                            {
                                ItemData = ItemData,
                                ItemDefineID = ItemData.ItemDefineID,
                                ItemID = ItemData.ItemDefineID and ItemData.ItemDefineID.TypeSpecificID or 0,
                                Count = ItemData.Count,
                            },
                            {
                                CompareItemData = self.InParams and self.InParams.CompareItemData
                            },
                        })
                    end
                end
            end)
        end
    end
end


--设置物品详情信息
--@param ItemData table @单个物品数据
function UGC_ItemDetail_UIBP:SetItemInfo(ItemData)
    local data = ItemData
    if data == nil then
        return
    end

    local ItemID = ItemData.ItemID or 0
    local ItemDefineID = data.ItemDefineID
    local ValidDefineID = nil
    if ItemDefineID then
        ValidDefineID = ItemDefineID
        ItemID = ItemDefineID.TypeSpecificID
    end
    
    -- 根据物品Tag判断武器类型，切换展示样式
    local bIsShootWeapon = ItemID > 0 and UGCItemSystemV2.ItemHasTagV2(ItemID, "Item.ShootWeapon")
    local bIsPistol = bIsShootWeapon and (UGCItemSystemV2.ItemHasTagV2(ItemID, "PistolSubType") or UGCItemSystemV2.ItemHasTagV2(ItemID, "OtherPistolItem"))

    local Slots = nil
    if ItemID and ItemID > 0 then
        Slots = UGCItemSystemV2.GetEquipTargetSlots(ItemID)
    end

    if bIsShootWeapon and not bIsPistol then
        if self.WidgetSwitcher_Style then
            self.WidgetSwitcher_Style:SetActiveWidgetIndex(1)
        end
        self:_SetupWeaponDetail(data, ValidDefineID, ItemID,
            self.CanvasPanel_MainWeaponDetail,
            EBackpackUIComponentConfigKey.Widget_MainWeaponDetailPanel,
            "MainWeaponDetailWidget")
    elseif bIsPistol then
        if self.WidgetSwitcher_Style then
            self.WidgetSwitcher_Style:SetActiveWidgetIndex(2)
        end
        self:_SetupWeaponDetail(data, ValidDefineID, ItemID,
            self.CanvasPanel_SubWeaponDetail,
            EBackpackUIComponentConfigKey.Widget_SubWeaponDetailPanel,
            "SubWeaponDetailWidget")
    else
        -- 通用物品
        if self.WidgetSwitcher_Style then
            self.WidgetSwitcher_Style:SetActiveWidgetIndex(0)
        end

        if Slots and #Slots > 0 then
            if self.AttachDetailsListWidget then
                self:AddCustomWidget(self.AttachDetailsListWidget)
                if CheckObjectContainsField(self.AttachDetailsListWidget, "InitData", true) then
                    self.AttachDetailsListWidget:InitData(ValidDefineID)
                end
            end
            if self.Panel_Accessory then
                self.Panel_Accessory:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
            end
        else
            if self.Panel_Accessory then
                self.Panel_Accessory:SetVisibility(ESlateVisibility.Collapsed)
            end
        end
    end

    -- 清空旧的配件数据，防止切换物品时残留
    self.AttachItems = {}
    self.AccessorySlots = {}

    if Slots and #Slots > 0 then
        for _, SlotName in ipairs(Slots) do
            local AttachItem = UGCItemSystemV2.GetAttachChildItem(ValidDefineID, SlotName)
            -- ReuseList2_Accessory: 记录所有槽位（含空槽位，DefineID 可能为 nil）
            table.insert(self.AccessorySlots, {ParentDefineID = ValidDefineID, SlotName = SlotName, DefineID = AttachItem})
            -- UGC_ReuseList2_Item: 只记录有配件的槽位
            if AttachItem and AttachItem.TypeSpecificID > 0 then
                table.insert(self.AttachItems, {ParentDefineID = ValidDefineID, DefineID = AttachItem, SlotName = SlotName})
            end
        end
    end

    -- 刷新配件列表（通过ReuseList2刷新，空列表也要Reload(0)清空旧显示）
    if self.UGC_ReuseList2_Item then
        self.UGC_ReuseList2_Item:Reload(#self.AttachItems)
    end

    if self.ReuseList2_Accessory and self.bAccessoryItemClassLoaded then
        self.ReuseList2_Accessory:Reload(#self.AccessorySlots)
    end

    local Count = data.ItemCount
    if Count == nil then
        Count = 0
    end

    local WeakSelf = WeakObjectPtr(self)

    local CommonItemWidget = self.UGC_Common_Item_UIBP and self.UGC_Common_Item_UIBP:IsValid() and self.UGC_Common_Item_UIBP:Get() or nil
    if CommonItemWidget then
        local LocalPC = UGCGameSystem.GetLocalPlayerController()
		local CustomItemWidgets = UGCBackpackSystemV2.GetCustomItemUIWidgetPathByItemID(LocalPC, ItemID)
        -- 优先传有效的 ItemDefineID（结构体），可额外显示配件品质点和耐久遮罩；为空时降级传ItemID
        CommonItemWidget:SetItemInfo({Item = ValidDefineID or ItemID, Count = Count})
        CommonItemWidget:SetCustomUISoftWidgetPath(CustomItemWidgets, function(UISlot, CustomUI)
            if WeakSelf:IsValid() and UE.IsValid(UISlot) and UE.IsValid(CustomUI) then
                local CanvasSlot = UISlot:AddChildToCanvas(CustomUI)
                if CanvasSlot then
                    CanvasSlot:SetAnchors({Minimum = {X = 0, Y = 0}, Maximum = {X = 1, Y = 1}})
                    CanvasSlot:SetOffsets({Left = 0, Right = 0, Bottom = 0, Top = 0})
                end
                
                if CheckObjectContainsField(CustomUI, "InitData", true) then
                    CustomUI:InitData({ItemDefineID = ValidDefineID, ItemID = ItemID, Count = Count})
                end
            end
        end)
    end

    local Name = ValidDefineID and UGCItemSystemV2.GetItemNameV2ByDefineID(ValidDefineID) or UGCItemSystemV2.GetItemNameV2(ItemID)
    local desc = ValidDefineID and UGCItemSystemV2.GetItemDetailV2ByDefineID(ValidDefineID) or UGCItemSystemV2.GetItemDetailV2(ItemID)
    if self.TextBlock_IconName then
        self.TextBlock_IconName:SetText(Name)
    end
    if self.TextBlock_Title then
        self.TextBlock_Title:SetText(Name)
    end

    -- 名字/标题品质背景（Image_Quality 随品质变化）：有物品读取背景图片直接设置，无物品还原原始 TintColor
    if self.Image_Quality then
        if ItemID and ItemID > 0 then
            local Quality = ValidDefineID and UGCItemSystemV2.GetItemQualityV2ByDefineID(ValidDefineID) or UGCItemSystemV2.GetItemQualityV2(ItemID)
            local QualityBgPath = UGCItemSystemV2.GetQualityBarTexturePath(Quality)
            if QualityBgPath then
                local weakSelf = WeakObjectPtr(self)
                UGCObjectUtility.AsyncLoadObject(QualityBgPath, function(LoadedTexture)
                    if weakSelf:IsValid() then
                        local selfObj = weakSelf:Get()
                        if selfObj and selfObj.Image_Quality then
                            selfObj.Image_Quality:SetBrushFromTexture(LoadedTexture, false)
                        end
                    end
                end)
            end
        end
    end

    if self.UTRichTextBlock_describe then
        self.UTRichTextBlock_describe:SetText(desc)
    end

    if self.TextBlock_Capacity then
        self.TextBlock_Capacity:SetText(1)
    end
end

---初始化武器详情Widget的公共逻辑：AddChildToCanvas → InitData → 禁用武器自身拖拽 → HiddenWeaponState
---@param Widget userdata @武器详情Widget实例（已确保UE.IsValid）
---@param CanvasPanel userdata @挂载容器CanvasPanel
---@param ValidDefineID FItemDefineID @有效物品实例ID（可能为nil，非实例武器仅有ItemID）
---@param ItemID number @物品配置ID（非实例武器时用于展示）
---@param SlotName string|nil @装备槽位名（如 EquipmentSlot.Core.MainSlot1）
function UGC_ItemDetail_UIBP:_InitWeaponDetailWidget(Widget, CanvasPanel, ValidDefineID, ItemID, SlotName)
    local CanvasSlot = CanvasPanel:AddChildToCanvas(Widget)
    if CanvasSlot then
        CanvasSlot:SetAnchors({Minimum = {X = 0, Y = 0}, Maximum = {X = 1, Y = 1}})
        CanvasSlot:SetOffsets({Left = 0, Right = 0, Bottom = 0, Top = 0})
    end
    if CheckObjectContainsField(Widget, "InitData", true) then
        Widget:InitData({ItemDefineID = ValidDefineID, ItemID = ItemID, SlotName = SlotName})
    end
    -- 详情面板：武器栏自身不支持拖拽（仅其配件槽支持）
    if CheckObjectContainsField(Widget, "RefreshWeaponDragMode", true) then
        Widget:RefreshWeaponDragMode(false)
    end
    if Widget.HiddenWeaponState then
        Widget:HiddenWeaponState()
    end
end

---武器详情面板统一入口：从BackpackUIComponent读取配置路径，同步创建或复用缓存Widget，最后调用 _InitWeaponDetailWidget
---@param ItemData table @物品原始数据（暂未使用，保留以兼容调用方）
---@param ValidDefineID FItemDefineID @有效物品实例ID
---@param ItemID number @物品配置ID（透传给武器详情控件，非实例武器时用于展示）
---@param CanvasPanel userdata @挂载容器CanvasPanel
---@param ConfigKey EBackpackUIComponentConfigKey @配置键（MainWeaponDetailPanel / SubWeaponDetailPanel）
---@param WidgetFieldName string @缓存字段名（"MainWeaponDetailWidget" / "SubWeaponDetailWidget"）
function UGC_ItemDetail_UIBP:_SetupWeaponDetail(ItemData, ValidDefineID, ItemID, CanvasPanel, ConfigKey, WidgetFieldName)
    if not CanvasPanel then
        return
    end

    local RawValue = UGCBackpackSystemV2.GetBackpackUIComponentConfig(ConfigKey)
    local ClassPath = UGCObjectUtility.GetPathBySoftObjectPath(RawValue)
    if not ClassPath or ClassPath == "" then
        return
    end

    local WeakRef = self[WidgetFieldName]
    local CachedWidget = WeakRef and WeakRef:IsValid() and WeakRef:Get() or nil
    if not CachedWidget then
        local WidgetClass = LoadClass(ClassPath)
        if not WidgetClass then
            return
        end

        local Widget = UGCWidgetUtility.CreateWidget(WidgetClass)
        if not Widget then
            return
        end

        self[WidgetFieldName] = WeakObjectPtr(Widget)
        local SlotName = (ItemData and ItemData.SlotName) or nil
        self:_InitWeaponDetailWidget(Widget, CanvasPanel, ValidDefineID, ItemID, SlotName)
    else
        local SlotName = (ItemData and ItemData.SlotName) or nil
        self:_InitWeaponDetailWidget(CachedWidget, CanvasPanel, ValidDefineID, ItemID, SlotName)
    end
end


---开放化接口：SetWeaponTabList
---设置武器Tab列表（通过 UGC_ReuseList2_Tab 展示，蓝图配置 ReuseList2 的 Orientation 控制水平/垂直方向）
---@param WeaponList table|nil @武器槽位列表，nil时隐藏整个Tab区域
---  WeaponList[i] table @单个武器槽位信息
---    .Idx     number  @槽位索引（1=武器一, 2=武器二, 3=副武器等）
---    .Name    string  @显示名称（如"武器一"、"武器二"）
---    .bHasWeapon boolean @该槽位是否有装备武器（无武器的Tab项置灰或隐藏）
---@param OnClickCallback function|nil @点击某个武器Tab时的回调，参数(SlotIdx)
---@param InitialSelectedIdx number|nil @初始选中的槽位索引（可选，不传则默认选中第一个有武器的Tab）
function UGC_ItemDetail_UIBP:SetWeaponTabList(WeaponList, OnClickCallback, InitialSelectedIdx)
    self.WeaponTabList = WeaponList
    if OnClickCallback then
        self.OnWeaponTabClickCallback = OnClickCallback
    end

    -- 无数据或空列表 → 隐藏整个Tab区域
    if not WeaponList or #WeaponList == 0 then
        if self.UGC_ReuseList2_Tab then
            self.UGC_ReuseList2_Tab:SetVisibility(ESlateVisibility.Hidden)
        end
        if self.PanelTabSwitch then
            self.PanelTabSwitch:SetVisibility(ESlateVisibility.Hidden)
        end
        if self.Button_SwitchWeapon then
            self.Button_SwitchWeapon:SetVisibility(ESlateVisibility.Hidden)
        end
        return
    end

    -- 显示Tab区域，隐藏旧单按钮
    if self.UGC_ReuseList2_Tab then
        self.UGC_ReuseList2_Tab:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
    end
    if self.PanelTabSwitch then
        self.PanelTabSwitch:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
    end

    -- 设置初始选中
    if InitialSelectedIdx then
        self.WeaponTabSelectedIdx = InitialSelectedIdx
    elseif not self.WeaponTabSelectedIdx or self.WeaponTabSelectedIdx == 0 then
        local FirstValidIdx = nil
        for _, TabData in ipairs(WeaponList) do
            if TabData.bHasWeapon then
                FirstValidIdx = TabData.Idx
                break
            end
        end
        self.WeaponTabSelectedIdx = FirstValidIdx or (WeaponList[1] and WeaponList[1].Idx or 1)
    end

    -- 通过 ReuseList2_Tab 渲染（ItemClass 已在蓝图中配置，首次无缓存时异步加载）
    if self.UGC_ReuseList2_Tab then
        local ItemClass = self.UGC_ReuseList2_Tab.ItemClass
        if not ItemClass then
            self:LoadTabButtonItemClass()
        else
            self.UGC_ReuseList2_Tab:Reload(#WeaponList)
        end
    end
end


---设置当前选中的武器Tab索引，并刷新 UGC_ReuseList2_Tab 的选中态
---@param SlotIdx number @要选中的槽位索引（1=武器一, 2=武器二）
function UGC_ItemDetail_UIBP:SetWeaponTabSelectedIdx(SlotIdx)
    self.WeaponTabSelectedIdx = SlotIdx
    if self.UGC_ReuseList2_Tab and self.WeaponTabList then
        self.UGC_ReuseList2_Tab:Reload(#self.WeaponTabList)
    end
end


---异步加载武器Tab的ItemClass
function UGC_ItemDetail_UIBP:LoadTabButtonItemClass()
    -- 尝试从 BackpackUIComponent 获取路径
    local ClassPath = nil
    local ItemDetailsTabItemWidget = UGCBackpackSystemV2.GetBackpackUIComponentConfig(EBackpackUIComponentConfigKey.Widget_ItemDetailsTabItemWidget)
    if ItemDetailsTabItemWidget then
        ClassPath = UGCObjectUtility.GetPathBySoftObjectPath(ItemDetailsTabItemWidget)
    end

    if not ClassPath or ClassPath == "" then
        return
    end


    local WeakSelf = WeakObjectPtr(self)
    UGCObjectUtility.AsyncLoadClass(ClassPath, function(itemClass)
        if not WeakSelf:IsValid() then return end
        local selfRef = WeakSelf:Get()
        if not selfRef then return end

        if itemClass and selfRef.UGC_ReuseList2_Tab then
            selfRef.UGC_ReuseList2_Tab:SetItemClass(itemClass)
            if selfRef.WeaponTabList and #selfRef.WeaponTabList > 0 then
                selfRef.UGC_ReuseList2_Tab:Reload(#selfRef.WeaponTabList)
            end
        else
        end
    end)
end


---武器Tab列表项更新回调（ReuseList2 OnUpdateItem）
---功能：当武器Tab列表项需要显示时，更新其名称、选中状态并绑定点击回调
---TabItem 为 Lua 控件 (UGC_ItemDetails_TabItem_UIBP)，通过 Lua 接口操作
---@param Widget userdata @列表项Widget（UGC_ItemDetails_TabItem_UIBP 实例）
---@param Idx number @列表索引（从0开始）
function UGC_ItemDetail_UIBP:OnUpdateItem_Tab(Widget, Idx)
    
    local TabData = self.WeaponTabList and self.WeaponTabList[Idx + 1]
    if not TabData then
        return
    end

    local SlotIdx = TabData.Idx
    local TabName = TabData.Name
    -- 英文槽位名（如 EquipmentSlot.Core.MainSlot1）转中文显示名
    if TabName and string.find(TabName, "%.") then
        local PC = BackpackManager.OwnerPC
        if PC then
            local displayName = UGCBackpackSystemV2.GetSlotDisplayName(PC, TabName)
            if displayName and displayName ~= "" then
                TabName = displayName
            end
        end
    end
    TabName = TabName or ("武器" .. tostring(SlotIdx))
    local IsSelected = (self.WeaponTabSelectedIdx == SlotIdx)

    -- 优先通过 Lua 接口设置（TabItem 已绑定 Lua 脚本时）
    if CheckObjectContainsField(Widget, "SetTabName", true) then
        Widget:SetTabName(TabName)
        if CheckObjectContainsField(Widget, "SetTabIdx", true) then
            Widget:SetTabIdx(SlotIdx)
        end
        if CheckObjectContainsField(Widget, "SetSelected", true) then
            Widget:SetSelected(IsSelected)
        end
        -- 绑定点击回调
        if CheckObjectContainsField(Widget, "SetOnTabClickCallback", true) then
            local WeakSelf = WeakObjectPtr(self)
            Widget:SetOnTabClickCallback(function(ClickedIdx)
                local selfRef = WeakSelf:Get()
                if not selfRef then return end
                selfRef.WeaponTabSelectedIdx = ClickedIdx
                if selfRef.UGC_ReuseList2_Tab then
                    selfRef.UGC_ReuseList2_Tab:Refresh()
                end
                if selfRef.OnWeaponTabClickCallback then
                    selfRef.OnWeaponTabClickCallback(ClickedIdx)
                end
            end)
        end
        return
    end

    -- 兜底：直接操作蓝图变量（TabItem 未绑定 Lua 脚本时，依赖蓝图暴露的字段）
    -- 蓝图实际变量：TextBlock_0(选中态文字)、TextBlock_3(未选中文字)、WidgetSwitcher_Tab(状态切换)
    if Widget.TextBlock_0 then
        Widget.TextBlock_0:SetText(TabName)
    end
    if Widget.TextBlock_3 then
        Widget.TextBlock_3:SetText(TabName)
    end
    if Widget.WidgetSwitcher_Tab then
        -- 与 SetSelected 内部映射一致：选中→Index 0, 未选中→Index 1
        Widget.WidgetSwitcher_Tab:SetActiveWidgetIndex(IsSelected and 0 or 1)
    end
    -- 注意：蓝图没有 Button_TabClick 等按钮变量，点击事件由 ReuseList2 的 OnItemClicked 或外部处理
end

--配件列表项更新回调（ReuseList2 OnUpdateItem）
--@param Widget userdata @列表项Widget（UGC_ItemParts_Open_UIBP实例）
--@param Idx number @列表索引（从0开始）
function UGC_ItemDetail_UIBP:OnUpdateItem(Widget, Idx)
    local AttachItem = self.AttachItems[Idx + 1]
    if not AttachItem then
        return
    end

    -- 调用控件的InitData接口（统一入口）
    if CheckObjectContainsField(Widget, "InitData", true) then
        Widget:InitData(AttachItem)
    end
end


---动态设置配件列表ItemClass并刷新列表
---功能：异步加载ItemClass，设置到ReuseList2后刷新列表
---@param classPath string @ItemClass路径
function UGC_ItemDetail_UIBP:SetAttachItemClassAndReload(classPath)
    if not classPath or classPath == "" then
        return
    end

    -- 保存路径
    self.AttachListItemClassPath = classPath

    -- 如果路径没变且已经加载过，直接刷新列表
    if self.bAttachItemClassLoaded and self.AttachListItemClassPath == classPath then
        if self.UGC_ReuseList2_Item then
            self.UGC_ReuseList2_Item:Reload(#self.AttachItems)
        end
        return
    end

    -- 异步加载ItemClass（开放化控件使用UGCObjectUtility.AsyncLoadClass）
    local WeakSelf = WeakObjectPtr(self)
    UGCObjectUtility.AsyncLoadClass(classPath, function(itemClass)
        if not WeakSelf:IsValid() then
            return
        end

        local selfRef = WeakSelf:Get()
        if not selfRef then return end
        if itemClass then
            -- 设置ItemClass到ReuseList2
            if selfRef.UGC_ReuseList2_Item then
                selfRef.UGC_ReuseList2_Item:SetItemClass(itemClass)
                selfRef.bAttachItemClassLoaded = true
                -- 设置完成后刷新列表
                selfRef.UGC_ReuseList2_Item:Reload(#selfRef.AttachItems)
            end
        else
            -- 加载失败时也尝试刷新列表（使用蓝图默认配置的ItemClass）
            if selfRef.UGC_ReuseList2_Item then
                selfRef.UGC_ReuseList2_Item:Reload(#selfRef.AttachItems)
            end
        end
    end)
end


---ReuseList2_Accessory 列表项更新回调
---@param Widget userdata @列表项Widget（UGC_WeaponFitting_Open_UIBP 实例）
---@param Idx number @列表索引（从0开始）
function UGC_ItemDetail_UIBP:OnUpdateItem_Accessory(Widget, Idx)
    local SlotData = self.AccessorySlots[Idx + 1]
    if not SlotData then
        return
    end
    if CheckObjectContainsField(Widget, "InitFitting", true) then
        Widget:InitFitting({SlotName = SlotData.SlotName})
    end
    if CheckObjectContainsField(Widget, "UpdateAttachItem", true) then
        Widget:UpdateAttachItem({ParentDefineID = SlotData.ParentDefineID, DefineID = SlotData.DefineID})
    end
end


---异步加载 ReuseList2_Accessory 的 ItemClass（WeaponFittingSlot）
function UGC_ItemDetail_UIBP:LoadAccessoryItemClass()
    if self.bAccessoryItemClassLoaded then
        return
    end

    local RawValue = UGCBackpackSystemV2.GetBackpackUIComponentConfig(EBackpackUIComponentConfigKey.Widget_WeaponFittingSlot)
    local ClassPath = UGCObjectUtility.GetPathBySoftObjectPath(RawValue)
    if not ClassPath or ClassPath == "" then
        return
    end

    local WeakSelf = WeakObjectPtr(self)
    UGCObjectUtility.AsyncLoadClass(ClassPath, function(itemClass)
        if not WeakSelf:IsValid() then return end
        local selfRef = WeakSelf:Get()
        if not selfRef then return end
        if itemClass and selfRef.ReuseList2_Accessory then
            selfRef.ReuseList2_Accessory:SetItemClass(itemClass)
            selfRef.bAccessoryItemClassLoaded = true
            selfRef.ReuseList2_Accessory:Reload(#selfRef.AccessorySlots)
        else
        end
    end)
end


--析构函数，UI销毁时自动调用
function UGC_ItemDetail_UIBP:Destruct()
    -- 移除配件列表事件绑定
    if self.UGC_ReuseList2_Item then
        self.UGC_ReuseList2_Item.OnUpdateItem:Remove(self.OnUpdateItem, self)
    end

    -- 移除武器Tab列表事件绑定
    if self.UGC_ReuseList2_Tab then
        self.UGC_ReuseList2_Tab.OnUpdateItem:Remove(self.OnUpdateItem_Tab, self)
    end

    -- 移除通用物品配件列表事件绑定
    if self.ReuseList2_Accessory then
        self.ReuseList2_Accessory.OnUpdateItem:Remove(self.OnUpdateItem_Accessory, self)
        self.ReuseList2_Accessory:Reload(0)
    end

    -- 移除按钮事件绑定
    if self.Button_Contrast then
        self.Button_Contrast.OnClicked:Remove(self.OnContrastClicked, self)
    end

    if self.Button_Close then
        self.Button_Close.OnClicked:Remove(self.OnCloseClicked, self)
    end

    self.MainWeaponDetailWidget = nil
    self.SubWeaponDetailWidget = nil
    self.AttachListItemClassPath = nil
    self.bAttachItemClassLoaded = false
    self.bAccessoryItemClassLoaded = false

    self.ItemDatas = nil
    self.ExtraData = nil
    self.InParams = nil
    self.UGC_Common_Item_UIBP = nil
    self.OnContrastClickCallback = nil
    self.OnCloseClickCallback = nil

    -- 清理武器Tab数据
    self.WeaponTabList = nil
    self.OnWeaponTabClickCallback = nil
    self._tabButtonClickBindings = nil
    self._TabItemClassPath = nil
    self.bInitDoOnce = false
end


return UGC_ItemDetail_UIBP