---@class TweenColor_C:UUserWidget
---@field PauseCheckBox UCheckBox
---@field TweenTarget UImage
---@field TypeNameText UTextBlock
---@field YoyoCheckBox UCheckBox
---@field TweenType EEasingType
---@field TweenHandler FTweenHandle
--Edit Below--
local TweenColor = { 
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

function TweenColor:Construct()
	self:LuaInit()
    self.Controller = UGCGameSystem.GetLocalPlayerController()
	local StartColor = KismetMathLibrary.MakeColor(0, 1, 0, 1)
	local EndColor = KismetMathLibrary.MakeColor(1, 0, 0, 1)
	local Delegate = function(Obj, Value)
        self.TweenTarget:SetColorAndOpacity(Value)
    end
    local Config = UGCTweenSystem.MakeConfig(0, -1, false, 0)
    self.TweenHandler = UGCTweenSystem.TweenColorValue(StartColor, EndColor, 1.0, self.TweenType, Delegate, Config)
	UGCTweenSystem.PauseTween(self.TweenHandler)	
    self.TypeNameText:SetText(GetEasingTypeName(self.TweenType))
end

function TweenColor:LuaInit()
	if self.bInitDoOnce then
		return;
	end
	self.bInitDoOnce = true;
	-- [Editor Generated Lua] BindingProperty Begin:
	-- [Editor Generated Lua] BindingProperty End;
	
	-- [Editor Generated Lua] BindingEvent Begin:
    
	self.PauseCheckBox.OnCheckStateChanged:Add(self.PauseCheckBox_OnCheckStateChanged, self);
	self.YoyoCheckBox.OnCheckStateChanged:Add(self.YoyoCheckBox_OnCheckStateChanged, self);
	-- [Editor Generated Lua] BindingEvent End;  
end

-- function TweenColor:Tick(MyGeometry, InDeltaTime)
-- end
-- function TweenColor:Destruct()
-- end
-- [Editor Generated Lua] function define Begin:

function TweenColor:PauseCheckBox_OnCheckStateChanged(bIsChecked)
	if not self.TweenHandler then
        return
    end	
    if bIsChecked then
        UGCTweenSystem.PauseTween(self.TweenHandler)
    else
        UGCTweenSystem.ResumeTween(self.TweenHandler)
    end
end

function TweenColor:YoyoCheckBox_OnCheckStateChanged(bIsChecked)
	if not self.TweenHandler then
        return
    end
    UGCTweenSystem.ConfigureTween(self.TweenHandler, 0, -1, bIsChecked, 0)
end

-- [Editor Generated Lua] function define End;

return TweenColor