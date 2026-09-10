---@class GameHUD_C:UUserWidget
---@field Button_Buff UButton
---@field Button_Circle UButton
---@field Button_Instance UButton
---@field Button_Item UButton
---@field Button_Machine UButton
---@field Button_Monster UButton
---@field Button_NewItem UButton
---@field Button_PCGRoad UButton
---@field Button_Skill UButton
---@field Button_Tween UButton
---@field Button_TweenArea UButton
---@field Button_TweenWidget UButton
---@field Button_UI UButton
---@field Button_Weapon UButton
---@field TextBlock_2 UTextBlock
---@field TextBlock_3 UTextBlock
---@field TextBlock_MonsterWave UTextBlock
---@field TitleText_Buff UTextBlock
---@field TitleText_Circle UTextBlock
---@field TitleText_Instance UTextBlock
---@field TitleText_Item UTextBlock
---@field TitleText_Machine UTextBlock
---@field TitleText_Monster UTextBlock
---@field TitleText_NewItem UTextBlock
---@field TitleText_PCGRoad UTextBlock
---@field TitleText_Skill UTextBlock
---@field TitleText_Tween UTextBlock
---@field TitleText_UI UTextBlock
---@field TitleText_Weapon UTextBlock
---@field TopButtons UHorizontalBox
---@field TweenBox UVerticalBox
--Edit Below--
local GameHUD = { bInitDoOnce = false }
function GameHUD:Construct()
    self:LuaInit();
end
function GameHUD:LuaInit()
    if self.bInitDoOnce then
        return;
    end
    self.bInitDoOnce = true;
    self.Button_Weapon.OnClicked:Add(self.Button_Weapon_OnClicked, self);
    self.Button_Monster.OnClicked:Add(self.Button_Monster_OnClicked, self);
    self.Button_Skill.OnClicked:Add(self.Button_Skill_OnClicked, self);
    self.Button_Buff.OnClicked:Add(self.Button_Buff_OnClicked, self);
    self.Button_Item.OnClicked:Add(self.Button_Item_OnClicked, self);
    self.Button_Instance.OnClicked:Add(self.Button_Instance_OnClicked, self);
    self.Button_Circle.OnClicked:Add(self.Button_Circle_OnClicked, self);
    self.Button_PCGRoad.OnClicked:Add(self.Button_PCGRoad_OnClicked, self);
    -- self.Button_NewItem.OnClicked:Add(self.Button_NewItem_OnClicked, self);
    -- self.Button_Machine.OnClicked:Add(self.Button_Machine_OnClicked, self);
    -- self.Button_UI.OnClicked:Add(self.Button_UI_OnClicked, self);
    self.Button_Tween.OnClicked:Add(self.Button_Tween_OnClicked, self);
    self.Button_TweenArea.OnClicked:Add(self.Button_TweenArea_OnClicked, self);
    self.Button_TweenWidget.OnClicked:Add(self.Button_TweenWidget_OnClicked, self);
end
function GameHUD:Button_Weapon_OnClicked()
    local PC = UGCGameSystem.GetLocalPlayerController()
    local TitleText = self.TitleText_Weapon:GetText()
    print("GameHUD:Button_Weapon_OnClicked TitleText=" .. TitleText)
    UnrealNetwork.CallUnrealRPC(PC, PC, "ServerTeleportTo", TitleText)
end
function GameHUD:Button_Monster_OnClicked()
    local PC = UGCGameSystem.GetLocalPlayerController()
    local TitleText = self.TitleText_Monster:GetText()
    print("GameHUD:Button_Monster_OnClicked TitleText=" .. TitleText)
    UnrealNetwork.CallUnrealRPC(PC, PC, "ServerTeleportTo", TitleText)
end
function GameHUD:Button_Skill_OnClicked()
    local PC = UGCGameSystem.GetLocalPlayerController()
    local TitleText = self.TitleText_Skill:GetText()
    print("GameHUD:Button_Skill_OnClicked TitleText=" .. TitleText)
    UnrealNetwork.CallUnrealRPC(PC, PC, "ServerTeleportTo", TitleText)
