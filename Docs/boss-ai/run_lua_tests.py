"""Run the Boss AI's engine-independent Lua tests with Lupa.

Usage from the TTS project root: python Docs/boss-ai/run_lua_tests.py
"""

from __future__ import annotations

import os
from pathlib import Path
import sys

from lupa import LuaRuntime


ROOT = Path(__file__).resolve().parents[2]
MODULES = (
    "BossAI_ConfigTests",
    "BossAI_Tests",
    "BossAI_RuntimeTests",
    "BossAI_WarningTests",
    "BossAI_LifecycleTests",
)
STANDALONE = (
    "Tests/BossMovementTests.lua",
    "Tests/SuperMonsterIcePassiveTests.lua",
)


def main() -> int:
    os.chdir(ROOT)
    total = passed = 0
    for name in MODULES:
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute("package.path = './?.lua;./?/init.lua;' .. package.path")
        try:
            result = lua.execute(
                f"return require('Script.AI.Boss.{name}').RunAll()"
            )
            if result["total"] is not None:
                count = int(result["total"])
                good = result["passed"]
                if good is None:
                    good = result["pass"]
                if good is None:
                    good = sum(bool(item["pass"]) for item in result["results"].values())
                good = int(good)
            else:
                count = len(result)
                good = sum(bool(result[i]["pass"]) for i in range(1, count + 1))
            print(f"{name}: {good}/{count}")
        except Exception as exc:
            print(f"{name}: ERROR {exc}", file=sys.stderr)
            return 1
        total += count
        passed += good
    print(f"Boss AI pure Lua: {passed}/{total}")
    if passed != total:
        return 1
    for path in STANDALONE:
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute("package.path = './?.lua;./?/init.lua;' .. package.path")
        try:
            lua.execute(f"dofile('{path}')")
        except Exception as exc:
            print(f"{path}: ERROR {exc}", file=sys.stderr)
            return 1
        print(f"{path}: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
