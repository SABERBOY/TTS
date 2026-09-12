---装备主页面打开/关闭（GM 与槽位点击共用）
---入口只创建 UGC_Equip_Main_UIBP，左侧子面板由主页面页签切换，不再单独 Create Basics/Strengthen。
local EquipPanelManager = {
    MainWidget = nil,
}

local MAIN_PATH = 'Asset/Blueprint/Prefabs/UI/UGC_Equip_Main_UIBP.UGC_Equip_Main_UIBP_C'
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

local function ShowAndInit(Widget, InParams)
    InParams = InParams or {}
    InParams.CloseCallback = function()
        EquipPanelManager.Close()
    end
    if not UGCWidgetUtility.IsWidgetAddedToSlot(Widget) then
        UGCWidgetUtility.AddToSlot(Widget, SLOT_NAME, 180)
    end
    UGCWidgetUtility.ShowWidget(Widget)
    if CheckObjectContainsField(Widget, 'InitData', true) then
        Widget:InitData(InParams)
    end
end

function EquipPanelManager.GetMainWidget()
    return ResolveWidget(EquipPanelManager.MainWidget)
end

---打开装备主页面。InParams.PageId = basics|strengthen|transform，强化可带 SlotIdx。
function EquipPanelManager.Open(InParams)
    InParams = InParams or {}
    InParams.PageId = InParams.PageId or 'basics'
    local Cached = EquipPanelManager.GetMainWidget()
    if Cached then
        ShowAndInit(Cached, InParams)
        print('[EquipPanel] Open reuse page=' .. tostring(InParams.PageId))
        return
    end
    local Path = UGCGameSystem.GetUGCResourcesFullPath(MAIN_PATH)
    UGCWidgetUtility.CreateWidgetAsync(Path, function(Widget)
        if not Widget or not UE.IsValid(Widget) then
            print('[EquipPanel] Open create failed')
            return
        end
        EquipPanelManager.MainWidget = WeakObjectPtr(Widget)
        ShowAndInit(Widget, InParams)
        print('[EquipPanel] Open created page=' .. tostring(InParams.PageId))
    end)
end

function EquipPanelManager.Close()
    local Cached = EquipPanelManager.GetMainWidget()
    if Cached then
        UGCWidgetUtility.HideWidget(Cached)
        print('[EquipPanel] Close')
    end
end

---槽位点击 / GM：切到主页面的强化页签，不再单独弹出 Strengthen overlay。
function EquipPanelManager.OpenStrengthen(SlotIdx)
    EquipPanelManager.Open({
        PageId = 'strengthen',
        SlotIdx = SlotIdx or 1,
    })
end

---兼容旧调用名：实际打开主页面装备页签
function EquipPanelManager.OpenBasics()
    EquipPanelManager.Open({ PageId = 'basics' })
end

function EquipPanelManager.CloseBasics()
    EquipPanelManager.Close()
end

function EquipPanelManager.GetBasicsWidget()
    local Main = EquipPanelManager.GetMainWidget()
    if Main and CheckObjectContainsField(Main, 'GetVisibleChild', true) then
        return Main:GetVisibleChild() or Main
    end
    return Main
end

return EquipPanelManager
