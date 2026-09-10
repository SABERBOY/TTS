---@class UGCPlayerState_C:BP_UGCPlayerState_C
-- Edit Below--
local UGCPlayerState = {
    HeroesInfo = {},
    CurrentHeroId = nil,
    CurrentPawn = nil,
    CurrentController = nil,

    ---@type table<int32, HeroStateInfo>
    HeroesStateInfoList = {}
}

---@class HeroStateInfo
HeroStateInfo = {
    HeroID = 0,
    AttributesAddList = {}
}

function UGCPlayerState:InitPlayerState(CurrentController)
    self.CurrentController = CurrentController
end

function UGCPlayerState:CreateHeroStateInfo(HeroID)
    ugcprint("UGCPlayerState:CreateHeroStateInfo(HeroID)" .. tostring(HeroID))
    if HeroID ~= nil and self.HeroesStateInfoList[HeroID] == nil then
        ---@type HeroStateInfo
        local NewHeroStateInfo = {}
        NewHeroStateInfo.HeroID = HeroID
        NewHeroStateInfo.AttributesAddList = {}

        self.HeroesStateInfoList[HeroID] = NewHeroStateInfo

    else
        ugcprint("UGCPlayerState:CreateHeroStateInfo(HeroID): self.HeroesStateInfoList[HeroID] ~= nil")
    end

end

function UGCPlayerState:GetHeroAttrAdd(HeroID, AttrName)
    if HeroID == nil or self.HeroesStateInfoList[HeroID] == nil then
        print("UGCPlayerState:GetHeroAttrAdd [HeroID == nil or self.HeroesStateInfoList[HeroID] == nil]")
        return 0
    end

    ugcprint("UGCPlayerState:GetHeroAttrAdd(HeroID,AttrName)" .. tostring(AttrName))
    local AttributesAddList = self.HeroesStateInfoList[HeroID].AttributesAddList
    if AttributesAddList ~= nil and AttributesAddList[AttrName] ~= nil then
        return AttributesAddList[AttrName]
    end
    return 0
end

function UGCPlayerState:OnHeroSelectionFinished(HeroID)
    print("UGCPlayerState:OnHeroSelectionFinished(HeroID)" .. tostring(HeroID))
    if HeroID == nil then
        print("UGCPlayerState:OnHeroSelectionFinished(HeroID) [HeroID == nil]")
        return
    end

    if self.HeroesStateInfoList[HeroID] == nil then
        self:CreateHeroStateInfo(HeroID)
    end

    self.CurrentPawn = UGCPlayerControllerSystem.GetPlayerCharacter(self.CurrentController)

    self.CurrentHeroId = HeroID

    if self.CurrentPawn ~= nil then
        for AttrName, AddValue in pairs(self.HeroesStateInfoList[HeroID].AttributesAddList) do
            UGCAttributeSystem.AddGameAttributeValue(self.CurrentPawn, AttrName, AddValue)
        end

    else
        ugcprint("UGCPlayerState:OnRespawnHero(HeroID) [self.CurrentPawn == nil]")
    end

end

function UGCPlayerState:AddPersistAttr(AttributeType, Value)
    ugcprint("UGCPlayerState:AddPersistAttr Try To Add " .. tostring(AttributeType) .. ": " .. tostring(Value))
    if not UGCGameSystem.IsServer() then
        return
    end

    ---@type HeroStateInfo
    local CurrentHeroStateInfo = self.HeroesStateInfoList[self.CurrentHeroId]
    if CurrentHeroStateInfo == nil then
        ugcprint("UGCPlayerState:AddPersistAttr [CurrentHeroStateInfo == nil]")
        return
    end

    if CurrentHeroStateInfo.AttributesAddList[AttributeType] == nil then
        CurrentHeroStateInfo.AttributesAddList[AttributeType] = Value
    else
        CurrentHeroStateInfo.AttributesAddList[AttributeType] =
            CurrentHeroStateInfo.AttributesAddList[AttributeType] + Value
    end
    UGCAttributeSystem.AddGameAttributeValue(self.CurrentPawn, AttributeType, Value)

end

function UGCPlayerState:GetReplicatedProperties()
    return "HeroesStateInfoList"
end
return UGCPlayerState
