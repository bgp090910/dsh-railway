#!/bin/sh
echo "===PURGE_DIAG2==="
echo "--- purge entry full config ---"
grep -B2 -A 25 "id: dsh-purge" /root/.dsh/profiles/web/cordis.patch.yml 2>/dev/null | head -35
echo "--- prompt-inject.md content head ---"
head -20 /root/.dsh/prompt-inject.md 2>/dev/null || echo "empty/missing"
echo "--- global dsh node_modules purged? (patched marker) ---"
ls /usr/local/lib/node_modules/@deepseek-ai/ 2>/dev/null | head -5
echo "--- profile node_modules @deepseek-ai ---"
ls /root/.dsh/profiles/web/node_modules/@deepseek-ai/ 2>/dev/null | head -8
echo "===PURGE_DIAG2_END==="
