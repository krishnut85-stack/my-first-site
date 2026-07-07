#!/bin/bash
cd /home/globalbot
echo "=== Final file ==="
md5sum gir.py
wc -l gir.py
echo ""
echo "=== AST check ==="
python3 -c "import ast; ast.parse(open('gir.py').read()); print('AST OK')" || { echo 'AST FAILED'; exit 1; }
echo ""
echo "=== py_compile ==="
python3 -m py_compile gir.py && echo "py_compile OK" || { echo 'py_compile FAILED'; exit 1; }
echo ""
echo "=== V101C markers ==="
grep -c "V101C" gir.py
echo ""
echo "=== All V101 markers ==="
grep -c "V101A\|V101B\|V101C" gir.py
echo ""
echo "=== Backups ==="
ls -la gir_backup_pre_V101*.py 2>/dev/null
ls -la gir_master_backup_pre_V101C_*.py 2>/dev/null
echo ""
echo "If both AST OK and py_compile OK: sudo systemctl restart globaleye"
echo "Then watch: journalctl -u globaleye -f | grep V101C"
echo ""
echo "Rollback if needed:"
echo "  cp gir_master_backup_pre_V101C_*.py gir.py && sudo systemctl restart globaleye"
