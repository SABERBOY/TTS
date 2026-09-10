---@class UGCSubsystemManager
-- UGC 全局子系统管理器
-- 提供类似UE Subsystem的功能，统一管理各种工具模块和子系统
-- 支持动态注册、获取、销毁模块，以及自动生命周期管理

local UGCSubsystemManager = {}

local _instance = nil                   -- 单例实例
local _subsystems = {}                  -- 已注册的SubSystem表 {name = instance}
local _subsystem_classes = {}           -- SubSystem定义表 {name = class}
local _initialization_order = {}        -- 初始化顺序列表
local _is_initialized = false           -- 管理器是否已初始化
local _lock = false                     -- 简易锁机制

-- 加锁
local function acquire_lock()
    while _lock do
        -- 简单的自旋等待
    end
    _lock = true
end

-- 解锁
local function release_lock()
    _lock = false
end

-- 安全调用函数
local function safe_call(func, ...)
    if type(func) ~= "function" then
        return false, "not a function"
    end
    
    local success, result = pcall(func, ...)
    if not success then
        print(string.format("[UGCSubsystemManager] Error: %s", tostring(result)))
        return false, result
    end
    
    return true, result
end

-- 初始化管理器
function UGCSubsystemManager:Initialize()
    if _is_initialized then
        print("[UGCSubsystemManager] Already initialized")
        return
    end
    
    print("[UGCSubsystemManager] Initializing subsystem manager...")
    
    -- 初始化全局命名空间
    if _G.UGCGlobalSystems == nil then
        _G.UGCGlobalSystems = {}
    end
    
    -- 注册管理器自身到全局表
    _G.UGCGlobalSystems.SubsystemManager = self
    
    _is_initialized = true
    print("[UGCSubsystemManager] Initialization complete")
end

-- 注册，不立即实例化，只是记录信息，如果传入了自动初始化，则会调用初始化方法
-- @param name string 子系统名称
-- @param module_path string 模块路径（用于require）
-- @param auto_init boolean 是否自动初始化（可选，默认false）
function UGCSubsystemManager:RegisterSubsystemClass(name, module_path, auto_init)
    acquire_lock()
    
    if _subsystem_classes[name] ~= nil then
        print(string.format("[UGCSubsystemManager] Warning: Subsystem class '%s' already registered, overwriting", name))
    end
    
    _subsystem_classes[name] = {
        module_path = module_path,
        auto_init = auto_init or false
    }
    
    print(string.format("[UGCSubsystemManager] Registered subsystem class: %s (path: %s)", name, module_path))
    
    -- 如果设置了自动初始化，立即创建实例
    if auto_init then
        release_lock()
        self:GetSubsystem(name)
        return
    end
    
    release_lock()
end

-- 动态加载并注册SubSystem
-- @param name string 子系统名称
-- @param instance table 子系统实例（可选，如果不提供则从已注册的类加载）
-- @return table 子系统实例
function UGCSubsystemManager:RegisterSubsystem(name, instance)
    acquire_lock()
    
    if _subsystems[name] ~= nil then
        print(string.format("[UGCSubsystemManager] Warning: Subsystem '%s' already exists, replacing", name))
    end
    
    local subsystem_instance = instance
    
    -- 如果没有提供实例，尝试从已注册的类加载
    if subsystem_instance == nil then
        local class_info = _subsystem_classes[name]
        if class_info == nil then
            release_lock()
            print(string.format("[UGCSubsystemManager] Error: Subsystem class '%s' not registered", name))
            return nil
        end
        
        -- 加载模块
        local success, module = pcall(require, class_info.module_path)
        if not success or module == nil then
            release_lock()
            print(string.format("[UGCSubsystemManager] Error: Failed to load module '%s': %s", class_info.module_path, tostring(module)))
            return nil
        end
        
        -- 如果模块有GetInstance方法，使用单例模式
        if type(module.GetInstance) == "function" then
            subsystem_instance = module:GetInstance()
        else
            -- 否则直接使用模块本身
            subsystem_instance = module
        end
    end
    
    -- 存储实例
    _subsystems[name] = subsystem_instance
    table.insert(_initialization_order, name)
    
    -- 调用Initialize方法（如果存在）
    if type(subsystem_instance.Initialize) == "function" and subsystem_instance.Initialize ~= UGCSubsystemManager.Initialize then
        safe_call(subsystem_instance.Initialize, subsystem_instance)
    end
    
    print(string.format("[UGCSubsystemManager] Registered subsystem instance: %s", name))
    
    release_lock()
    return subsystem_instance
end

-- 获取子SubSystem
-- @param name string 子系统名称
-- @return table 子系统实例，如果不存在返回nil
function UGCSubsystemManager:GetSubsystem(name)
    -- 如果已经实例化，直接返回
    if _subsystems[name] ~= nil then
        return _subsystems[name]
    end
    
    -- 否则尝试注册并返回
    return self:RegisterSubsystem(name)
end

