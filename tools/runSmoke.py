# Usage: python tools/runSmoke.py <xiv|ffxiExpanded> [addonRoot]
import os
import sys
from lupa import lua51

toolsDir = os.path.dirname(os.path.abspath(__file__))
style = sys.argv[1] if len(sys.argv) > 1 else 'xiv'
root = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(toolsDir)
root = root.replace('\\', '/').rstrip('/') + '/'

lua = lua51.LuaRuntime()
lua.globals().ADDON_ROOT = root
lua.globals().STYLE = style
src = open(os.path.join(toolsDir, 'avSmoke.lua'), encoding='utf-8').read()
try:
    lua.execute(src)
except Exception as e:
    print('SMOKE FAILED:', e)
    sys.exit(1)
