local Suite={}
function Suite.Run()
    local T=require('Script.Blueprint.Prefabs.UI.Equip.EquipStrengthenTransaction')
    local fees={{ID=1001,Cost=100,ShortCode='NotEnoughGold'},{ID=1002,Cost=1,ShortCode='NotEnoughDiamond'}}
    local function fixture()
        local a={Balances={[1001]=1000,[1002]=10},Value=10,Queue={},Locked=false}
        function a:Begin() if self.Locked or self.Recovery then return false end; self.Locked=true; return true end
        function a:Finish() self.Locked=false end
        function a:Balance(id) return self.Balances[id] end
        function a:Change(id,delta,done) self.Queue[#self.Queue+1]={ID=id,Delta=delta,Done=done} end
        function a:Level() return self.Value end
        function a:SetLevel(level) self.Value=level; return not self.FailLevel end
        function a:AfterCommit() self.Refreshed=true end
        function a:RecordRecovery(record) self.Recovery=record end
        function a:Flush(ok,n)
            local job=table.remove(self.Queue,1); n=n or math.abs(job.Delta)
            self.Balances[job.ID]=self.Balances[job.ID]+(job.Delta<0 and -n or n)
            job.Done(ok~=false,n); job.Done(ok~=false,n)
        end
        return a
    end
    local total=0
    local function test(name,fn) fn(); total=total+1; print('PASS strengthen '..name) end
    test('levels wait for both async fees and concurrent operation is busy',function()
        local a=fixture(); local result
        assert(T.Run(a,10,11,fees,function(r) result=r end).Code=='Pending')
        assert(T.Run(a,10,11,fees).Code=='CurrencyBusy')
        a:Flush(); assert(a.Value==10 and not result); a:Flush()
        assert(result.OK and a.Value==11 and a.Refreshed and not a.Locked)
    end)
    test('second fee failure waits for refund and keeps original level',function()
        local a=fixture(); local result; T.Run(a,10,11,fees,function(r) result=r end)
        a:Flush(); a:Flush(false,0); assert(a.Locked and not result)
        a:Flush(); assert(result.Code=='TransactionFailed' and a.Balances[1001]==1000 and a.Value==10)
    end)
    test('level write failure after mutation compensates both currencies and level',function()
        local a=fixture(); a.FailLevel=true; local result
        T.Run(a,10,11,fees,function(r) result=r end); a:Flush(); a:Flush()
        -- Native setter may report failure after writing; restoring the value must be read back.
        a.FailLevel=false; a:Flush(); a:Flush()
        assert(result.Code=='RecoveryRequired' and a.Value==10 and a.Balances[1001]==1000 and a.Balances[1002]==10)
    end)
    test('uncompensated refund blocks future writers with recovery evidence',function()
        local a=fixture(); local result; T.Run(a,10,11,fees,function(r) result=r end)
        a:Flush(); a:Flush(false,0); a:Flush(false,0)
        assert(result.Code=='RecoveryRequired' and a.Recovery and not a.Locked)
        assert(T.Run(a,10,11,fees).Code=='CurrencyBusy')
    end)
    test('short balance and read errors perform no debit',function()
        for _,mode in ipairs({'short','read'}) do
            local a=fixture(); a.Balances[1001]=99
            if mode=='read' then function a:Balance() error('native read failed') end end
            assert(not T.Run(a,10,11,fees).OK and #a.Queue==0 and not a.Locked and a.Value==10)
        end
    end)
    print('EquipStrengthenTransaction: '..total..' tests passed'); return total
end
return Suite
