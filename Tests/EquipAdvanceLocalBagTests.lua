-- 升阶面板本地背包读取的离线用例。原生接口用桩模拟，Run 只在宿主 Python harness 里显式调用。
-- 覆盖点：与预览页/强化页同一取背包入口、大背包一次读出且零 RPC、投影口径与服务端一致、
-- Revision 只用稳定实例 Key、ViewModel 能直接消费这份本地快照。
local T={}
function T.Run()
    local D=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceData')
    local Currency=require('Script.Blueprint.Prefabs.UI.Equip.EquipCurrency')
    local M=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceViewModel')
    local Bag=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceLocalBag')
    local n=0
    local function test(name,fn) fn(); n=n+1; print('PASS LocalBag '..name) end
    -- 白手套同系列的两个真实 ItemID：8310099(白) → 8310098(绿)
    local HEAD,IDOL,GLOVE,LEGACY=8310099,8310098,8310106,9999001
    local Wearable={[HEAD]=true,[IDOL]=true,[GLOVE]=true,[LEGACY]=true}
    local KernelSlot={[HEAD]='EquipmentSlot.Common.Head',[IDOL]='EquipmentSlot.Common.Head'}
    local Instances,Custom,Size,RPC,Archive={},{},{},0,nil
    local function add(itemID,instance,custom,size,count,equipped)
        Instances[instance]={ItemID=itemID,Count=count or 1,EquippedSlot=equipped or ''}
        Custom[instance]=custom or {EquipAdvance={Version=1,Viewed=true}}
        Size[instance]=size or 64
    end
    local function key(itemID,instance) return '1:'..tostring(itemID)..':'..tostring(instance) end
    -- 每次读取都新建 DefineID 与 CustomData 表，模拟原生 userdata 的不稳定地址
    local function define(instance)
        local entry=Instances[instance]
        return {Type=1,TypeSpecificID=entry.ItemID,InstanceID=instance}
    end
    local function bagIDs()
        local out={}
        for instance in pairs(Instances) do out[#out+1]=define(instance) end
        return out
    end
    local function copy(value)
        if type(value)~='table' then return value end
        local out={}
        for k,v in pairs(value) do out[k]=copy(v) end
        return out
    end
    local function rows(map)
        local out={}
        for _,row in ipairs(map) do out[row.Key]=row end
        return out
    end
    local function count(items,itemID)
        local total=0
        for _,row in ipairs(items) do if row.ItemID==itemID then total=total+1 end end
        return total
    end
    UnrealNetwork={CallUnrealRPC=function() RPC=RPC+1 end}
    BackpackUtils={GetItemInstanceID=function(id) return id and id.InstanceID or 0 end}
    UGCItemSystemV2={
        LoadItemCustomData=function(id) return copy(Custom[id.InstanceID] or {}) end,
        GetItemCustomDataSize=function(id) return Size[id.InstanceID] or 0 end,
        GetAttachTargetItem=function(id) return false,nil end,
        GetAttachChildrenItem=function(id) return {} end,
        GetEquipTargetSlots=function(itemID)
            local name=KernelSlot[itemID]
            return name and {name} or {}
        end,
    }
    UGCBackpackSystemV2={
        GetAllItemDefineIDsV2=function() return bagIDs() end,
        CheckCanEquipItemToAnySlotV2=function(_,itemID) return Wearable[itemID]==true end,
        ItemCanEquipToSlot=function() return false end,
        GetItemEquippingSlot=function(_,id) return Instances[id.InstanceID].EquippedSlot end,
        GetItemCountByDefineIDV2=function(_,id) return Instances[id.InstanceID].Count end,
        GetEquipSlots=function() return {} end,
        GetEquippedItemBySlotName=function() return nil end,
        GetBackpackComponentV2=function() return nil end,
    }
    UGCAttributeSystem={GetGameAttributeValue=function(_,Name)
        return ({EquipSlotLv_Helmet=180,EquipSlotLv_Shoes=12})[Name] or 0
    end}
    UGCPlayerStateSystem={GetPlayerArchiveData=function() return Archive end,
        SavePlayerArchiveData=function() return true end}
    local Manager={GetItemData=function(_,id) return {ItemIcon='icon_'..id} end,
        GetItemNum=function(_,id) return id==1001 and 12000 or 7 end}
    UGCGamePartSystem={IsGamePartLoaded=function() return true end,
        GetGamePartGlobalActor=function() return Manager end}
    local ReadTable=UGCGameSystem.GetTableData
    UGCGameSystem.GetTableData=function(path)
        if tostring(path):match('UGCObject') then
            return {['1001']={ItemID=1001,ItemName='金币'},['1002']={ItemID=1002,ItemName='钻石'}}
        end
        return ReadTable(path)
    end
    local PC={GetPlayerCharacterSafety=function() return {} end}
    UGCGameSystem.GetLocalPlayerController=function() return PC end
    UGCGameSystem.GetUIDByPlayerController=function() return 7 end
    CheckObjectContainsField=function() return true end
    local function reset()
        Instances,Custom,Size,RPC,Archive={},{},{},0,nil
        Currency.RecoveryByUID['7']=nil
        for instance=1,300 do add(HEAD,instance) end
        add(HEAD,901,{EquipAdvance={Version=1,Locked=true}})
        add(HEAD,902,{EquipAdvance={Version=1,Gold=500}})
        add(HEAD,903,{EquipAdvance={Version=2}})
        add(HEAD,904,nil,900)
        add(HEAD,905,nil,64,3)
        add(HEAD,906,nil,64,1,'EquipmentSlot.Common.Head')
        add(IDOL,907)
        add(IDOL,908)
        add(GLOVE,909)
        add(LEGACY,910)
    end
    reset(); Bag.Reset()
    test('big bag is read locally through the shared collector with zero rpc',function()
        local snapshot=Bag.Collect()
        assert(snapshot.OK and snapshot.Code=='Snapshot')
        -- 300 件同名白装 + 6 件特殊状态 + 2 件绿装 + 手套 + 未接入升阶的旧装备
        assert(#snapshot.Items==310,'items='..tostring(#snapshot.Items))
        assert(snapshot.RowCount==310 and snapshot.LocalBag==true)
        assert(RPC==0,'local bag read must not touch UnrealNetwork')
        assert(snapshot.GoldHave==12000 and snapshot.DiamondHave==7)
        assert(snapshot.Levels[1]==180 and snapshot.Levels[6]==12 and snapshot.Levels[4]==0)
        assert(snapshot.Blocked==false)
    end)
    test('rows carry the shared projection plus a local define id only',function()
        local by=rows(Bag.Collect().Items)
        local sample=by[key(HEAD,1)]
        for _,field in ipairs({'Key','ItemID','EquippedSlot','SlotIdx','RankOrder',
            'AllowedMaterial','SafeAuto','Locked','HasInvestment','DefineID'}) do
            assert(sample[field]~=nil,'missing '..field)
        end
        assert(rawget(sample,'CustomData')==nil and rawget(sample,'Count')==nil)
        assert(sample.SlotIdx==1 and sample.RankOrder==1)
        assert(by[key(GLOVE,909)].SlotIdx==4,'slot idx comes from the advance config')
        local legacy=by[key(LEGACY,910)]
        assert(legacy.SlotIdx==0 and legacy.RankOrder==0 and legacy.AllowedMaterial==true)
        assert(by[key(HEAD,906)].EquippedSlot=='EquipmentSlot.Common.Head')
    end)
    test('client projection equals the server-side rule',function()
        local by=rows(Bag.Collect().Items)
        assert(by[key(HEAD,901)].Locked==true and by[key(HEAD,901)].AllowedMaterial==false)
        local invested=by[key(HEAD,902)]
        assert(invested.HasInvestment==true and invested.SafeAuto==false
            and invested.AllowedMaterial==true)
        assert(by[key(HEAD,903)].AllowedMaterial==false and by[key(HEAD,903)].SafeAuto==false,
            'unknown ledger version is not consumable')
        assert(by[key(HEAD,904)].AllowedMaterial==false,'custom data over 512 bytes')
        assert(by[key(HEAD,905)].AllowedMaterial==false,'stacked item is not a single instance')
        assert(by[key(HEAD,906)].AllowedMaterial==false and by[key(HEAD,906)].SafeAuto==false,
            'equipped item is protected')
        assert(by[key(IDOL,907)].RankOrder==2 and by[key(IDOL,907)].AllowedMaterial==true)
        for instance=1,300 do
            local row=by[key(HEAD,instance)]
            assert(row and row.AllowedMaterial and row.SafeAuto,'plain material '..instance)
        end
        for _,instance in ipairs({1,901,902,903,904,905,906}) do
            local row=by[key(HEAD,instance)]
            local expected=D.ProjectRow({Key=row.Key,ItemID=HEAD,CustomData=Custom[instance],
                Count=Instances[instance].Count,EquippedSlot=Instances[instance].EquippedSlot,
                Attached=false,CustomDataSize=Size[instance]},{SlotIdx=1,RankOrder=1})
            for _,field in ipairs({'AllowedMaterial','SafeAuto','Locked','HasInvestment'}) do
                assert(row[field]==expected[field],field..' instance '..instance)
            end
        end
    end)
    test('revision ignores fresh define ids and tracks real bag changes',function()
        local first=Bag.Collect()
        local again=Bag.Collect()
        assert(first.Revision==again.Revision,'an unchanged bag must not bump revision')
        add(HEAD,911)
        local added=Bag.Collect()
        assert(added.Revision==again.Revision+1 and #added.Items==#again.Items+1)
        Custom[911]={EquipAdvance={Version=1,Gold=1}}
        local changed=Bag.Collect()
        assert(changed.Revision==added.Revision+1,'ledger change is a change')
        assert(count(changed.Items,HEAD)==307,'head count='..tostring(count(changed.Items,HEAD)))
    end)
    test('recovery record blocks the panel without a server round trip',function()
        Archive={EquipAdvanceRecovery={Version=1,RequestID='r1'}}
        assert(Bag.Collect().Blocked==true)
        assert(RPC==0,'blocking state is read from the local archive')
        Archive=nil; Currency.RecoveryByUID['7']=nil
        assert(Bag.Collect().Blocked==false)
    end)
    test('missing controller reports read failed instead of an empty bag',function()
        UGCGameSystem.GetLocalPlayerController=function() return nil end
        local snapshot=Bag.Collect()
        assert(not snapshot.OK and snapshot.Code=='ReadFailed')
        UGCGameSystem.GetLocalPlayerController=function() return PC end
        assert(Bag.Collect().OK)
    end)
    test('view model consumes the local snapshot without further changes',function()
        reset(); Bag.Reset()
        local m=M.New()
        assert(m:ApplySnapshot(Bag.Collect()))
        assert(#m.Items==310 and m:LocalCode()=='SelectTarget')
        assert(m:SelectTarget(key(IDOL,907)))
        local target,cfg,rank=m:Definition()
        assert(target.Key==key(IDOL,907) and cfg.ItemID==IDOL and rank.Order==2)
        assert(target.DefineID and target.DefineID.InstanceID==907)
        assert(#m.Materials>=1,'auto selection found the sibling instance')
        assert(m:ToggleMaterial(key(IDOL,907))==false,'target is never its own material')
        assert(m:LocalCode()~='Loading')
    end)
    print('EquipAdvanceLocalBag: '..n..' tests passed')
end
return T
