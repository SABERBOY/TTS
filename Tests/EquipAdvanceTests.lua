-- Engine-independent transaction tests. The adapter models native side effects,
-- including false returns AFTER mutation; the production service is not mocked.
-- Do not execute tests during the editor's automatic LuaCheck/import scan.
-- Run explicitly from Tests/run_equipment_tests.py (or invoke this module.Run()).
local Suite={}
function Suite.Run()
local loaded, System = pcall(require, 'Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceSystem')
assert(loaded, 'equipment advancement service must exist')
local Config = require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceConfig')
local function copy(v)
    if type(v) ~= 'table' then return v end
    local r = {}; for k,x in pairs(v) do r[k] = copy(x) end; return r
end
local function fixture(id, count, equipped)
    local a = { Items={}, Gold=10000, Diamond=100, Level=180, Seq=0, Time=10, Calls={}, Fail={} }
    function a:IsServer() return true end
    function a:Now() return self.Time end
    function a:List() local r={}; for _,x in pairs(self.Items) do r[#r+1]=copy(x) end; return r end
    function a:Balance(id) return id==8310084 and self.Gold or self.Diamond end
    function a:SlotLevel() return self.Level end
    function a:AssetReady(item) return Config.Items[item] ~= nil end
    function a:Count(x) return self.Items[x.Key] and 1 or 0 end
    function a:CanRemove() return true end
    function a:CanEquip() return true end
    function a:Hit(op)
        self.Calls[op]=(self.Calls[op] or 0)+1
        if self.Fail[op]==self.Calls[op] then return false end
        return true
    end
    function a:Allocate(item, data)
        self.Seq=self.Seq+1
        return {Key='k'..self.Seq, ItemID=item, CustomData=copy(data), EquippedSlot='', Count=1}
    end
    function a:Save(x) return self:Hit('Save') end
    function a:Add(x)
        if not self:Hit('Add') then return 0 end
        self.Items[x.Key]=copy(x); return 1
    end
    function a:Remove(x)
        if not self:Hit('Remove') then return 0 end
        self.Items[x.Key]=nil; return 1
    end
    function a:ChangeCurrency(id, delta)
        local field=id==8310084 and 'Gold' or 'Diamond'
        if not self:Hit('Currency') then return 0 end
        self[field]=self[field]+delta; return math.abs(delta)
    end
    function a:Equip(x, slot)
        if not self:Hit('Equip') then return false end
        self.Items[x.Key].EquippedSlot=slot; return true
    end
    function a:Unequip(x)
        self.Items[x.Key].EquippedSlot=''; return true
    end
    function a:Refresh() end
    function a:Begin() return true end
    function a:Finish() end
    function a:RecordRecovery(r) self.Recovery=r end
    for i=1,count do
        local x=a:Allocate(id,{ExtraAffixes={'A'}, Keep='preserved',EquipAdvance={Version=1,Viewed=true}})
        if i==1 and equipped then x.EquippedSlot='EquipmentSlot.Common.Ornament' end
        a.Items[x.Key]=x
    end
    a.Calls={}
    return a,System.New(a)
end
local total=0
local function test(name, fn)
    local ok,err=pcall(fn); assert(ok,name..': '..tostring(err))
    total=total+1; print('PASS '..name)
end
local function count(a) return #a:List() end
local function preview(s, target, mats) return s:Preview(target or 'k1',mats) end
local function commit(s,p,id,confirm) return s:Execute(p.Token,id or 'req1',confirm==true) end
test('config separates purple subranks and reports missing assets',function()
    assert(Config.Items[8310103].RankOrder==4)
    assert(Config.Items[8310102].RankOrder==5)
    assert(Config.Items[8310101].RankOrder==6)
    local r=Config.Validate(); assert(#r.Errors==0 and #r.Missing>0)
    local g,d=0,0; for _,v in ipairs(Config.Rules) do g=g+v.Gold; d=d+v.Diamond end
    assert(g==10000 and d==23)
end)
test('destroy two white instances and create green, inherit data',function()
    local a,s=fixture(8310131,2,true); local p=preview(s)
    assert(p.OK and p.Gold==100 and p.NextItemID==8310130)
    local r=commit(s,p); assert(r.OK and count(a)==1 and a.Gold==9900)
    assert(not a.Items.k1 and not a.Items.k2)
    local n=a.Items[r.NewKey]; assert(n.ItemID==8310130 and n.CustomData.Keep=='preserved')
    assert(n.EquippedSlot=='EquipmentSlot.Common.Ornament')
    assert(n.CustomData.EquipAdvance.Gold==100)
end)
test('purple plus one needs three identical IDs and explicit confirmation',function()
    local a,s=fixture(8310102,3)
    assert(preview(s).Code=='ManualMaterialsRequired')
    local p=preview(s,'k1',{'k2','k3'}); assert(p.OK)
    assert(commit(s,p).Code=='ConfirmationRequired' and count(a)==3)
    local r=commit(s,p,'req2',true); assert(r.OK and count(a)==1)
    assert(a.Items[r.NewKey].ItemID==8310101 and a.Gold==9350 and a.Diamond==99)
end)
test('different stage same quality or different series rejected',function()
    for _,other in ipairs({8310103,8310109}) do
        local a,s=fixture(8310102,3); a.Items.k2.ItemID=other
        assert(preview(s,'k1',{'k2','k3'}).Code=='MaterialItemMismatch')
        assert(a.Gold==10000 and count(a)==3)
    end
end)
test('missing next stage blocks before mutation',function()
    local a,s=fixture(8310129,2)
    assert(preview(s).Code=='NextItemMissing'); assert(a.Gold==10000)
end)
test('level, money, ownership, duplicates and protected materials',function()
    local a,s=fixture(8310131,2)
    a.Level=9; assert(preview(s).Code=='LevelTooLow'); a.Level=180
    a.Gold=99; assert(preview(s).Code=='NotEnoughGold'); a.Gold=10000
    assert(preview(s,'absent').Code=='TargetNotOwned')
    assert(preview(s,'k1',{'k1'}).Code=='DuplicateInstance')
    a.Items.k2.CustomData.EquipAdvance={Locked=true}
    assert(preview(s,'k1',{'k2'}).Code=='MaterialProtected')
    assert(count(a)==2 and a.Gold==10000)
end)
test('stale preview and request replay cannot spend twice',function()
    local a,s=fixture(8310131,2); local p=preview(s)
    a.Items.k2.CustomData.EquipAdvance={Tracked=true}
    assert(not commit(s,p).OK and a.Gold==10000)
    a.Items.k2.CustomData.EquipAdvance={Version=1,Viewed=true}; p=preview(s)
    local r=commit(s,p,'req2'); assert(r.OK)
    assert(commit(s,p,'req2').NewKey==r.NewKey and a.Gold==9900)
    assert(not commit(s,p,'req3').OK and a.Gold==9900)
end)
test('expired preview',function()
    local a,s=fixture(8310131,2); local p=preview(s); a.Time=1000
    assert(commit(s,p).Code=='PreviewExpired' and count(a)==2)
end)
test('failure injection restores equipment, currencies and equipped target',function()
    for _,f in ipairs({{'Remove',1},{'Remove',2},{'Currency',1},{'Save',1},{'Add',1},{'Equip',1}}) do
        local a,s=fixture(8310131,2,true); a.Fail[f[1]]=f[2]
        local r=commit(s,preview(s)); assert(not r.OK,f[1])
        assert(count(a)==2 and a.Gold==10000 and a.Diamond==100,f[1])
        local worn=0
        for _,x in pairs(a.Items) do
            assert(x.ItemID==8310131 and x.CustomData.Keep=='preserved',f[1])
            if x.EquippedSlot~='' then worn=worn+1 end
        end
        assert(worn==1,f[1])
    end
end)
test('merge historical ledgers exactly once',function()
    local a,s=fixture(8310131,2)
    a.Items.k1.CustomData.EquipAdvance={Gold=20,Diamond=2,MaterialParts=4,Locked=true}
    a.Items.k2.CustomData.EquipAdvance={Gold=30,Diamond=3,MaterialParts=5}
    assert(preview(s).Code=='MaterialCountMismatch','auto-fill must skip invested equipment')
    local r=commit(s,preview(s,'k1',{'k2'})); assert(r.OK)
    local h=a.Items[r.NewKey].CustomData.EquipAdvance
    assert(h.Gold==150 and h.Diamond==5 and h.MaterialParts==21 and h.Locked)
end)
test('compensation failure blocks future requests and retains recovery',function()
    local a,s=fixture(8310131,2); a.Fail.Save=1; a.Fail.Add=1
    local r=commit(s,preview(s)); assert(r.Code=='RecoveryRequired' and a.Recovery)
    assert(preview(s).Code=='RecoveryRequired')
end)
test('partial currency debit and output creation followed by error are compensated',function()
    for _,mode in ipairs({'currency','created','removed'}) do
        local a,s=fixture(8310131,2,true)
        if mode=='currency' then
            local change=a.ChangeCurrency; local first=true
            function a:ChangeCurrency(id,delta)
                if first and delta<0 then first=false; self.Gold=self.Gold-40; return 40 end
                return change(self,id,delta)
            end
        elseif mode=='created' then
            local add=a.Add; local first=true
            function a:Add(x)
                local n=add(self,x)
                if first then first=false; error('native threw after adding') end
                return n
            end
        else
            local remove=a.Remove; local first=true
            function a:Remove(x)
                local n=remove(self,x)
                if first then first=false; error('native threw after removal') end
                return n
            end
        end
        local r=commit(s,preview(s)); assert(r.Code=='TransactionFailed',mode)
        assert(count(a)==2 and a.Gold==10000,mode)
        for _,x in pairs(a.Items) do assert(x.ItemID==8310131,mode) end
    end
end)
test('full backpack works and restores full backpack on create failure',function()
    for _,fail in ipairs({false,true}) do
        local a,s=fixture(8310131,2,true); a.Capacity=1
        local add=a.Add
        function a:Add(x)
            local used=0
            for _,item in pairs(self.Items) do if item.EquippedSlot=='' then used=used+1 end end
            if used>=self.Capacity then return 0 end
            return add(self,x)
        end
        if fail then a.Fail.Add=1 end
        local r=commit(s,preview(s))
        assert(fail and r.Code=='TransactionFailed' or not fail and r.OK)
        assert(count(a)==(fail and 2 or 1))
    end
end)
test('all eleven rules require target plus the configured material quantity',function()
    for rank,rule in ipairs(Config.Rules) do
        local id=990000+rank; local nextID=id+1
        local old1,old2=Config.Items[id],Config.Items[nextID]
        Config.Items[id]={ItemID=id,RankOrder=rank,SlotIdx=3,NextItemID=nextID,Series='Test'}
        Config.Items[nextID]={ItemID=nextID,RankOrder=rank+1,SlotIdx=3,Series='Test'}
        local a,s=fixture(id,rule.Materials+1)
        local keys={}; for i=1,rule.Materials do keys[i]='k'..(i+1) end
        local p=preview(s,'k1',keys); assert(p.OK)
        local r=commit(s,p,'rank'..rank,true)
        assert(r.OK and count(a)==1 and a.Items[r.NewKey].ItemID==nextID)
        assert(a.Gold==10000-rule.Gold and a.Diamond==100-rule.Diamond)
        Config.Items[id],Config.Items[nextID]=old1,old2
    end
end)
test('reentrant mutation is busy and server authority is mandatory',function()
    local a,s=fixture(8310131,2); local p=preview(s); local p2=preview(s)
    local remove=a.Remove
    function a:Remove(x)
        assert(s:Execute(p2.Token,'recursive',false).Code=='Busy')
        return remove(self,x)
    end
    assert(commit(s,p).OK)
    function a:IsServer() return false end
    assert(s:Execute(p.Token,'client',true).Code=='ClientForbidden')
end)
test('unknown or unseen material never auto-fills, manual selection remains possible',function()
    local a,s=fixture(8310131,2)
    a.Items.k2.CustomData.EquipAdvance=nil
    assert(preview(s).Code=='MaterialCountMismatch')
    assert(preview(s,'k1',{'k2'}).OK)
    a.Items.k2.CustomData.EquipAdvance={Viewed=false}
    assert(preview(s).Code=='MaterialCountMismatch')
end)
test('unrestorable oversized input is rejected before removal',function()
    local a,s=fixture(8310131,2)
    a.Items.k1.CustomDataSize=513
    assert(preview(s).Code=='CustomDataTooLarge' and not a.Calls.Remove)
    a.Items.k1.CustomDataSize=100; a.Items.k2.CustomDataSize=513
    assert(preview(s,'k1',{'k2'}).Code=='CustomDataTooLarge' and not a.Calls.Remove)
end)
test('slot rank compatibility uses independent subrank and original legacy fallback',function()
    local original=UGCItemSystemV2
    UGCItemSystemV2={GetItemQualityV2=function() return 3 end}
    local slots=require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotSystem')
    local purple1=slots.GetEquipRankOrder(8310102)
    local purple2=slots.GetEquipRankOrder(8310101)
    local legacy=slots.GetEquipRankOrder(8310017)
    UGCItemSystemV2=original
    assert(purple1==5 and purple2==6 and legacy==4)
    assert(slots.GetEffectiveLevel(180,5)==60 and slots.GetEffectiveLevel(180,6)==75)
end)
test('GM quick step consumes one group per click and can reuse invested outputs',function()
    local loaded,Q=pcall(require,'Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceGM')
    assert(loaded,'GM quick helpers must exist')
    local a,s=fixture(8310131,4)
    local first=Q.AdvanceOnce(s,'click1'); assert(first.OK and count(a)==3)
    assert(Q.AdvanceOnce(s,'click1').NewKey==first.NewKey and count(a)==3)
    assert(Q.AdvanceOnce(s,'click2').OK and count(a)==2)
    local third=Q.AdvanceOnce(s,'click3'); assert(third.OK and count(a)==1)
    assert(a.Items[third.NewKey].ItemID==8310129)
    assert(a.Items[third.NewKey].CustomData.EquipAdvance.Gold==400)
    local gold=a.Gold
    local done=Q.AdvanceOnce(s,'click4')
    assert(done.Code=='NoAdvanceAvailable' and done.Reasons.NextItemMissing and a.Gold==gold)
end)
test('GM quick step confirms purple but respects protections, funds and levels',function()
    local Q=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceGM')
    local a,s=fixture(8310102,3)
    a.Level=59; assert(Q.AdvanceOnce(s,'low').Reasons.LevelTooLow)
    a.Level=60; a.Diamond=0; assert(Q.AdvanceOnce(s,'poor').Reasons.NotEnoughDiamond)
    a.Diamond=1; a.Items.k2.CustomData.EquipAdvance.Locked=true
    assert(Q.AdvanceOnce(s,'protected').Code=='NoAdvanceAvailable' and count(a)==3)
    a.Items.k2.CustomData.EquipAdvance.Locked=false
    local r=Q.AdvanceOnce(s,'purple'); assert(r.OK and r.NewItemID==8310101 and count(a)==1)
end)
test('GM supplies repeat, prepare all configured recipes and stop at capacity',function()
    local Q=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceGM')
    local a,s=fixture(8310131,0)
    assert(Q.Money(s).OK and Q.Money(s).OK)
    assert(a.Gold==210000 and a.Diamond==2100)
    local pack=Q.Equipment(s); assert(pack.OK and pack.Added==57 and count(a)==57)
    local seen={}; for _,x in pairs(a.Items) do seen[x.ItemID]=(seen[x.ItemID] or 0)+1 end
    assert(seen[8310102]==3 and seen[8310131]==2 and not seen[8310129])
    local add=a.Add; function a:Add(x) if count(self)>=60 then return 0 end; return add(self,x) end
    local partial=Q.Equipment(s); assert(not partial.OK and partial.Added==3 and count(a)==60)
    assert(not s.Busy)
end)
test('GM quick actions require GM permission and respect service recovery',function()
    local R=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceRuntime')
    local oldGM,oldService=R.IsGM,R.GetService
    R.IsGM=function() return false end
    assert(R.GMQuick({},'money').Code=='GMForbidden')
    local a,s=fixture(8310131,2)
    R.IsGM=function() return true end; R.GetService=function() return s end
    s.Blocked=true; local blocked=R.GMQuick({},'money')
    R.IsGM,R.GetService=oldGM,oldService
    assert(blocked.Code=='BusyOrRecovery' and a.Gold==10000)
end)
test('GM full equipment pack advances one transaction at a time until exhausted',function()
    local Q=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceGM')
    local a,s=fixture(8310131,0)
    assert(Q.Money(s).OK and Q.Equipment(s).OK)
    local completed=0
    for i=1,58 do
        local before=count(a)
        local result=Q.AdvanceOnce(s,'pack'..i)
        if not result.OK then
            assert(result.Code=='NoAdvanceAvailable' and completed>=27)
            assert(not result.Reasons.NotEnoughGold and not result.Reasons.NotEnoughDiamond)
            assert(count(a)==before)
            return
        end
        completed=completed+1
        local rule=Config.Rules[Config.Items[result.TargetItemID].RankOrder]
        assert(count(a)==before-rule.Materials)
    end
    error('quick advance failed to terminate')
end)
print(string.format('EquipAdvance: %d tests passed',total))
return total
end
return Suite
