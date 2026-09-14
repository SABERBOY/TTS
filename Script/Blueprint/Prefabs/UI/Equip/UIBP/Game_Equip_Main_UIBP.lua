---@class Game_Equip_Main_UIBP_C:UAEUserWidget
---@field CanvasPanel_Tab2 UCanvasPanel
---@field Common_DragDrop_Common Common_DragDrop_Item_C
---@field Currency_1 Common_Currency_UIBP_C
---@field Currency_2 Common_Currency_UIBP_C
---@field Currency_3 Common_Currency_UIBP_C
---@field Currency_4 Common_Currency_UIBP_C
---@field NewButton_Close UNewButton
---@field ReuseList2_Level1 ReuseList2_C
---@field ReuseList2_Level2 ReuseList2_C
---@field ScaleBox_IPX UScaleBox
---@field TextBlock_Title UTextBlock
---@field UGC_Equip_Basics_Main_UIBP_7 Game_Equip_Basics_Main_UIBP_C
---@field UGC_Equip_Develop_Strengthen_UIBP Game_Equip_Develop_Strengthen_UIBP_C
---@field UGC_Equip_Develop_Transform_UIBP Game_Equip_Develop_Transform_UIBP_C
--Edit Below--
---装备主页面：右侧两级页签切换左侧已挂载的装备/强化/转化面板。
---  一级：装备 / 养成；养成下二级：强化 / 转化。
---  关闭按钮与页签 NewButton 的 OnClicked 不在 Construct 绑定（会原生崩溃），延迟到 InitData。
local EquipSlotSystem = require('Script.Common.EquipSlotSystem')

local PAGE_BASICS = 'basics'
local PAGE_STRENGTHEN = 'strengthen'
local PAGE_TRANSFORM = 'transform'

local LEVEL1_TABS = {
    { Id = 'equip', Title = '装备', Page = PAGE_BASICS, bHasLevel2 = false },
    { Id = 'develop', Title = '养成', bHasLevel2 = true },
}

local LEVEL2_DEVELOP = {
    { Id = 'strengthen', Title = '强化', Page = PAGE_STRENGTHEN },
    { Id = 'transform', Title = '转化', Page = PAGE_TRANSFORM },
}

local PAGE_WIDGET_NAME = {
    [PAGE_BASICS] = 'UGC_Equip_Basics_Main_UIBP_7',
    [PAGE_STRENGTHEN] = 'UGC_Equip_Develop_Strengthen_UIBP',
    [PAGE_TRANSFORM] = 'UGC_Equip_Develop_Transform_UIBP',
}

local PAGE_TITLE = {
    [PAGE_BASICS] = '装备',
    [PAGE_STRENGTHEN] = '强化',
    [PAGE_TRANSFORM] = '转化',
}

local LEVEL1_ITEM_CLASS = '/Game/UGC/UITemplate/Asset/Equip/UIBP/Item/UGC_Equip_Level1_Tabs_UIBP.UGC_Equip_Level1_Tabs_UIBP_C'
local LEVEL2_ITEM_CLASS = '/Game/UGC/UITemplate/Asset/Equip/UIBP/Item/UGC_Equip_Level2_Tabs_UIBP.UGC_Equip_Level2_Tabs_UIBP_C'

local Game_Equip_Main_UIBP = {
    bInitDoOnce = false,
    bCloseBound = false,
    bTabListsBound = false,
    InParams = nil,
    PageId = PAGE_BASICS,
    Level1Idx = 1,
    Level2Idx = 1,
    DevelopPageId = PAGE_STRENGTHEN,
    StrengthenSlotIdx = 1,
    TabClickBound = nil,
    TabClickData = nil,
}

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

local function SetCurrencyIcon(ImageWidget, ItemID)
    if not ImageWidget or not ItemID or ItemID == 0 then
        return
    end
    local OK, Path = pcall(function()
        return UGCItemSystemV2.GetItemIconTextureV2(ItemID)
    end)
    local PathStr = SoftPathToString(OK and Path or nil)
    if not PathStr then
        return
    end
    local WeakImage = WeakObjectPtr(ImageWidget)
    pcall(function()
        UGCObjectUtility.AsyncLoadObject(PathStr, function(LoadedTexture)
            if not WeakImage:IsValid() or not LoadedTexture then
                return
            end
            local Image = WeakImage:Get()
            if Image then
                pcall(function()
                    Image:SetBrushFromTexture(LoadedTexture, false)
                end)
            end
        end)
    end)
end

