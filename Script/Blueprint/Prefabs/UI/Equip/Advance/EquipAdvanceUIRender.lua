-- Render the existing template widgets; never changes their shared blueprints.
local C=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceConfig')
local U={}; local imageRequests=setmetatable({},{__mode='k'})
function U.Visible(w,show,hit)
    if w then w:SetVisibility(show and (hit and ESlateVisibility.Visible or ESlateVisibility.SelfHitTestInvisible) or ESlateVisibility.Collapsed) end
end
function U.Text(w,text) if w then w:SetText(text or '') end end
function U.Image(w,path,match)
    if not w then return end
    local stamp=(imageRequests[w] or 0)+1; imageRequests[w]=stamp
    U.Visible(w,false)
    if not path then return end
    if type(path)~='string' then path=UGCObjectUtility.GetPathBySoftObjectPath(path) end
    if not path or path=='' or path=='None' then return end
    local weak=WeakObjectPtr(w)
    UGCObjectUtility.AsyncLoadObject(path,function(texture)
        if not weak:IsValid() then return end
        local widget=weak:Get()
        if texture and imageRequests[widget]==stamp then
            widget:SetBrushFromTexture(texture,match==true); U.Visible(widget,true)
        end
    end)
end
function U.Icon(w,item,level,selected)
    if not w then return end
    for _,field in ipairs({'TextBlock_Effect','AffixsBar_Item','CanvasPanel_New','CanvasPanel_Unusable','TextBlock_Using'}) do
        if CheckObjectContainsField(w,field,true) then U.Visible(w[field],false) end
    end
    local id=item and item.ItemID
    if w.WidgetSwitcher_Content then w.WidgetSwitcher_Content:SetActiveWidgetIndex(0) end
    U.Visible(w.CanvasPanel_NotWornState,true)
    -- The shared develop icon places its image under an initially collapsed canvas.
    if w.CanvasPanel_NotWornState then U.Visible(w.CanvasPanel_NotWornState:GetParent(),id~=nil) end
    U.Text(w.TextBlock_Level,id and tostring(level or 0) or '—')
    U.Visible(w.CanvasPanel_Select,selected==true)
    U.Visible(w.Image_Select,selected==true)
    local quality=id and UGCItemSystemV2.GetItemQualityV2(id) or 0
    U.Image(w.Image_DefaultIcon,id and UGCItemSystemV2.GetItemIconTextureV2(id),true)
    U.Image(w.Image_QualityBarBg,UGCItemSystemV2.GetQualityTexturePath(quality or 0))
    U.Image(w.Image_QualityBar,id and UGCItemSystemV2.GetQualityBarTexturePath(quality or 0))
    w:SetRenderOpacity(id and 1 or 0.35)
end
function U.Name(item)
    if not item then return '' end
    return UGCItemSystemV2.GetItemNameV2(item.ItemID) or tostring(item.ItemID)
end
function U.Rank(item)
    local cfg=item and C.Items[item.ItemID]; local rank=cfg and C.Ranks[cfg.RankOrder]
    return rank and rank.Name or '未接入升阶'
end
function U.Currency(w,id,have,cost)
    U.Visible(w,cost~=nil and cost>0)
    if not w or not cost or cost<=0 then return end
    U.Visible(w.NewButton_Currency_Increase,false)
    U.Visible(w.NewButton_Currency_Tips,false)
    U.Text(w.TextBlock_Currency_Amount,tostring(have or 0)..' / '..tostring(cost))
    w.TextBlock_Currency_Amount:SetColorAndOpacity({SpecifiedColor=have>=cost and
        {R=0.95,G=0.85,B=0.55,A=1} or {R=1,G=0.25,B=0.2,A=1},ColorUseRule=0})
    U.Image(w.Image_Currency_Icon,UGCItemSystemV2.GetItemIconTextureV2(id))
end
return U
