import sys
from lupa import lua51
L = lua51.LuaRuntime()
src = open(sys.argv[1], encoding='utf-8').read()
f = L.eval('function(s) local fn, err = loadstring(s); return err or "syntax ok" end')
print(f(src))