local function SetWidgetVisible(Widget, bVisible)
    if not Widget then
        return
    end
    Widget:SetVisibility(bVisible and ESlateVisibility.SelfHitTestInvisible or ESlateVisibility.Collapsed)
end

local function ApplyTabItem(Widget, Title, bSelected)
    if not Widget then
        return
    end
    if Widget.TextBlock_Name then
        Widget.TextBlock_Name:SetText(Title)
    end
    if Widget.TextBlock_Name_Selected then
        Widget.TextBlock_Name_Selected:SetText(Title)
    end
    if Widget.WidgetSwitcher_Selected then
        Widget.WidgetSwitcher_Selected:SetActiveWidgetIndex(bSelected and 1 or 0)
    end
end

function Game_Equip_Main_UIBP:Construct()
    self:LuaInit()
end

function Game_Equip_Main_UIBP:LuaInit()
    if self.bInitDoOnce then
        return
    end
    self.bInitDoOnce = true
    self.TabClickBound = {}
    self.TabClickData = {}
    self.PageId = PAGE_BASICS
    self.Level1Idx = 1
    self.Level2Idx = 1
    self.DevelopPageId = PAGE_STRENGTHEN
    print('[EquipMain] LuaInit begin')

    if self.TextBlock_Title then
        self.TextBlock_Title:SetText(PAGE_TITLE[PAGE_BASICS])
    end
    SetWidgetVisible(self.CanvasPanel_Tab2, false)
    self:ApplyPageVisibility(PAGE_BASICS)
    self:EnsureTabListsBound()
    print('[EquipMain] LuaInit end')
end

function Game_Equip_Main_UIBP:GetPageWidget(PageId)
    local Name = PAGE_WIDGET_NAME[PageId]
    return Name and self[Name] or nil
end

function Game_Equip_Main_UIBP:GetVisibleChild()
    return self:GetPageWidget(self.PageId)
end

function Game_Equip_Main_UIBP:ApplyPageVisibility(PageId)
    for Id, Name in pairs(PAGE_WIDGET_NAME) do
        SetWidgetVisible(self[Name], Id == PageId)
    end
end

function Game_Equip_Main_UIBP:EnsureCloseBound()
    if self.bCloseBound then
        return
    end
    local Btn = self.NewButton_Close
    if not Btn then
        print('[EquipMain] NewButton_Close 缺失')
        return
    end
    local OK, Err = pcall(function()
        Btn.OnClicked:Add(self.OnCloseClicked, self)
    end)
    if OK then
        self.bCloseBound = true
        print('[EquipMain] 关闭按钮已绑定')
    else
        print('[EquipMain] 关闭按钮绑定失败 err=' .. tostring(Err))
    end
end

function Game_Equip_Main_UIBP:EnsureTabListsBound()
    if self.bTabListsBound then
        return
    end
    local AllBound = true
    if self.ReuseList2_Level1 then
        local OK, Err = pcall(function()
            self.ReuseList2_Level1.OnUpdateItem:Add(self.OnUpdateLevel1Item, self)
        end)
        if not OK then
            AllBound = false
            print('[EquipMain] Level1 OnUpdateItem 绑定失败 err=' .. tostring(Err))
        end
    else
        AllBound = false
        print('[EquipMain] ReuseList2_Level1 缺失')
    end
    if self.ReuseList2_Level2 then
        local OK, Err = pcall(function()
            self.ReuseList2_Level2.OnUpdateItem:Add(self.OnUpdateLevel2Item, self)
        end)
        if not OK then
            AllBound = false
            print('[EquipMain] Level2 OnUpdateItem 绑定失败 err=' .. tostring(Err))
        end
    else
        AllBound = false
        print('[EquipMain] ReuseList2_Level2 缺失')
    end
    if AllBound then
        self.bTabListsBound = true
        print('[EquipMain] 两级页签列表已绑定')
    end
end

function Game_Equip_Main_UIBP:EnsureItemClass(List, ClassPath, Tag)
    if not List or List.ItemClass or not ClassPath then
        return
    end
    print('[EquipMain] ' .. Tag .. ' ItemClass 未加载，异步兜底')
    local WeakSelf = WeakObjectPtr(self)
    local WeakList = WeakObjectPtr(List)
    UGCObjectUtility.AsyncLoadClass(ClassPath, function(LoadedClass)
        if not WeakSelf:IsValid() or not WeakList:IsValid() or not LoadedClass then
            print('[EquipMain] ' .. Tag .. ' ItemClass 兜底失败')
            return
        end
        local SelfRef = WeakSelf:Get()
        local CurList = WeakList:Get()
        if SelfRef and CurList then
            CurList:SetItemClass(LoadedClass)
            SelfRef:ReloadTabs()
            print('[EquipMain] ' .. Tag .. ' ItemClass 兜底完成')
        end
    end)
