-- UI selection state only. The server remains authoritative for every transaction.
local C=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceConfig')
local M={}; M.__index=M
M.Messages={
    SelectTarget='请从右侧选择要升阶的装备',Loading='正在读取背包…',ReadFailed='背包尚未就绪，请稍候重试',
    UnsupportedItem='该装备尚未配置升阶路线',MaxRank='已达到最高阶位',NextItemMissing='下一阶段尚未配置',
    NextAssetUnavailable='下一阶段装备资产不可用',LevelTooLow='对应槽位强化等级不足',
    NotEnoughGold='金币不足',NotEnoughDiamond='钻石不足',MaterialCountMismatch='点击材料位，选择相同装备',
    MaterialProtected='材料正在穿戴、被保护或占用',TargetBusy='目标正在被其他操作占用',
    InvalidTargetState='目标实例状态不支持升阶',InvalidCustomData='装备数据异常，无法升阶',
    CustomDataTooLarge='装备自定义数据超出限制',CannotRemove='装备暂时无法消耗',
    NextCannotEquip='下一阶段无法穿戴到原槽位',TargetNotOwned='目标装备已变化，请重新选择',
    MaterialNotOwned='材料装备已变化，请重新选择',MaterialItemMismatch='材料必须与目标的物品ID相同',
    DuplicateInstance='目标和材料必须是不同实例',ManualMaterialsRequired='请手动选择材料装备',
    Checking='正在校验升阶条件…',Ready='条件满足，可以升阶',Submitting='正在升阶，请稍候…',
    Confirm='再次点击确认消耗目标与材料',Advanced='升阶成功！已选中新的装备',
    PreviewExpired='预览已过期，正在重新校验',PreviewMissing='请重新预览',PreviewStale='装备状态已变化，请重新预览',
    Busy='当前操作处理中',ServerError='读取失败，请稍候重试',TransactionFailed='升阶未成功，资源已补偿，请重新选择',
    RecoveryRequired='资源恢复待处理，已暂停升阶，请联系管理人员',Timeout='等待服务端结果，点击按钮重试原请求',
}
function M.Message(code) return M.Messages[code] or ('暂时无法升阶：'..tostring(code)) end
function M.New()
    return setmetatable({Items={},ByKey={},Materials={},Code='Loading'},M)
end
function M:Invalidate()
    self.Preview=nil; self.PreviewRequest=nil; self.ConfirmArmed=false
end
function M:Definition()
    local target=self.ByKey[self.TargetKey]
    local cfg=target and C.Items[target.ItemID]
    return target,cfg,cfg and C.Ranks[cfg.RankOrder],cfg and C.Rules[cfg.RankOrder]
