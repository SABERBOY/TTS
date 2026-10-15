"""Run equipment transaction tests with the installed Lupa Lua runtime."""
from pathlib import Path
import os
import json
from lupa.lua51 import LuaRuntime

os.chdir(Path(__file__).resolve().parents[1])
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path = './?.lua;./?/init.lua;' .. package.path")
fixture = json.loads(Path('Tests/Fixtures/EquipAdvanceTables.json').read_text(encoding='utf-8'))
lua.globals().EquipAdvanceTableFixture = lua.table_from({
    name: {row['Name']: {k: v for k, v in row.items() if k != 'Name'} for row in rows}
    for name, rows in fixture.items()
}, recursive=True)
lua.execute("""
UGCGameSystem = {
    GetUGCResourcesFullPath=function(path) return '/TTS/'..path end,
    GetTableData=function(path)
        assert(path:match('^/TTS/'), 'native table read requires full resource path')
        return EquipAdvanceTableFixture[path:match('%.([^%.]+)$')]
    end,
}
""")
config_source = Path('Script/Blueprint/Prefabs/UI/Equip/Advance/EquipAdvanceConfig.lua').read_text(encoding='utf-8-sig')
lua.globals().EquipAdvanceReloadConfig = lambda: lua.execute(config_source)
lua.execute(Path('Tests/EquipAdvanceConfigTests.lua').read_text(encoding='utf-8-sig')).Run()
lua.execute(Path('Tests/EquipAdvanceTests.lua').read_text(encoding='utf-8-sig')).Run()
lua.execute(Path('Tests/EquipAdvanceUITests.lua').read_text(encoding='utf-8-sig')).Run()
lua.execute(Path('Tests/EquipCurrencyTests.lua').read_text(encoding='utf-8-sig')).Run()
lua.execute(Path('Tests/EquipStrengthenTransactionTests.lua').read_text(encoding='utf-8-sig')).Run()
# Local bag reads install native stubs, so this group runs last in the shared VM.
lua.execute(Path('Tests/EquipAdvanceLocalBagTests.lua').read_text(encoding='utf-8-sig')).Run()
UI_DIR = Path('Script/Blueprint/Prefabs/UI/Equip')
panel = (UI_DIR / 'UIBP/Game_Equip_Develop_Transform_UIBP.lua').read_text(encoding='utf-8-sig')
local_bag = (UI_DIR / 'Advance/EquipAdvanceLocalBag.lua').read_text(encoding='utf-8-sig')
# 升阶背包必须与预览页/强化页同源，且不得再把整包数据塞进 RPC。
assert 'EquipSlotSystem.CollectBagEquipItems' in (UI_DIR / 'UIBP/Game_Equip_Develop_Strengthen_UIBP.lua').read_text(encoding='utf-8-sig')
assert 'System.CollectBagEquipItems' in local_bag
assert 'Client.Snapshot' not in panel and 'ServerRPC_EquipAdvanceSnapshot' not in panel
assert 'EquipAdvanceLocalBag' in panel
assert 'CallUnrealRPC' not in local_bag and 'UnrealNetwork' not in local_bag
print('Advancement bag read is local (CollectBagEquipItems) with no snapshot RPC')
config = lua.eval("require('Script.Blueprint.Prefabs.UI.Equip.Advance.EquipAdvanceConfig')")
orders = {row['RankID']: row['Order'] for row in fixture['EquipAdvanceRank']}
for row in fixture['EquipAdvanceRank']:
    actual = config.Ranks[row['Order']]
    for key, value in row.items():
        if key != 'Name':
            assert actual['Name' if key == 'DisplayName' else key] == value
for row in fixture['EquipAdvanceRule']:
    for key in ('Materials', 'Gold', 'Diamond'):
        assert config.Rules[orders[row['RankID']]][key] == row[key]
for row in fixture['EquipAdvanceItem']:
    actual = config.Items[row['ItemID']]
    for key, value in row.items():
        if key != 'Name':
            assert actual[key] == (None if key == 'NextItemID' and value == 0 else value)
    assert actual.RankOrder == orders[row['RankID']]
print('All migrated configuration fields match the original snapshot')
