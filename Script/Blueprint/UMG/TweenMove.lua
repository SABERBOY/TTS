---@class TweenMove_C:UUserWidget
---@field PauseCheckBox UCheckBox
---@field ShowName UTextBlock
---@field TweenImage UImage
---@field YoyoCheckBox UCheckBox
---@field TweenType EEasingType
---@field TweenHandler FTweenHandle
--Edit Below--
local TweenMove = 
{ 
	bInitDoOnce = false,
    Controller = nil
} 
local function GetEasingTypeName(EasingType)
    for Name, Value in pairs(EEasingType) do
        if Value == EasingType then
            return Name
        end
    end
    return "Unknown"
end


function TweenMove:Construct()
	self:LuaInit()
    self.Controller = UGCGameSystem.GetLocalPlayerController()
	local StartLocation = KismetMathLibrary.MakeVector(0, 0, 0)
	local EndLocation = KismetMathLibrary.MakeVector(700, 0, 0)
	local Delegate = function(Obj, Value)
        local Slot = UGCWidgetManagerSystem.SlotAsCanvasSlot(self.TweenImage)
		Slot:SetPosition(KismetMathLibrary.MakeVector2D(Value.X, 0))
    end
    local Config = UGCTweenSystem.MakeConfig(0, -1, false, 0)
    self.TweenHandler = UGCTweenSystem.TweenVectorValue(StartLocation, EndLocation, 1.0, self.TweenType, Delegate, Config)
	UGCTweenSystem.PauseTween(self.TweenHandler)
	self.ShowName:SetText(GetEasingTypeName(self.TweenType))
end
-- function TweenMove:Tick(MyGeometry, InDeltaTime)
-- end
-- function TweenMove:Destruct()
-- end
-- [Editor Generated Lua] function define Begin:
function TweenMove:LuaInit()
	if self.bInitDoOnce then
		return;
	end
	self.bInitDoOnce = true;
	-- [Editor Generated Lua] BindingProperty Begin:
	-- [Editor Generated Lua] BindingProperty End;
	
	-- [Editor Generated Lua] BindingEvent Begin:
	self.YoyoCheckBox.OnCheckStateChanged:Add(self.YoyoCheckBox_OnCheckStateChanged, self);
	self.PauseCheckBox.OnCheckStateChanged:Add(self.PauseCheckBox_OnCheckStateChanged, self);
	-- [Editor Generated Lua] BindingEvent End;
end

function TweenMove:YoyoCheckBox_OnCheckStateChanged(bIsChecked)
	if not self.TweenHandler then
        return
    end
    UGCTweenSystem.ConfigureTween(self.TweenHandler, 0, -1, bIsChecked, 0)
end

function TweenMove:PauseCheckBox_OnCheckStateChanged(bIsChecked)
	if not self.TweenHandler then
        return
    end
    if bIsChecked then
        UGCTweenSystem.PauseTween(self.TweenHandler)
    else
        UGCTweenSystem.ResumeTween(self.TweenHandler)
    end
end

-- [Editor Generated Lua] function define End;

return TweenMove