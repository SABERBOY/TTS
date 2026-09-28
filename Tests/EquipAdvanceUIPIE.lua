-- Explicit isolated DS fixture for interactive UI acceptance. No import-time work.
local T={}
function T.Setup(pc)
    local R=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceRuntime')
    assert(R.IsGM(pc) and not AdvanceUITestState,'GM required; clean previous fixture first')
    local s=R.GetService(pc); assert(not s.Busy and not s.Blocked)
    local a=s.A
    AdvanceUITestState={Tag='advance-ui:'..os.time(),Gold=a:Balance(8310084),Diamond=a:Balance(8310132),Levels={}}
    local state=AdvanceUITestState
    for i=1,6 do state.Levels[i]=a:SlotLevel(i);assert(R.GMLevel(pc,i,180).OK) end
    assert(a:ChangeCurrency(8310084,10000)==10000)
    assert(a:ChangeCurrency(8310132,100)==100)
    a:Begin()
    local ok,err=pcall(function()
        for _,recipe in ipairs({{8310131,6},{8310102,3},{8310093,1},{8310103,2},{8310104,2}}) do
            for i=1,recipe[2] do
                local x=a:Allocate(recipe[1],{AdvanceUIProbe=state.Tag,EquipAdvance={Version=1,Viewed=true}})
                assert(x and a:Save(x) and a:Add(x)==1,'seed')
            end
        end
    end)
    a:Finish();assert(ok,err)
    local first=R.UISnapshot(pc);local second=R.UISnapshot(pc)
    assert(first.Revision==second.Revision,'unstable snapshot')
    print('[AdvanceUIAcceptance] SETUP marked=14 stableRevision='..first.Revision)
end
function T.Audit(pc)
    local R=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceRuntime')
    local a=R.GetService(pc).A;assert(AdvanceUITestState);local state=AdvanceUITestState;local counts={}
    for _,x in ipairs(a:List()) do
        if x.CustomData.AdvanceUIProbe==state.Tag then counts[x.ItemID]=(counts[x.ItemID] or 0)+1 end
    end
    local result={Kind='UIAcceptance',OK=true,Code='Audit',Counts=counts,
        GoldSpent=state.Gold+10000-a:Balance(8310084),DiamondSpent=state.Diamond+100-a:Balance(8310132)}
    UnrealNetwork.CallUnrealRPC(pc,pc,'Client_EquipAdvanceResult',result)
    return result
end
function T.Cleanup(pc)
    local R=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceRuntime')
    local a=R.GetService(pc).A;assert(AdvanceUITestState);local state=AdvanceUITestState;local removed=0
    for _,x in ipairs(a:List()) do
        if x.CustomData.AdvanceUIProbe==state.Tag then
            if x.EquippedSlot~='' then assert(a:Unequip(x)) end
            assert(a:Remove(x)==1);removed=removed+1
        end
    end
    for _,v in ipairs({{8310084,state.Gold},{8310132,state.Diamond}}) do
        local delta=v[2]-a:Balance(v[1]);if delta~=0 then a:ChangeCurrency(v[1],delta) end
        assert(a:Balance(v[1])==v[2])
    end
    for i=1,6 do assert(R.GMLevel(pc,i,state.Levels[i]).OK) end
    for _,x in ipairs(a:List()) do assert(x.CustomData.AdvanceUIProbe~=state.Tag) end
    AdvanceUITestState=nil
    UnrealNetwork.CallUnrealRPC(pc,pc,'Client_EquipAdvanceResult',{Kind='UIAcceptance',OK=true,Code='Cleanup',Removed=removed})
end
return T
