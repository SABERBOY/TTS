---装备面板打开/关闭（GM 与其它入口共用）
local EquipPanelManager = {
    BasicsWidget = nil,
    StrengthenWidget = nil,
}

local BASICS_PATH = 'Asset/Blueprint/Prefabs/UI/UGC_Equip_Basics_Main_UIBP.UGC_Equip_Basics_Main_UIBP_C'
local STRENGTHEN_PATH = 'Asset/Blueprint/Prefabs/UI/UGC_Equip_Develop_Strengthen_UIBP.UGC_Equip_Develop_Strengthen_UIBP_C'
local SLOT_NAME = 'UI.UISlot.MainUISlot_High'

local function ResolveWidget(WeakPtr)
    if not WeakPtr then
        return nil
    end
    if WeakPtr.IsValid and WeakPtr:IsValid() then
        return WeakPtr:Get()
    end
    return nil
end

function EquipPanelManager.OpenBasics()
    local Cached = ResolveWidget(EquipPanelManager.BasicsWidget)
    if Cached then
        if not UGCWidgetUtility.IsWidgetAddedToSlot(Cached) then
            UGCWidgetUtility.AddToSlot(Cached, SLOT_NAME, 180)
        end
        UGCWidgetUtility.ShowWidget(Cached)
        if CheckObjectContainsField(Cached, 'InitData', true) then
            Cached:InitData({})
        end
        print('[EquipPanel] OpenBasics reuse')
        return
    end
    local Path = UGCGameSystem.GetUGCResourcesFullPath(BASICS_PATH)
    UGCWidgetUtility.CreateWidgetAsync(Path, function(Widget)
        if not Widget or not UE.IsValid(Widget) then
            print('[EquipPanel] OpenBasics create failed')
            return
        end
        EquipPanelManager.BasicsWidget = WeakObjectPtr(Widget)
        if not UGCWidgetUtility.IsWidgetAddedToSlot(Widget) then
            UGCWidgetUtility.AddToSlot(Widget, SLOT_NAME, 180)
        end
        UGCWidgetUtility.ShowWidget(Widget)
        if CheckObjectContainsField(Widget, 'InitData', true) then
            Widget:InitData({})
        end
        print('[EquipPanel] OpenBasics created')
    end)
end

function EquipPanelManager.CloseBasics()
    local Cached = ResolveWidget(EquipPanelManager.BasicsWidget)
    if Cached then
        UGCWidgetUtility.HideWidget(Cached)
        print('[EquipPanel] CloseBasics')
    end
end

function EquipPanelManager.OpenStrengthen(SlotIdx)
    SlotIdx = SlotIdx or 1
    local Cached = ResolveWidget(EquipPanelManager.StrengthenWidget)
    local function Apply(Widget)
        if not UGCWidgetUtility.IsWidgetAddedToSlot(Widget) then
            UGCWidgetUtility.AddToSlot(Widget, SLOT_NAME, 200)
        end
        UGCWidgetUtility.ShowWidget(Widget)
        if CheckObjectContainsField(Widget, 'InitData', true) then
            Widget:InitData({
                SlotIdx = SlotIdx,
                CloseCallback = function()
                    UGCWidgetUtility.HideWidget(Widget)
                end,
            })
        end
    end
    if Cached then
        Apply(Cached)
        print('[EquipPanel] OpenStrengthen reuse slot=' .. tostring(SlotIdx))
        return
    end
    local Path = UGCGameSystem.GetUGCResourcesFullPath(STRENGTHEN_PATH)
    UGCWidgetUtility.CreateWidgetAsync(Path, function(Widget)
        if not Widget or not UE.IsValid(Widget) then
            print('[EquipPanel] OpenStrengthen create failed')
            return
        end
        EquipPanelManager.StrengthenWidget = WeakObjectPtr(Widget)
        Apply(Widget)
        print('[EquipPanel] OpenStrengthen created slot=' .. tostring(SlotIdx))
    end)
end

function EquipPanelManager.GetBasicsWidget()
    return ResolveWidget(EquipPanelManager.BasicsWidget)
end

return EquipPanelManager
