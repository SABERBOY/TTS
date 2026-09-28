---@class Game_Equip_Develop_Transform_UIBP_C:UAEUserWidget
---@field Common_Currency1 Common_Currency_UIBP_C
---@field Common_Currency2 Common_Currency_UIBP_C
---@field Develop_Icon_0 UGC_Equip_Develop_Icon_Item_UIBP_C
---@field Develop_Icon_01 UGC_Equip_Develop_Icon_Item_UIBP_C
---@field Develop_Icon_02 UGC_Equip_Develop_Icon_Item_UIBP_C
---@field Develop_Icon_03 UGC_Equip_Develop_Icon_Item_UIBP_C
---@field Develop_Icon_04 UGC_Equip_Develop_Icon_Item_UIBP_C
---@field Develop_Icon_05 UGC_Equip_Develop_Icon_Item_UIBP_C
---@field Develop_Icon_06 UGC_Equip_Develop_Icon_Item_UIBP_C
---@field Image_AdvanceLeftBg UImage
---@field Image_AdvanceRightBg UImage
---@field Image_arrow UImage
---@field NewButton_Choice UNewButton
---@field NewButton_Start UNewButton
---@field ReuseList2_Grade ReuseList2_C
---@field TextBlock_3 UTextBlock
---@field TextBlock_6 UTextBlock
---@field TextBlock_7 UTextBlock
---@field TextBlock_8 UTextBlock
---@field TextBlock_9 UTextBlock
---@field TextBlock_Choose UTextBlock
---@field TextBlock_Grade UTextBlock
---@field TextBlock_Status UTextBlock
---@field TextBlock_TargetName UTextBlock
--Edit Below--
local C=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceConfig')
local Client=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceClient')
local Model=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceViewModel')
local UI=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceUIRender')
local Panel={}
function Panel:Construct()
    -- NewButton delegates are not ready during Construct. Bind only in InitData.
    self.Active=false
end
function Panel:InitData(params)
    self.InParams=params or {}; self.Model=self.Model or Model.New(); self.Active=true
    if not self.Model.CommitRequest then self.Model.Snapshot=nil end
    self.Bindings=self.Bindings or {}; self.RowData=self.RowData or {}
    self.TextBlock_Grade.Slot:SetSize({SizeRule=1,Value=1})
    self.TextBlock_Grade:SetJustification(1)
    self.TextBlock_3:SetJustification(1)
    self.Common_Currency1:GetParent().Slot:SetAutoSize(true)
    if not self.Bound then
        self:Bind(self.NewButton_Start.OnClicked,self.OnStart)
        self:Bind(self.NewButton_Choice.OnClicked,self.OnMode)
        self:Bind(self.ReuseList2_Grade.OnUpdateItem,self.OnUpdateItem)
        for i=0,6 do
            local widget=i==0 and self.Develop_Icon_0 or self['Develop_Icon_0'..i]
            local drag=widget and widget.Common_DragDrop_Item
            if drag then
                UI.Visible(drag,true,true)
                local index=i
                self:Bind(drag.OnDragClicked,function(owner) owner:OnMaterialSlot(index) end)
            end
        end
        self.Bound=true
    end
    local weak=WeakObjectPtr(self)
    Client.Subscribe(self,function(result)
        if weak:IsValid() then weak:Get():OnResult(result) end
    end)
    if not self.Timer then
        local pc=UGCGameSystem.GetLocalPlayerController()
        self.TimerOwner=pc
        self.Timer=UGCGameSystem.SetTimer(pc,function()
            if weak:IsValid() then weak:Get():Poll() end
        end,1,true)
    end
    self:RequestSnapshot(); self:Render()
