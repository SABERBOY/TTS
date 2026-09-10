---@class DropBox_C:AActor
---@field TextRender_ActiveState UTextRenderComponent
---@field TextRender UTextRenderComponent
---@field UGCPresetCommonDropItemComponent UUGCPresetCommonDropItemComponent_C
---@field Cube UStaticMeshComponent
---@field Box UBoxComponent
---@field DefaultSceneRoot USceneComponent
---@field DropInterval float
---@field DropCDTimer float
---@field Color_Active FColor
---@field Color_CoolDown FColor
local BP_DropBox = {}

function BP_DropBox:ReceiveBeginPlay()
    BP_DropBox.SuperClass.ReceiveBeginPlay(self)
    self.Box.OnComponentBeginOverlap:Add(self.Box_OnComponentBeginOverlap, self)
    self.DropCDTimer = 0.0
end

function BP_DropBox:ReceiveEndPlay()
	self.Box.OnComponentBeginOverlap:Remove(self.Box_OnComponentBeginOverlap, self)
	self.DropCDTimer = 0.0
end

function BP_DropBox:CanActive()
    return self.DropCDTimer >= self.DropInterval
end

function BP_DropBox:ReceiveTick(DeltaTime)
    BP_DropBox.SuperClass.ReceiveTick(self, DeltaTime)

    self.DropCDTimer = self.DropCDTimer + DeltaTime

    if self:CanActive() then
        self.TextRender_ActiveState:SetText('CanDrop')
        self.TextRender_ActiveState:SetTextRenderColor(self.Color_Active)
    else
        local InCoolDownTime = math.floor(self.DropInterval - self.DropCDTimer)
        self.TextRender_ActiveState:SetText('InCoolDown' .. '(' .. tostring(InCoolDownTime) .. ')')
        self.TextRender_ActiveState:SetTextRenderColor(self.Color_CoolDown)
    end
end

function BP_DropBox:Box_OnComponentBeginOverlap(OverlappedComponent, OtherActor, OtherComp, OtherBodyIndex, bFromSweep,
    SweepResult)
    if self:CanActive() then
        self.DropCDTimer = 0.0
        local TraceIgnoreActors = {}
        TraceIgnoreActors[0] = self
        self.UGCPresetCommonDropItemComponent:StartDrop(self, nil, TraceIgnoreActors)
    end
end

return BP_DropBox
