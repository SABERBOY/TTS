-- Engine adapter. Never writes item CDOs or keeps a second backpack save.
local C=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceConfig')
local D=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceData')
local S=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceSystem')
local G=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceGuard')
local R={Services=setmetatable({},{__mode='k'}),RecoveryByUID={}}
local A={}; A.__index=A
local RECOVERY_KEY='EquipAdvanceRecovery'
local function pawn(pc) return pc:GetPlayerCharacterSafety() end
local function uid(pc) return UGCGameSystem.GetUIDByPlayerController(pc) end
function A:IsServer() return UGCGameSystem.IsServer() end
function A:Now() return os.time() end
function A:Record(id)
    local key=G.Key(id)
    assert(key,'Equipment instance identity unavailable')
    local data=UGCItemSystemV2.LoadItemCustomData(id)
    if data==nil then data={} end
    assert(type(data)=='table','CustomData read failed')
    local attached,parent=UGCItemSystemV2.GetAttachTargetItem(id)
    -- A backpack equip slot is not a child attachment to another item.
    attached=attached==true and parent~=nil and (parent.TypeSpecificID or 0)~=0
    local children=UGCItemSystemV2.GetAttachChildrenItem(id)
    for _,child in pairs(children or {}) do
        if child and (child.TypeSpecificID or 0)~=0 then attached=true; break end
    end
    return {Key=key,DefineID=id,ItemID=id.TypeSpecificID,
        CustomDataSize=UGCItemSystemV2.GetItemCustomDataSize(id),
        CustomData=D.Copy(data),Count=UGCBackpackSystemV2.GetItemCountByDefineIDV2(self.PC,id),
        EquippedSlot=UGCBackpackSystemV2.GetItemEquippingSlot(self.PC,id) or '',Attached=attached}
