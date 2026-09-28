-- Shared client bridge for the advancement panel and existing GM commands.
local M={Sequence=0,Listeners={}}
function M.NewRequestID()
    M.Sequence=M.Sequence+1
    return 'ui:'..tostring(os.time())..':'..M.Sequence
end
function M.Subscribe(key,callback) M.Listeners[key]=callback end
function M.Unsubscribe(key) M.Listeners[key]=nil end
local function log(value,prefix,depth)
    if depth>5 then return end
    if type(value)~='table' then print(prefix..tostring(value)); return end
    local keys={}; for k in pairs(value) do keys[#keys+1]=k end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    for _,k in ipairs(keys) do log(value[k],prefix..tostring(k)..'.',depth+1) end
end
function M.Receive(result)
    if result.Kind=='Snapshot' then M.LastSnapshot=result else M.LastResult=result end
    if result.Kind=='Preview' then M.LastPreview=result.OK and result or nil end
    if result.Kind=='Commit' and result.Code~='ConfirmationRequired' then M.LastPreview=nil end
    if result.Kind~='Snapshot' or not result.OK then
        print('[EquipAdvance] '..tostring(result.Kind)..' '..tostring(result.Code)..' OK='..tostring(result.OK))
    end
    if result.Kind=='GM' then
        if result.Code=='NoAdvanceAvailable' then
            print('[EquipAdvance] 当前背包没有满足条件的升阶组合。请查看Reasons：材料、等级、货币或下一阶配置不足。')
        elseif result.Code=='Advanced' then
            M.LastPreview=nil
            print('[EquipAdvance] 已合成一次，下一阶ItemID='..tostring(result.NewItemID)..'；可继续点击自动合成。')
        elseif result.Code=='GMQuickEquipmentAdded' or result.Code=='GMQuickEquipmentPartial' then
            print('[EquipAdvance] 本次已添加装备 '..tostring(result.Added)..'/'..tostring(result.Planned)..' 件。')
        end
    end
    if result.Kind~='Snapshot' then log(result,'[EquipAdvance] ',0) end
    if M.OnResult then pcall(M.OnResult,result) end
    for _,callback in pairs(M.Listeners) do
        local ok,err=pcall(callback,result)
        if not ok then print('[EquipAdvance] UI callback error: '..tostring(err)) end
    end
end
local function call(name,...)
    local pc=UGCGameSystem.GetLocalPlayerController()
    if pc then UnrealNetwork.CallUnrealRPC(pc,pc,name,...) end
end
function M.Preview(target,materials) call('ServerRPC_EquipAdvancePreview',target,materials) end
function M.Snapshot(request) call('ServerRPC_EquipAdvanceSnapshot',request) end
function M.PreviewForUI(target,materials,request) call('ServerRPC_EquipAdvancePreview',target,materials,request) end
function M.CommitForUI(token,request,confirmed) call('ServerRPC_EquipAdvanceCommit',token,request,confirmed==true) end
function M.Confirm(confirmed)
    if not M.LastPreview then print('[EquipAdvance] 请先预览成功'); return end
    M.Sequence=M.Sequence+1
    local request=M.LastPreview.Token..':client:'..M.Sequence
    call('ServerRPC_EquipAdvanceCommit',M.LastPreview.Token,request,confirmed==true)
end
function M.GM(action,args) call('ServerRPC_EquipAdvanceGM',action,args or {}) end
function M.Quick(action)
    M.Sequence=M.Sequence+1
    M.GM('quick',{action,tostring(os.time())..':'..M.Sequence})
end
return M
