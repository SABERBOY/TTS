--- BOSS AI 确定性随机流（规格 §6）
--- 每只 BOSS 独立使用自己的随机流；固定种子可复现；不消耗引擎特效随机。
--- 说明：实现为经典 LCG（state = state * 48271 % 2147483647），
---       整数运算 + 浮点归一，跨平台稳定，便于测试复现。
local BossAI_Random = {}
BossAI_Random.__index = BossAI_Random

local A = 48271
local M = 2147483647 -- 2^31 - 1（梅森素数模）

--- 创建随机流
---@param seed number|nil 种子（缺省 1）
function BossAI_Random.New(seed)
    local self = setmetatable({}, BossAI_Random)
    self:SetSeed(seed)
    return self
end

--- 重置种子
function BossAI_Random:SetSeed(seed)
    seed = math.floor(tonumber(seed) or 1)
    if seed <= 0 then
        seed = 1
    end
    self._state = seed % M
    if self._state == 0 then
        self._state = 1
    end
    self._seed = seed
end

--- 返回原始种子（用于调试显示 / 复现）
function BossAI_Random:GetSeed()
    return self._seed
end

--- 下一个 [0, 1) 浮点
function BossAI_Random:Next()
    self._state = (self._state * A) % M
    return (self._state - 1) / (M - 1)
end

--- 下一个 [minV, maxV) 浮点
function BossAI_Random:Range(minV, maxV)
    if maxV <= minV then
        return minV
    end
    return minV + (maxV - minV) * self:Next()
end

--- 下一个 [1, maxN] 整数
function BossAI_Random:Int(maxN)
    if maxN <= 1 then
        return 1
    end
    return math.floor(self:Next() * maxN) + 1
end

--- 按权重表抽样
---@param entries table[] 形如 { {value=..., weight=number}, ... }（顺序遍历，保证稳定）
---@return any|nil 被选中的 value；全部权重非法时返回 nil
function BossAI_Random:PickWeighted(entries)
    if type(entries) ~= 'table' or #entries == 0 then
        return nil
    end

    local total = 0
    for i = 1, #entries do
        local w = tonumber(entries[i].weight) or 0
        if w > 0 and w < math.huge then -- 跳过零/负/非有限权重（规格 §6 安全处理）
            total = total + w
        end
    end
    if total <= 0 then
        return nil
    end

    local roll = self:Next() * total
    local acc = 0
    for i = 1, #entries do
        local w = tonumber(entries[i].weight) or 0
        if w > 0 and w < math.huge then
            acc = acc + w
            if roll < acc then
                return entries[i].value, entries[i]
            end
        end
    end
    -- 浮点边界兜底：返回最后一个合法项
    for i = #entries, 1, -1 do
        local w = tonumber(entries[i].weight) or 0
        if w > 0 and w < math.huge then
            return entries[i].value, entries[i]
        end
    end
    return nil
end

return BossAI_Random
