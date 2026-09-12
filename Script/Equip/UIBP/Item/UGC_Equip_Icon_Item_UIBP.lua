---@class UGC_Equip_Icon_Item_UIBP_C:UAEUserWidget
---@field AffixsBar_Item UGC_Equip_AffixsBar_Item_UIBP_C
---@field CanvasPanel_New UCanvasPanel
---@field CanvasPanel_NotWornState UCanvasPanel
---@field CanvasPanel_Select UCanvasPanel
---@field CanvasPanel_Unusable UCanvasPanel
---@field Common_DragDrop_Item Common_DragDrop_Item_C
---@field Image_DefaultIcon UImage
---@field Image_QualityBar UImage
---@field Image_QualityBarBg UImage
---@field Image_Select UImage
---@field TextBlock_Effect UTextBlock
---@field TextBlock_FittingName UTextBlock
---@field TextBlock_Level UTextBlock
---@field TextBlock_Using UTextBlock
---@field WidgetSwitcher_Content UWidgetSwitcher
---@field WidgetSwitcher_Unusable UWidgetSwitcher
---@field FittingName FText
---@field FittingSketch FSlateBrush
--Edit Below--
-- 引擎 Prefab /Game/UGC/UITemplate/.../UGC_Equip_Icon_Item_UIBP 无项目 Lua 绑定。
-- New(Widget) 返回包装实例；冒号方法写该控件字段。进引擎 API 用 :GetWidget()。
local UGC_Equip_Icon_Item_UIBP = {}

UGC_Equip_Icon_Item_UIBP.CLASS_PATH = '/Game/UGC/UITemplate/Asset/Equip/UIBP/Item/UGC_Equip_Icon_Item_UIBP.UGC_Equip_Icon_Item_UIBP_C'

-- 以 tostring(Widget)（含对象路径+地址）为键：同一 UObject 多次从 Lua 取出的 userdata 不保证同一份，
-- 用 userdata 弱键会导致重复建代理、点击重复绑定。失效条目在 New 时顺带清理。
local ProxyCache = {}
local ProxyCacheCount = 0
local PRUNE_THRESHOLD = 64

local function SoftPathToString(Path)
    if not Path then
        return nil
    end
    if type(Path) == 'string' then
        return Path ~= '' and Path or nil
    end
    local OK, Converted = pcall(function()
        return UGCObjectUtility.GetPathBySoftObjectPath(Path)
    end)
    if OK and type(Converted) == 'string' and Converted ~= '' and Converted ~= 'None' then
        return Converted
    end
    return nil
end

local function ResolveWidget(Proxy)
    local Weak = Proxy and Proxy.__widget
    if not Weak then
        return nil
    end
    local OK, Widget = pcall(function()
        if not Weak:IsValid() then
            return nil
        end
        local W = Weak:Get()
        if not W or not UE.IsValid(W) then
            return nil
        end
        return W
    end)
    if OK then
        return Widget
    end
    return nil
end

local META = {
    __index = function(Proxy, Key)
        local Method = UGC_Equip_Icon_Item_UIBP[Key]
        if Method ~= nil then
            return Method
        end
        local Widget = ResolveWidget(Proxy)
        if not Widget then
            return nil
        end
        local OK, Value = pcall(function()
            return Widget[Key]
        end)
        if OK then
            return Value
        end
        return nil
    end,
    __newindex = function(Proxy, Key, Value)
        if Key == '__widget' or Key == 'bClickBound' or Key == 'Data' then
            rawset(Proxy, Key, Value)
            return
        end
        local Widget = ResolveWidget(Proxy)
        if not Widget then
            return
        end
        pcall(function()
            Widget[Key] = Value
        end)
    end,
}

function UGC_Equip_Icon_Item_UIBP.New(Widget)
    if not Widget then
        print('[EquipIconItem] New 失败：传入的单元格控件为空')
        return nil
    end
    local Key = tostring(Widget)
    local Cached = ProxyCache[Key]
    if Cached then
        if ResolveWidget(Cached) then
            return Cached
        end
        ProxyCache[Key] = nil
        ProxyCacheCount = ProxyCacheCount - 1
    end
    if ProxyCacheCount >= PRUNE_THRESHOLD then
        for K, P in pairs(ProxyCache) do
            if not ResolveWidget(P) then
                ProxyCache[K] = nil
                ProxyCacheCount = ProxyCacheCount - 1
            end
        end
    end
    local Proxy = {
        __widget = WeakObjectPtr(Widget),
        bClickBound = false,
        Data = nil,
    }
    setmetatable(Proxy, META)
    ProxyCache[Key] = Proxy
    ProxyCacheCount = ProxyCacheCount + 1
    return Proxy
