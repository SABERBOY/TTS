---@class Game_Equip_Advance_Row_UIBP_C:UAEUserWidget
-- Advancement-only reusable row. Each refresh replaces the instance click payload.
local UI=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceUIRender')
local Row={}
function Row:ApplyAdvanceData(data)
    self.AdvanceData=data
    if not self.ClickBound then
        self.NewButton_Select.OnClicked:Add(self.OnSelect,self); self.ClickBound=true
    end
    local item=data.Item
    UI.Text(self.TextBlock_IconName,UI.Name(item))
    UI.Text(self.TextBlock_Part,'部位：'..data.Part..'  ·  '..UI.Rank(item))
    local state=item.EquippedSlot~='' and '穿戴中' or (item.Locked and '已锁定' or '背包')
    UI.Text(self.TextBlock_Profession,state..(item.HasInvestment and ' · 含历史投入' or ''))
    UI.Text(self.TextBlock_Num,'Lv.'..data.Level)
    UI.Text(self.TextBlock_Value,data.Selected and (data.IsTarget and '✓ 当前目标' or '✓ 已选为材料') or
        (data.MaterialMode and (item.AllowedMaterial and '点击选为材料' or '不可消耗：保护或状态限制') or '点击查看升阶'))
    UI.Icon(self.Equip_Icon_Item,item,data.Level,data.Selected)
    -- Row button owns input, so the nested drag widget must not consume taps.
    UI.Visible(self.Equip_Icon_Item.Common_DragDrop_Item,false)
    self.NewButton_Select:SetIsEnabled(not data.MaterialMode or item.AllowedMaterial==true)
    self:SetRenderOpacity(data.MaterialMode and not item.AllowedMaterial and 0.4 or 1)
end
function Row:OnSelect()
    local data=self.AdvanceData
    if data and data.OnClick then data.OnClick(data.Item.Key) end
end
function Row:Destruct()
    if self.ClickBound then self.NewButton_Select.OnClicked:Remove(self.OnSelect,self) end
    self.ClickBound=false; self.AdvanceData=nil
end
return Row
