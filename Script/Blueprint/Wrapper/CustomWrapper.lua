---@class CustomWrapper_C:UGCPickupWrapper_BP_C
---@field TweenType EEasingType
---@field EnableTween bool
---@field Duration float
---@field StartLocation FVector
---@field EndLocation FVector
---@field Rotator FRotator
---@field DataID FString @物品实例数据ID，格式 "ItemID_Level"（如 "8310048_2"），在编辑器中配置
--Edit Below--
local CustomWrapper = {
    SubSystem = nil,
    TweenHandler = nil,
}

---------------------------------------------------------------------------
-- 拾取物写入 DataID
--
-- 两种拾取物来源：
--   1. SpawnPickupWrapper 产出：CustomData（含 DataID）在产出时已写入，
--      拾取时自动继承到背包物品，OnItemPickup 中检测到已有 DataID 则跳过
--   2. StartDrop 产出：CustomData 未写入，需要在 OnItemPickup 中
--      手动将 self.DataID 写入物品的 CustomData
---------------------------------------------------------------------------

--- 拾取物品时回调（DS端），将 DataID 写入物品实例自定义数据
---@param PickerPawn ASTExtraBaseCharacter @拾取者
function CustomWrapper:OnItemPickup(PickerPawn)
    CustomWrapper.SuperClass.OnItemPickup(self, PickerPawn)

    if not self:HasAuthority() then return end
    if not self.DataID or self.DataID == "" then return end

    local DefineID = self:GetDefineID()
    if not DefineID then return end

    -- 检查 CustomData 是否已包含 DataID（SpawnPickupWrapper 产出的情况）
    local CustomData = UGCItemSystemV2.LoadItemCustomData(DefineID) or {}
    if CustomData.DataID then return end

    -- 从 self.DataID 写入（StartDrop 产出的情况）
    CustomData.DataID = self.DataID
    UGCItemSystemV2.SaveItemCustomData(DefineID, CustomData)
    print(string.format("[OnItemPickup] ItemID=%d DataID=%s", DefineID.TypeSpecificID, tostring(self.DataID)))
end

---------------------------------------------------------------------------
-- 动效相关
---------------------------------------------------------------------------

function CustomWrapper:ReceiveBeginPlay()
    if self:HasAuthority() then return end
    if self.EnableTween then
        self:InitTween()
    end
    self:SwitchTweenType(self:GetDefineID().TypeSpecificID)
end

--- DataID 网络同步回调（客户端）
function CustomWrapper:OnRep_DataID()
    -- 仅客户端触发，DataID 同步完成后可用于客户端显示
end

function CustomWrapper:SwitchTweenType(ItemID)
    if UGCItemSystemV2.ItemHasTagV2(ItemID,"WrapperTween.UpAndDown") then
        self:StartTween_UpAndDown()
    end
    if UGCItemSystemV2.ItemHasTagV2(ItemID,"WrapperTween.Rotator") then
        self:StartTween_Rotator()
    end
end

function CustomWrapper:InitTween()
    local SubSystemClass = UE.LoadClass("/Script/UnrealTween.TweenSubsystem")
    self.SubSystem = SubsystemBlueprintLibrary.GetWorldSubsystem(self, SubSystemClass)
    CustomWrapper.SuperClass.ReceiveBeginPlay(self)
end

function CustomWrapper:StartTween_Rotator()
    if self:HasAuthority() then return end
    if not self.SubSystem then return end
    self:StopTween()
    local UpdateDelegate = UGCDelegateUtility.CreateUEDelegate(self)
    UpdateDelegate:Bind(function(Obj, Value)
        self.StaticMeshComp:K2_SetRelativeRotation(Value,false,nil,false)
    end, self)
    self.TweenHandler = self.SubSystem:TweenRotatorValue(Rotator.New(0,0,0),self.Rotator, self.Duration, self.TweenType, UpdateDelegate,true)
    local CompleteDelegate = UGCDelegateUtility.CreateUEDelegate(self)
    CompleteDelegate:Bind(function(Obj, Value)
        self.TweenHandler = nil
    end, self)
    self.SubSystem:BindCompleteDelegate(self.TweenHandler, CompleteDelegate)
    self.SubSystem:ConfigureTween(self.TweenHandler, 0, -1, true, 0)
end

function CustomWrapper:StartTween_UpAndDown()
    if self:HasAuthority() then return end
    if not self.SubSystem then return end
    self:StopTween()
    local UpdateDelegate = UGCDelegateUtility.CreateUEDelegate(self)
    UpdateDelegate:Bind(function(Obj, Value)
        self.StaticMeshComp:K2_SetRelativeLocation(Value)
    end, self)
    self.TweenHandler = self.SubSystem:TweenVectorValue(self.StartLocation, self.EndLocation, self.Duration, self.TweenType, UpdateDelegate)
    local CompleteDelegate = UGCDelegateUtility.CreateUEDelegate(self)
    CompleteDelegate:Bind(function(Obj, Value)
        self.TweenHandler = nil
    end, self)
    self.SubSystem:BindCompleteDelegate(self.TweenHandler, CompleteDelegate)
    self.SubSystem:ConfigureTween(self.TweenHandler, 0, -1, true, 0)
end

function CustomWrapper:StopTween(ClickParam)
    if not self.TweenHandler or not self.SubSystem then return end
    self.SubSystem:StopTween(self.TweenHandler)
    self.TweenHandler = nil
    self.Sphere:K2_SetRelativeLocation(self.StartLocation)
end

--- DataID 需要网络同步，让客户端也能获取
function CustomWrapper:GetReplicatedProperties()
    return "DataID"
end

return CustomWrapper
