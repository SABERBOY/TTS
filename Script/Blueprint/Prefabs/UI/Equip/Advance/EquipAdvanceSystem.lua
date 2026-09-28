-- Pure server transaction service. Engine calls live in EquipAdvanceRuntime.
local C=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceConfig')
local D=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceData')
local S={}; S.__index=S
local function failure(code) return {OK=false,Code=code} end
local function validKey(k) return type(k)=='string' and #k>0 and #k<=160 end
local function signature(records)
    local values={}
    for _,r in ipairs(records) do values[#values+1]={r.Key,r.ItemID,r.CustomData,r.EquippedSlot,r.Attached} end
    return D.Fingerprint(values)
end
function S.New(adapter)
    return setmetatable({A=adapter,Previews={},Requests={},RequestOrder={},Sequence=0},S)
end
function S:Build(targetKey,materialKeys)
    if self.Blocked then return failure('RecoveryRequired') end
    if not self.A:IsServer() then return failure('ClientForbidden') end
    if not validKey(targetKey) then return failure('InvalidTarget') end
    local items,byKey=self.A:List(),{}
    for _,item in ipairs(items) do byKey[item.Key]=item end
    local target=byKey[targetKey]
    if not target then return failure('TargetNotOwned') end
    local def=C.Items[target.ItemID]
    if not def then return failure('UnsupportedItem') end
    local rank=C.Ranks[def.RankOrder]; local rule=C.Rules[def.RankOrder]
    if not rule then return failure('MaxRank') end
    if not def.NextItemID or not C.Items[def.NextItemID] then return failure('NextItemMissing') end
    if not self.A:AssetReady(def.NextItemID) then return failure('NextAssetUnavailable') end
    if target.Attached or target.Count~=1 then return failure('InvalidTargetState') end
    if target.CustomDataSize and target.CustomDataSize>512 then return failure('CustomDataTooLarge') end
    if not D.ValidState(target.CustomData) then return failure('InvalidCustomData') end
    local state=target.CustomData.EquipAdvance or {}
    if state.Reserved or state.InTrade or target.CustomData.Reserved or target.CustomData.InTrade then
        return failure('TargetBusy')
    end
    if target.EquippedSlot~='' and not self.A:CanEquip(def.NextItemID,target.EquippedSlot) then
        return failure('NextCannotEquip')
    end
    local level=self.A:SlotLevel(def.SlotIdx)
    if level<rank.Cap then local r=failure('LevelTooLow'); r.RequiredLevel=rank.Cap; r.Level=level; return r end
    if self.A:Balance(C.GoldItemID)<rule.Gold then return failure('NotEnoughGold') end
    if self.A:Balance(C.DiamondItemID)<rule.Diamond then return failure('NotEnoughDiamond') end
    local automatic=materialKeys==nil
    if automatic then
        if rank.Major>=4 then return failure('ManualMaterialsRequired') end
        materialKeys={}
        table.sort(items,function(a,b) return a.Key<b.Key end)
        for _,item in ipairs(items) do
            if item.Key~=targetKey and item.ItemID==target.ItemID and D.ValidState(item.CustomData)
                and D.IsSafeAutoMaterial(item) and item.Count==1 and #materialKeys<rule.Materials then
                materialKeys[#materialKeys+1]=item.Key
            end
        end
    end
    if type(materialKeys)~='table' then return failure('InvalidMaterials') end
    local n=0
    for k in pairs(materialKeys) do
        if type(k)~='number' or k~=math.floor(k) or k<1 or k>rule.Materials then return failure('InvalidMaterials') end
        n=n+1
    end
    if n~=rule.Materials then return failure('MaterialCountMismatch') end
    local records,seen={target},{[targetKey]=true}
    for _,key in ipairs(materialKeys) do
        if not validKey(key) then return failure('InvalidMaterials') end
        if seen[key] then return failure('DuplicateInstance') end
        seen[key]=true
        local item=byKey[key]
        if not item then return failure('MaterialNotOwned') end
        if item.ItemID~=target.ItemID then return failure('MaterialItemMismatch') end
        if item.CustomDataSize and item.CustomDataSize>512 then return failure('CustomDataTooLarge') end
        if not D.ValidState(item.CustomData) then return failure('InvalidCustomData') end
        if item.Count~=1 or D.IsProtected(item) then return failure('MaterialProtected') end
        records[#records+1]=item
    end
    for _,item in ipairs(records) do
        if not self.A:CanRemove(item) then return failure('CannotRemove') end
    end
    return {OK=true,Code='Ready',TargetKey=targetKey,ItemID=target.ItemID,
        RankID=rank.RankID,RankOrder=rank.Order,Major=rank.Major,Minor=rank.Minor,
        NextItemID=def.NextItemID,NextRankID=C.Ranks[def.RankOrder+1].RankID,
        SlotIdx=def.SlotIdx,Level=level,RequiredLevel=rank.Cap,
        Gold=rule.Gold,Diamond=rule.Diamond,MaterialKeys=D.Copy(materialKeys),
        RequiresConfirmation=rank.Major>=4,Records=records,Signature=signature(records)}
end
local function public(p)
    local r={}; for k,v in pairs(p) do if k~='Records' and k~='Signature' then r[k]=D.Copy(v) end end; return r
end
function S:Preview(targetKey,materialKeys)
    if self.Busy then return failure('Busy') end
    local ok,p=pcall(self.Build,self,targetKey,materialKeys)
    if not ok then return failure('ReadFailed') end
    if not p.OK then return p end
    self.Sequence=self.Sequence+1
    p.Token='advance:'..tostring(self.A:Now())..':'..self.Sequence
    p.Expires=self.A:Now()+120
    self.Previews[p.Token]=p
    -- A bounded set of short-lived previews, even if a client spams requests.
    local keys={}; for key,x in pairs(self.Previews) do keys[#keys+1]={key,x.Expires} end
    table.sort(keys,function(a,b) return a[2]<b[2] end)
    for i=1,#keys-32 do self.Previews[keys[i][1]]=nil end
    return public(p)
end
function S:Candidates(targetKey)
    local list=self.A:List(); local target
    for _,r in ipairs(list) do if r.Key==targetKey then target=r end end
    if not target then return {} end
    local out={}
    for _,r in ipairs(list) do
        if r.Key~=targetKey and r.ItemID==target.ItemID then
            local valid=D.ValidState(r.CustomData)
            out[#out+1]={Key=r.Key,ItemID=r.ItemID,Allowed=valid and not D.IsProtected(r),
                SafeAuto=valid and D.IsSafeAutoMaterial(r)}
        end
    end
    table.sort(out,function(a,b) return a.Key<b.Key end); return out
end
function S:Remember(request,token,result)
    result.RequestID=request
    self.Requests[request]={Token=token,Result=D.Copy(result)}
    self.RequestOrder[#self.RequestOrder+1]=request
    if #self.RequestOrder>128 then self.Requests[table.remove(self.RequestOrder,1)]=nil end
    return result
end
function S:MergedData(p)
    local data=D.Copy(p.Records[1].CustomData)
    local state=data.EquipAdvance or {}; data.EquipAdvance=state
    state.Version=1
    state.Gold=(state.Gold or 0)+p.Gold
    state.Diamond=(state.Diamond or 0)+p.Diamond
    state.MaterialParts=state.MaterialParts or 0
    for i=2,#p.Records do
        local material=p.Records[i]; local h=material.CustomData.EquipAdvance or {}
        state.Gold=state.Gold+(h.Gold or 0); state.Diamond=state.Diamond+(h.Diamond or 0)
        state.MaterialParts=state.MaterialParts+(h.MaterialParts or 0)+C.Ranks[C.Items[material.ItemID].RankOrder].RecycleParts
    end
    assert(D.ValidState(data),'Merged ledger exceeds supported bounds')
    return data
end
function S:Spawn(j,itemID,data)
    local x=self.A:Allocate(itemID,D.Copy(data))
    if not x then error('AllocateFailed') end
    j.Created[#j.Created+1]=x -- record BEFORE any call that can partly succeed
    if self.A:Save(x)~=true then error('SaveCustomDataFailed') end
    if self.A:Add(x)~=1 or self.A:Count(x)~=1 then error('CreateFailed') end
    return x
end
function S:Rollback(j)
    local errors,map={},{}
    local function attempt(label,fn)
        local ok,err=pcall(fn)
        if not ok then errors[#errors+1]=label..':'..tostring(err) end
    end
    -- Remove partially-created output before recreating any consumed inputs.
    for _,x in ipairs(j.Created) do
        attempt('remove-output',function()
            if self.A:Count(x)>0 then self.A:Remove(x) end
            assert(self.A:Count(x)==0,'still present')
        end)
    end
    if #errors>0 then j.Errors=errors; return false,map end
    j.Restored=j.Restored or {}
    -- Restore the equipped target first, then materials, so a full backpack fits.
    for _,old in ipairs(j.Originals) do
        attempt('restore:'..old.Key,function()
            local restored=old
            if self.A:Count(old)==0 then
                restored=self.A:Allocate(old.ItemID,D.Copy(old.CustomData))
                assert(restored,'allocate'); j.Restored[#j.Restored+1]=restored
                assert(self.A:Save(restored)==true,'save')
                assert(self.A:Add(restored)==1 and self.A:Count(restored)==1,'add')
            else assert(self.A:Count(old)==1,'unexpected count') end
            if old.EquippedSlot~='' then assert(self.A:Equip(restored,old.EquippedSlot)==true,'equip') end
            map[old.Key]=restored.Key
        end)
    end
    for _,id in ipairs({C.GoldItemID,C.DiamondItemID}) do
        attempt('currency:'..id,function()
            local delta=j.Balances[id]-self.A:Balance(id)
            if delta~=0 then self.A:ChangeCurrency(id,delta) end
            assert(self.A:Balance(id)==j.Balances[id],'balance mismatch')
        end)
    end
    j.Errors=errors
    return #errors==0,map
end
function S:Execute(token,request,confirmed)
    if not self.A:IsServer() then return failure('ClientForbidden') end
    if not validKey(request) or not validKey(token) then return failure('InvalidRequest') end
    local previous=self.Requests[request]
    if previous then
        if previous.Token~=token then return failure('RequestConflict') end
        return D.Copy(previous.Result)
    end
    if self.Blocked then return failure('RecoveryRequired') end
    if self.Busy then return failure('Busy') end
    local p=self.Previews[token]
    if not p then return self:Remember(request,token,failure('PreviewMissing')) end
    if self.A:Now()>p.Expires then
        self.Previews[token]=nil; return self:Remember(request,token,failure('PreviewExpired'))
    end
    if p.RequiresConfirmation and confirmed~=true then return failure('ConfirmationRequired') end
    local valid,current=pcall(self.Build,self,p.TargetKey,p.MaterialKeys)
    if not valid then return self:Remember(request,token,failure('ReadFailed')) end
    if not current.OK then return self:Remember(request,token,current) end
    if current.Signature~=p.Signature or current.NextItemID~=p.NextItemID then
        return self:Remember(request,token,failure('PreviewStale'))
    end
    p=current
    self.Busy=true; self.Previews[token]=nil
    local j={Originals=p.Records,Created={},Balances={},Token=token,RequestID=request}
    self.Journal=j
    local ok,output=pcall(function()
        j.Balances[C.GoldItemID]=self.A:Balance(C.GoldItemID)
        j.Balances[C.DiamondItemID]=self.A:Balance(C.DiamondItemID)
        assert(self.A:Begin()~=false,'BeginFailed'); j.Begun=true
        local data=self:MergedData(p)
        -- Remove materials first to free space before unequipping the target.
        for i=2,#p.Records do
            local x=p.Records[i]; j.Mutated=true
            assert(self.A:Remove(x)==1 and self.A:Count(x)==0,'RemoveMaterialFailed')
        end
        local old=p.Records[1]
        if old.EquippedSlot~='' then assert(self.A:Unequip(old)==true,'UnequipFailed') end
        j.Mutated=true
        assert(self.A:Remove(old)==1 and self.A:Count(old)==0,'RemoveTargetFailed')
        for _,entry in ipairs({{C.GoldItemID,p.Gold},{C.DiamondItemID,p.Diamond}}) do
            if entry[2]>0 then
                assert(self.A:ChangeCurrency(entry[1],-entry[2])==entry[2],'CurrencyFailed')
                assert(self.A:Balance(entry[1])==j.Balances[entry[1]]-entry[2],'CurrencyMismatch')
            end
        end
        local new=self:Spawn(j,p.NextItemID,data)
        if old.EquippedSlot~='' then assert(self.A:Equip(new,old.EquippedSlot)==true,'EquipFailed') end
        return new
    end)
    local result
    if ok then result={OK=true,Code='Advanced',OldKey=p.TargetKey,NewKey=output.Key,
        NewItemID=p.NextItemID,RankID=p.NextRankID,Gold=p.Gold,Diamond=p.Diamond}
    else
        local restored,map=true,{}
        if j.Mutated then
            local rbOK,rb,mapResult=pcall(self.Rollback,self,j)
            restored=rbOK and rb==true; map=mapResult or {}
            if not rbOK then j.Errors={tostring(rb)} end
        end
        result={OK=false,Code=restored and 'TransactionFailed' or 'RecoveryRequired',
            Detail=tostring(output),RestoredKeys=map}
        if not restored then
            self.Blocked=true; self.Recovery=j
            local saved,saveError=pcall(self.A.RecordRecovery,self.A,j)
            result.RecoveryRecorded=saved
            if not saved then result.RecoveryRecordError=tostring(saveError) end
        end
    end
    if j.Begun then pcall(self.A.Finish,self.A) end
    self.Busy=false; self.Journal=nil
    local refreshed=pcall(self.A.Refresh,self.A,p.SlotIdx)
    result.RefreshPending=not refreshed
    return self:Remember(request,token,result)
end
return S
