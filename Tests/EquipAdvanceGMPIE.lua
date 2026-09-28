-- Explicit GM/DS test; never runs during LuaCheck. Isolates auto-selection to
-- newly generated test instances and always attempts to restore starting state.
local T={}
function T.Run(pc)
    local R=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceRuntime')
    local Slots=require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotSystem')
    assert(R.IsGM(pc),'GM server required')
    local s=R.GetService(pc); assert(not s.Busy and not s.Blocked,'service unavailable')
    local a=s.A; local p=pc:GetPlayerCharacterSafety(); assert(p,'pawn required')
    local list=a.List; local original={}; local levels={}
    for _,x in ipairs(a:List()) do original[x.Key]=true end
    local gold,diamond=a:Balance(8310084),a:Balance(8310132)
    for slot=1,6 do levels[slot]=Slots.GetSlotLevel(nil,slot,p) end
    a.List=function(self)
        local out={}
        for _,x in ipairs(list(self)) do if not original[x.Key] then out[#out+1]=x end end
        return out
    end
    local merged=0; local tag='quick-pie:'..os.time()
    local ok,err=pcall(function()
        assert(R.GMQuick(pc,'money').OK and R.GMQuick(pc,'money').OK,'money add')
        assert(a:Balance(8310084)==gold+200000 and a:Balance(8310132)==diamond+2000,'repeat money')
        local pack=R.GMQuick(pc,'equipment')
        assert(pack.OK and pack.Added==57,'pack '..tostring(pack.Code)..':'..tostring(pack.Added))
        for _,x in ipairs(a:List()) do assert(x.EquippedSlot=='','unexpected auto-equip') end
        assert(R.GMQuick(pc,'levels').OK,'levels')
        for slot=1,6 do assert(Slots.GetSlotLevel(nil,slot,p)==180,'level readback') end
        for i=1,58 do
            local before=#a:List()
            local r=R.GMQuick(pc,'advance',tag..':'..i)
            if not r.OK then
                assert(r.Code=='NoAdvanceAvailable' and merged>=27,'end '..tostring(r.Code))
                print('[AdvanceGMPIE] PASS repeated money, 57 items, six levels, one merge per click, exhausted; merges='..merged..' remaining='..before)
                return
            end
            merged=merged+1
            local after=#a:List(); assert(after<before,'no consumption')
            local replay=R.GMQuick(pc,'advance',tag..':'..i)
            assert(replay.NewKey==r.NewKey and #a:List()==after,'request replay')
        end
        error('did not terminate')
    end)
    local cleaned,cleanError=pcall(function()
        for _,x in ipairs(a:List()) do
            assert(x.EquippedSlot=='','cleanup unexpected equip')
            assert(a:Remove(x)==1,'cleanup item')
        end
        for slot=1,6 do Slots.SetSlotLevel(p,slot,levels[slot]) end
        for id,value in pairs({[8310084]=gold,[8310132]=diamond}) do
            local delta=value-a:Balance(id)
            if delta~=0 then assert(a:ChangeCurrency(id,delta)==math.abs(delta),'cleanup money') end
        end
        a:Refresh()
    end)
    a.List=list
    print('[AdvanceGMPIE] RESULT ok='..tostring(ok)..' cleanup='..tostring(cleaned)..' error='..tostring(err)..' cleanupError='..tostring(cleanError))
    assert(ok,err); assert(cleaned,cleanError)
    return merged
end
return T
