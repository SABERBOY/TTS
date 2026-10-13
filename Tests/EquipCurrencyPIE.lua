-- Explicit GM/DS acceptance. Every spend and cleanup waits for its callback.
-- Run as literal reviewed code through the official console, never Lua file I/O.
local T={}
function T.Run(pc)
    local R=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceRuntime')
    local M=require('Script.Blueprint.Prefabs.UI.Equip.EquipCurrency')
    local C=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceConfig')
    local Slots=require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotSystem')
    local Q=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceGM')
    local D=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceData')
    assert(R.IsGM(pc),'GM DS required')
    local s=R.GetService(pc); assert(not s.Busy and not s.Blocked,'Busy/RecoveryRequired')
    local a=s.A; local pawn=pc:GetPlayerCharacterSafety(); local ps=pc:GetCurPlayerState()
    local uid=UGCGameSystem.GetUIDByPlayerController(pc)
    local archive=UGCPlayerStateSystem.GetPlayerArchiveData(uid) or {}
    local storedLevels=D.Copy(archive.EquipSlotLevels)
    local tag='virtual-pie:'..os.time(); local levels={}; local balances={}
    for i=1,6 do levels[i]=Slots.GetSlotLevel(nil,i,pawn) end
    for _,id in ipairs({1001,1002}) do balances[id]=M.Balance(pc,id) end
    local oldList,oldAllocate,oldSave=a.List,a.Allocate,a.Save
    local wornSlot='EquipmentSlot.Common.Ornament'
    local oldWorn=UGCBackpackSystemV2.GetEquippedItemBySlotName(pc,wornSlot)
    -- Test GM selection only sees tagged equipment, preserving the real inventory.
    function a:List()
        local result={}
        for _,x in ipairs(oldList(self)) do if x.CustomData.VirtualCurrencyTest==tag then result[#result+1]=x end end
        return result
    end
    function a:Allocate(id,data) data.VirtualCurrencyTest=tag; return oldAllocate(self,id,data) end
    local tests,completed={},0; local stopping=false
    local function note(text) print('[EquipCurrencyPIE] '..text) end
    local function finish(success,why)
        if stopping then return end; stopping=true
        a.List,a.Allocate,a.Save=oldList,oldAllocate,oldSave
        if s.Busy or s.Blocked then note('FAILED pending/recovery; retain evidence '..tostring(why)); return end
        local clean,cleanError=pcall(function()
            for _,x in ipairs(a:List()) do
                if x.CustomData.VirtualCurrencyTest==tag then
                    if x.EquippedSlot~='' then assert(a:Unequip(x)) end
                    assert(a:Remove(x)==1)
                end
            end
            if oldWorn and (oldWorn.TypeSpecificID or 0)~=0 then assert(a:Equip(a:Record(oldWorn),wornSlot)) end
            for i=1,6 do assert(Slots.SetSlotLevel(pawn,i,levels[i])) end
            local saved=UGCPlayerStateSystem.GetPlayerArchiveData(uid) or {}
            saved.EquipSlotLevels=storedLevels
            assert(UGCPlayerStateSystem.SavePlayerArchiveData(uid,saved)~=false)
            a:Refresh()
        end)
        local ids={1001,1002}
        local function refund(index)
            local id=ids[index]
            if not id then
                note('completed='..completed..' success='..tostring(success)..' cleanup='..tostring(clean)..
                    ' gold='..M.Balance(pc,1001)..' diamond='..M.Balance(pc,1002)..' detail='..tostring(why or cleanError))
                return
            end
            M.ChangeAsync(pc,id,balances[id]-M.Balance(pc,id),function(ok)
                clean=clean and ok and M.Balance(pc,id)==balances[id]; refund(index+1)
            end)
        end
        refund(1)
    end
    local run
    local function guard(fn)
        local ok,why=pcall(fn)
        if not ok then finish(false,why) end
    end
    local function addTest(name,fn) tests[#tests+1]={Name=name,Run=fn} end
    run=function(index)
        local entry=tests[index]
        if not entry then finish(true); return end
        guard(function()
            entry.Run(function()
                completed=completed+1; note('PASS '..entry.Name); run(index+1)
            end)
        end)
    end
    local function seed(id,count)
        local keys={}; assert(a:Begin())
        local ok,why=pcall(function()
            for i=1,count do
                local x=a:Allocate(id,{EquipAdvance={Version=1,Viewed=true}})
                assert(a:Save(x) and a:Add(x)==1); keys[i]=x.Key
                assert((UGCBackpackSystemV2.GetItemEquippingSlot(pc,x.DefineID) or '')=='','automatic equip leaked')
            end
        end)
        a:Finish(); assert(ok,why); return keys
    end
    local function resolve(key)
        for _,x in ipairs(a:List()) do if x.Key==key then return x end end
        error('missing output '..key)
    end
    local function commit(keys,request,verified)
        local materials={}; for i=2,#keys do materials[#materials+1]=keys[i] end
        local p=s:Preview(keys[1],materials); assert(p.OK,p.Code)
        s:Execute(p.Token,tag..request,true,function(r) guard(function() verified(r,p) end) end)
    end
    addTest('saved UGCObject IDs and three tables',function(next)
        assert(M.Definitions()[1001] and M.Definitions()[1002])
        assert(M.GetManager():GetMappedItemID(1001)==nil and M.GetData(1002).ItemIcon)
        local report=C.Validate(function(id) return a:AssetReady(id) end)
        assert(#report.Errors==0 and #C.ItemRows==39)
        note('rank=12 rule=11 item=39 missing='..#report.Missing)
        next()
    end)
    addTest('repeatable GM money uses virtual balances',function(next)
        assert(Q.Money(s).OK and Q.Money(s).OK)
        assert(M.Balance(pc,1001)==balances[1001]+200000 and M.Balance(pc,1002)==balances[1002]+2000)
        next()
    end)
    addTest('white bag advance and exact request replay',function(next)
        local keys=seed(8310131,2); assert(Slots.SetSlotLevel(pawn,3,10))
        local gold=M.Balance(pc,1001)
        commit(keys,':white',function(r,p)
            assert(r.OK,r.Code..':'..tostring(r.Detail))
            local output=resolve(r.NewKey)
            assert(output.ItemID==8310130 and output.EquippedSlot=='' and output.CustomData.EquipAdvance.Gold==100)
            assert(M.Balance(pc,1001)==gold-100)
            s:Execute(p.Token,tag..':white',true,function(replay)
                guard(function() assert(replay.NewKey==r.NewKey and M.Balance(pc,1001)==gold-100); next() end)
            end)
        end)
    end)
    addTest('glove purple plus one requires two materials and both currencies',function(next)
        local keys=seed(8310102,3); assert(Slots.SetSlotLevel(pawn,4,60))
        local gold,diamond=M.Balance(pc,1001),M.Balance(pc,1002)
        commit(keys,':glove',function(r)
            assert(r.OK and r.NewItemID==8310101,r.Code..':'..tostring(r.Detail))
            assert(M.Balance(pc,1001)==gold-650 and M.Balance(pc,1002)==diamond-1)
            assert(resolve(r.NewKey).CustomData.EquipAdvance.Gold==650); next()
        end)
    end)
    addTest('worn target keeps slot and attributes do not stack',function(next)
        local keys=seed(8310124,3); assert(Slots.SetSlotLevel(pawn,3,60))
        assert(a:Equip(resolve(keys[1]),wornSlot)); a:Refresh()
        commit(keys,':worn',function(r)
            assert(r.OK,r.Code..':'..tostring(r.Detail))
            assert(resolve(r.NewKey).EquippedSlot==wornSlot and r.NewItemID==8310123)
            local attack=UGCAttributeSystem.GetGameAttributeValue(pawn,'BaseAttack')
            a:Refresh(); assert(UGCAttributeSystem.GetGameAttributeValue(pawn,'BaseAttack')==attack)
            next()
        end)
    end)
    addTest('creation failure refunds virtual money and restores equipment',function(next)
        local keys=seed(8310131,2); local gold=M.Balance(pc,1001); local fail=true
        function a:Save(x) if fail then fail=false; return false end; return oldSave(self,x) end
        commit(keys,':rollback',function(r)
            a.Save=oldSave
            assert(r.Code=='TransactionFailed' and M.Balance(pc,1001)==gold,r.Code)
            assert(resolve(r.RestoredKeys[keys[1]]).ItemID==8310131); next()
        end)
    end)
    addTest('missing next item and low strengthen level cause zero debit',function(next)
        local keys=seed(8310129,2); local gold,diamond=M.Balance(pc,1001),M.Balance(pc,1002)
        assert(s:Preview(keys[1],{keys[2]}).Code=='NextItemMissing')
        keys=seed(8310131,2); assert(Slots.SetSlotLevel(pawn,3,9))
        assert(s:Preview(keys[1],{keys[2]}).Code=='LevelTooLow')
        assert(M.Balance(pc,1001)==gold and M.Balance(pc,1002)==diamond); next()
    end)
    addTest('slot strengthening spends virtual gold with original curve',function(next)
        assert(Slots.SetSlotLevel(pawn,1,1))
        local gold=M.Balance(pc,1001); local cost=Slots.GetBatchCost(1,1)
        Slots.ServerTryStrengthen(ps,pawn,1,1,function(ok,why,level)
            guard(function()
                assert(ok and level==2,why)
                assert(M.Balance(pc,1001)==gold-cost and Slots.GetSlotLevel(nil,1,pawn)==2)
                note('strengthen cost='..cost); next()
            end)
        end)
    end)
    addTest('slot write failure restores virtual gold and previous level',function(next)
        local originalSet=Slots.SetSlotLevel; local first=true; local gold=M.Balance(pc,1001)
        Slots.SetSlotLevel=function(p,slot,level)
            if first then first=false; return false end
            return originalSet(p,slot,level)
        end
        Slots.ServerTryStrengthen(ps,pawn,1,1,function(ok,why)
            Slots.SetSlotLevel=originalSet
            guard(function() assert(not ok and why=='TransactionFailed'); assert(M.Balance(pc,1001)==gold); next() end)
        end)
    end)
    addTest('GM 57 item pack merges exactly once per click until exhausted',function(next)
        -- Clear the earlier tagged cases so pack counts have a precise baseline.
        for _,x in ipairs(a:List()) do
            if x.EquippedSlot~='' then assert(a:Unequip(x)) end
            assert(a:Remove(x)==1)
        end
        for i=1,6 do assert(Slots.SetSlotLevel(pawn,i,180)) end
        local pack=Q.Equipment(s); assert(pack.OK and pack.Added==57,'GM pack')
        local clicks=0; local click
        click=function()
            Q.AdvanceOnce(s,tag..':pack'..clicks,function(r)
                guard(function()
                    if r.OK then clicks=clicks+1; assert(clicks<=57); click()
                    else
                        assert(r.Code=='NoAdvanceAvailable' and clicks==27 and #a:List()==27,r.Code)
                        note('GM clicks=27 remaining=27'); next()
                    end
                end)
            end)
        end
        click()
    end)
    note('START '..tag..' gold='..balances[1001]..' diamond='..balances[1002])
    run(1)
end
return T
