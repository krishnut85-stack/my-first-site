#!/bin/bash
# Run FIRST. Master backup before V101C touches gir.py.
cd /home/globalbot
cp gir.py gir_master_backup_pre_V101C_$(date +%Y%m%d_%H%M%S).py
ls -la gir.py gir_master_backup_pre_V101C_*.py | tail -3
md5sum gir.py
wc -l gir.py
echo "Master backup done. Now run PATCH_12."
