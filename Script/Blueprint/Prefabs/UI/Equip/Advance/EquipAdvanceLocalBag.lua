-- 升阶面板的背包读取：与装备预览页、槽位强化页完全相同的取背包逻辑。
-- EquipSlotSystem.CollectBagEquipItems(PC) 在客户端本地把背包读成 Lua 表，
-- 不再走 ServerRPC_EquipAdvanceSnapshot → Client_EquipAdvanceResult 的整包回传：
-- 背包物品一多，整包快照塞进单条 RPC 会超出传输上限，客户端直接崩溃。
-- 事务仍然服务端权威——Preview/Commit 只回传实例 Key 与少量字段，负载与背包大小无关。
local System=require('Script.Blueprint.Prefabs.UI.Equip.EquipSlotSystem')
local Guard=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceGuard')
local D=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceData')
local C=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceConfig')
local Currency=require('Script.Blueprint.Prefabs.UI.Equip.EquipCurrency')
local M={State=setmetatable({},{__mode='k'})}
local function read(fn,default)
    local ok,value=pcall(fn)
    if not ok or value==nil then return default end
    return value
end
local function flag(value) return value and '1' or '0' end
-- 挂载判定与 EquipAdvanceRuntime.A:Record 同语义：背包格子的装备槽不算挂载。
-- 客户端拿不到原生挂载信息时按“未挂载”处理，服务端 Build 仍会拒绝并给出 MaterialProtected。
local function attached(PC,id)
    local ok,target,parent=pcall(function() return UGCItemSystemV2.GetAttachTargetItem(id) end)
    local result=false
    if ok and target==true and parent then
        local specific=read(function() return parent.TypeSpecificID end,0)
        result=(specific or 0)~=0
    end
    if not result then
        local okc,children=pcall(function() return UGCItemSystemV2.GetAttachChildrenItem(id) end)
        if okc then
            pcall(function()
                for _,child in pairs(children or {}) do
                    local specific=child and read(function() return child.TypeSpecificID end,0) or 0
                    if (specific or 0)~=0 then result=true; break end
                end
            end)
        end
    end
    return result
end
---@param PC APlayerController|nil 省略则取本地 Controller，与另外两个页面一致
---@return table 与 Runtime.UISnapshot 同形状的只读快照（OK/Code/Items/Levels/GoldHave/DiamondHave/Blocked/Revision）
function M.Collect(PC)
    PC=PC or System.GetLocalPC()
    if not PC then return {OK=false,Code='ReadFailed',Items={},Levels={}} end
    local pawn=read(function() return PC:GetPlayerCharacterSafety() end)
    local collected=read(function() return System.CollectBagEquipItems(PC) end,{}) or {}
    local records,seen={},{}
    for _,entry in ipairs(collected) do
        local id=entry.DefineID
        local key=id and Guard.Key(id) or nil
        local itemID=entry.ItemID or System.GetDefineItemID(id)
        if key and itemID and not seen[key] then
            seen[key]=true
            records[#records+1]={Key=key,DefineID=id,ItemID=itemID,
                CustomData=read(function() return UGCItemSystemV2.LoadItemCustomData(id) end,{}) or {},
                CustomDataSize=read(function() return UGCItemSystemV2.GetItemCustomDataSize(id) end,0) or 0,
                Count=read(function() return UGCBackpackSystemV2.GetItemCountByDefineIDV2(PC,id) end,0) or 0,
                EquippedSlot=(entry.SlotName~='' and entry.SlotName
                    or read(function() return UGCBackpackSystemV2.GetItemEquippingSlot(PC,id) end,'')) or '',
                Attached=attached(PC,id)}
        end
    end
    table.sort(records,function(x,y) return x.Key<y.Key end)
    local rows,parts={},{}
    for _,x in ipairs(records) do
        local row=D.ProjectRow(x,C.Items[x.ItemID])
        -- 本地专有字段：这份快照不再进 RPC，带 DefineID 才能与背包格子的原生接口继续通信。
        row.DefineID=x.DefineID
        rows[#rows+1]=row
        parts[#parts+1]=table.concat({row.Key,row.ItemID,row.SlotIdx,row.RankOrder,row.EquippedSlot,
            x.Count,x.CustomDataSize,flag(x.Attached),flag(row.AllowedMaterial),flag(row.SafeAuto),
            flag(row.Locked),flag(row.HasInvestment)},',')
    end
    local levels={}
    for i=1,6 do levels[i]=System.GetSlotLevel(nil,i,pawn) end
    local gold=read(function() return Currency.Balance(PC,C.GoldItemID) end,0)
    local diamond=read(function() return Currency.Balance(PC,C.DiamondItemID) end,0)
    local blocked=read(function() return Currency.GetRecovery(PC) end)~=nil
    local state=M.State[PC]
    if not state then state={Revision=0}; M.State[PC]=state end
    -- 指纹只用稳定实例 Key 与投影字段（已按 Key 排序），不含每次新建的 DefineID userdata 地址，
    -- 否则不变的背包每次轮询都会失效预览与二次确认。
    parts[#parts+1]=table.concat({levels[1],levels[2],levels[3],levels[4],levels[5],levels[6],
        gold,diamond,flag(blocked)},',')
    local fingerprint=table.concat(parts,';')
    if fingerprint~=state.Fingerprint then
        state.Fingerprint=fingerprint; state.Revision=state.Revision+1
    end
    return {OK=true,Code='Snapshot',Items=rows,Levels=levels,Blocked=blocked,
        GoldHave=gold,DiamondHave=diamond,Revision=state.Revision,LocalBag=true,RowCount=#rows}
end
function M.Reset(PC)
    if PC then M.State[PC]=nil; return end
    M.State=setmetatable({},{__mode='k'})
end
return M
