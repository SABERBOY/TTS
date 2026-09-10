---@class UGCSubsystemBootstrap
-- UGCSubSystem 启动器
-- 负责在游戏启动时初始化子系统管理器和预注册常用子系统

local UGCSubsystemBootstrap = {}

-- 启动配置
local _bootstrap_config = {
    -- auto_preload = true,            -- 是否自动预加载常用模块
    auto_register = true,           -- 是否自动注册子系统
    debug_mode = true               -- 是否开启调试模式
}

-- 预定义的SubSystem注册表
local _predefined_subsystems = {
    -- {
    --     name = "SoundSystem",
    --     path = "Script.utils.UGCSoundTools",
    --     auto_init = true
    -- }
}

function UGCSubsystemBootstrap:Initialize(config)
    print("[UGCSubsystemBootstrap] Initializing bootstrap...")
    
    -- 合并配置
    if config ~= nil then
        for k, v in pairs(config) do
            _bootstrap_config[k] = v
        end
    end
    
    -- 初始化管理器
    local manager = require("Script.Framework.SubSystem.UGCSubsystemManager"):GetInstance()
    
    -- -- 预加载模块（如果启用）
    -- if _bootstrap_config.auto_preload then
    --     local loader = require("Script.ProjectEnv.UGCModuleLoader")
    --     loader:PreloadCommonModules()
    -- end
    
    -- 自动注册子系统（如果启用）
    if _bootstrap_config.auto_register then
        self:RegisterPredefinedSubsystems(manager)
    end
    
    if _bootstrap_config.debug_mode then
        manager:PrintStatus()
    end
    
    print("[UGCSubsystemBootstrap] Bootstrap complete")
    
    return manager
end

-- 注册SubSystem
-- @param manager UGCSubsystemManager SubSystem引用
function UGCSubsystemBootstrap:RegisterPredefinedSubsystems(manager)
    print("[UGCSubsystemBootstrap] Registering predefined subsystems...")
    
    for _, subsystem_info in ipairs(_predefined_subsystems) do
        manager:RegisterSubsystemClass(
            subsystem_info.name,
            subsystem_info.path,
            subsystem_info.auto_init
        )
    end
    
    print(string.format("[UGCSubsystemBootstrap] Registered %d predefined subsystems", #_predefined_subsystems))
end

-- 添加SubSystem
-- @param name string SubSystem名称
-- @param path string 模块路径
-- @param auto_init boolean 是否自动初始化
function UGCSubsystemBootstrap:AddPredefinedSubsystem(name, path, auto_init)
    table.insert(_predefined_subsystems, {
        name = name,
        path = path,
        auto_init = auto_init or false
    })
    
    print(string.format("[UGCSubsystemBootstrap] Added predefined subsystem: %s", name))
end

-- 清除所有SubSystem
function UGCSubsystemBootstrap:ClearPredefinedSubsystems()
    _predefined_subsystems = {}
    print("[UGCSubsystemBootstrap] Cleared all predefined subsystems")
end

-- 关闭所有SubSystem
function UGCSubsystemBootstrap:Shutdown()
    print("[UGCSubsystemBootstrap] Shutting down...")
    
    local manager = GetSubsystemManager()
    if manager ~= nil then
        manager:ShutdownAll()
    end
    
    print("[UGCSubsystemBootstrap] Shutdown complete")
end

function UGCSubsystemBootstrap:QuickStart()
    return self:Initialize(nil)
end

return UGCSubsystemBootstrap
