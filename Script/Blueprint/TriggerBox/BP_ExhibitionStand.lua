---@class ExhibitionStand_C:AActor
---@field TextRenderStatus UTextRenderComponent
---@field TextRender UTextRenderComponent
---@field Widget UWidgetComponent
---@field ParticleSystem UParticleSystemComponent
---@field Cube UStaticMeshComponent
---@field Box UBoxComponent
---@field DefaultSceneRoot USceneComponent
---@field TitleText FString
---@field TeleportTo AActor
---@field LocationOffset FVector
---@field RotationOffset FRotator
--Edit Below--
local BP_ExhibitionStand = {}

function BP_ExhibitionStand:ReceiveBeginPlay()
    BP_ExhibitionStand.SuperClass.ReceiveBeginPlay(self)

    if UGCGameSystem.IsServer() then
        self.Box.OnComponentBeginOverlap:Add(self.OnBeginOverlap, self)
        self.Box.OnComponentEndOverlap:Add(self.OnEndOverlap, self)
    else
        self:SetTitleText(self.TitleText)
        self:SetStatusText("")
    end
end

function BP_ExhibitionStand:ReceiveEndPlay()
    if UGCGameSystem.IsServer() then
        self.Box.OnComponentBeginOverlap:Remove(self.OnBeginOverlap, self)
        self.Box.OnComponentEndOverlap:Remove(self.OnEndOverlap, self)
    end
end

function BP_ExhibitionStand:SetTitleText(TitleTxt)
    self.Widget.Widget.TextBlock_Title:SetText(TitleTxt)
end

function BP_ExhibitionStand:SetStatusText(StatusTxt)
    self.TextRenderStatus:K2_SetText(StatusTxt)
end

function BP_ExhibitionStand:OnBeginOverlap(OverlappedComp, Other, OtherComp, OtherBodyIndex, bFromSweep, SweepResult)
    if UGCGameSystem.IsServer() then
        self:Server_TeleportTo(Other)
    end
end

function BP_ExhibitionStand:Server_TeleportTo(PlayerPawn)
    if self.TeleportTo then
        local TargetPos = self.TeleportTo:K2_GetActorLocation()
        UGCPlayerControllerSystem.TeleportTo(PlayerPawn.Controller, TargetPos.X + self.LocationOffset.X, TargetPos.Y + self.LocationOffset.Y, TargetPos.Z + self.LocationOffset.Z)
    end
end

return BP_ExhibitionStand