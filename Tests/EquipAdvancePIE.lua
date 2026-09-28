-- Explicit DS/GM smoke test. Never runs during LuaCheck. Creates tagged test
-- equipment only, restores currencies/slot levels and the previously worn item.
local T={}
function T.Run(pc)
    local R=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceRuntime')
    assert(R.IsGM(pc),'GM server required')
    local C=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceConfig')
    local Slots=require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotSystem')
    local G=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceGuard')
    local s=R.GetService(pc); assert(not s.Blocked and not s.Busy,'service blocked')
    local a=s.A; local pawn=pc:GetPlayerCharacterSafety(); assert(pawn,'pawn required')
    local tag='AdvanceSmoke:'..os.time()
    local money={[C.GoldItemID]=a:Balance(C.GoldItemID),[C.DiamondItemID]=a:Balance(C.DiamondItemID)}
    local level=Slots.GetSlotLevel(nil,3,pawn)
    local slot='EquipmentSlot.Common.Ornament'
    local oldWorn=UGCBackpackSystemV2.GetEquippedItemBySlotName(pc,slot)
    local oldKey=G.Key(oldWorn)
    local before=UGCAttributeSystem.GetGameAttributeValue(pawn,'BaseAttack')
    local completed=0
    local function note(msg) print('[AdvancePIE] '..msg) end
    local function resolve(key)
        for _,x in ipairs(a:List()) do if x.Key==key then return x end end
        error('instance not found '..tostring(key))
    end
    local function seed(id,n)
        local keys={}; a:Begin()
        local ok,err=pcall(function()
            for i=1,n do
                local x=a:Allocate(id,{AdvanceSmoke=tag,EquipAdvance={Version=1,Viewed=true}})
                assert(a:Save(x),'seed save'); assert(a:Add(x)==1,'seed add')
                assert((UGCBackpackSystemV2.GetItemEquippingSlot(pc,x.DefineID) or '')=='','auto-equip leaked')
                keys[i]=x.Key
            end
        end)
        a:Finish(); assert(ok,err); return keys
    end
    local function run(name,fn)
        fn(); completed=completed+1; note('PASS '..name)
    end
    local ok,err=pcall(function()
        for id in pairs(money) do assert(a:ChangeCurrency(id,10000)==10000,'currency seed') end
        local keys=seed(8310131,2)
        assert(keys[1]~=keys[2],'native unique instance identity')
        run('level gate has zero debit',function()
            Slots.SetSlotLevel(pawn,3,9)
            local beforeGold=a:Balance(C.GoldItemID)
            assert(s:Preview(keys[1],{keys[2]}).Code=='LevelTooLow')
            assert(a:Balance(C.GoldItemID)==beforeGold)
        end)
        Slots.SetSlotLevel(pawn,3,10)
        run('white to green in bag and request replay',function()
            local p=s:Preview(keys[1],{keys[2]}); assert(p.OK,p.Code)
            local gold=a:Balance(C.GoldItemID)
            local r=s:Execute(p.Token,tag..':white',false); assert(r.OK,r.Code..':'..tostring(r.Detail))
            local x=resolve(r.NewKey)
            assert(x.ItemID==8310130 and x.EquippedSlot=='' and x.CustomData.AdvanceSmoke==tag)
            assert(x.CustomData.EquipAdvance.Gold==100)
            assert(a:Balance(C.GoldItemID)==gold-100)
            assert(s:Execute(p.Token,tag..':white',false).NewKey==r.NewKey)
            assert(a:Balance(C.GoldItemID)==gold-100)
            keys={r.NewKey}
        end)
        run('green to blue and missing purple asset',function()
            local material=seed(8310130,1)[1]
            Slots.SetSlotLevel(pawn,3,20)
            local p=s:Preview(keys[1],{material}); assert(p.OK,p.Code)
            local r=s:Execute(p.Token,tag..':green',false); assert(r.OK,r.Code..':'..tostring(r.Detail))
            local x=resolve(r.NewKey); assert(x.ItemID==8310129 and x.CustomData.EquipAdvance.Gold==300)
            assert(s:Preview(x.Key,{}).Code=='NextItemMissing')
        end)
        run('worn purple plus one, manual confirmation, two same ID materials',function()
            local purple=seed(8310124,3)
            local target=resolve(purple[1]); assert(a:Equip(target,slot),'wear target')
            Slots.SetSlotLevel(pawn,3,60); a:Refresh()
            local p=s:Preview(purple[1],{purple[2],purple[3]}); assert(p.OK,p.Code)
            assert(s:Execute(p.Token,tag..':unconfirmed',false).Code=='ConfirmationRequired')
            local gold,diamond=a:Balance(C.GoldItemID),a:Balance(C.DiamondItemID)
            local r=s:Execute(p.Token,tag..':purple',true); assert(r.OK,r.Code..':'..tostring(r.Detail))
            local x=resolve(r.NewKey)
            assert(x.ItemID==8310123 and x.EquippedSlot==slot and Slots.GetEquipRankOrder(x.DefineID)==6)
            assert(a:Balance(C.GoldItemID)==gold-650 and a:Balance(C.DiamondItemID)==diamond-1)
            local attack=UGCAttributeSystem.GetGameAttributeValue(pawn,'BaseAttack')
            a:Refresh(); assert(UGCAttributeSystem.GetGameAttributeValue(pawn,'BaseAttack')==attack,'double attribute application')
            note('purple new='..r.NewKey..' rank=6 BaseAttack='..tostring(attack))
        end)
        run('real backpack compensation after injected creation failure',function()
            local white=seed(8310131,2); Slots.SetSlotLevel(pawn,3,10)
            local p=s:Preview(white[1],{white[2]}); assert(p.OK,p.Code)
            local gold=a:Balance(C.GoldItemID); local save=a.Save
            local fail=true
            a.Save=function(self,x) if fail then fail=false; return false end; return save(self,x) end
            local called,r=pcall(s.Execute,s,p.Token,tag..':rollback',false)
            a.Save=save; assert(called,r); assert(r.Code=='TransactionFailed',r.Code)
            assert(a:Balance(C.GoldItemID)==gold)
            for _,old in ipairs(white) do
                local new=r.RestoredKeys[old]; assert(new and resolve(new).ItemID==8310131,'restore old data')
            end
        end)
        run('native equip succeeds then reports failure: restore original worn item',function()
            local white=seed(8310131,2); Slots.SetSlotLevel(pawn,3,10)
            assert(a:Equip(resolve(white[1]),slot),'wear rollback target')
            local p=s:Preview(white[1],{white[2]}); assert(p.OK,p.Code)
            local gold=a:Balance(C.GoldItemID); local equip=a.Equip; local fail=true
            a.Equip=function(self,x,name)
                local result=equip(self,x,name)
                if fail then fail=false; assert(result,'native equip'); return false end
                return result
            end
            local called,r=pcall(s.Execute,s,p.Token,tag..':equiprollback',false)
            a.Equip=equip; assert(called,r); assert(r.Code=='TransactionFailed',r.Code)
            assert(a:Balance(C.GoldItemID)==gold,'refund')
            local restored=resolve(r.RestoredKeys[white[1]])
            assert(restored.ItemID==8310131 and restored.EquippedSlot==slot,'restore worn source')
        end)
    end)
    -- Always attempt cleanup; never remove untagged player equipment.
    local clean,cleanError=pcall(function()
        for _,x in ipairs(a:List()) do
            if x.CustomData.AdvanceSmoke==tag then
                if x.EquippedSlot~='' then assert(a:Unequip(x),'cleanup unequip') end
                assert(a:Remove(x)==1,'cleanup remove')
            end
        end
        if oldKey then assert(a:Equip({Key=oldKey,DefineID=oldWorn},slot),'restore original wear') end
        Slots.SetSlotLevel(pawn,3,level)
        for id,value in pairs(money) do
            local delta=value-a:Balance(id)
            if delta~=0 then assert(a:ChangeCurrency(id,delta)==math.abs(delta),'restore currency') end
        end
        a:Refresh()
        assert(UGCAttributeSystem.GetGameAttributeValue(pawn,'BaseAttack')==before,'restore attack')
    end)
    note('RESULT passed='..completed..' ok='..tostring(ok)..' cleanup='..tostring(clean)
        ..' error='..tostring(err)..' cleanupError='..tostring(cleanError))
    assert(ok,err); assert(clean,cleanError)
    return completed
end
return T
