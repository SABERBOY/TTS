---@class Buff_GiftOfLife_C:PersistEffectBuff
---@field EnableHealth float
---@field RestoreMaxHealthPercentage float
--Edit Below--
local Buff_GiftOfLife = {
    OwnerActor = nil
}
 


-- function Buff_GiftOfLife:CanApply_BP(OwnerActor)
--     -- AttrModifyFunctionLibrary.GetGameAttributeValue()
-- --    AttrModifyFunctionLibrary.GetAttributeValue(OwnerActor,'Health')
-- --    if AttrModifyFunctionLibrary.GetAttributeValuePercentage(OwnerActor,'Health')
--     return true
-- end 





-- buff启动条件
--[[
function Buff_GiftOfLife:CanApply_BP(OwnerActor)
-- return true
end
--]]

-- buff开始

function Buff_GiftOfLife:OnApply_BP(OwnerActor)
    self.OwnerActor = OwnerActor
end


-- buff结束
--[[
function Buff_GiftOfLife:OnUnApply_BP(OwnerActor, Reason)

end
--]]

-- buff合并条件，A为当前身上已有buff，B为外来buff，当要挂载外来buff时会判断A.CanMerge(B)
--[[
function Buff_GiftOfLife:CanMerge_BP(PersistEffect)
-- return true
end
--]]

-- buff合并，A为当前身上已有buff，B为外来buff，调用A.OnMerge(B)
--[[
function Buff_GiftOfLife:OnMerge_BP(PersistEffect)

end
--]]

-- 开启Tick需要SetTickEnable(true)，或buff为间隔触发类型会自动开启
--[[
function Buff_GiftOfLife:Tick_BP(OwnerActor, DeltaTime)

end
--]]

--[[
function Buff_GiftOfLife:OnInterrupted_BP(OwnerActor)

end
--]]

-- buff总持续时长变化，如修改ApplyTime、修改StackNum
--[[
function Buff_GiftOfLife:OnTotalDurationChange_BP(PreTime, CurTime)

end
--]]

-- buff堆叠层数变化
--[[
function Buff_GiftOfLife:OnStackChange_BP(PreNum, CurNum)

end
--]]

-- buff触发前条件判断

function Buff_GiftOfLife:CanTrigger_BP()
    local HealthMax = UGCAttributeSystem.GetGameAttributeValue(self.OwnerActor, 'HealthMax')
    local Health = UGCAttributeSystem.GetGameAttributeValue(self.OwnerActor, 'Health')
    if HealthMax == 0 then
        print("Buff_GiftOfLife:CanTrigger_BP() HealthMax == 0!")
    end
	return Health/HealthMax  < self.EnableHealth
end


-- buff触发效果
function Buff_GiftOfLife:OnTrigger_BP(Delta)
    print("Buff_GiftOfLife Log: OnTrigger_BP(Delta)")
	--[[
	  if UGCGameSystem.IsServer() then
        local AddValue = UGCAttributeSystem.GetGameAttributeValue(self.OwnerActor, 'HealthMax')* self.RestoreMaxHealthPercentage
        UGCAttributeSystem.AddGameAttributeValue(self.OwnerActor, 'Health', AddValue)
    end
	]]
  
end

return Buff_GiftOfLife