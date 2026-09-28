-- Inert during LuaCheck. Run explicitly through the offline Python harness.
local T={}
function T.Run()
    local M=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceViewModel')
    local D=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceData')
    local n=0
    local function test(name,fn) fn(); n=n+1; print('PASS UI '..name) end
    local function item(key,id,safe,allowed)
        return {Key=key,ItemID=id,RankOrder=id==8310102 and 5 or 1,SlotIdx=4,
            SafeAuto=safe==true,AllowedMaterial=allowed~=false,EquippedSlot=''}
    end
    local function state(id)
        local m=M.New()
        m:ApplySnapshot({OK=true,Revision=1,GoldHave=10000,DiamondHave=100,Levels={180,180,180,180,180,180},Items={
            item('a',id,true),item('b',id,true),item('c',id,false),item('d',id,true,false),item('other',8310093,true)}})
        return m
    end
    local function preview(m,request,now,confirm)
        assert(m:BeginPreview(request))
        assert(m:AcceptPreview({OK=true,Code='Ready',ClientRequestID=request,Token='token:'..request,
            RequiresConfirmation=confirm==true},now))
    end
    test('low rank auto selection is exact ID and excludes invested or protected',function()
        local m=state(8310131); assert(m:SelectTarget('a'))
        assert(#m.Materials==1 and m.Materials[1]=='b')
        assert(not m:CanSubmit(10)); preview(m,'p',10)
        assert(m:CanSubmit(10)); assert(m:StartCommit('commit',10)=='token:p')
        assert(not m:SelectTarget('b') and not m:CanSubmit(11))
    end)
    test('purple manual materials, exact count, two step confirmation',function()
        local m=state(8310102); m:SelectTarget('a'); assert(#m.Materials==0)
        assert(not m:ToggleMaterial('a') and not m:ToggleMaterial('other') and not m:ToggleMaterial('d'))
        assert(m:ToggleMaterial('b')); assert(not m:BeginPreview('short'))
        assert(m:ToggleMaterial('c')); preview(m,'p',1,true)
        assert(m:StartCommit('first',2)==nil and m.ConfirmArmed)
        assert(m:StartCommit('second',3)=='token:p')
    end)
    test('stale and unsolicited replies never enable the button',function()
        local m=state(8310131); m:SelectTarget('a'); m:BeginPreview('old')
        m:SelectTarget('b'); m:BeginPreview('new')
        assert(not m:AcceptPreview({OK=true,ClientRequestID='old',Token='old'},10))
        assert(not m:CanSubmit(10))
        assert(m:AcceptPreview({OK=true,Code='Ready',ClientRequestID='new',Token='new'},10))
        assert(not m:AcceptPreview({OK=true,Token='gm'},10))
        assert(not m:AcceptCommit({OK=true,NewKey='bad'}))
    end)
    test('money, threshold, missing route and unsupported item disable submission',function()
        local m=state(8310131); m:SelectTarget('a')
        m.Snapshot.Levels[3]=9; assert(m:LocalCode()=='LevelTooLow')
        m.Snapshot.Levels[3]=10; m.Snapshot.GoldHave=99; assert(m:LocalCode()=='NotEnoughGold')
        m:SelectTarget('other'); assert(m:LocalCode()=='NextItemMissing')
        m.Items[#m.Items+1]=item('legacy',999); m.ByKey.legacy=m.Items[#m.Items]
        m:SelectTarget('legacy'); assert(m:LocalCode()=='UnsupportedItem')
    end)
    test('snapshot changes invalidate confirmation and prune unavailable materials',function()
        local m=state(8310102);m:SelectTarget('a');m:ToggleMaterial('b');m:ToggleMaterial('c')
        preview(m,'p',1,true);m:StartCommit('x',2)
        local s=D.Copy(m.Snapshot);s.Revision=2
        for _,x in ipairs(s.Items) do if x.Key=='b' then x.AllowedMaterial=false end end
        assert(m:ApplySnapshot(s));assert(not m.ConfirmArmed and not m.Preview and #m.Materials==1)
    end)
    test('unchanged snapshot retains preview, expiry disables it',function()
        local m=state(8310131);m:SelectTarget('a');preview(m,'p',10)
        assert(not m:ApplySnapshot(D.Copy(m.Snapshot)))
        assert(m:CanSubmit(11) and not m:CanSubmit(121))
    end)
    test('commit timeout retains identical token/request, replayed response ignored',function()
        local m=state(8310131);m:SelectTarget('a');preview(m,'p',1);m:StartCommit('same',2)
        assert(m.CommitRequest=='same' and m.CommitToken=='token:p')
        assert(m:StartCommit('new',50)==nil and m.CommitRequest=='same')
        assert(m:AcceptCommit({OK=true,Code='Advanced',ClientRequestID='same',NewKey='next'}))
        assert(not m:AcceptCommit({OK=true,ClientRequestID='same',NewKey='next'}))
        local s=D.Copy(m.Snapshot);s.Revision=2;s.Items={item('next',8310130)}
        m:ApplySnapshot(s);assert(m.TargetKey=='next' and not m.PendingNewKey)
    end)
    test('rollback remaps target and recovery remains blocked',function()
        local m=state(8310131);m:SelectTarget('a');preview(m,'p',1);m:StartCommit('r',2)
        m:AcceptCommit({OK=false,Code='TransactionFailed',ClientRequestID='r',RestoredKeys={a='restored'}})
        assert(m.TargetKey=='restored' and #m.Materials==0 and m.NoticeOK==false)
        m.CommitRequest='r2'
        m:AcceptCommit({OK=false,Code='RecoveryRequired',ClientRequestID='r2'})
        assert(m:LocalCode()=='RecoveryRequired')
    end)
    test('material mode retains distinct instances and excludes target',function()
        local m=state(8310102);m:SelectTarget('a');m.MaterialMode=true
        local rows=m:VisibleItems();assert(#rows==3)
        for _,x in ipairs(rows) do assert(x.Key~='a' and x.ItemID==8310102) end
    end)
    print('EquipAdvanceUI: '..n..' tests passed')
end
return T
