#!/bin/bash
# Increase EQ_MAX_POS from 10 to 12.
# Single-line edit, AST-safe (just changes a number literal).
python3 << 'PYEOF'
import ast, hashlib, shutil, sys

PATH = "/home/globalbot/gir.py"
BACKUP = "/home/globalbot/gir_backup_pre_V102_eqmaxpos.py"

OLD = 'EQ_MAX_POS = 10                 # FIX_V43_MAXPOS: raised 5->10 (11 legacy holdings blocking scan, \u20b980K idle)'
NEW = 'EQ_MAX_POS = 12                 # V102: raised 10->12 (more capacity for V92-V100 candidate quality)'

with open(PATH, "r") as f:
    content = f.read()
md5_before = hashlib.md5(content.encode()).hexdigest()
print(f"[V102] BEFORE md5={md5_before}")

# Try the exact match first; if rupee symbol gets mangled, fall back to looser match
if OLD in content:
    new_content = content.replace(OLD, NEW)
elif "EQ_MAX_POS = 10" in content and content.count("EQ_MAX_POS = 10") == 1:
    # Looser match if rupee symbol encoding differs
    import re
    new_content = re.sub(r'^EQ_MAX_POS = 10\b.*$', NEW, content, count=1, flags=re.MULTILINE)
    if new_content == content:
        print("[V102] FATAL: regex fallback also failed.")
        sys.exit(1)
else:
    print(f"[V102] FATAL: anchor not found uniquely (found {content.count('EQ_MAX_POS = 10')} times).")
    sys.exit(1)

try:
    ast.parse(new_content)
except SyntaxError as e:
    print(f"[V102] FATAL: syntax error: {e}")
    sys.exit(1)

shutil.copy(PATH, BACKUP)
print(f"[V102] backup -> {BACKUP}")
with open(PATH, "w") as f:
    f.write(new_content)
md5_after = hashlib.md5(new_content.encode()).hexdigest()
print(f"[V102] AFTER  md5={md5_after}")

# Verify
import subprocess
r = subprocess.run(["grep", "-n", "^EQ_MAX_POS", PATH], capture_output=True, text=True)
print(f"[V102] new line: {r.stdout.strip()}")
print("[V102] OK — EQ_MAX_POS raised 10 -> 12. Restart bot to apply.")
PYEOF
