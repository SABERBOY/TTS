-- Official virtual currency gateway. No native calls during LuaCheck/import.
local M={GoldItemID=1001,DiamondItemID=1002,
    TablePath='Asset/Data/Table/UGCObject.UGCObject',Owners=setmetatable({},{__mode='k'}),RecoveryByUID={}}
local definitions
local function integer(n) return type(n)=='number' and n==n and n>=0 and n<=2147483647 and n==math.floor(n) end
function M.Controller(player)
    if not player then return nil end
    if CheckObjectContainsField(player,'GetPlayerCharacterSafety',true) then return player end
    return UGCGameSystem.GetPlayerControllerByPlayerPawn(player)
end
function M.GetManager()
    assert(UGCGamePartSystem.IsGamePartLoaded('VirtualItemManager'),'VirtualCurrencyNotReady')
    local manager=UGCGamePartSystem.GetGamePartGlobalActor('VirtualItemManager')
    assert(manager,'VirtualCurrencyNotReady')
    return manager
end
function M.Definitions()
    if definitions then return definitions end
    local rows=UGCGameSystem.GetTableData(UGCGameSystem.GetUGCResourcesFullPath(M.TablePath))
    assert(rows,'VirtualCurrencyTableMissing')
    local found={}
    for _,row in pairs(rows) do
        if row.ItemID==M.GoldItemID or row.ItemID==M.DiamondItemID then
            assert(not found[row.ItemID],'DuplicateVirtualCurrency')
            found[row.ItemID]={ItemID=row.ItemID,Name=row.ItemName}
        end
    end
    assert(found[M.GoldItemID] and found[M.DiamondItemID],'VirtualCurrencyDefinitionMissing')
    definitions=found; return definitions
end
function M.GetData(id)
    assert(M.Definitions()[id],'UnknownVirtualCurrency')
    local data=M.GetManager():GetItemData(id)
    assert(data,'VirtualCurrencyNotReady')
    return data
end
function M.Balance(player,id)
    local pc=M.Controller(player); assert(pc,'VirtualCurrencyPlayerMissing')
    M.GetData(id)
    local n=M.GetManager():GetItemNum(id,pc)
    assert(integer(n),'VirtualCurrencyBalanceInvalid')
    return n
end
function M.TryBalance(player,id)
    local ok,value=pcall(M.Balance,player,id)
    if ok then return value end
    return nil,tostring(value)
end
function M.Acquire(player,owner)
    local pc=M.Controller(player)
    if not pc or not owner or M.Owners[pc] or M.GetRecovery(pc) then return false end
    M.Owners[pc]=owner; return true
end
function M.GetRecovery(player)
    local pc=M.Controller(player); if not pc then return nil end
    local uid=UGCGameSystem.GetUIDByPlayerController(pc)
    assert(uid and uid~=0,'VirtualCurrencyPlayerMissing')
    local key=tostring(uid)
    if M.RecoveryByUID[key] then return M.RecoveryByUID[key] end
    local archive=UGCPlayerStateSystem.GetPlayerArchiveData(uid)
    local record=archive and (archive.EquipCurrencyRecovery or archive.EquipAdvanceRecovery)
    if record then M.RecoveryByUID[key]=record end
    return record
end
function M.Block(player,record)
    local pc=M.Controller(player); local uid=UGCGameSystem.GetUIDByPlayerController(pc)
    assert(uid and uid~=0,'VirtualCurrencyPlayerMissing')
    M.RecoveryByUID[tostring(uid)]=record
    local archive=UGCPlayerStateSystem.GetPlayerArchiveData(uid) or {}
    archive.EquipCurrencyRecovery=record
    assert(UGCPlayerStateSystem.SavePlayerArchiveData(uid,archive)~=false,'CurrencyRecoverySaveFailed')
end
function M.Release(player,owner)
    local pc=M.Controller(player)
    if pc and M.Owners[pc]==owner then M.Owners[pc]=nil end
end
function M.IsBusy(player) return M.Owners[M.Controller(player)]~=nil end
-- Callback owns completion, even if the official RemoveItem result is deferred.
-- A failed native result can still have changed balance; callers compensate by snapshot.
function M.ChangeAsync(player,id,delta,done,owner)
    local pc=M.Controller(player); local held=owner~=nil; owner=owner or {}
    if not pc or type(delta)~='number' or not integer(math.abs(delta)) or not UGCGameSystem.IsServer() then done(false,0,'InvalidCurrencyRequest'); return end
    if held and M.Owners[pc]~=owner or not held and not M.Acquire(pc,owner) then done(false,0,'CurrencyBusy'); return end
    local settled=false
    local function finish(ok,n,reason)
        if settled then return end
        settled=true
        if not held then M.Release(pc,owner) end
        if ok then reason=nil end
        done(ok,n,reason)
    end
    local before
    local ok,err=pcall(function()
        local manager=M.GetManager(); before=M.Balance(pc,id)
        if delta==0 then finish(true,0); return end
        if delta>0 then
            local accepted=manager:AddVirtualItem(pc,id,delta,'equipment:'..id)
            local after=M.Balance(pc,id)
            finish(accepted==true and after==before+delta,math.max(0,after-before),'CurrencyAddFailed')
        else
            if before < -delta then finish(false,0,'NotEnoughCurrency'); return end
            manager:RemoveItem(pc,id,-delta,function(result)
                local read,after=pcall(M.Balance,pc,id)
                local n=read and math.max(0,before-after) or 0
                finish(read and result and result.bSucceeded==true and n==-delta,n,'CurrencyRemoveFailed')
            end)
        end
    end)
    if not ok then finish(false,0,tostring(err)) end
end
-- Convenience for immediate completion (GM additions/tests). Production spending uses callbacks.
function M.Change(player,id,delta,owner)
    local value,reason
    M.ChangeAsync(player,id,delta,function(ok,n,why) value=ok and n or 0; reason=why end,owner)
    return value,reason
end
return M
