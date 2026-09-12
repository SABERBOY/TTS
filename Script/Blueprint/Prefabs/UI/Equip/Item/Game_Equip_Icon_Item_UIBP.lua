---@class Game_Equip_Icon_Item_UIBP_C:UAEUserWidget
---@field AffixsBar_Item Game_Equip_AffixsBar_Item_UIBP_C
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
---装备槽 / 背包格子图标单元（项目副本 Game_Equip_Icon_Item_UIBP）：
---  引擎按资产路径自动绑定本 Lua 类，self 就是控件本身；
---  槽位名/等级/图标/品质底图/穿戴中状态全部由本类的冒号实例方法处理，
---  不再需要 New(Widget) 代理与 EquipUIHelper 工具类。
local Game_Equip_Icon_Item_UIBP = {
    bInitDoOnce = false,
    bClickBound = false,
    Data = nil,
}

---异步把纹理路径贴到 Image 上。
---bMatchSize=true 时 Brush.ImageSize 跟随纹理尺寸：Image_DefaultIcon 在 ScaleBox(ScaleToFit) 里，
---预制体默认 Brush 是 16x16 正方形，不跟随会把非正方形图标压扁。
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

--构造函数，UI创建时自动调用
function Game_Equip_Icon_Item_UIBP:Construct()
    self:LuaInit()
end

function Game_Equip_Icon_Item_UIBP:LuaInit()
    if self.bInitDoOnce then
        return
    end
    self.bInitDoOnce = true
    -- 预制体把 NotWornState / Unusable 的外层无名 CanvasPanel 默认设为 Collapsed，
    -- 不打开它 Image_DefaultIcon 永远拿不到布局（实测 desired=0，图标不渲染）。
    if self.CanvasPanel_NotWornState then
        self.CanvasPanel_NotWornState:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
        pcall(function()
            local Wrap = self.CanvasPanel_NotWornState:GetParent()
            if Wrap and Wrap:GetVisibility() == ESlateVisibility.Collapsed then
                Wrap:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
            end
        end)
    end
    if self.CanvasPanel_Unusable then
        self.CanvasPanel_Unusable:SetVisibility(ESlateVisibility.Collapsed)
    end
end

---等级数字。预制体里 TextBlock 已固定显示 "LV." 前缀，这里只写数字。
---@param Level number 槽位强化等级
function Game_Equip_Icon_Item_UIBP:SetItemLevel(Level)
    if not self.TextBlock_Level then
        return false
    end
    local OK = pcall(function()
        self.TextBlock_Level:SetText(tostring(Level or 0))
    end)
    return OK == true
end

---格子名字：空槽显示槽位名（头盔/衣服…），有装备时收起（名字改由 Tips / 强化页展示）。
---名字与图标同在 CanvasPanel_NotWornState 下，同时显示会互相遮挡。
---@param Text string|nil
function Game_Equip_Icon_Item_UIBP:SetFittingName(Text)
    if not self.TextBlock_FittingName then
        return false
    end
    local bShow = Text ~= nil and Text ~= ''
    local OK = pcall(function()
        self.TextBlock_FittingName:SetText(Text or '')
        self.TextBlock_FittingName:SetVisibility(bShow and ESlateVisibility.SelfHitTestInvisible or ESlateVisibility.Collapsed)
    end)
    return OK == true
end

---穿戴中标记
---@param bEquipped boolean
function Game_Equip_Icon_Item_UIBP:SetUsing(bEquipped)
    if self.TextBlock_Using then
        if bEquipped then
            self.TextBlock_Using:SetText('穿戴中')
            self.TextBlock_Using:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
        else
            self.TextBlock_Using:SetVisibility(ESlateVisibility.Collapsed)
        end
    end
    return true
end

---物品图标（只写 Image_DefaultIcon；品质底图由 SetQuality 负责）
---@param ItemID number
---@param DefineID any|nil 有实例时优先用 DefineID（走实例数据重写的图标）
function Game_Equip_Icon_Item_UIBP:SetIcon(ItemID, DefineID)
    if not self.Image_DefaultIcon then
        return false
    end
    if not ItemID or ItemID == 0 then
        return true
    end
    local PathStr = GetItemIconPath(DefineID, ItemID)
    if not PathStr then
        return false
    end
    return SetImageBrushFromPath(self.Image_DefaultIcon, PathStr, true)
end

---品质底图 + 底部品质色条。
---Image_QualityBarBg 在 SizeBox(258x258)+ScaleBox 内，尺寸固定，不需要匹配纹理尺寸；
---Quality 为 nil（空槽）时用品质 0 底图并隐藏色条。
---@param Quality number|nil 内核品质等级
function Game_Equip_Icon_Item_UIBP:SetQuality(Quality)
    local HasQuality = Quality ~= nil
    local Q = HasQuality and math.max(0, math.floor(Quality)) or 0

    if self.Image_QualityBarBg then
        local BgPath = nil
        pcall(function()
            BgPath = UGCItemSystemV2.GetQualityTexturePath(Q)
        end)
        BgPath = SoftPathToString(BgPath)
        if BgPath then
            SetImageBrushFromPath(self.Image_QualityBarBg, BgPath, false)
        end
        self.Image_QualityBarBg:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
    end

    if self.Image_QualityBar then
        if HasQuality then
            local BarPath = nil
            pcall(function()
                BarPath = UGCItemSystemV2.GetQualityBarTexturePath(Q)
            end)
            BarPath = SoftPathToString(BarPath)
            if BarPath then
                SetImageBrushFromPath(self.Image_QualityBar, BarPath, false)
            end
            self.Image_QualityBar:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
        else
            self.Image_QualityBar:SetVisibility(ESlateVisibility.Collapsed)
        end
    end
    return true
end

---刷新格子：等级 / 名字 / 图标 / 品质 / 穿戴中
---@param ItemID number|nil 物品 ID，nil/0 表示空槽
---@param Level number 槽位强化等级
---@param EmptyName string 空槽显示名（槽位名）
---@param bEquipped boolean 是否穿戴中
---@param DefineID any|nil 背包 DefineID，有实例时用于读取实例名称/图标/品质
function Game_Equip_Icon_Item_UIBP:ApplyData(ItemID, Level, EmptyName, bEquipped, DefineID)
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
        self:SetIcon(nil, nil)
    end
    self:SetQuality(Quality)
    self:SetUsing(bEquipped)
    if self.WidgetSwitcher_Content then
        pcall(function()
            self.WidgetSwitcher_Content:SetActiveWidgetIndex(0)
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

---绑定格子点击（委托只能在控件构造完成后 Add，即 InitData/Refresh 时机，不能放 Construct）
---@param OnClick function
function Game_Equip_Icon_Item_UIBP:BindClick(OnClick)
    if self.bClickBound or not OnClick then
        return self.bClickBound == true
    end
    local DragDrop = self.Common_DragDrop_Item
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

--析构函数，UI销毁时自动调用
function Game_Equip_Icon_Item_UIBP:Destruct()
    self.Data = nil
    self.bClickBound = false
    self.bInitDoOnce = false
end

return Game_Equip_Icon_Item_UIBP
