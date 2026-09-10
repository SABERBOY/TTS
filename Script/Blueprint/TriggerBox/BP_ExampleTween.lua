---@class BP_ExampleTween_C:BP_ExampleBase_C
---@field TextRender UTextRenderComponent
---@field Sphere UStaticMeshComponent
---@field Scene USceneComponent
---@field TweenType EEasingType
---@field StartLocation FVector
---@field EndLocation FVector
---@field Duration float
--Edit Below--
local BP_ExampleTween = {
    TweenHandler = nil,
}

local function GetEasingTypeName(EasingType)
    for Name, Value in pairs(EEasingType) do
        if Value == EasingType then
            return Name
        end
    end
    return "Unknown"
end

function BP_ExampleTween:ReceiveBeginPlay()
    BP_ExampleTween.SuperClass.ReceiveBeginPlay(self)
    if not self:HasAuthority() then
        self.TextRender:SetText(GetEasingTypeName(self.TweenType))
    end
end

--检查是否可以交互
function BP_ExampleTween:CheckCanActive(ClickParam)
    return true;
end

function BP_ExampleTween:StartTween(ClickParam)
    self:StopTween()
	local UpdateDelegate = function(Obj, Value)
        self.Sphere:K2_SetRelativeLocation(Value)
    end
    self.TweenHandler = UGCTweenSystem.TweenVectorValue(self.StartLocation, self.EndLocation, self.Duration, self.TweenType, UpdateDelegate)
    local CompleteDelegate = function(Obj, Value)
        self.TweenHandler = nil
    end
    UGCTweenSystem.BindCompletedDelegate(self.TweenHandler, CompleteDelegate)
    UGCTweenSystem.ConfigureTween(self.TweenHandler, 0, 1, false, 0)
end

function BP_ExampleTween:StopTween(ClickParam)
    if not self.TweenHandler then
        return
    end
    UGCTweenSystem.KillTween(self.TweenHandler)
    self.TweenHandler = nil
    self.Sphere:K2_SetRelativeLocation(self.StartLocation)
end

function BP_ExampleTween:PauseTween(ClickParam) 
    if not self.TweenHandler then
        return
    end
    UGCTweenSystem.PauseTween(self.TweenHandler)
end

function BP_ExampleTween:ResumeTween(ClickParam) 
    if not self.TweenHandler then
        return
    end
    UGCTweenSystem.ResumeTween(self.TweenHandler)
end

function BP_ExampleTween:SetLoop(ClickParam)
    self:StopTween()
	local UpdateDelegate = function(Obj, Value)
        self.Sphere:K2_SetRelativeLocation(Value)
    end
    local Config = UGCTweenSystem.MakeConfig(0, -1, false, 0)
    self.TweenHandler = UGCTweenSystem.TweenVectorValue(self.StartLocation, self.EndLocation, self.Duration, self.TweenType, UpdateDelegate, Config)
end

function BP_ExampleTween:SetYoyo(ClickParam)
    self:StopTween()
	local UpdateDelegate = function(Obj, Value)
        self.Sphere:K2_SetRelativeLocation(Value)
    end
    local Config = UGCTweenSystem.MakeConfig(0, -1, true, 0)
    self.TweenHandler = UGCTweenSystem.TweenVectorValue(self.StartLocation, self.EndLocation, self.Duration, self.TweenType, UpdateDelegate, Config)
end


--[[
function BP_ExampleTween:ReceiveTick(DeltaTime)
    BP_ExampleTween.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function BP_ExampleTween:ReceiveEndPlay()
    BP_ExampleTween.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function BP_ExampleTween:GetReplicatedProperties()
    return
end
--]]

--[[
function BP_ExampleTween:GetAvailableServerRPCs()
    return
end
--]]

return BP_ExampleTween