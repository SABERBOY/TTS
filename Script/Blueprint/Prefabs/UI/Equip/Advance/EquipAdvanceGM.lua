-- GM-only convenience operations. Runtime checks GM permission before dispatch.
-- Quick merge is an explicit GM confirmation, not normal safe auto-selection.
local C=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceConfig')
local D=require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceData')
local Q={}
function Q.Money(s)
    local added={}; local ok=true
    for _,entry in ipairs({{C.GoldItemID,100000},{C.DiamondItemID,1000}}) do
        local before=s.A:Balance(entry[1])
        local called=pcall(s.A.ChangeCurrency,s.A,entry[1],entry[2])
        local delta=s.A:Balance(entry[1])-before
        added[tostring(entry[1])]=delta
        ok=ok and called and delta==entry[2]
    end
    return {OK=ok,Code=ok and 'GMQuickMoneyAdded' or 'GMQuickMoneyPartial',Added=added}
end
function Q.Equipment(s)
    local plan={}; local total=0
    for _,row in ipairs(C.ItemRows) do
        local rule=C.Rules[row.RankOrder]
        if rule and row.NextItemID and C.Items[row.NextItemID] then
            plan[#plan+1]={ItemID=row.ItemID,Count=rule.Materials+1,Rank=row.RankOrder}
            total=total+rule.Materials+1
        end
    end
    table.sort(plan,function(a,b) return a.Rank<b.Rank or a.Rank==b.Rank and a.ItemID<b.ItemID end)
    local a=s.A; local keys={}; local pending
    s.Busy=true
    local ok,err=pcall(function()
        assert(a:Begin()~=false,'BeginFailed')
        for _,row in ipairs(plan) do
            assert(a:AssetReady(row.ItemID),'AssetUnavailable:'..row.ItemID)
            for _=1,row.Count do
                pending=a:Allocate(row.ItemID,{EquipAdvance={Version=1,Viewed=true}})
                assert(pending and a:Save(pending)==true,'SaveFailed')
                local n=a:Add(pending)
                if a:Count(pending)==1 then keys[#keys+1]=pending.Key; pending=nil end
                assert(n==1 and pending==nil,'BackpackFullOrAddFailed')
            end
        end
    end)
    -- Report actual additions even if a native call threw after adding an item.
    if pending then
        pcall(function() if a:Count(pending)==1 then keys[#keys+1]=pending.Key end end)
    end
    local finished,finishError=pcall(a.Finish,a)
    s.Busy=false
    return {OK=ok and finished,Code=ok and finished and 'GMQuickEquipmentAdded' or 'GMQuickEquipmentPartial',
        Added=#keys,Planned=total,Keys=keys,Detail=tostring(err or finishError)}
end
function Q.AdvanceOnce(s,request)
    if type(request)~='string' or #request==0 or #request>100 then return {OK=false,Code='InvalidRequest'} end
    request='gmquick:'..request
    if s.Requests[request] then return D.Copy(s.Requests[request].Result) end
    local items=s.A:List(); local groups={}; local reasons={}
    for _,x in ipairs(items) do
        if C.Items[x.ItemID] and x.Count==1 and not D.IsProtected(x) and D.ValidState(x.CustomData)
            and (not x.CustomDataSize or x.CustomDataSize<=512) then
            groups[x.ItemID]=groups[x.ItemID] or {}; table.insert(groups[x.ItemID],x)
        else reasons.ProtectedOrInvalid=(reasons.ProtectedOrInvalid or 0)+1 end
    end
    local ids={}; for id in pairs(groups) do ids[#ids+1]=id end
    table.sort(ids,function(a,b)
        local ra,rb=C.Items[a].RankOrder,C.Items[b].RankOrder
        return ra<rb or ra==rb and a<b
    end)
    for _,id in ipairs(ids) do
        local group=groups[id]; table.sort(group,function(a,b) return a.Key<b.Key end)
        local rule=C.Rules[C.Items[id].RankOrder]
        -- Let the normal service report missing routes/levels/balances too.
        for _,target in ipairs(group) do
            local materials={}
            for _,x in ipairs(group) do
                if x.Key~=target.Key and rule and #materials<rule.Materials then materials[#materials+1]=x.Key end
            end
            local p=s:Preview(target.Key,materials)
            if p.OK then
                -- Exactly one execution per click; never continue after a failed transaction.
                local r=s:Execute(p.Token,request,true)
                r.TargetItemID=id
                return r
            end
            reasons[p.Code]=(reasons[p.Code] or 0)+1
        end
    end
    return {OK=false,Code='NoAdvanceAvailable',Reasons=reasons}
end
return Q
