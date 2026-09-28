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
            {UGCGMUI.ItemTypeEnum.Button, {{"打开装备面板"}, {"打开 Game_Equip_Main_UIBP：右侧页签切换装备/强化/转化"}}, "C_OpenEquipPanel"},
            {UGCGMUI.ItemTypeEnum.Button, {{"关闭装备面板"}, {"隐藏装备主页面"}}, "C_CloseEquipPanel"},
            {UGCGMUI.ItemTypeEnum.Button, {{"打开头盔强化面板"}, {"打开装备主页面并切到头盔槽强化页签"}}, "C_OpenHelmetStrengthen"},
        },
        ["测试物品"] = {
            {UGCGMUI.ItemTypeEnum.Button, {{"添加[头盔]传奇头盔"}, {"DS 添加 8310017 传奇头盔，可装备物品会自动穿上"}}, "C_AddTestHelmet"},
            {UGCGMUI.ItemTypeEnum.Button, {{"添加[护甲]冲刺护甲"}, {"DS 添加 8310016 冲刺护甲，可装备物品会自动穿上"}}, "C_AddTestArmor"},
            {UGCGMUI.ItemTypeEnum.Button, {{"添加[戒指]高级戒指"}, {"DS 添加 8310015 高级戒指，可装备物品会自动穿上"}}, "C_AddTestRing"},
            {UGCGMUI.ItemTypeEnum.Button, {{"添加[护膝]急速护膝"}, {"DS 添加 8310014 急速护膝，可装备物品会自动穿上"}}, "C_AddTestKneepad"},
            {UGCGMUI.ItemTypeEnum.Button, {{"一键添加4件测试装备"}, {"依次添加 8310017/8310016/8310015/8310014 并自动穿上，便于一次覆盖多个槽位"}}, "C_AddAllTestEquips"},
            {UGCGMUI.ItemTypeEnum.Button, {{"添加测试金币"}, {"DS 添加 100000 金币，便于点强化"}}, "C_AddTestGold"},
        },
        ["装备升阶"] = {
            {UGCGMUI.ItemTypeEnum.Button, {{"一键添加升阶货币"}, {"每次添加100000金币和1000钻石，可重复点击"}}, "C_AdvanceQuickMoney"},
            {UGCGMUI.ItemTypeEnum.Button, {{"一键添加升阶装备"}, {"每条已有升阶配方各添加一组目标和材料（当前57件）；不自动穿戴，背包满时停止"}}, "C_AdvanceQuickEquipment"},
            {UGCGMUI.ItemTypeEnum.Button, {{"全部测试槽位强化至180"}, {"设置6个槽位的运行时强化等级，不主动写强化存档"}}, "C_AdvanceQuickLevels"},
            {UGCGMUI.ItemTypeEnum.Button, {{"自动合成一次（确认消耗材料）"}, {"每点击一次合成一组；按阶位从低到高选择背包装备，含历史投入；跳过穿戴及保护物品"}}, "C_AdvanceQuickOnce"},
            {UGCGMUI.ItemTypeEnum.Button, {{"列出装备实例"}, {"日志显示实例Key、独立阶位、下一阶ID、穿戴状态"}}, "C_AdvanceList"},
            {UGCGMUI.ItemTypeEnum.TextInput, {{"添加升阶测试物品", "ItemID 数量"}, {"例：8310131 2；8310084 10000；8310132 100。装备不会自动穿戴"}}, "C_AdvanceAdd"},
            {UGCGMUI.ItemTypeEnum.TextInput, {{"设置测试强化等级", "槽位1-6 等级0-180"}, {"例：3 60；仅本次运行时修改，不主动写强化存档"}}, "C_AdvanceLevel"},
            {UGCGMUI.ItemTypeEnum.TextInput, {{"预览升阶", "目标Key 材料Key..."}, {"Key从实例列表复制；白绿蓝可省略材料；紫及以上必须手选"}}, "C_AdvancePreview"},
            {UGCGMUI.ItemTypeEnum.TextInput, {{"确认上次升阶预览", "输入 YES"}, {"检查预览消耗后输入YES执行；将销毁目标和材料并生成下一阶"}}, "C_AdvanceConfirm"},
            {UGCGMUI.ItemTypeEnum.TextInput, {{"设置装备保护", "Key Locked/Tracked/Reserved/InTrade/Viewed true/false"}, {"例：实例Key Locked true"}}, "C_AdvanceProtect"},
            {UGCGMUI.ItemTypeEnum.Button, {{"升阶配置自检"}, {"检查独立阶位、下一阶配置、资产和缺失路线"}}, "C_AdvanceCheck"},
            {UGCGMUI.ItemTypeEnum.Button, {{"检查升阶恢复状态"}, {"只读输出补偿失败的阻断与恢复记录"}}, "C_AdvanceRecovery"},
        },
    }

    CurFuncList["怪物测试"] = {
        ["行为树"] = {
            {UGCGMUI.ItemTypeEnum.Button, {{"召唤超级怪物到身边"}, {"SuperMonster 传送到玩家脚下（场景里没有则直接生成），并把玩家设为目标"}}, "C_SummonSuperMonster"},
        },
    }

    return CurFuncList
