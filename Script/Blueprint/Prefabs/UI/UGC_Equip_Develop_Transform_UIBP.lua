---@class UGC_Equip_Develop_Transform_UIBP_C:UAEUserWidget
---@field Common_Currency Common_Currency_UIBP_C
---@field Develop_Icon_0 UGC_Equip_Develop_Icon_Item_UIBP_C
---@field Develop_Icon_1 UGC_Equip_Materials_Item_UIBP_C
---@field Develop_Icon_2 UGC_Equip_Materials_Item_UIBP_C
---@field Develop_Icon_3 UGC_Equip_Materials_Item_UIBP_C
---@field Develop_Icon_4 UGC_Equip_Materials_Item_UIBP_C
---@field Develop_Icon_5 UGC_Equip_Materials_Item_UIBP_C
---@field Develop_Icon_6 UGC_Equip_Materials_Item_UIBP_C
---@field Image_arrow UImage
---@field NewButton_Choice UNewButton
---@field NewButton_Start UNewButton
---@field ReuseList2_Grade ReuseList2_C
---@field TextBlock_6 UTextBlock
---@field TextBlock_7 UTextBlock
---@field TextBlock_8 UTextBlock
---@field TextBlock_9 UTextBlock
---@field TextBlock_Choose UTextBlock
---@field TextBlock_Grade UTextBlock
--Edit Below--
---装备转化面板（占位）：由 UGC_Equip_Main_UIBP 二级页签切入，玩法逻辑后续再接。
local UGC_Equip_Develop_Transform_UIBP = { bInitDoOnce = false }

function UGC_Equip_Develop_Transform_UIBP:Construct()
    self:LuaInit()
end

function UGC_Equip_Develop_Transform_UIBP:LuaInit()
    if self.bInitDoOnce then
        return
    end
    self.bInitDoOnce = true
    print('[EquipTransform] LuaInit')
    if self.TextBlock_Choose then
        self.TextBlock_Choose:SetText('转化')
    end
    if self.TextBlock_Grade then
        self.TextBlock_Grade:SetText('转化')
    end
end

function UGC_Equip_Develop_Transform_UIBP:InitData(InParams)
    self.InParams = InParams or {}
    print('[EquipTransform] InitData')
end

function UGC_Equip_Develop_Transform_UIBP:Destruct()
    self.InParams = nil
    self.bInitDoOnce = false
end

return UGC_Equip_Develop_Transform_UIBP
