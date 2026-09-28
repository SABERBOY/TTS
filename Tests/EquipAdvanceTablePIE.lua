-- Explicit server-only native test for saved DataTable configuration and costs.
local T={}
function T.Run(pc,expectedWhiteGold)
    local root='Script.Blueprint.Prefabs.UI.Equip.'
    local C=require(root..'Advance.EquipAdvanceConfig')
    local R=require(root..'Advance.EquipAdvanceRuntime')
    local Slots=require(root..'EquipSlotSystem')
    assert(R.IsGM(pc),'GM required')
    local s=R.GetService(pc); assert(not s.Busy and not s.Blocked,'service unavailable')
    local a=s.A; local p=pc:GetPlayerCharacterSafety(); assert(p,'pawn required')
    local report=C.Validate(function(id) return a:AssetReady(id) end)
    assert(#C.Ranks==12 and #C.Rules==11 and #C.ItemRows==39 and #report.Errors==0,'table contract')
    assert(#report.Missing==12 and C.Rules[1].Gold==expectedWhiteGold,'table value')
    local gold,diamond=a:Balance(8310084),a:Balance(8310132)
    local lv3,lv4=Slots.GetSlotLevel(nil,3,p),Slots.GetSlotLevel(nil,4,p)
    local tag='TableProbe:'..os.time()
    local function seed(id,n)
        local keys={}; a:Begin()
        local ok,err=pcall(function()
            for i=1,n do
                local x=a:Allocate(id,{AdvanceTableProbe=tag,EquipAdvance={Version=1,Viewed=true}})
                assert(a:Save(x) and a:Add(x)==1,'seed')
                keys[i]=x.Key
            end
        end)
        a:Finish(); assert(ok,err); return keys
    end
    local ok,err=pcall(function()
        assert(a:ChangeCurrency(8310084,10000)==10000 and a:ChangeCurrency(8310132,100)==100)
        Slots.SetSlotLevel(p,3,10); Slots.SetSlotLevel(p,4,60)
        local white=seed(8310131,2)
        local preview=s:Preview(white[1],{white[2]})
        assert(preview.OK and preview.Gold==expectedWhiteGold,'white preview')
        local before=a:Balance(8310084)
        local result=s:Execute(preview.Token,tag..':white',true)
        assert(result.OK and result.NewItemID==8310130,'white commit')
        assert(a:Balance(8310084)==before-expectedWhiteGold,'actual table cost')
        print('[AdvanceTablePIE] PASS white preview and debit='..expectedWhiteGold)
        local gloves=seed(8310102,3)
        preview=s:Preview(gloves[1],{gloves[2],gloves[3]})
        assert(preview.OK and preview.NextItemID==8310101 and preview.RequiredLevel==60
            and preview.Gold==650 and preview.Diamond==1 and #preview.MaterialKeys==2,'glove preview')
        before=a:Balance(8310084); local beforeDiamond=a:Balance(8310132)
        result=s:Execute(preview.Token,tag..':glove',true)
        assert(result.OK and result.NewItemID==8310101 and a:Balance(8310084)==before-650
            and a:Balance(8310132)==beforeDiamond-1,'glove commit')
        print('[AdvanceTablePIE] PASS 8310102 -> 8310101 materials=2 level=60 gold=650 diamond=1')
        local terminal=seed(8310129,1)[1]
        before=a:Balance(8310084); beforeDiamond=a:Balance(8310132)
        assert(s:Preview(terminal,{}).Code=='NextItemMissing','missing route')
        assert(a:Balance(8310084)==before and a:Balance(8310132)==beforeDiamond,'missing route no debit')
        print('[AdvanceTablePIE] PASS missing next stage has zero debit; all 39 assets valid')
    end)
    local clean,cleanError=pcall(function()
        for _,x in ipairs(a:List()) do
            if x.CustomData.AdvanceTableProbe==tag then
                assert(x.EquippedSlot=='','unexpected equip'); assert(a:Remove(x)==1,'cleanup equipment')
            end
        end
        Slots.SetSlotLevel(p,3,lv3); Slots.SetSlotLevel(p,4,lv4)
        for id,value in pairs({[8310084]=gold,[8310132]=diamond}) do
            local delta=value-a:Balance(id)
            if delta~=0 then assert(a:ChangeCurrency(id,delta)==math.abs(delta),'cleanup currency') end
        end
        a:Refresh()
    end)
    print('[AdvanceTablePIE] RESULT cost='..expectedWhiteGold..' ok='..tostring(ok)..' cleanup='..tostring(clean)
        ..' error='..tostring(err)..' cleanupError='..tostring(cleanError))
    assert(ok,err); assert(clean,cleanError)
end
return T
