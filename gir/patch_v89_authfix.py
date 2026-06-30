"""Make V89 use kite_token.json directly instead of KiteSession.kite()"""
import shutil, ast
from pathlib import Path

GIR = Path('/home/globalbot/gir.py')
shutil.copy(GIR, GIR.with_suffix('.py.bak_v89_authfix'))
src = GIR.read_text()

# Find the V89 block we inserted and prepend a fresh kite client construction
old = "# PATCH_V89: Correct day P&L computation"
new = '''# PATCH_V89_AUTHFIX: ensure fresh kite client from saved token file
            try:
                import json as _ajson, os as _aos
                from kiteconnect import KiteConnect as _KC
                _ak = _aos.getenv("KITE_API_KEY", "")
                with open("/home/globalbot/data/kite_token.json") as _atf:
                    _atok = _ajson.load(_atf)
                kite = _KC(api_key=_ak)
                kite.set_access_token(_atok["access_token"])
            except Exception as _ae:
                lines.append(f"_(auth fallback failed: {_ae})_")

            # PATCH_V89: Correct day P&L computation'''

if old not in src:
    print("V89 marker not found"); exit(1)

src2 = src.replace(old, new, 1)
ast.parse(src2)
GIR.write_text(src2)
print("AUTHFIX applied")
