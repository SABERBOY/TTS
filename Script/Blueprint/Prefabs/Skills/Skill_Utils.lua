local Skill_Utils = {}

--- 获取角色当前装备的武器
---@param OwnerActor object 拥有者Actor
---@return object|nil 当前武器，如果没有则返回nil
function Skill_Utils:GetCurrentWeapon(OwnerActor)
    if not OwnerActor then return nil end
    return UGCWeaponManagerSystem.GetCurrentWeapon(OwnerActor)
end

--- 日志输出工具函数，直接支持多参数
---@param module string 模块名称
---@param level string 日志级别(LogDev|LogInfo|LogWarning|LogError)
---@param ... any 变参数列表
function Skill_Utils:Log(module, level, ...)
    if not module then 
        return 
    end
    
    -- 标准化日志级别
    level = level or "LogInfo"
    module = module or "Skill"
    
    -- 拼接所有参数
    local args = {...}
    local str = string.format("[%s] [%s] ", module, level)
    for i, v in ipairs(args) do
        if type(v) == "string" then
            str = str .. v
        else
            str = str .. tostring(v) .. " "
        end
    end
    
    -- 使用ugcprint代替print
    ugcprint(str)
end

--- 开发日志，仅在开发版本输出
---@param module string 模块名称
---@param ... any 变参数列表
function Skill_Utils:LogDev(module, ...)
    self:Log(module, "LogDev", ...)
end

--- 信息日志
---@param module string 模块名称
---@param ... any 变参数列表
function Skill_Utils:LogInfo(module, ...)
    self:Log(module, "LogInfo", ...)
end

--- 警告日志
---@param module string 模块名称
---@param ... any 变参数列表
function Skill_Utils:LogWarning(module, ...)
    self:Log(module, "LogWarning", ...)
end

--- 错误日志
---@param module string 模块名称
---@param ... any 变参数列表
function Skill_Utils:LogError(module, ...)
    self:Log(module, "LogError", ...)
end

--- 安全获取对象属性，避免nil引用错误
---@param obj any 要检查的对象
---@param ... string 属性路径
---@return any 属性值或nil
function Skill_Utils:SafeGet(obj, ...)
    if obj == nil then 
        return nil 
    end
    
    local current = obj
    for i, key in ipairs({...}) do
        if current[key] == nil then
            return nil
        end
        current = current[key]
    end
    
    return current
end

--- 检查对象是否为指定类型
---@param object any 要检查的对象
---@param className string 类名路径
---@return boolean 是否为指定类型
function Skill_Utils:IsInstanceOf(object, className)
    if not object or not className then 
        return false 
    end
    
    local class = UE.LoadClass(className)
    if not class then 
        return false 
    end
    
    return UE.IsA(object, class)
end

--- 筛选数组中指定类型的对象
---@param array UEArray UE数组对象
---@param className string 类名路径
---@return UEArray 筛选后的数组
function Skill_Utils:FilterArrayByClass(array, className)
    if not array or not className then 
        return array 
    end 
    
    local class = UE.LoadClass(className)
    if not class then 
        return array 
    end
    
    local count = array:Num()
    for i = count, 1, -1 do
        local item = array:Get(i)
        if not item or not UE.IsA(item, class) then
            array:RemoveAt(i)
        end
    end
    
    return array
end

--- 添加属性值
---@param actor object 目标Actor
---@param attributeName string 属性名称
---@param value number 要添加的值
---@return boolean 操作是否成功
function Skill_Utils:SafeAddAttributeValue(actor, attributeName, value)
    if not actor or not attributeName or value == nil then 
        self:LogError("SkillUtils", "Invalid parameters in SafeAddAttributeValue")
        return false 
    end
    
    -- 直接调用属性系统方法
    UGCAttributeSystem.AddGameAttributeValue(actor, attributeName, value)
    return true
end

--- 获取属性值
---@param actor object 目标Actor
---@param attributeName string 属性名称
---@param defaultValue number 默认值(如果获取失败)
---@return number 属性值
function Skill_Utils:SafeGetAttributeValue(actor, attributeName, defaultValue)
    defaultValue = defaultValue or 0
    
    if not actor or not attributeName then
        self:LogError("SkillUtils", "Invalid parameters in SafeGetAttributeValue")
        return defaultValue
    end
    
    -- 直接调用属性系统方法
    local value = UGCAttributeSystem.GetGameAttributeValue(actor, attributeName)
    
    -- 基本检查确保返回值是有效的
    if value == nil then
        return defaultValue
    end
    
    return value
end

--- 检查是否在服务器上运行
---@return boolean 是否在服务器上运行
function Skill_Utils:IsServer()
    return UGCGameSystem.IsServer()
end

return Skill_Utils
