-- Callback-based slot strengthening. Shares the advancement currency lock.
local T={}
function T.Run(a,current,target,fees,complete)
    local result,finished
    local function reply(r)
        if finished then return end; finished=true; result=r
        pcall(a.Finish,a)
        if complete then pcall(complete,r) end
    end
    local began,locked=pcall(a.Begin,a)
    if not began or not locked then
        result={OK=false,Code='CurrencyBusy'}
        if complete then pcall(complete,result) end
        return result
    end
    local function change(id,delta,done)
        local settled=false
        local function once(ok,n,why)
            if settled then return end; settled=true; done(ok,n,why)
        end
        local ok,why=pcall(a.Change,a,id,delta,once)
        if not ok then once(false,0,tostring(why)) end
    end
    local balances={}
    local short
    local checked,err=pcall(function()
        for _,fee in ipairs(fees) do
            balances[fee.ID]=a:Balance(fee.ID)
            if balances[fee.ID]<fee.Cost then short=fee.ShortCode; error(fee.ShortCode) end
        end
    end)
    if not checked then reply({OK=false,Code=short or 'CurrencyNotReady',Detail=tostring(err)}); return result end
    local function failed(reason)
        local errors={}
        local levelOK,levelError=pcall(function()
            if a:Level()~=current then assert(a:SetLevel(current),'RestoreLevelFailed') end
            assert(a:Level()==current,'RestoreLevelMismatch')
        end)
        if not levelOK then errors[#errors+1]=tostring(levelError) end
        local function restore(index)
            local fee=fees[index]
            if not fee then
                local record={Version=1,Kind='Strengthen',Level=current,Target=target,Balances=balances,Errors=errors}
                local saved=true
                if #errors>0 then saved=pcall(a.RecordRecovery,a,record) end
                reply({OK=false,Code=#errors==0 and 'TransactionFailed' or 'RecoveryRequired',
                    Detail=tostring(reason),RecoveryRecorded=saved})
                return
            end
            local read,delta=pcall(function() return balances[fee.ID]-a:Balance(fee.ID) end)
            if not read then errors[#errors+1]=tostring(delta); restore(index+1); return end
            local function verify(ok)
                local valid=pcall(function() assert(ok and a:Balance(fee.ID)==balances[fee.ID],'RestoreCurrencyFailed') end)
                if not valid then errors[#errors+1]='currency:'..fee.ID end
                restore(index+1)
            end
            if delta==0 then verify(true) else change(fee.ID,delta,verify) end
        end
        restore(1)
    end
    local function debit(index)
        local fee=fees[index]
        if not fee then
            local applied,applyError=pcall(function()
                assert(a:Level()==current,'LevelChanged')
                assert(a:SetLevel(target) and a:Level()==target,'SetLevelFailed')
            end)
            if not applied then failed(applyError); return end
            local saved,saveError=pcall(a.AfterCommit,a)
            reply({OK=true,Code='Strengthened',Level=target,RefreshPending=not saved,Detail=not saved and tostring(saveError) or nil})
            return
        end
        if fee.Cost==0 then debit(index+1); return end
        change(fee.ID,-fee.Cost,function(ok,n,why)
            local exact=pcall(function()
                assert(ok and n==fee.Cost and a:Balance(fee.ID)==balances[fee.ID]-fee.Cost,'CurrencyMismatch')
            end)
            if not exact then failed(why or 'CurrencyMismatch') else debit(index+1) end
        end)
    end
    debit(1)
    return result or {OK=false,Code='Pending'}
end
return T
