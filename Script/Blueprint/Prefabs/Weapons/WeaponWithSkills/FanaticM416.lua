---@class FanaticM416_C:BP_UGC_Rifle_M416_C
-- Edit Below--
local FanaticM416 = {}

function FanaticM416:StartFireFilter()
    if FanaticM416.SuperClass.StartFireFilter(self) == true then
        if UGCBuffSystem.HasBuff(self:GetOwner(), "FireProhibited") then
            return false
        end
        return true
    end
    return false
end

return FanaticM416
