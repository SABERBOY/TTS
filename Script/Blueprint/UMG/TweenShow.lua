---@class TweenShow_C:UUserWidget
---@field ButtonClose UButton
---@field ColorButton UButton
---@field Image_0 UImage
---@field MoveButton UButton
---@field MoveColorSwitcher UWidgetSwitcher
---@field TweenColor TweenColor_C
---@field TweenColor_334 TweenColor_C
---@field TweenColor_442 TweenColor_C
---@field TweenColor_580 TweenColor_C
---@field TweenColor_719 TweenColor_C
---@field TweenColor_C_720 TweenColor_C
---@field TweenColor_C_721 TweenColor_C
---@field TweenColor_C_722 TweenColor_C
---@field TweenColor_C_723 TweenColor_C
---@field TweenColor_C_724 TweenColor_C
---@field TweenColor_C_725 TweenColor_C
---@field TweenColor_C_726 TweenColor_C
---@field TweenColor_C_727 TweenColor_C
---@field TweenColor_C_728 TweenColor_C
---@field TweenColor_C_729 TweenColor_C
---@field TweenColor_C_730 TweenColor_C
---@field TweenColor_C_731 TweenColor_C
---@field TweenColor_C_732 TweenColor_C
---@field TweenColor_C_733 TweenColor_C
---@field TweenColor_C_734 TweenColor_C
---@field TweenColor_C_735 TweenColor_C
---@field TweenColor_C_736 TweenColor_C
---@field TweenColor_C_737 TweenColor_C
---@field TweenColor_C_738 TweenColor_C
---@field TweenColor_C_739 TweenColor_C
---@field TweenColor_C_740 TweenColor_C
---@field TweenColor_C_741 TweenColor_C
---@field TweenColor_C_742 TweenColor_C
---@field TweenColor_C_743 TweenColor_C
---@field TweenColor_C_744 TweenColor_C
---@field TweenColor_C_745 TweenColor_C
---@field TweenMove TweenMove_C
---@field TweenMove_127 TweenMove_C
---@field TweenMove_C_1 TweenMove_C
---@field TweenMove_C_2 TweenMove_C
---@field TweenMove_C_3 TweenMove_C
---@field TweenMove_C_4 TweenMove_C
---@field TweenMove_C_5 TweenMove_C
---@field TweenMove_C_6 TweenMove_C
---@field TweenMove_C_7 TweenMove_C
---@field TweenMove_C_8 TweenMove_C
---@field TweenMove_C_9 TweenMove_C
---@field TweenMove_C_10 TweenMove_C
---@field TweenMove_C_11 TweenMove_C
---@field TweenMove_C_12 TweenMove_C
---@field TweenMove_C_13 TweenMove_C
---@field TweenMove_C_14 TweenMove_C
---@field TweenMove_C_15 TweenMove_C
---@field TweenMove_C_16 TweenMove_C
---@field TweenMove_C_17 TweenMove_C
---@field TweenMove_C_18 TweenMove_C
---@field TweenMove_C_19 TweenMove_C
---@field TweenMove_C_20 TweenMove_C
---@field TweenMove_C_21 TweenMove_C
---@field TweenMove_C_22 TweenMove_C
---@field TweenMove_C_23 TweenMove_C
---@field TweenMove_C_24 TweenMove_C
---@field TweenMove_C_25 TweenMove_C
---@field TweenMove_C_26 TweenMove_C
---@field TweenMove_C_27 TweenMove_C
---@field TweenMove_C_28 TweenMove_C
---@field TweenMove_C_128 TweenMove_C
--Edit Below--
local TweenShow = { 
	bInitDoOnce = false,
	---@type GameHUD_C
	ParentWidget = nil
} 
function TweenShow:Construct()
	self:LuaInit();
	
end
-- function TweenShow:Tick(MyGeometry, InDeltaTime)
-- end
-- function TweenShow:Destruct()
-- end
-- [Editor Generated Lua] function define Begin:
function TweenShow:LuaInit()
	if self.bInitDoOnce then
		return;
	end
	self.bInitDoOnce = true;
	-- [Editor Generated Lua] BindingProperty Begin:
	-- [Editor Generated Lua] BindingProperty End;
	
	-- [Editor Generated Lua] BindingEvent Begin:
	self.ButtonClose.OnClicked:Add(self.ButtonClose_OnClicked, self);
	self.ColorButton.OnClicked:Add(self.ColorButton_OnClicked, self);
	self.MoveButton.OnClicked:Add(self.MoveButton_OnClicked, self);
	-- [Editor Generated Lua] BindingEvent End;
end
function TweenShow:ButtonClose_OnClicked()
    UGCWidgetManagerSystem.RemoveFromSlot(self)
	if self.ParentWidget then
        self.ParentWidget:CloseTweenShow()
    end
end
function TweenShow:ColorButton_OnClicked()
	self.MoveColorSwitcher:SetActiveWidgetIndex(1)
end

function TweenShow:MoveButton_OnClicked()
	self.MoveColorSwitcher:SetActiveWidgetIndex(0)
end

-- [Editor Generated Lua] function define End;
return TweenShow