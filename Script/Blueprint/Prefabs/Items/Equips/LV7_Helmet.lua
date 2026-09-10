---@class LV7_Helmet_C:Template_Equipment_Helmet_C
--Edit Below--
local LV7_Helmet = {} 

--[[V2背包事件]]--
--[[
--- func 能否创建物品Handle(服务端生效)
---@return bool @是否允许创建物品Handle, 若不允许，物品也将创建失败
-- function LV7_Helmet:CanCreateItemHandleV2()
--     return LV7_Helmet.SuperClass.CanCreateItemHandleV2(self);
-- end

--- func 当创建物品Handle后回调，可重载并自定义(服务端生效)
--  function LV7_Helmet:OnCreateItemHandleV2()
--     LV7_Helmet.SuperClass.OnCreateItemHandleV2(self);
--  end

--- func 能否销毁物品Handle，可重载并自定义(服务端生效)
---@return bool 是否允许销毁Handle, 若不允许，物品移除或丢弃也可能失败
-- function LV7_Helmet:CanDestoryItemHandleV2()
--     return LV7_Helmet.SuperClass.CanDestoryItemHandleV2(self);
-- end

--- func 销毁物品Handle前回调，可重载并自定义(服务端生效)
-- function LV7_Helmet:OnDestoryItemHandleV2()
--     LV7_Helmet.SuperClass.OnDestoryItemHandleV2(self);
-- end

--- func 能否更新此物品实例，可重载并自定义(服务端生效)
---@param NewItemCount number 新物品数量
---@param OldItemCount number 旧物品数量
---@return 是否允许物品数量更新，若不允许，物品添加或移除操作可能失败
-- function LV7_Helmet:CanUpdateItemCountV2(NewItemCount, OldItemCount)
--     return LV7_Helmet.SuperClass.CanUpdateItemCountV2(self, NewItemCount, OldItemCount);
-- end

--- func 物品数量更新后回调，可重载并自定义(服务端生效)
---@param NewItemCount number 新物品数量
---@param OldItemCount number 旧物品数量
-- function LV7_Helmet:OnUpdateItemCountV2(NewItemCount, OldItemCount)
--     LV7_Helmet.SuperClass.OnUpdateItemCountV2(self, NewItemCount, OldItemCount);
-- end

--- func 能否使用物品，可重载并自定义(服务端生效)
---@return 物品是否能够被使用
-- function LV7_Helmet:CanUseV2()
--     return LV7_Helmet.SuperClass.CanUseV2(self);
-- end

--- func 当物品被使用回调，可重载并自定义(服务端生效)
-- function LV7_Helmet:OnUseV2()
--     LV7_Helmet.SuperClass.OnUseV2(self);
-- end

--- func 当物品被取消使用，与UseItem对应，用于清理状态，应当支持多次调用，不产生额外副作用，移除物品时自动调用，可重载并自定义(服务端生效)
-- function LV7_Helmet:OnDisuseV2()
--     LV7_Helmet.SuperClass.OnDisuseV2(self);
-- end

--- func 其他物品能否附加到此槽位(服务端生效)
---@param SlotName string 槽位名称
---@param ItemDefineID userdata 物品ID
-- function LV7_Helmet:CanAttachToSlot(SlotName, ItemDefineID)
--     return LV7_Helmet.SuperClass.CanAttachToSlot(self, SlotName, ItemDefineID);
-- end

--- func 当其他物品附加到此槽位(服务端生效)
---@param SlotName string 槽位名称
---@param ItemDefineID userdata 物品ID
-- function LV7_Helmet:OnAttachToSlot(SlotName, ItemDefineID)
--     LV7_Helmet.SuperClass.OnAttachToSlot(self, SlotName, ItemDefineID);
-- end

--- func 当物品从此槽位移除(服务端生效)
---@param SlotName string 槽位名称
---@param ItemDefineID userdata 物品ID
-- function LV7_Helmet:OnDetachBySlot(SlotName, ItemDefineID)
--     LV7_Helmet.SuperClass.OnDetachBySlot(self, SlotName, ItemDefineID);
-- end

--- func 能否Attach到Parent物品上, 如果Parent为空物品, 说明将被Attach到背包装备槽位(服务端生效)
---@param ParentDefineID userdata 父物品ID
---@param SlotName string 槽位名称
---@return bool 能否Attach
-- function LV7_Helmet:CanAttach(ParentDefineID, SlotName)
--     return LV7_Helmet.SuperClass.CanAttach(self, ParentDefineID, SlotName);
-- end

--- func 当Attach到Parent物品上, 如果Parent为空物品, 说明是被Attach到背包装备槽位(服务端生效)
---@param ParentDefineID userdata 父物品ID
---@param SlotName string 槽位名称
-- function LV7_Helmet:OnAttach(ParentDefineID, SlotName)
--     LV7_Helmet.SuperClass.OnAttach(self, ParentDefineID, SlotName);
-- end

--- func 当从Parent物品上解除Attach, 如果Parent为空物品, 说明是从背包装备槽位解除装备(服务端生效)
---@param ParentDefineID userdata 父物品ID
---@param SlotName string 槽位名称
-- function LV7_Helmet:OnDetach(ParentDefineID, SlotName)
--     LV7_Helmet.SuperClass.OnDetach(self, ParentDefineID, SlotName);
-- end

--- func 当物品被装备前，检查能否装备(服务端生效)
---@return bool 能否装备
-- function LV7_Helmet:CanEquip()
--     return LV7_Helmet.SuperClass.CanEquip(self);
-- end

--- func 当物品被装备回调(服务端生效)
-- function LV7_Helmet:OnEquip()
--     LV7_Helmet.SuperClass.OnEquip(self);
-- end

--- func 当物品被卸下回调(服务端生效)
-- function LV7_Helmet:OnUnEquip()
--     LV7_Helmet.SuperClass.OnUnEquip(self);
-- end

--- func 当物品在背包中被交换槽位前，检查能否交换(服务端生效)
---@param OldSlotName string 旧槽位名称
---@param NewSlotName string 新槽位名称
---@return 能否交换到新槽位
-- function LV7_Helmet:CanSwapEquipSlot(OldSlotName, NewSlotName)
--     return LV7_Helmet.SuperClass.CanSwapEquipSlot(self, OldSlotName, NewSlotName);
-- end

--- func 当物品被交换到新装备槽位后回调(服务端生效)
---@param OldSlotName string 旧槽位名称
---@param NewSlotName string 新槽位名称
-- function LV7_Helmet:OnSwapEquipSlot(OldSlotName, NewSlotName)
--     LV7_Helmet.SuperClass.OnSwapEquipSlot(self, OldSlotName, NewSlotName);
-- end
]]--

return LV7_Helmet