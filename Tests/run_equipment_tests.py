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