end

local function AdvanceArgs(text)
    local out={}
    for word in tostring(text or ''):gmatch('[^%s,，]+') do out[#out+1]=word end
    return out
end
local function AdvanceClient() return require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceClient') end
function UGCGM:C_AdvanceQuickMoney() AdvanceClient().Quick('money') end
function UGCGM:C_AdvanceQuickEquipment() AdvanceClient().Quick('equipment') end
function UGCGM:C_AdvanceQuickLevels() AdvanceClient().Quick('levels') end
function UGCGM:C_AdvanceQuickOnce() AdvanceClient().Quick('advance') end
function UGCGM:C_AdvanceList() AdvanceClient().GM('list') end
function UGCGM:C_AdvanceCheck() AdvanceClient().GM('check') end
function UGCGM:C_AdvanceRecovery() AdvanceClient().GM('recovery') end
function UGCGM:C_AdvanceAdd(text) AdvanceClient().GM('add',AdvanceArgs(text)) end
function UGCGM:C_AdvanceLevel(text) AdvanceClient().GM('level',AdvanceArgs(text)) end
function UGCGM:C_AdvanceProtect(text)
    local a=AdvanceArgs(text)
    if a[3]~='true' and a[3]~='false' then print('[EquipAdvance] 保护值须为true/false'); return end
    a[3]=a[3]=='true'; AdvanceClient().GM('protect',a)
end
function UGCGM:C_AdvancePreview(text)
    local a=AdvanceArgs(text); local target=table.remove(a,1)
    AdvanceClient().Preview(target,#a>0 and a or nil)
end
function UGCGM:C_AdvanceConfirm(text)
    if tostring(text or ''):match('^%s*(.-)%s*$')~='YES' then print('[EquipAdvance] 确认请输入YES'); return end
    AdvanceClient().Confirm(true)
end

--- GM命令：一键召唤超级怪物到玩家身边
--- 在客户端被调用，通过 ServerRPC 转发到 DS 端执行
function UGCGM:C_SummonSuperMonster()
    print('[GM] C_SummonSuperMonster')
    local PC = UGCGameSystem.GetLocalPlayerController()
    if not PC then
        print('[GM] C_SummonSuperMonster: PlayerController is nil')
        return
    end
    UnrealNetwork.CallUnrealRPC(PC, PC, 'ServerRPC_GMSummonMonster')
    print('[GM] C_SummonSuperMonster: sent ServerRPC')
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

local TEST_GOLD_COUNT = 100000

--- 测试装备清单（DS 端 AddItemV2 添加，可装备物品会自动穿上，用于覆盖不同槽位）
local TEST_EQUIP_LIST = {
    { ItemID = 8310017, Name = '传奇头盔' },
    { ItemID = 8310016, Name = '冲刺护甲' },
    { ItemID = 8310015, Name = '高级戒指' },
    { ItemID = 8310014, Name = '急速护膝' },
}

--- 内部：向 DS 发送"添加装备"RPC（不负责刷新面板）
---@param ItemID number
---@param Name string
---@return userdata|nil @PlayerController
local function SendAddEquipRPC(ItemID, Name)
    local PC = UGCGameSystem.GetLocalPlayerController()
    if not PC then
        print(string.format('[GM] 添加装备失败：无 PlayerController，ItemID=%s(%s)', tostring(ItemID), tostring(Name)))
        return nil
    end
    UnrealNetwork.CallUnrealRPC(PC, PC, 'ServerRPC_GMAddItem', ItemID, 1)
    print(string.format('[GM] 已发送添加装备 RPC：%s ItemID=%s', tostring(Name), tostring(ItemID)))
    return PC
end

--- 内部：物品同步到客户端后刷新已打开的装备面板
---@param PC userdata
---@param Delay number
local function RefreshEquipPanelLater(PC, Delay)
    UGCGameSystem.SetTimer(PC, function()
        local EquipPanelManager = require('Script.Blueprint.Prefabs.UI.Equip.EquipPanelManager')
        local Widget = EquipPanelManager.GetMainWidget()
        if Widget and CheckObjectContainsField(Widget, 'Refresh', true) then
            Widget:Refresh()
        end
    end, Delay, false)
end

--- 内部：按清单下标添加一件测试装备并刷新面板
---@param Idx number
local function AddTestEquip(Idx)
    local Def = TEST_EQUIP_LIST[Idx]
    if not Def then
        print('[GM] AddTestEquip: 非法下标 ' .. tostring(Idx))
        return
    end
    local PC = SendAddEquipRPC(Def.ItemID, Def.Name)
    if PC then
        RefreshEquipPanelLater(PC, 0.4)
    end
end

function UGCGM:C_AddTestHelmet()
    print('[GM] C_AddTestHelmet')
    AddTestEquip(1)
end

function UGCGM:C_AddTestArmor()
    print('[GM] C_AddTestArmor')
    AddTestEquip(2)
end

function UGCGM:C_AddTestRing()
    print('[GM] C_AddTestRing')
    AddTestEquip(3)
end

function UGCGM:C_AddTestKneepad()
    print('[GM] C_AddTestKneepad')
    AddTestEquip(4)
end

--- GM命令：一键添加 4 件测试装备（依次发 RPC，最后统一刷新一次面板）
function UGCGM:C_AddAllTestEquips()
    print('[GM] C_AddAllTestEquips')
    local PC = nil
    for _, Def in ipairs(TEST_EQUIP_LIST) do
        PC = SendAddEquipRPC(Def.ItemID, Def.Name) or PC
    end
    if PC then
        RefreshEquipPanelLater(PC, 1.2)
    end
end

function UGCGM:C_OpenEquipPanel()
    print('[GM] C_OpenEquipPanel')
    local EquipPanelManager = require('Script.Blueprint.Prefabs.UI.Equip.EquipPanelManager')
    EquipPanelManager.Open({ PageId = 'basics' })
end

function UGCGM:C_CloseEquipPanel()
    print('[GM] C_CloseEquipPanel')
    local EquipPanelManager = require('Script.Blueprint.Prefabs.UI.Equip.EquipPanelManager')
    EquipPanelManager.Close()
end

function UGCGM:C_OpenHelmetStrengthen()
    print('[GM] C_OpenHelmetStrengthen')
    local EquipPanelManager = require('Script.Blueprint.Prefabs.UI.Equip.EquipPanelManager')
    EquipPanelManager.Open({ PageId = 'strengthen', SlotIdx = 1 })
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