end

function Game_Equip_Main_UIBP:ReloadTabs()
    if self.ReuseList2_Level1 then
        self:EnsureItemClass(self.ReuseList2_Level1, LEVEL1_ITEM_CLASS, 'Level1')
        if self.ReuseList2_Level1.ItemClass then
            self.ReuseList2_Level1:Reload(#LEVEL1_TABS)
        end
    end
    local bShowLevel2 = self.Level1Idx == 2
    if self.ReuseList2_Level2 then
        self:EnsureItemClass(self.ReuseList2_Level2, LEVEL2_ITEM_CLASS, 'Level2')
        if bShowLevel2 and self.ReuseList2_Level2.ItemClass then
            self.ReuseList2_Level2:Reload(#LEVEL2_DEVELOP)
        end
    end
end

function Game_Equip_Main_UIBP:BindTabClick(Widget, Kind, LuaIdx)
    if not Widget then
        return
    end
    self.TabClickBound = self.TabClickBound or {}
    self.TabClickData = self.TabClickData or {}
    local Key = tostring(Widget)
    self.TabClickData[Key] = { Kind = Kind, Idx = LuaIdx }
    if self.TabClickBound[Key] then
        return
    end
    local BtnName = Kind == 'l2' and 'NewButton_Level2_Tab' or 'NewButton_Level1_Tab'
    if not CheckObjectContainsField(Widget, BtnName, true) then
        return
    end
    local Btn = Widget[BtnName]
    if not Btn then
        return
    end
    local WeakSelf = WeakObjectPtr(self)
    local WeakWidget = WeakObjectPtr(Widget)
    local OK = pcall(function()
        Btn.OnClicked:Add(function()
            if not WeakSelf:IsValid() or not WeakWidget:IsValid() then
                return
            end
            local SelfRef = WeakSelf:Get()
            local ItemWidget = WeakWidget:Get()
            local Data = SelfRef and SelfRef.TabClickData and SelfRef.TabClickData[tostring(ItemWidget)]
            if not SelfRef or not Data then
                return
            end
            if Data.Kind == 'l1' then
                SelfRef:OnLevel1Clicked(Data.Idx)
            else
                SelfRef:OnLevel2Clicked(Data.Idx)
            end
        end)
    end)
    if OK then
        self.TabClickBound[Key] = true
    end
end

function Game_Equip_Main_UIBP:OnUpdateLevel1Item(Widget, Idx)
    local LuaIdx = Idx + 1
    local Tab = LEVEL1_TABS[LuaIdx]
    if not Tab then
        return
    end
    ApplyTabItem(Widget, Tab.Title, self.Level1Idx == LuaIdx)
    self:BindTabClick(Widget, 'l1', LuaIdx)
end

function Game_Equip_Main_UIBP:OnUpdateLevel2Item(Widget, Idx)
    local LuaIdx = Idx + 1
    local Tab = LEVEL2_DEVELOP[LuaIdx]
    if not Tab then
        return
    end
    ApplyTabItem(Widget, Tab.Title, self.Level2Idx == LuaIdx)
    self:BindTabClick(Widget, 'l2', LuaIdx)
end

function Game_Equip_Main_UIBP:OnLevel1Clicked(LuaIdx)
    local Tab = LEVEL1_TABS[LuaIdx]
    if not Tab then
        return
    end
    print('[EquipMain] Level1 click idx=' .. tostring(LuaIdx) .. ' id=' .. tostring(Tab.Id))
    if Tab.bHasLevel2 then
        self:SwitchToPage(self.DevelopPageId or PAGE_STRENGTHEN)
    else
        self:SwitchToPage(Tab.Page or PAGE_BASICS)
    end
end

function Game_Equip_Main_UIBP:OnLevel2Clicked(LuaIdx)
    local Tab = LEVEL2_DEVELOP[LuaIdx]
    if not Tab then
        return
    end
    print('[EquipMain] Level2 click idx=' .. tostring(LuaIdx) .. ' id=' .. tostring(Tab.Id))
    self:SwitchToPage(Tab.Page)
end

function Game_Equip_Main_UIBP:SyncTabIndexByPage(PageId)
    if PageId == PAGE_BASICS then
        self.Level1Idx = 1
        return
    end
    self.Level1Idx = 2
    if PageId == PAGE_TRANSFORM then
        self.Level2Idx = 2
        self.DevelopPageId = PAGE_TRANSFORM
    else
        self.Level2Idx = 1
        self.DevelopPageId = PAGE_STRENGTHEN
    end
end

function Game_Equip_Main_UIBP:SwitchToPage(PageId, Extra)
    Extra = Extra or {}
    PageId = PageId or PAGE_BASICS
    if not PAGE_WIDGET_NAME[PageId] then
        PageId = PAGE_BASICS
    end
    self.PageId = PageId
    self:SyncTabIndexByPage(PageId)
    SetWidgetVisible(self.CanvasPanel_Tab2, self.Level1Idx == 2)
    self:ApplyPageVisibility(PageId)
    if self.TextBlock_Title then
        self.TextBlock_Title:SetText(PAGE_TITLE[PageId] or '装备')
    end

    local Child = self:GetPageWidget(PageId)
    if Child and CheckObjectContainsField(Child, 'InitData', true) then
        if PageId == PAGE_STRENGTHEN then
            self.StrengthenSlotIdx = Extra.SlotIdx or self.StrengthenSlotIdx or 1
            local WeakSelf = WeakObjectPtr(self)
            Child:InitData({
                SlotIdx = self.StrengthenSlotIdx,
                CloseCallback = function()
                    if not WeakSelf:IsValid() then
                        return
                    end
                    local SelfRef = WeakSelf:Get()
                    if SelfRef then
                        SelfRef:SwitchToPage(PAGE_BASICS)
                    end
                end,
            })
        else
            Child:InitData(Extra)
        end
    end
    self:RefreshCurrencies()
    self:ReloadTabs()
    print('[EquipMain] SwitchToPage ' .. tostring(PageId) .. ' slot=' .. tostring(self.StrengthenSlotIdx))
end

function Game_Equip_Main_UIBP:RefreshCurrencies()
    local OK, Err = pcall(function()
        local PC = UGCGameSystem.GetLocalPlayerController()
        local IDs = nil
        if PC then
            IDs = UGCBackpackSystemV2.GetCurrencyIDList(PC)
        end
        local Count = 0
        if IDs and (type(IDs) == 'table' or type(IDs) == 'userdata') then
            Count = #IDs
        end
        for i = 1, 4 do
            local Widget = self['Currency_' .. i]
            if Widget then
                if i > Count then
                    Widget:SetVisibility(ESlateVisibility.Collapsed)
                else
                    Widget:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
                    local ItemID = IDs[i]
                    local Amount = EquipSlotSystem.GetItemCount(PC, ItemID)
                    if Widget.TextBlock_Currency_Amount then
                        Widget.TextBlock_Currency_Amount:SetText(tostring(Amount or 0))
                    end
                    SetCurrencyIcon(Widget.Image_Currency_Icon, ItemID)
                end
            end
        end
    end)
    if not OK then
        print('[EquipMain] RefreshCurrencies err=' .. tostring(Err))
    end
end

function Game_Equip_Main_UIBP:Refresh()
    self:RefreshCurrencies()
    local Child = self:GetVisibleChild()
    if Child and CheckObjectContainsField(Child, 'Refresh', true) then
        Child:Refresh()
    end
    self:ReloadTabs()
end

function Game_Equip_Main_UIBP:InitData(InParams)
    InParams = InParams or {}
    self.InParams = InParams
    print('[EquipMain] InitData page=' .. tostring(InParams.PageId) .. ' slot=' .. tostring(InParams.SlotIdx))
    self:EnsureCloseBound()
    self:EnsureTabListsBound()
    self:SwitchToPage(InParams.PageId or PAGE_BASICS, InParams)
end

function Game_Equip_Main_UIBP:OnCloseClicked()
    print('[EquipMain] close')
    if self.InParams and self.InParams.CloseCallback then
        self.InParams.CloseCallback()
        return
    end
    UGCWidgetUtility.HideWidget(self)
end

function Game_Equip_Main_UIBP:Destruct()
    if self.ReuseList2_Level1 then
        pcall(function()
            self.ReuseList2_Level1.OnUpdateItem:Remove(self.OnUpdateLevel1Item, self)
        end)
    end
    if self.ReuseList2_Level2 then
        pcall(function()
            self.ReuseList2_Level2.OnUpdateItem:Remove(self.OnUpdateLevel2Item, self)
        end)
    end
    self.InParams = nil
    self.TabClickBound = {}
    self.TabClickData = {}
    self.bCloseBound = false
    self.bTabListsBound = false
    self.bInitDoOnce = false
    print('[EquipMain] Destruct')
end

return Game_Equip_Main_UIBP