end

function UGC_Equip_Icon_Item_UIBP:GetWidget()
    return ResolveWidget(self)
end

function UGC_Equip_Icon_Item_UIBP:IsValid()
    return ResolveWidget(self) ~= nil
end

function UGC_Equip_Icon_Item_UIBP:SetItemLevel(Level)
    local Widget = self:GetWidget()
    if not Widget or not Widget.TextBlock_Level then
        return false
    end
    -- 预制体里 TextBlock_0 已固定显示 "LV." 前缀，这里只写数字
    local OK = pcall(function()
        Widget.TextBlock_Level:SetText(tostring(Level or 0))
    end)
    return OK == true
end

function UGC_Equip_Icon_Item_UIBP:SetFittingName(Text)
    local Widget = self:GetWidget()
    if not Widget or not Widget.TextBlock_FittingName then
        return false
    end
    -- 名字与图标同在 CanvasPanel_NotWornState 下会互相遮挡：空槽显示槽位名，穿戴后只留图标+等级，名字收起
    local bShow = Text ~= nil and Text ~= ''
    local OK = pcall(function()
        Widget.TextBlock_FittingName:SetText(Text or '')
        Widget.TextBlock_FittingName:SetVisibility(bShow and ESlateVisibility.SelfHitTestInvisible or ESlateVisibility.Collapsed)
    end)
    return OK == true
end

function UGC_Equip_Icon_Item_UIBP:SetUsing(bEquipped)
    local Widget = self:GetWidget()
    if not Widget then
        return false
    end
    if Widget.TextBlock_Using then
        if bEquipped then
            Widget.TextBlock_Using:SetText('穿戴中')
            Widget.TextBlock_Using:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
        else
            Widget.TextBlock_Using:SetVisibility(ESlateVisibility.Collapsed)
        end
    end
    if Widget.CanvasPanel_NotWornState then
        Widget.CanvasPanel_NotWornState:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
        -- 预制体把 NotWornState/Unusable 外层的无名 CanvasPanel 默认 Collapsed，
        -- 不打开它 Image_DefaultIcon 永远拿不到布局（实测 desired=0，图标不渲染）
        pcall(function()
            local Wrap = Widget.CanvasPanel_NotWornState:GetParent()
            if Wrap and Wrap:GetVisibility() == ESlateVisibility.Collapsed then
                Wrap:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
            end
        end)
    end
    if Widget.CanvasPanel_Unusable then
        Widget.CanvasPanel_Unusable:SetVisibility(ESlateVisibility.Collapsed)
    end
    return true
end

---异步把纹理路径贴到 Image 上。
---bMatchSize=true 时 Brush.ImageSize 跟随纹理尺寸：Image_DefaultIcon 在 ScaleBox(ScaleToFit) 里，
---预制体默认 Brush 是 16x16 正方形，若不匹配尺寸，非正方形图标会被压成正方形（看起来变扁）。
local function SetImageBrushFromPath(ImageWidget, PathStr, bMatchSize)
    if not ImageWidget or not PathStr then
        return false
    end
    local WeakImage = WeakObjectPtr(ImageWidget)
    local OK = pcall(function()
        UGCObjectUtility.AsyncLoadObject(PathStr, function(LoadedTexture)
            if not WeakImage:IsValid() or not LoadedTexture then
                return
            end
            local Image = WeakImage:Get()
            if Image then
                pcall(function()
                    Image:SetBrushFromTexture(LoadedTexture, bMatchSize == true)
                end)
            end
        end)
    end)
    return OK == true
end

local function GetItemIconPath(DefineID, ItemID)
    local Path = nil
    if DefineID ~= nil and type(DefineID) ~= 'number' then
        pcall(function()
            Path = UGCItemSystemV2.GetItemIconTextureV2ByDefineID(DefineID)
        end)
    end
    local PathStr = SoftPathToString(Path)
    if not PathStr and ItemID and ItemID ~= 0 then
        pcall(function()
            Path = UGCItemSystemV2.GetItemIconTextureV2(ItemID)
        end)
        PathStr = SoftPathToString(Path)
    end
    return PathStr
end

