-- Saved UE DataTables are the only runtime configuration source.
-- Fixed contract: six major ranks, twelve stages, maximum strengthen level 180.
local C={GoldItemID=8310084,DiamondItemID=8310132}
local data={Ranks={},Rules={},ItemRows={},Items={}}
local attempted=false
local base='Asset/Data/Table/Customized/'
local loadErrors={}
local function err(report,code,value)
    report.Errors[#report.Errors+1]=code..':'..tostring(value or '')
end
local function integer(n,min,max)
    return type(n)=='number' and n==n and n==math.floor(n) and n>=min and n<=max
end
local function name(v)
    return type(v)=='string' and v~='' and v~='None'
end
local function routes(cfg,report,assetReady)
    local stages,seriesSlots={},{}
    for _,row in ipairs(cfg.ItemRows) do
        local stage=row.Series..':'..row.RankOrder
        if stages[stage] then err(report,'DuplicateStage',stage) end
        stages[stage]=true
        if seriesSlots[row.Series] and seriesSlots[row.Series]~=row.SlotIdx then err(report,'SeriesSlotMismatch',row.Series) end
        seriesSlots[row.Series]=row.SlotIdx
        if row.NextItemID then
            local dest=cfg.Items[row.NextItemID]
            if not dest or dest.Series~=row.Series or dest.SlotIdx~=row.SlotIdx or dest.RankOrder~=row.RankOrder+1 then
                err(report,'InvalidNext',row.ItemID)
            end
        elseif row.RankOrder<12 then
            report.Missing[#report.Missing+1]=row.Series..':'..cfg.Ranks[row.RankOrder+1].RankID
        end
        local visited,cursor={},row
        while cursor do
            if visited[cursor.ItemID] then err(report,'Cycle',row.ItemID); break end
            visited[cursor.ItemID]=true; cursor=cfg.Items[cursor.NextItemID]
        end
        if assetReady then
            local ok,ready=pcall(assetReady,row.ItemID)
            if not ok or not ready then err(report,'AssetMissing',row.ItemID) end
        end
    end
end
local function read(tableName)
    local path=base..tableName..'.'..tableName
    local raw=UGCGameSystem.GetTableData(UGCGameSystem.GetUGCResourcesFullPath(path))
    assert(type(raw)=='table' or type(raw)=='userdata','TableMissing:'..tableName)
    -- Native UGC returns a pairs-compatible TableStruct userdata, not a Lua table.
    local rows={}
    for key,row in pairs(raw) do rows[tostring(key)]=row end
    assert(next(rows)~=nil,'TableEmpty:'..tableName)
    return rows
end
local function load()
    local report={Errors={},Missing={}}
    local cfg={Ranks={},Rules={},ItemRows={},Items={}}
    local rankRows,ruleRows,itemRows=read('EquipAdvanceRank'),read('EquipAdvanceRule'),read('EquipAdvanceItem')
    local byRank={}; local count=0
    for key,row in pairs(rankRows) do
        count=count+1
        local id,order=row.RankID,row.Order
        if not name(id) or tostring(key)~=id or not integer(order,1,12)
            or not name(row.DisplayName) or not integer(row.Cap,1,180)
            or not integer(row.RecycleParts,0,2147483647) then
            err(report,'InvalidRankRow',key)
        elseif byRank[id] or cfg.Ranks[order] then err(report,'DuplicateRankOrOrder',key)
        else
            local major=order<=3 and order or 4+math.floor((order-4)/3)
            local minor=order<=3 and 0 or (order-4)%3
            if row.Major~=major or row.Minor~=minor then err(report,'InvalidMajorMinor',key) end
            local rank={RankID=id,Order=order,Name=row.DisplayName,Major=row.Major,Minor=row.Minor,
                Cap=row.Cap,RecycleParts=row.RecycleParts}
            cfg.Ranks[order]=rank; byRank[id]=rank
        end
    end
    if count~=12 then err(report,'RankCount',count) end
    for i=1,12 do
        if not cfg.Ranks[i] then err(report,'MissingRankOrder',i)
        elseif i>1 and cfg.Ranks[i-1] and cfg.Ranks[i].Cap<=cfg.Ranks[i-1].Cap then err(report,'NonIncreasingCap',i) end
    end
    if cfg.Ranks[12] and cfg.Ranks[12].Cap~=180 then err(report,'TerminalCapMustBe180',cfg.Ranks[12].Cap) end
    count=0
    for key,row in pairs(ruleRows) do
        count=count+1
        local rank=byRank[row.RankID]
        if not rank or rank.Order==12 or tostring(key)~=row.RankID
            or not integer(row.Materials,1,2147483647) or not integer(row.Gold,0,2147483647)
            or not integer(row.Diamond,0,2147483647) then err(report,'InvalidRuleRow',key)
        elseif cfg.Rules[rank.Order] then err(report,'DuplicateRule',key)
        else cfg.Rules[rank.Order]={Materials=row.Materials,Gold=row.Gold,Diamond=row.Diamond} end
    end
    if count~=11 then err(report,'RuleCount',count) end
    for i=1,11 do if not cfg.Rules[i] then err(report,'MissingRuleOrder',i) end end
    for key,row in pairs(itemRows) do
        local rank=byRank[row.RankID]
        if not integer(row.ItemID,1,2147483647) or tostring(key)~=tostring(row.ItemID)
            or not name(row.Series) or not integer(row.SlotIdx,1,6) or not rank
            or not integer(row.NextItemID,0,2147483647) then err(report,'InvalidItemRow',key)
        elseif cfg.Items[row.ItemID] then err(report,'DuplicateItemID',row.ItemID)
        else
            local item={ItemID=row.ItemID,Series=row.Series,SlotIdx=row.SlotIdx,RankID=row.RankID,
                RankOrder=rank.Order,NextItemID=row.NextItemID~=0 and row.NextItemID or nil}
            cfg.ItemRows[#cfg.ItemRows+1]=item; cfg.Items[item.ItemID]=item
        end
    end
    -- Resolve cross-table links only after all basic rows are valid.
    if #report.Errors==0 then routes(cfg,report) end
    table.sort(cfg.ItemRows,function(a,b) return a.ItemID<b.ItemID end)
    return cfg,report
end
local function ensureLoaded()
    if attempted then return end
    attempted=true
    local ok,cfg,report=pcall(load)
    if ok and #report.Errors==0 then
        data=cfg
    else
        loadErrors=ok and report.Errors or {'TableReadFailed:'..tostring(cfg)}
        for _,value in ipairs(loadErrors) do print('[EquipAdvanceConfig] DISABLED '..value) end
    end
end
function C.Validate(assetReady)
    ensureLoaded()
    local report={Errors={},Missing={}}
    for _,value in ipairs(loadErrors) do report.Errors[#report.Errors+1]=value end
    if #report.Errors==0 then routes(C,report,assetReady) end
    return report
end
-- LuaCheck imports every script without a running world/resource mount. Do not
-- call native APIs on import; existing field access triggers one runtime load.
return setmetatable(C,{__index=function(_,key)
    if data[key]~=nil then ensureLoaded(); return data[key] end
end})