end
function A:List()
    assert(UGCBackpackSystemV2.CheckInitPersistCompleted(self.PC),'Backpack not initialized')
    local out,seen={},{}
    local function push(id)
        if not id or not C.Items[id.TypeSpecificID] then return end
        local key=G.Key(id); assert(key,'Invalid equipment instance')
        if not seen[key] then seen[key]=true; out[#out+1]=self:Record(id) end
    end
    for _,id in pairs(UGCBackpackSystemV2.GetAllItemDefineIDsV2(self.PC)) do push(id) end
    for _,slot in pairs(UGCBackpackSystemV2.GetEquipSlots(self.PC)) do
        push(UGCBackpackSystemV2.GetEquippedItemBySlotName(self.PC,slot))
    end
    return out
end
function A:Balance(id) return UGCBackpackSystemV2.GetItemCountV2(self.PC,id) end
function A:SlotLevel(slot)
    local system=require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotSystem')
    return system.GetSlotLevel(nil,slot,pawn(self.PC))
end
function A:AssetReady(id)
    local ok,handle=pcall(UGCItemSystemV2.GetConfigItemHandle,id)
    return ok and handle~=nil and handle.ShouldPersist==true and handle.MaxNumberOfStacks==1
end
function A:Count(x) return UGCBackpackSystemV2.GetItemCountByDefineIDV2(self.PC,x.DefineID) end
function A:CanRemove(x) return UGCBackpackSystemV2.CanRemoveItemV2(self.PC,x.DefineID,1)==1 end
function A:CanEquip(id,slot) return UGCBackpackSystemV2.ItemCanEquipToSlot(self.PC,id,slot)==true end
function A:Begin() self.Allocated={}; return true end
function A:Finish()
    for _,x in ipairs(self.Allocated or {}) do G.Suppressed[x.Key]=nil end
    self.Allocated=nil
end
function A:Allocate(id,data)
    assert(self.Allocated,'Allocate requires transaction guard')
    local define=UGCItemSystemV2.GetItemDefineID(id)
    local key=G.Key(define); assert(key,'Allocate identity failed')
    local x={Key=key,DefineID=define,ItemID=id,CustomData=data,EquippedSlot='',Count=1}
    G.Suppressed[key]=true
    self.Allocated[#self.Allocated+1]=x
    return x
end
function A:Save(x)
    -- Keep native default instance data and copy the source custom fields over it.
    local data=UGCItemSystemV2.LoadItemCustomData(x.DefineID) or {}
    for k,v in pairs(x.CustomData) do data[k]=D.Copy(v) end
    if UGCItemSystemV2.SaveItemCustomData(x.DefineID,data)~=true then return false end
    local read=UGCItemSystemV2.LoadItemCustomData(x.DefineID)
    if type(read)~='table' then return false end
    for k,v in pairs(x.CustomData) do if D.Fingerprint(read[k])~=D.Fingerprint(v) then return false end end
    local size=UGCItemSystemV2.GetItemCustomDataSize(x.DefineID)
    return type(size)=='number' and size<=512
end
function A:Add(x) return UGCBackpackSystemV2.AddItemByDefineIDV2(self.PC,x.DefineID,1,false) end
function A:Remove(x) return UGCBackpackSystemV2.RemoveItemByDefineIDV2(self.PC,x.DefineID,1) end
function A:ChangeCurrency(id,delta)
    if delta>=0 then return UGCBackpackSystemV2.AddItemV2(self.PC,id,delta) end
    return UGCBackpackSystemV2.RemoveItemV2(self.PC,id,-delta)
end
function A:Unequip(x)
    if UGCBackpackSystemV2.UnEquipItemV2(self.PC,x.EquippedSlot)~=true then return false end
    return (UGCBackpackSystemV2.GetItemEquippingSlot(self.PC,x.DefineID) or '')==''
end
function A:Equip(x,slot)
    local current=UGCBackpackSystemV2.GetEquippedItemBySlotName(self.PC,slot)
    if G.Key(current)==x.Key then return true end
    if UGCBackpackSystemV2.EquipItemV2(self.PC,slot,x.DefineID)~=true then return false end
    return G.Key(UGCBackpackSystemV2.GetEquippedItemBySlotName(self.PC,slot))==x.Key
end
function A:Refresh()
    local p=pawn(self.PC)
    if p then require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotAttrApplier').RefreshAllSlots(p) end
end
function A:RecordRecovery(j)
    -- Only failed transaction participants are recorded, never the full backpack.
    local record={Version=1,RequestID=j.RequestID,Token=j.Token,Errors=j.Errors,
        Balances=j.Balances,Originals={},Created={},Restored={}}
    for _,field in ipairs({'Originals','Created','Restored'}) do
        for _,x in ipairs(j[field] or {}) do
            record[field][#record[field]+1]={Key=x.Key,ItemID=x.ItemID,CustomData=D.Copy(x.CustomData),EquippedSlot=x.EquippedSlot}
        end
    end
    local id=uid(self.PC)
    R.RecoveryByUID[tostring(id)]=record
    local archive=UGCPlayerStateSystem.GetPlayerArchiveData(id)
    if archive==nil then archive={} end
    assert(type(archive)=='table','Invalid archive root')
    archive[RECOVERY_KEY]=record
    local saved=UGCPlayerStateSystem.SavePlayerArchiveData(id,archive)
    print('[EquipAdvance] RECOVERY REQUIRED UID='..tostring(id)..' archive='..tostring(saved))
    assert(saved~=false,'Recovery record save failed')
end
function R.GetService(pc)
    assert(UGCGameSystem.IsServer() and pc,'Server controller required')
    if R.Services[pc] then return R.Services[pc] end
    local id=uid(pc); assert(id and id~=0,'Player UID not ready')
    local service=S.New(setmetatable({PC=pc},A))
    local archive=UGCPlayerStateSystem.GetPlayerArchiveData(id)
    assert(archive==nil or type(archive)=='table','Invalid archive root')
    service.Recovery=R.RecoveryByUID[tostring(id)] or (archive and archive[RECOVERY_KEY])
    service.Blocked=service.Recovery~=nil
    R.Services[pc]=service
    return service
end
function R.Release(pc) R.Services[pc]=nil end
-- Read-only player UI snapshot. No GM permission and no client-supplied prices.
function R.UISnapshot(pc)
    local s=R.GetService(pc); local a=s.A
    local records=a:List(); local seen={}
    for _,x in ipairs(records) do seen[x.Key]=true end
    -- Show legacy wearable equipment too; it is explicitly unsupported for advancement.
    for _,id in pairs(UGCBackpackSystemV2.GetAllItemDefineIDsV2(pc)) do
        local key=G.Key(id)
        if key and not seen[key] and UGCBackpackSystemV2.CheckCanEquipItemToAnySlotV2(pc,id.TypeSpecificID) then
            records[#records+1]=a:Record(id); seen[key]=true
        end
    end
    table.sort(records,function(x,y) return x.Key<y.Key end)
    local result={OK=true,Code='Snapshot',Items={},Levels={},Blocked=s.Blocked==true,
        GoldHave=a:Balance(C.GoldItemID),DiamondHave=a:Balance(C.DiamondItemID)}
    for i=1,6 do result.Levels[i]=a:SlotLevel(i) end
    local signatures={}
    for _,x in ipairs(records) do
        local cfg=C.Items[x.ItemID]; local state=x.CustomData.EquipAdvance
        if type(state)~='table' then state={} end
        local valid=D.ValidState(x.CustomData) and x.Count==1 and (x.CustomDataSize or 0)<=512
        signatures[#signatures+1]={x.Key,x.ItemID,x.CustomData,x.Count,x.EquippedSlot,x.Attached,x.CustomDataSize}
        result.Items[#result.Items+1]={Key=x.Key,ItemID=x.ItemID,EquippedSlot=x.EquippedSlot,
            SlotIdx=cfg and cfg.SlotIdx or 0,RankOrder=cfg and cfg.RankOrder or 0,
            AllowedMaterial=valid and not D.IsProtected(x) and true or false,
            SafeAuto=valid and D.IsSafeAutoMaterial(x) and true or false,
            Locked=state.Locked==true or x.CustomData.Locked==true,
            HasInvestment=valid and ((state.Gold or 0)>0 or (state.Diamond or 0)>0 or (state.MaterialParts or 0)>0) or false}
    end
    local fingerprint=D.Fingerprint({signatures,result.Levels,result.GoldHave,result.DiamondHave,result.Blocked})
    if fingerprint~=s.UIFingerprint then s.UIFingerprint=fingerprint; s.UIRevision=(s.UIRevision or 0)+1 end
    result.Revision=s.UIRevision
    return result
end
function R.IsGM(pc) return UGCGameSystem.IsServer() and UGCGameSystem.IsEnableGM(pc)==true end
function R.Summary(pc)
    local service=R.GetService(pc); local result={}
    for _,x in ipairs(service.A:List()) do
        local cfg=C.Items[x.ItemID]; local rank=C.Ranks[cfg.RankOrder]
        result[#result+1]={Key=x.Key,ItemID=x.ItemID,Name=UGCItemSystemV2.GetItemNameV2(x.ItemID),
            Rank=rank.Name,Major=rank.Major,Minor=rank.Minor,SlotIdx=cfg.SlotIdx,
            NextItemID=cfg.NextItemID,EquippedSlot=x.EquippedSlot,State=x.CustomData.EquipAdvance or {}}
    end
    table.sort(result,function(a,b) return a.Key<b.Key end)
    return result
end
-- GM helpers share the exact same adapter, preserving normal item blueprints.
function R.GMAdd(pc,id,count)
    if not R.IsGM(pc) then return {OK=false,Code='GMForbidden'} end
    id=tonumber(id); count=tonumber(count)
    if not id or not count or count~=math.floor(count) or count<1 then return {OK=false,Code='InvalidInput'} end
    local service=R.GetService(pc)
    if service.Busy or service.Blocked then return {OK=false,Code='BusyOrRecovery'} end
    local a=service.A
    if id==C.GoldItemID or id==C.DiamondItemID then
        if count>100000 then return {OK=false,Code='CountTooLarge'} end
        local n=a:ChangeCurrency(id,count); return {OK=n==count,Code='GMAdded',Count=n}
    end
    if not C.Items[id] or count>16 or not a:AssetReady(id) then return {OK=false,Code='InvalidItem'} end
    local keys={}; a:Begin()
    local ok,err=pcall(function()
        for _=1,count do
            local x=a:Allocate(id,{EquipAdvance={Version=1,Viewed=true}})
            assert(a:Save(x),'save failed'); assert(a:Add(x)==1,'add failed')
            keys[#keys+1]=x.Key
        end
    end)
    a:Finish()
    return {OK=ok,Code=ok and 'GMAdded' or 'GMAddFailed',Detail=tostring(err),Keys=keys}
end
function R.GMLevel(pc,slot,level)
    if not R.IsGM(pc) then return {OK=false,Code='GMForbidden'} end
    slot=tonumber(slot); level=tonumber(level)
    if not slot or not level or slot~=math.floor(slot) or slot<1 or slot>6
        or level~=math.floor(level) or level<0 or level>180 then return {OK=false,Code='InvalidInput'} end
    local service=R.GetService(pc)
    if service.Busy or service.Blocked then return {OK=false,Code='BusyOrRecovery'} end
    local p=pawn(pc); if not p then return {OK=false,Code='NoPawn'} end
    local system=require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotSystem')
    local ok=system.SetSlotLevel(p,slot,level)
    service.A:Refresh()
    -- Test levels are runtime-only; do not overwrite the player's permanent save.
    return {OK=ok,Code='GMLevelSet',SlotIdx=slot,Level=system.GetSlotLevel(nil,slot,p)}
end
function R.GMProtect(pc,key,field,value)
    if not R.IsGM(pc) then return {OK=false,Code='GMForbidden'} end
    local allowed={Locked=true,Tracked=true,Reserved=true,InTrade=true,Viewed=true}
    if not allowed[field] or type(value)~='boolean' then return {OK=false,Code='InvalidInput'} end
    local service=R.GetService(pc)
    if service.Busy or service.Blocked then return {OK=false,Code='BusyOrRecovery'} end
    for _,x in ipairs(service.A:List()) do
        if x.Key==key then
            local original=D.Copy(x.CustomData)
            if not D.ValidState(original) or x.CustomDataSize>512 then return {OK=false,Code='InvalidCustomData'} end
            local state=x.CustomData.EquipAdvance or {}; x.CustomData.EquipAdvance=state
            state.Version=1; state[field]=value
            local ok,saved=pcall(service.A.Save,service.A,x)
            if not ok or not saved then
                -- GM flags edit an existing item, unlike freshly allocated output.
                -- Restore the exact original root if validation failed after Save.
                local restored=UGCItemSystemV2.SaveItemCustomData(x.DefineID,original)
                return {OK=false,Code='GMProtectionFailed',Restored=restored==true,Key=key}
            end
            return {OK=true,Code='GMProtectionSet',Key=key}
        end
    end
    return {OK=false,Code='TargetNotOwned'}
end
function R.GMQuick(pc,action,request)
    if not R.IsGM(pc) then return {OK=false,Code='GMForbidden'} end
    local service=R.GetService(pc)
    if service.Busy or service.Blocked then return {OK=false,Code='BusyOrRecovery'} end
    local quick=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceGM')
    if action=='money' then return quick.Money(service)
    elseif action=='equipment' then return quick.Equipment(service)
    elseif action=='advance' then return quick.AdvanceOnce(service,request)
    elseif action=='levels' then
        for slot=1,6 do
            local result=R.GMLevel(pc,slot,180)
            if not result.OK then return result end
        end
        return {OK=true,Code='GMQuickLevelsSet',Level=180}
    end
    return {OK=false,Code='InvalidGMAction'}
end
return R
