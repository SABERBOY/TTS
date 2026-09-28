-- Only the newly allocated instances of an active transaction skip auto-equip.
-- CanAutoEquip does not affect explicit EquipItemV2 calls.
local G={Suppressed={}}
function G.Key(id)
    if id==nil or type(id)=='number' then return nil end
    local ok,key=pcall(function()
        local instance=BackpackUtils.GetItemInstanceID(id)
        if not instance or instance==0 then return nil end
        return tostring(id.Type)..':'..tostring(id.TypeSpecificID)..':'..tostring(instance)
    end)
    return ok and key or nil
end
function G.IsSuppressed(id)
    local key=G.Key(id)
    return key~=nil and G.Suppressed[key]==true
end
return G
