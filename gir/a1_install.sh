#!/bin/bash
set -e
cd /home/globalbot

if [ ! -f news_brain.py.a1_new ]; then
    echo "ERROR: news_brain.py.a1_new not found"
    echo "Upload it via SFTP first (same way you uploaded trendlyne_data.xlsx)"
    exit 1
fi

python3 -c "import py_compile; py_compile.compile('news_brain.py.a1_new', doraise=True)"
echo "New file SYNTAX OK"

BAK="news_brain.py.bak_pre_A1_$(date +%Y%m%d_%H%M%S)"
cp news_brain.py "$BAK"
echo "Backup: $BAK"

mv news_brain.py.a1_new news_brain.py
echo "Installed"

grep -c FIX_NB_A1_PARSER news_brain.py
wc -l news_brain.py
echo "Run: sudo systemctl restart globaleye"
