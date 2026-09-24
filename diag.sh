#!/bin/sh
echo "===PURGE_DIAG==="
echo "--- dsh-purge entry in profile patch ---"
grep -A 15 "dsh-purge" /root/.dsh/profiles/web/cordis.patch.yml 2>/dev/null | head -20 || echo "not in profile patch"
echo "--- purge installed in node_modules? ---"
ls -d /root/.dsh/profiles/web/node_modules/*purge* /root/.dsh/profiles/web/node_modules/.pnpm/*purge* 2>/dev/null || echo "no purge dirs"
echo "--- prompt-inject.md anywhere ---"
find /root/.dsh -maxdepth 3 -name "prompt-inject.md" 2>/dev/null || echo "no prompt-inject.md"
echo "--- dsh home root listing ---"
ls /root/.dsh/ 2>/dev/null
echo "===PURGE_DIAG_END==="
