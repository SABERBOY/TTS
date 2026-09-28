-- Shared value helpers; no gameplay globals or mutable player state.
local D={}
function D.Copy(value)
    if type(value)~='table' then return value end
    local out={}; for k,v in pairs(value) do out[k]=D.Copy(v) end; return out
end
function D.Fingerprint(value)
    if type(value)~='table' then return type(value)..':'..tostring(value) end
    local keys={}; for k in pairs(value) do keys[#keys+1]=k end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    local out={}; for _,k in ipairs(keys) do
        local v=D.Fingerprint(value[k]); out[#out+1]=tostring(k)..':'..#v..':'..v
    end
    return '{'..table.concat(out,'|')..'}'
end
function D.IsProtected(record)
    local data=record.CustomData or {}; local state=data.EquipAdvance or {}
    return record.EquippedSlot~='' or record.Attached or state.Locked or state.Tracked
        or state.Reserved or state.InTrade or data.Locked or data.Tracked or data.Reserved or data.InTrade
end
function D.IsSafeAutoMaterial(record)
    local state=(record.CustomData or {}).EquipAdvance or {}
    -- Existing UI does not yet publish a reliable viewed flag. Unknown is not
    -- safe to auto-consume; explicit manual selection is still supported.
    return not D.IsProtected(record) and state.Viewed==true and not record.IsNew
        and (state.Gold or 0)==0 and (state.Diamond or 0)==0 and (state.MaterialParts or 0)==0
end
function D.ValidState(data)
    if type(data)~='table' then return false end
    local s=data.EquipAdvance
    if s==nil then return true end
    if type(s)~='table' or (s.Version~=nil and s.Version~=1) then return false end
    for _,name in ipairs({'Gold','Diamond','MaterialParts'}) do
        local n=s[name]
        if n~=nil and (type(n)~='number' or n~=n or n<0 or n>1e12 or n~=math.floor(n)) then return false end
    end
    for _,name in ipairs({'Locked','Tracked','Reserved','InTrade','Viewed'}) do
        if s[name]~=nil and type(s[name])~='boolean' then return false end
    end
    return true
end
return D