-- 注销 SubSystem
-- @param name string 子系统名称
function UGCSubsystemManager:UnregisterSubsystem(name)
    acquire_lock()
    
    local subsystem = _subsystems[name]
    if subsystem == nil then
        release_lock()
        print(string.format("[UGCSubsystemManager] Warning: Subsystem '%s' not found", name))
        return
    end
    
    -- 调用Shutdown方法（如果存在）
    if type(subsystem.Shutdown) == "function" then
        safe_call(subsystem.Shutdown, subsystem)
    end
    
    _subsystems[name] = nil
    
    -- 从初始化顺序列表中移除
    for i, subsystem_name in ipairs(_initialization_order) do
        if subsystem_name == name then
            table.remove(_initialization_order, i)
            break
        end
    end
    
    print(string.format("[UGCSubsystemManager] Unregistered subsystem: %s", name))
    
    release_lock()
end

-- 检查SubSystem是否已注册
-- @param name string 子系统名称
-- @return boolean
function UGCSubsystemManager:HasSubsystem(name)
    return _subsystems[name] ~= nil
end

-- 获取所有已注册的SubSystem名称
-- @return table SubSystem name table
function UGCSubsystemManager:GetAllSubsystemNames()
    local names = {}
    for name, _ in pairs(_subsystems) do
        table.insert(names, name)
    end
    return names
end

-- Tick所有支持Tick的SubSystem
-- @param delta_time number 帧间隔时间
function UGCSubsystemManager:Tick(delta_time)
    for _, name in ipairs(_initialization_order) do
        local subsystem = _subsystems[name]
        if subsystem ~= nil and type(subsystem.Tick) == "function" then
            safe_call(subsystem.Tick, subsystem, delta_time)
        end
    end
end

-- 销毁所有SubSystem
function UGCSubsystemManager:ShutdownAll()
    acquire_lock()
    
    print("[UGCSubsystemManager] Shutting down all subsystems...")
    
    -- 按初始化顺序的逆序销毁
    for i = #_initialization_order, 1, -1 do
        local name = _initialization_order[i]
        local subsystem = _subsystems[name]
        
        if subsystem ~= nil and type(subsystem.Shutdown) == "function" then
            print(string.format("[UGCSubsystemManager] Shutting down subsystem: %s", name))
            safe_call(subsystem.Shutdown, subsystem)
        end
    end
    
    -- 清空所有数据
    _subsystems = {}
    _initialization_order = {}
    
    print("[UGCSubsystemManager] All subsystems shut down")
    
    release_lock()
end

-- Reload SubSystem
-- @param name string 子系统名称
function UGCSubsystemManager:ReloadSubsystem(name)
    print(string.format("[UGCSubsystemManager] Reloading subsystem: %s", name))
    
    self:UnregisterSubsystem(name)
    
    -- 清除模块缓存
    local class_info = _subsystem_classes[name]
    if class_info ~= nil then
        package.loaded[class_info.module_path] = nil
    end
    
    -- 重新注册
    return self:RegisterSubsystem(name)
end

-- 打印所有子系统状态（调试用）
function UGCSubsystemManager:PrintStatus()
    print("[UGCSubsystemManager] ==================== Status ====================")
    print(string.format("Initialized: %s", tostring(_is_initialized)))
    print(string.format("Registered Classes: %d", self:_count_table(_subsystem_classes)))
    print(string.format("Active Subsystems: %d", self:_count_table(_subsystems)))
    
    print("\nRegistered Classes:")
    for name, info in pairs(_subsystem_classes) do
        local status = _subsystems[name] ~= nil and "ACTIVE" or "NOT_LOADED"
        print(string.format("  - %s [%s] (path: %s, auto_init: %s)", 
            name, status, info.module_path, tostring(info.auto_init)))
    end
    
    print("\nInitialization Order:")
    for i, name in ipairs(_initialization_order) do
        print(string.format("  %d. %s", i, name))
    end
    
    print("[UGCSubsystemManager] ================================================")
end

function UGCSubsystemManager:_count_table(tbl)
    local count = 0
    for _, _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function UGCSubsystemManager:GetInstance()
    if _instance == nil then
        _instance = {}
        setmetatable(_instance, { __index = UGCSubsystemManager })
        _instance:Initialize()
    end
    return _instance
end

function UGCSubsystemManager:RegisterToGlobal()
    if _G.UGCGlobalSystems == nil then
        _G.UGCGlobalSystems = {}
    end
    _G.UGCGlobalSystems.SubsystemManager = self
end

function GetSubsystemManager()
    if _G.UGCGlobalSystems ~= nil and _G.UGCGlobalSystems.SubsystemManager ~= nil then
        return _G.UGCGlobalSystems.SubsystemManager
    end
    
    local UGCSubsystemManager = require("Script.Framework.SubSystem.UGCSubsystemManager")
    return UGCSubsystemManager:GetInstance()
end

_G.GetSubsystemManager = GetSubsystemManager

function GetSubsystem(name)
    local manager = GetSubsystemManager()
    if manager == nil then
        print(string.format("[UGCSubsystemManager] Error: SubsystemManager not initialized"))
        return nil
    end
    return manager:GetSubsystem(name)
end

_G.GetSubsystem = GetSubsystem

return UGCSubsystemManager