---物品图标（只写 Image_DefaultIcon；品质底图由 SetQuality 负责）
---@param ItemID number
---@param DefineID any|nil 有实例时优先用 DefineID（走实例数据重写的图标）
function UGC_Equip_Icon_Item_UIBP:SetIcon(ItemID, DefineID)
    local Widget = self:GetWidget()
    if not Widget then
        return false
    end
    if not ItemID or ItemID == 0 then
        return true
    end
    local PathStr = GetItemIconPath(DefineID, ItemID)
    if not PathStr then
        return false
    end
    return SetImageBrushFromPath(Widget.Image_DefaultIcon, PathStr, true)
end

---品质底图 + 底部品质色条。
---Image_QualityBarBg 在 SizeBox(258x258)+ScaleBox 内，尺寸固定，不需要匹配纹理尺寸；
---Quality 为 nil（空槽）时用品质 0 底图并隐藏色条。
---@param Quality number|nil 内核品质等级
function UGC_Equip_Icon_Item_UIBP:SetQuality(Quality)
    local Widget = self:GetWidget()
    if not Widget then
        return false
    end
    local HasQuality = Quality ~= nil
    local Q = HasQuality and math.max(0, math.floor(Quality)) or 0

    if Widget.Image_QualityBarBg then
        local BgPath = nil
        pcall(function()
            BgPath = UGCItemSystemV2.GetQualityTexturePath(Q)
        end)
        BgPath = SoftPathToString(BgPath)
        if BgPath then
            SetImageBrushFromPath(Widget.Image_QualityBarBg, BgPath, false)
        end
        Widget.Image_QualityBarBg:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
    end

    if Widget.Image_QualityBar then
        if HasQuality then
            local BarPath = nil
            pcall(function()
                BarPath = UGCItemSystemV2.GetQualityBarTexturePath(Q)
            end)
            BarPath = SoftPathToString(BarPath)
            if BarPath then
                SetImageBrushFromPath(Widget.Image_QualityBar, BarPath, false)
            end
            Widget.Image_QualityBar:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
        else
            Widget.Image_QualityBar:SetVisibility(ESlateVisibility.Collapsed)
        end
    end
    return true
end

---@param ItemID number|nil 物品 ID，nil/0 表示空槽
---@param Level number 槽位强化等级
---@param EmptyName string 空槽显示名（槽位名）
---@param bEquipped boolean 是否穿戴中
---@param DefineID any|nil 背包 DefineID，有实例时用于读取实例名称/图标/品质
function UGC_Equip_Icon_Item_UIBP:ApplyData(ItemID, Level, EmptyName, bEquipped, DefineID)
    local Widget = self:GetWidget()
    if not Widget then
        return false
    end
    local HasItem = ItemID ~= nil and ItemID ~= 0
    local Quality = nil
    self:SetItemLevel(Level)
    if HasItem then
        -- 有装备时名字收起，只显示图标；名字在 Tips / 强化页展示
        self:SetFittingName('')
        self:SetIcon(ItemID, DefineID)
        pcall(function()
            if DefineID ~= nil and type(DefineID) ~= 'number' then
                Quality = UGCItemSystemV2.GetItemQualityV2ByDefineID(DefineID)
            end
            if type(Quality) ~= 'number' then
                Quality = UGCItemSystemV2.GetItemQualityV2(ItemID)
            end
        end)
        if type(Quality) ~= 'number' then
            Quality = 0
        end
    else
        self:SetFittingName(EmptyName or '')
    end
    self:SetQuality(Quality)
    self:SetUsing(bEquipped)
    if Widget.WidgetSwitcher_Content then
        pcall(function()
            Widget.WidgetSwitcher_Content:SetActiveWidgetIndex(0)
        end)
    end
    self.Data = {
        ItemID = ItemID,
        DefineID = DefineID,
        Level = Level,
        EmptyName = EmptyName,
        bEquipped = bEquipped,
        Quality = Quality,
    }
    return true
end

function UGC_Equip_Icon_Item_UIBP:BindClick(OnClick)
    if self.bClickBound or not OnClick then
        return self.bClickBound == true
    end
    local Widget = self:GetWidget()
    local DragDrop = Widget and Widget.Common_DragDrop_Item
    if not DragDrop then
        return false
    end
    local OK = pcall(function()
        DragDrop.OnDragClicked:Add(OnClick)
    end)
    if OK then
        self.bClickBound = true
    end
    return OK == true
end

return UGC_Equip_Icon_Item_UIBP
