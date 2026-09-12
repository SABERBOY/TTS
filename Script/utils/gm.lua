-------------------------------------------------------------------------------
-- UGC 项目自定义 GM 命令
-- 路径：Script/utils/gm.lua
-- 引擎 GM 面板会自动扫描此文件，调用 Register 注册自定义按钮
-------------------------------------------------------------------------------
local UGCGM = {}

--- 注册自定义 GM 命令到 GM 面板
--- 返回格式：{ [TabName] = { [SubTabName] = { {ItemType, Params, FuncName}, ... } } }
---@param DebugUI table @UGCGMUI 实例，用于获取 ItemTypeEnum
---@return table @GM 命令字典
function UGCGM:Register(DebugUI)
    local UGCGMUI = require("client.ingame.ugc.ugc_gmui")
    local CurFuncList = {}

    CurFuncList["物品实例"] = {
        ["添加物品"] = {
            {UGCGMUI.ItemTypeEnum.TextInput, {{"添加带实例数据物品", "DataID 如 8310048_2"}, {"输入DataID添加物品，格式为 ItemID_Level，如 8310048_2 表示8310048号物品的2级实例"}}, "C_AddItemWithInstanceData"},
        },
    }

    CurFuncList["装备系统"] = {
        ["面板"] = {
            {UGCGMUI.ItemTypeEnum.Button, {{"打开装备面板"}, {"打开 UGC_Equip_Main_UIBP：右侧页签切换装备/强化/转化"}}, "C_OpenEquipPanel"},
            {UGCGMUI.ItemTypeEnum.Button, {{"关闭装备面板"}, {"隐藏装备主页面"}}, "C_CloseEquipPanel"},
            {UGCGMUI.ItemTypeEnum.Button, {{"打开头盔强化面板"}, {"打开装备主页面并切到头盔槽强化页签"}}, "C_OpenHelmetStrengthen"},
        },
        ["测试物品"] = {
            {UGCGMUI.ItemTypeEnum.Button, {{"添加测试头盔"}, {"DS 添加 LV7_Helmet(8310017)，可装备物品会自动穿上"}}, "C_AddTestHelmet"},
            {UGCGMUI.ItemTypeEnum.Button, {{"添加测试金币"}, {"DS 添加 100000 金币，便于点强化"}}, "C_AddTestGold"},
        },
    }

    return CurFuncList
end

--- GM命令：添加带实例数据的物品
--- 在客户端被调用，通过 ServerRPC 转发到 DS 端执行
---@param param string @DataID，格式 "ItemID_Level"（如 "8310048_2"）
function UGCGM:C_AddItemWithInstanceData(param)
    print(string.format("[GM] C_AddItemWithInstanceData param=%s", tostring(param)))
    if not param or param == "" then
        print("[GM] C_AddItemWithInstanceData: param is empty")
        return
    end

    local DataID = param:match("^%s*(.-)%s*$")  -- trim whitespace
    if DataID == "" then
        print("[GM] C_AddItemWithInstanceData: DataID is empty after trim")
        return
    end

    local PC = UGCGameSystem.GetLocalPlayerController()
    if not PC then
        print("[GM] C_AddItemWithInstanceData: PlayerController is nil")
        return
    end

    -- 通过 ServerRPC 在 DS 端执行 AddItemWithInstanceData
    UnrealNetwork.CallUnrealRPC(PC, PC, "ServerRPC_AddItemWithInstanceData", DataID)
    print(string.format("[GM] C_AddItemWithInstanceData: sent ServerRPC DataID=%s", DataID))
end

local TEST_HELMET_ITEM_ID = 8310017
local TEST_GOLD_COUNT = 100000

function UGCGM:C_OpenEquipPanel()
    print('[GM] C_OpenEquipPanel')
    local EquipPanelManager = require('Script.Common.EquipPanelManager')
    EquipPanelManager.Open({ PageId = 'basics' })
end

function UGCGM:C_CloseEquipPanel()
    print('[GM] C_CloseEquipPanel')
    local EquipPanelManager = require('Script.Common.EquipPanelManager')
    EquipPanelManager.Close()
end

function UGCGM:C_OpenHelmetStrengthen()
    print('[GM] C_OpenHelmetStrengthen')
    local EquipPanelManager = require('Script.Common.EquipPanelManager')
    EquipPanelManager.Open({ PageId = 'strengthen', SlotIdx = 1 })
end

function UGCGM:C_AddTestHelmet()
    local PC = UGCGameSystem.GetLocalPlayerController()
    if not PC then
        print('[GM] C_AddTestHelmet: no PC')
        return
    end
    UnrealNetwork.CallUnrealRPC(PC, PC, 'ServerRPC_GMAddItem', TEST_HELMET_ITEM_ID, 1)
    print('[GM] C_AddTestHelmet sent ItemID=' .. tostring(TEST_HELMET_ITEM_ID))
    -- 物品同步到客户端后刷新已打开的装备面板
    UGCGameSystem.SetTimer(PC, function()
        local EquipPanelManager = require('Script.Common.EquipPanelManager')
        local Widget = EquipPanelManager.GetMainWidget()
        if Widget and CheckObjectContainsField(Widget, 'Refresh', true) then
            Widget:Refresh()
        end
    end, 0.4, false)
end

function UGCGM:C_AddTestGold()
    local PC = UGCGameSystem.GetLocalPlayerController()
    if not PC then
        print('[GM] C_AddTestGold: no PC')
        return
    end
    -- ItemID=0：服务端按第一货币处理
    UnrealNetwork.CallUnrealRPC(PC, PC, 'ServerRPC_GMAddItem', 0, TEST_GOLD_COUNT)
    print('[GM] C_AddTestGold sent count=' .. tostring(TEST_GOLD_COUNT))
end

return UGCGM