end
function Panel:Bind(delegate,fn)
    delegate:Add(fn,self); self.Bindings[#self.Bindings+1]={Delegate=delegate,Fn=fn}
end
function Panel:Deactivate()
    self.Active=false; Client.Unsubscribe(self)
    if self.Timer then UGCGameSystem.ClearTimer(self.TimerOwner,self.Timer); self.Timer=nil end
    self.SnapshotRequest=nil
    if self.Model and not self.Model.CommitRequest then self.Model:Invalidate() end
end
function Panel:Destruct()
    self:Deactivate()
    for _,binding in ipairs(self.Bindings or {}) do binding.Delegate:Remove(binding.Fn,self) end
    self.Bindings={}; self.Bound=false; self.RowData={}
end
function Panel:RequestSnapshot()
    if not self.Active or self.SnapshotRequest then return end
    self.SnapshotRequest=Client.NewRequestID(); self.SnapshotAt=os.time()
    Client.Snapshot(self.SnapshotRequest)
end
function Panel:Poll()
    if not self.Active then return end
    local now=os.time(); local m=self.Model
    if self.SnapshotRequest and now-self.SnapshotAt>8 then
        self.SnapshotRequest=nil; m:Invalidate(); m.Code='ReadFailed'; self:Render()
    end
    if m.CommitRequest then
        if now-m.CommitAt>8 then m.Code='Timeout'; self:Render() end
        return
    end
    if m.PreviewRequest and now-(self.PreviewAt or now)>8 then
        m:Invalidate(); m.Code='ReadFailed'; self:Render()
    end
    if m.Preview and not m:CanSubmit(now) then self:RequestPreview() end
    self:RequestSnapshot()
end
function Panel:RequestPreview()
    local m=self.Model; local request=Client.NewRequestID()
    if m:BeginPreview(request) then
        self.PreviewAt=os.time()
        Client.PreviewForUI(m.TargetKey,m.Materials,request)
    end
    self:Render()
end
function Panel:OnResult(result)
    if not self.Active then return end
    local m=self.Model
    if result.Kind=='Snapshot' and self.SnapshotRequest and result.ClientRequestID==self.SnapshotRequest then
        self.SnapshotRequest=nil
        local changed=m:ApplySnapshot(result)
        if changed or (not m.Preview and not m.PreviewRequest and not m.CommitRequest) then
            if result.OK then self:RequestPreview() else self:Render() end
        end
    elseif result.Kind=='Preview' and m:AcceptPreview(result,os.time()) then
        self:Render()
    elseif result.Kind=='Commit' and m:AcceptCommit(result) then
        self.SnapshotRequest=nil; self:RequestSnapshot(); self:Render()
    end
end
function Panel:OnMode()
    local m=self.Model
    if m.CommitRequest then return end
    if m.TargetKey then m.MaterialMode=not m.MaterialMode end
    self:Render()
end
function Panel:OnMaterialSlot(index)
    local m=self.Model
    if m.CommitRequest then return end
    if index==0 then m.MaterialMode=false
    elseif m.TargetKey then
        if m.Materials[index] then m:ToggleMaterial(m.Materials[index]); self:RequestPreview() end
        m.MaterialMode=true
    end
    self:Render()
end
function Panel:SelectItem(key)
    local m=self.Model
    local changed
    if m.MaterialMode then changed=m:ToggleMaterial(key) else changed=m:SelectTarget(key) end
    if changed then self:RequestPreview() end
end
function Panel:OnStart()
    local m=self.Model; local now=os.time()
    if m.CommitRequest then
        if now-m.CommitAt>8 then
            m.CommitAt=now; m.Code='Submitting'
            Client.CommitForUI(m.CommitToken,m.CommitRequest,true)
        end
    elseif m:CanSubmit(now) then
        local token=m:StartCommit(Client.NewRequestID(),now)
        if token then Client.CommitForUI(token,m.CommitRequest,true) end
    else self:RequestPreview() end
    self:Render()
end
function Panel:OnUpdateItem(widget,index)
    local item=self.DisplayItems and self.DisplayItems[index+1]
    if not item then return end
    local m=self.Model; local selected=item.Key==m.TargetKey
    for _,key in ipairs(m.Materials) do if key==item.Key then selected=true end end
    local slot=item.SlotIdx; local names={'头盔','胸甲','饰品','手套','腰带','鞋'}
    widget:ApplyAdvanceData({Item=item,Level=m.Snapshot and m.Snapshot.Levels[slot] or 0,
        Part=names[slot] or '装备',Selected=selected,IsTarget=item.Key==m.TargetKey,MaterialMode=m.MaterialMode,
        OnClick=function(key) self:SelectItem(key) end})
end
function Panel:Render()
    local m=self.Model; if not m then return end
    local target,cfg,rank,rule=m:Definition(); local s=m.Snapshot or {Levels={},GoldHave=0,DiamondHave=0}
    local level=cfg and s.Levels[cfg.SlotIdx] or 0
    UI.Icon(self.Develop_Icon_0,target,level,true)
    for i=1,6 do
        local w=self['Develop_Icon_0'..i]; local required=rule and rule.Materials or 0
        UI.Visible(w,i<=required,true)
        if i<=required then UI.Icon(w,m.ByKey[m.Materials[i]],level,m.Materials[i]~=nil) end
    end
    UI.Currency(self.Common_Currency1,C.GoldItemID,s.GoldHave,rule and rule.Gold)
    UI.Currency(self.Common_Currency2,C.DiamondItemID,s.DiamondHave,rule and rule.Diamond)
    local nextRank=cfg and cfg.NextItemID and C.Ranks[cfg.RankOrder+1]
    UI.Text(self.TextBlock_Grade,rank and (rank.Name..' → '..(nextRank and nextRank.Name or '未配置')) or '选择装备')
    local title=target and UI.Name(target) or '装备升阶'
    if m.NoticeOK and m.PendingNewKey==nil and target then title=title..' · 升阶完成' end
    UI.Text(self.TextBlock_TargetName,title)
    local detail=rank and string.format('槽位强化 %d / %d   材料 %d / %d',level or 0,rank.Cap,#m.Materials,rule and rule.Materials or 0) or ''
    local status=Model.Message(m.Code)
    if m.MaterialMode and (m.Code=='Ready' or m.Code=='MaterialCountMismatch') then status='选择材料：再次点击可取消' end
    if m.Notice and (not target or not m.NoticeOK) then status=m.Notice end
    UI.Text(self.TextBlock_Status,detail..'\n'..status)
    UI.Text(self.TextBlock_Choose,m.MaterialMode and '返回装备' or (target and '选择材料' or '全部装备'))
    local can=m:CanSubmit(os.time()) or (m.CommitRequest and os.time()-m.CommitAt>8)
    self.NewButton_Start:SetIsEnabled(can==true)
    self.NewButton_Start:SetRenderOpacity(can and 1 or 0.45)
    UI.Text(self.TextBlock_3,m.Code=='Timeout' and '重试原请求' or
        (m.CommitRequest and '升阶中…' or (m.ConfirmArmed and '确认升阶' or '升阶')))
    self.NewButton_Choice:SetIsEnabled(m.TargetKey~=nil and not m.CommitRequest)
    self.DisplayItems=m:VisibleItems()
    local signature=tostring(m.MaterialMode)..':'..tostring(m.TargetKey)..':'..table.concat(m.Materials,',')..':'..tostring(s.Revision)
    if signature~=self.ListSignature then
        self.ListSignature=signature
        self.ReuseList2_Grade:Reload(#self.DisplayItems)
        self.ReuseList2_Grade:Refresh()
    end
    if m.Snapshot and #self.DisplayItems==0 and not target then UI.Text(self.TextBlock_Status,'背包中没有装备，可获取装备后再来升阶') end
end
function Panel:Refresh() self:RequestSnapshot() end
return Panel
