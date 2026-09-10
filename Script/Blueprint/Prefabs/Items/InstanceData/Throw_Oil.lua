---@class Throw_Oil_C:Template_Projectile_Burning_C
--Edit Below--
local Throw_Oil = {} 

--[[经典背包事件]]--
--[[
--- func 处理物品的拾取(服务端生效)
---@return bool @是否拾取该物品, 返回true才能拾取进背包
-- function Throw_Oil:HandlePickup(ItemContainer, PickupInfo, Reason)
--    return Throw_Oil.SuperClass.HandlePickup(self, ItemContainer, PickupInfo, Reason)
-- end

--- func 处理物品的丢弃(服务端生效)
---@return bool @是否丢弃该物品, 返回true才会丢弃
-- function Throw_Oil:HandleDrop(InCount, Reason)
--    return Throw_Oil.SuperClass.HandleDrop(self, InCount, Reason)
-- end

--- func 处理物品的取出(服务端生效)
---@return number @可取出物品数量
-- function Throw_Oil:HandleTake(TakeCount, TotalCount)
--    return Throw_Oil.SuperClass.HandleTake(self, TakeCount, TotalCount)
-- end

--- func 处理物品的使用(服务端生效)
---@return bool @使用是否成功
-- function Throw_Oil:HandleUse(Target, Reason)
--    return Throw_Oil.SuperClass.HandleUse(self, Target, Reason) 
-- end

--- func 处理物品的取消使用(服务端生效)
---@return bool @取消使用是否成功
-- function Throw_Oil:HandleDisuse(Reason)
--    return Throw_Oil.SuperClass.HandleDisuse(self, Reason) 
-- end

--- func 尝试取消使用物品，仅尝试(服务端生效)
---@return bool @物品能否取消使用
-- function Throw_Oil:HandleTryDisuse(Reason)
--    return Throw_Oil.SuperClass.HandleTryDisuse(self, Reason)
-- end

--- func 处理物品的有效性(服务端生效)
-- function Throw_Oil:HandleEnable(bEnable)
--    Throw_Oil.SuperClass.HandleEnable(self, bEnable)
-- end

--- func 处理物品的清除(服务端生效)
---@return bool @清除物品是否成功
-- function Throw_Oil:HanldeCleared()
--    return Throw_Oil.SuperClass.HanldeCleared(self)
-- end
]]--


return Throw_Oil