end
function M:ApplySnapshot(snapshot)
    if not snapshot.OK then self:Invalidate(); self.Code=snapshot.Code; return true end
    local changed=not self.Snapshot or self.Snapshot.Revision~=snapshot.Revision
    self.Snapshot=snapshot; self.Items=snapshot.Items or {}; self.ByKey={}
    for _,x in ipairs(self.Items) do self.ByKey[x.Key]=x end
    table.sort(self.Items,function(a,b)
        if a.RankOrder~=b.RankOrder then return a.RankOrder<b.RankOrder end
        if a.ItemID~=b.ItemID then return a.ItemID<b.ItemID end
        return a.Key<b.Key
    end)
    if self.PendingNewKey and self.ByKey[self.PendingNewKey] then
        self.TargetKey=self.PendingNewKey; self.PendingNewKey=nil; self.Materials={}; self.Manual=false
        changed=true
    end
    if not self.ByKey[self.TargetKey] then self.TargetKey=nil; self.Materials={}; changed=true end
    if changed and not self.CommitRequest then
        self:Invalidate()
        local keep={}; local t=self.ByKey[self.TargetKey]
        for _,key in ipairs(self.Materials) do
            local x=self.ByKey[key]
            if t and x and x.ItemID==t.ItemID and x.AllowedMaterial and key~=t.Key then keep[#keep+1]=key end
        end
        self.Materials=keep
        if not self.Manual then self:AutoSelect() end
    end
    return changed
end
function M:SelectTarget(key)
    if self.CommitRequest or not self.ByKey[key] then return false end
    self.TargetKey=key; self.Materials={}; self.Manual=false; self.MaterialMode=false; self.Notice=nil; self.NoticeOK=nil
    self:Invalidate(); self:AutoSelect(); return true
end
function M:AutoSelect()
    local target,cfg,rank,rule=self:Definition()
    self.Materials={}
    if not target or not rule or rank.Major>=4 then return end
    for _,x in ipairs(self.Items) do
        if x.Key~=target.Key and x.ItemID==target.ItemID and x.SafeAuto and #self.Materials<rule.Materials then
            self.Materials[#self.Materials+1]=x.Key
        end
    end
end
function M:ToggleMaterial(key)
    if self.CommitRequest then return false end
    local target,cfg,rank,rule=self:Definition(); local x=self.ByKey[key]
    if not target or not rule or not x or key==target.Key or x.ItemID~=target.ItemID or not x.AllowedMaterial then return false end
    for i,k in ipairs(self.Materials) do
        if k==key then table.remove(self.Materials,i); self.Manual=true; self:Invalidate(); return true end
    end
    if #self.Materials>=rule.Materials then return false end
    self.Materials[#self.Materials+1]=key; self.Manual=true; self:Invalidate(); return true
end
function M:LocalCode()
    if not self.Snapshot then return 'Loading' end
    if self.Snapshot.Blocked then return 'RecoveryRequired' end
    local target,cfg,rank,rule=self:Definition()
    if not target then return 'SelectTarget' end
    if not cfg then return 'UnsupportedItem' end
    if not rule then return 'MaxRank' end
    if not cfg.NextItemID then return 'NextItemMissing' end
    if (self.Snapshot.Levels[cfg.SlotIdx] or 0)<rank.Cap then return 'LevelTooLow' end
    if self.Snapshot.GoldHave<rule.Gold then return 'NotEnoughGold' end
    if self.Snapshot.DiamondHave<rule.Diamond then return 'NotEnoughDiamond' end
    if #self.Materials~=rule.Materials then return 'MaterialCountMismatch' end
    return 'Ready'
end
function M:BeginPreview(request)
    if self.CommitRequest then return false end
    self:Invalidate(); self.Code=self:LocalCode()
    if self.Code~='Ready' then return false end
    self.PreviewRequest=request; self.Code='Checking'; return true
end
function M:AcceptPreview(result,now)
    if self.CommitRequest or not self.PreviewRequest or result.ClientRequestID~=self.PreviewRequest then return false end
    self.PreviewRequest=nil; self.Preview=result.OK and result or nil; self.Code=result.Code
    self.PreviewAt=now; self.ConfirmArmed=false
    return true
end
function M:CanSubmit(now)
    return not self.CommitRequest and self.Preview~=nil and self.Preview.OK==true
        and self:LocalCode()=='Ready' and now-(self.PreviewAt or 0)<110
end
function M:StartCommit(request,now)
    if not self:CanSubmit(now) then return nil end
    if (self.Preview.RequiresConfirmation or self.Manual) and not self.ConfirmArmed then
        self.ConfirmArmed=true; self.Code='Confirm'; return nil
    end
    self.CommitRequest=request; self.CommitToken=self.Preview.Token; self.CommitAt=now; self.Code='Submitting'
    return self.CommitToken
end
function M:AcceptCommit(result)
    if not self.CommitRequest or result.ClientRequestID~=self.CommitRequest then return false end
    self.CommitRequest=nil; self.CommitToken=nil; self:Invalidate(); self.Code=result.Code
    self.Notice=M.Message(result.Code); self.NoticeOK=result.OK==true; self.Materials={}; self.Manual=false; self.MaterialMode=false
    if result.OK then self.PendingNewKey=result.NewKey; self.TargetKey=nil
    elseif result.RestoredKeys then self.TargetKey=result.RestoredKeys[self.TargetKey] or self.TargetKey end
    if result.Code=='RecoveryRequired' and self.Snapshot then self.Snapshot.Blocked=true end
    return true
end
function M:VisibleItems()
    if not self.MaterialMode then return self.Items end
    local target=self.ByKey[self.TargetKey]; local out={}
    for _,x in ipairs(self.Items) do
        if target and x.ItemID==target.ItemID and x.Key~=target.Key then out[#out+1]=x end
    end
    return out
end
return M
