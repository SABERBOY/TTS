local R=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceRuntime')
local C=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceConfig')
local RPC={}
local function reply(pc,kind,fn)
    local ok,result=pcall(fn)
    if not ok then
        print('[EquipAdvance] '..kind..' error: '..tostring(result))
        result={OK=false,Code='ServerError'}
    end
    result.Kind=kind
    UnrealNetwork.CallUnrealRPC(pc,pc,'Client_EquipAdvanceResult',result)
    return result
end
function RPC.Preview(pc,target,materials)
    return reply(pc,'Preview',function()
        local s=R.GetService(pc)
        local result=s:Preview(target,materials)
        if result.Code=='ManualMaterialsRequired' or result.OK then result.Candidates=s:Candidates(target) end
        return result
    end)
end
function RPC.Commit(pc,token,request,confirmed)
    return reply(pc,'Commit',function() return R.GetService(pc):Execute(token,request,confirmed) end)
end
function RPC.GM(pc,action,args)
    return reply(pc,'GM',function()
        if not R.IsGM(pc) then return {OK=false,Code='GMForbidden'} end
        if type(args)~='table' then args={} end
        if action=='list' then return {OK=true,Code='List',Items=R.Summary(pc)}
        elseif action=='add' then return R.GMAdd(pc,args[1],args[2])
        elseif action=='level' then return R.GMLevel(pc,args[1],args[2])
        elseif action=='protect' then return R.GMProtect(pc,args[1],args[2],args[3])
        elseif action=='quick' then return R.GMQuick(pc,args[1],args[2])
        elseif action=='check' then
            local a=R.GetService(pc).A
            local report=C.Validate(function(id) return a:AssetReady(id) end)
            return {OK=#report.Errors==0,Code='ConfigCheck',Report=report}
        elseif action=='recovery' then
            local s=R.GetService(pc)
            return {OK=true,Code='RecoveryStatus',Blocked=s.Blocked==true,
                Recovery=s.Recovery and {RequestID=s.Recovery.RequestID,Errors=s.Recovery.Errors} or {}}
        end
        return {OK=false,Code='InvalidGMAction'}
    end)
end
return RPC
