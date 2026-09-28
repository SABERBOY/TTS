-- UI-independent client bridge. Future UIBP can read LastResult / subscribe OnResult.
local M={Sequence=0}
local function log(value,prefix,depth)
    if depth>5 then return end
    if type(value)~='table' then print(prefix..tostring(value)); return end
    local keys={}; for k in pairs(value) do keys[#keys+1]=k end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    for _,k in ipairs(keys) do log(value[k],prefix..tostring(k)..'.',depth+1) end
end
function M.Receive(result)
    M.LastResult=result
    if result.Kind=='Preview' then M.LastPreview=result.OK and result or nil end
    if result.Kind=='Commit' and result.Code~='ConfirmationRequired' then M.LastPreview=nil end
    print('[EquipAdvance] '..tostring(result.Kind)..' '..tostring(result.Code)..' OK='..tostring(result.OK))
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
    log(result,'[EquipAdvance] ',0)
    if M.OnResult then pcall(M.OnResult,result) end
end
local function call(name,...)
    local pc=UGCGameSystem.GetLocalPlayerController()
    if pc then UnrealNetwork.CallUnrealRPC(pc,pc,name,...) end
end
function M.Preview(target,materials) call('ServerRPC_EquipAdvancePreview',target,materials) end
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
