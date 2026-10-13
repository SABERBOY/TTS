-- Offline only, explicit Run. Native API stubs never become production fallback.
local T={}
function T.Run()
    local M=require('Script.Blueprint.Prefabs.UI.Equip.EquipCurrency')
    local oldSystem,oldParts,oldArchive,oldCheck=UGCGameSystem,UGCGamePartSystem,UGCPlayerStateSystem,CheckObjectContainsField
    local pc={IsPC=true}; local pawn={}; local server,loaded=true,true
    local archive={}; local manager={Amounts={[1001]=1000,[1002]=10},Queue={}}
    CheckObjectContainsField=function(x) return x.IsPC==true end
    UGCPlayerStateSystem={GetPlayerArchiveData=function() return archive end,
        SavePlayerArchiveData=function(_,value) archive=value; return true end}
    UGCGameSystem={IsServer=function() return server end,GetUIDByPlayerController=function() return 99 end,
        GetPlayerControllerByPlayerPawn=function(x) assert(x==pawn); return pc end,
        GetUGCResourcesFullPath=function(path) return '/TTS/'..path end,
        GetTableData=function(path)
            assert(path=='/TTS/Asset/Data/Table/UGCObject.UGCObject')
            return {['1001']={ItemID=1001,ItemName='金币'},['1002']={ItemID=1002,ItemName='钻石'}}
        end}
    UGCGamePartSystem={IsGamePartLoaded=function() return loaded end,GetGamePartGlobalActor=function() return manager end}
    function manager:GetItemData(id) return {ItemID=id,ItemIcon='virtual-icon'} end
    function manager:GetItemNum(id,player) assert(player==pc); return self.Amounts[id] end
    function manager:AddVirtualItem(player,id,num) assert(player==pc); self.Amounts[id]=self.Amounts[id]+num; return true end
    function manager:RemoveItem(player,id,num,done) self.Queue[#self.Queue+1]={ID=id,Num=num,Done=done} end
    local total=0
    local function test(name,fn) fn(); total=total+1; print('PASS currency '..name) end
    local ok,err=pcall(function()
        test('official definitions and pawn/controller balance route',function()
            assert(M.GoldItemID==1001 and M.DiamondItemID==1002 and M.Balance(pawn,1001)==1000)
            assert(M.GetData(1002).ItemIcon=='virtual-icon' and M.Change(pc,1002,3)==3)
        end)
        test('pending native removal blocks concurrent additions and duplicate callbacks',function()
            local callbacks=0
            M.ChangeAsync(pc,1001,-100,function(success,n) assert(success and n==100); callbacks=callbacks+1 end)
            assert(M.IsBusy(pc) and callbacks==0 and M.Change(pc,1002,1)==0)
            local job=table.remove(manager.Queue,1); manager.Amounts[1001]=900
            job.Done({bSucceeded=true}); job.Done({bSucceeded=true})
            assert(callbacks==1 and not M.IsBusy(pc))
        end)
        test('explicit transaction owner retains common lock through callback',function()
            local owner={}; assert(M.Acquire(pc,owner))
            local success
            M.ChangeAsync(pc,1001,-50,function(ok) success=ok end,owner)
            local job=table.remove(manager.Queue,1); manager.Amounts[1001]=850; job.Done({bSucceeded=true})
            assert(success and M.IsBusy(pc) and not M.Acquire(pc,{})); M.Release(pc,owner)
        end)
        test('failure after partial debit reports actual count for snapshot compensation',function()
            local result,n
            M.ChangeAsync(pc,1001,-100,function(ok,count) result,n=ok,count end)
            local job=table.remove(manager.Queue,1); manager.Amounts[1001]=810; job.Done({bSucceeded=false})
            assert(result==false and n==40 and M.Change(pc,1001,40)==40)
            local add=manager.AddVirtualItem
            manager.AddVirtualItem=function(self,player,id,num) add(self,player,id,num); return false end
            assert(M.Change(pc,1002,1)==0,'native rejected add must not report success')
            manager.AddVirtualItem=add
        end)
        test('manager not loaded, malformed input and client writes are rejected',function()
            loaded=false; assert(M.TryBalance(pc,1001)==nil); loaded=true
            for _,delta in ipairs({'bad',0/0,math.huge}) do
                M.ChangeAsync(pc,1001,delta,function(ok) assert(not ok) end)
            end
            server=false; assert(M.Change(pc,1001,100)==0); server=true
            assert(manager.Amounts[1001]==850 and not M.IsBusy(pc))
        end)
        test('uncompensated currency recovery survives archive read and blocks shared writers',function()
            M.Block(pc,{Kind='test',Balances={[1001]=850}})
            assert(not M.Acquire(pc,{}) and M.GetRecovery(pc).Kind=='test')
            M.RecoveryByUID={}; assert(not M.Acquire(pc,{}))
            archive={}; M.RecoveryByUID={}
        end)
    end)
    UGCGameSystem,UGCGamePartSystem,UGCPlayerStateSystem,CheckObjectContainsField=oldSystem,oldParts,oldArchive,oldCheck
    assert(ok,err); print('EquipCurrency: '..total..' tests passed'); return total
end
return T
