-- Explicit pure Lua tests; fixture is supplied by the Python runner, never production.
local T={}
function T.Run()
    local original=UGCGameSystem
    local earlyCalls=0
    UGCGameSystem={GetUGCResourcesFullPath=function() earlyCalls=earlyCalls+1; error('not ready') end}
    local delayed=EquipAdvanceReloadConfig()
    local slots=require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotSystem')
    UGCGameSystem=original
    assert(earlyCalls==0,'module import must not call native APIs during LuaCheck')
    assert(#delayed.Ranks==12,'first runtime access must load tables')
    assert(slots.GetRank(5).Name=='紫+1' and slots.GetRank(5).Cap==60,'slot metadata must sync at runtime')
    local function copy(v)
        if type(v)~='table' then return v end
        local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
    end
    local total=1
    local function test(name,edit,expectValid)
        local data=copy(EquipAdvanceTableFixture)
        if edit then edit(data) end
        UGCGameSystem={GetUGCResourcesFullPath=function(p) return '/TTS/'..p end,
            GetTableData=function(p)
                assert(p:match('^/TTS/'),'full path required')
                return data[p:match('%.([^%.]+)$')]
            end}
        local c=EquipAdvanceReloadConfig()
        local report=c.Validate()
        UGCGameSystem=original
        if expectValid then
            assert(#report.Errors==0,name)
            assert(#c.Ranks==12 and #c.Rules==11 and #c.ItemRows==39,name)
            assert(c.Items[8310102].RankOrder==5 and c.Items[8310102].NextItemID==8310101,name)
            assert(c.Items[8310129].NextItemID==nil and #report.Missing==12,name)
        else
            assert(#report.Errors>0,name..': invalid table must report errors')
            assert(next(c.Items)==nil and next(c.Ranks)==nil and next(c.Rules)==nil and #c.ItemRows==0,name..': atomic rejection')
        end
        total=total+1; print('PASS config '..name)
        return c
    end
    test('unsorted named rows normalize existing contract',nil,true)
    local c=test('table edits are authoritative',function(d)
        d.EquipAdvanceRule.R01_WHITE.Gold=137
        d.EquipAdvanceRank.R01_WHITE.DisplayName='白色测试'
    end,true)
    assert(c.Rules[1].Gold==137 and c.Ranks[1].Name=='白色测试','no hardcoded data fallback')
    test('missing table',function(d) d.EquipAdvanceRule=nil end,false)
    test('duplicate order',function(d) d.EquipAdvanceRank.R02_GREEN.Order=1 end,false)
    test('invalid rank reference',function(d) d.EquipAdvanceItem['8310102'].RankID='UNKNOWN' end,false)
    test('missing rule',function(d) d.EquipAdvanceRule.R02_GREEN=nil end,false)
    test('row name mismatch',function(d) d.EquipAdvanceItem['8310102'].ItemID=8310103 end,false)
    test('duplicate series stage',function(d) d.EquipAdvanceItem['8310113'].Series='EQ_GLOVE_02' end,false)
    test('rank skip',function(d) d.EquipAdvanceItem['8310102'].NextItemID=8310100 end,false)
    test('cross series',function(d) d.EquipAdvanceItem['8310102'].NextItemID=8310108 end,false)
    test('cycle',function(d) d.EquipAdvanceItem['8310101'].NextItemID=8310102 end,false)
    test('negative cost',function(d) d.EquipAdvanceRule.R01_WHITE.Gold=-1 end,false)
    test('zero material count',function(d) d.EquipAdvanceRule.R01_WHITE.Materials=0 end,false)
    test('invalid cap',function(d) d.EquipAdvanceRank.R01_WHITE.Cap=181 end,false)
    test('invalid slot',function(d) d.EquipAdvanceItem['8310102'].SlotIdx=7 end,false)
    test('invalid major minor',function(d) d.EquipAdvanceRank.R05_PURPLE_1.Minor=0 end,false)
    print('EquipAdvanceConfig: '..total..' tests passed')
    return total
end
return T