end
function GameHUD:Button_Buff_OnClicked()
    local PC = UGCGameSystem.GetLocalPlayerController()
    local TitleText = self.TitleText_Buff:GetText()
    print("GameHUD:Button_Buff_OnClicked TitleText=" .. TitleText)
    UnrealNetwork.CallUnrealRPC(PC, PC, "ServerTeleportTo", TitleText)
end
function GameHUD:Button_Item_OnClicked()
    local PC = UGCGameSystem.GetLocalPlayerController()
    local TitleText = self.TitleText_Item:GetText()
    print("GameHUD:Button_Item_OnClicked TitleText=" .. TitleText)
    UnrealNetwork.CallUnrealRPC(PC, PC, "ServerTeleportTo", TitleText)
end
function GameHUD:Button_Instance_OnClicked()
    local PC = UGCGameSystem.GetLocalPlayerController()
    local TitleText = self.TitleText_Instance:GetText()
    print("GameHUD:Button_Instance_OnClicked TitleText=" .. TitleText)
    UnrealNetwork.CallUnrealRPC(PC, PC, "ServerTeleportTo", TitleText)
end
--开始缩圈
function GameHUD:Button_Circle_OnClicked()
    local PC = STExtraGameplayStatics.GetFirstPlayerController(self)
    local TitleText = self.TitleText_Circle:GetText()
    print("GameHUD:Button_Circle_OnClicked TitleText=" .. TitleText)
    UnrealNetwork.CallUnrealRPC(PC, PC, "ServerRPC_StartCircle")
end
function GameHUD:Button_PCGRoad_OnClicked()
    local PC = UGCGameSystem.GetLocalPlayerController()
    local TitleText = self.TitleText_PCGRoad:GetText()
    print("GameHUD:Button_PCGRoad_OnClicked TitleText=" .. TitleText)
    UnrealNetwork.CallUnrealRPC(PC, PC, "ServerTeleportTo", TitleText)
end
-- function GameHUD:Button_NewItem_OnClicked()
--     local PC = UGCGameSystem.GetLocalPlayerController()
--     local TitleText = self.TitleText_NewItem:GetText()
--     print("GameHUD:Button_NewItem_OnClicked TitleText="..TitleText)
--     UnrealNetwork.CallUnrealRPC(PC, PC, "ServerTeleportTo", TitleText)
-- end
-- function GameHUD:Button_Machine_OnClicked()
--     local PC = UGCGameSystem.GetLocalPlayerController()
--     local TitleText = self.TitleText_Machine:GetText()
--     print("GameHUD:Button_Machine_OnClicked TitleText="..TitleText)
--     UnrealNetwork.CallUnrealRPC(PC, PC, "ServerTeleportTo", TitleText)
-- end
-- function GameHUD:Button_UI_OnClicked()
--     local PC = UGCGameSystem.GetLocalPlayerController()
--     local TitleText = self.TitleText_UI:GetText()
--     print("GameHUD:Button_UI_OnClicked TitleText="..TitleText)
--     UnrealNetwork.CallUnrealRPC(PC, PC, "ServerTeleportTo", TitleText)
-- end
function GameHUD:Button_Tween_OnClicked()
    if self.TweenBox:IsVisible() then
        self.TweenBox:SetVisibility(ESlateVisibility.Collapsed)
    else
        self.TweenBox:SetVisibility(ESlateVisibility.Visible)
    end
end
function GameHUD:Button_TweenArea_OnClicked()
    local PC = UGCGameSystem.GetLocalPlayerController()
    local TitleText = self.TitleText_Tween:GetText()
    print("GameHUD:Button_PCGRoad_OnClicked TitleText=" .. TitleText)
    UnrealNetwork.CallUnrealRPC(PC, PC, "ServerTeleportTo", TitleText)    
end
function GameHUD:Button_TweenWidget_OnClicked()
    if not self.TweenShow then
        local Path = UGCGameSystem.GetUGCResourcesFullPath('Asset/Blueprint/UMG/TweenShow.TweenShow_C')
        UGCWidgetManagerSystem.CreateWidgetAsync(Path, function(Widget)
            self.TweenShow = Widget
            UGCWidgetManagerSystem.AddToSlot(self.TweenShow, 'UI.UISlot.MainUISlot_High', 100)
            Widget.ParentWidget = self
        end)
    else

    end
end

function GameHUD:CloseTweenShow()
    self.TweenShow = nil
end

return GameHUD