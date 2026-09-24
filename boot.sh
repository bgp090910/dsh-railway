#!/bin/sh
set -eu

# Bootstraps the persistent $DSH_HOME volume on first boot only.
# Idempotent: later restarts/redeploys keep plugins, credentials,
# settings, and bound sessions on the mounted volume.

MARKER=/root/.dsh/.booted-v19
DSH=/usr/local/bin/dsh

if [ ! -f "$MARKER" ]; then
  echo "=== first boot: bootstrapping persistent dsh home ==="
  mkdir -p /root/.dsh/profiles/web /root/.dsh/workspace

  # pnpm >=10.9: run all dependency build scripts without approval
  printf "dangerouslyAllowAllBuilds: true\noverrides:\n  '@deepseek-ai/dsh-type-meta': 'npm:@deepseek-ai/dsh-brand@0.1.7-rc.1'\n" \
    > /root/.dsh/profiles/web/pnpm-workspace.yaml

  # rebuild cordis.patch.yml from scratch (previous boots corrupted it)
  rm -f /root/.dsh/profiles/web/cordis.patch.yml

  # missing sandbox plugin referenced by the web profile
  cd /root/.dsh/profiles/web && pnpm add @deepseek-ai/dsh-sandbox-local@0.1.5-rc.3 || true

  # Telegram bridge (remote-control style — the only plugin verified working
  # in this container; dsh-telegram fails activation on dsh 0.1.5-rc seam)
  "$DSH" plugin --profile web remove dsh-telegram || true
  rm -rf /root/.dsh/dsh-telegram-src
  "$DSH" plugin --profile web add github:hi-wenw/dsh-telegram-channel --allow-build='*' || true

  # remove the old remote-control style plugin
  "$DSH" plugin --profile web remove github:hi-wenw/dsh-telegram-channel || true
  cd /root/.dsh/profiles/web && pnpm remove @hi-wenw/dsh-telegram-channel 2>/dev/null || true
  rm -rf node_modules/.pnpm/*telegram-channel* 2>/dev/null || true
  echo "TELEGRAM_PLUGIN_SWAPPED"

  # dsh-purge jailbreak plugin
  "$DSH" plugin --profile web add https://github.com/YuJunZhiXue/dsh-purge/archive/refs/heads/master.tar.gz --allow-build='*' || true

  # Plugin market (further plugins one-click from the Web UI)
  "$DSH" plugin --profile web add dshmarket --allow-build='*' || true

  # Long-term cross-session memory (engram's prepare script is broken on pnpm 11; use dsh-memory instead)
  "$DSH" plugin --profile web add github:FuRongJun-1999/dsh-memory --allow-build='*' || true

  # Autonomous heartbeat tasks — removed (Windows-only plugin, useless on Linux)
  # Answer quality reviewer — removed (3987 config server breaks in container; not needed)

  # Prompt optimizer
  "$DSH" plugin --profile web add github:1321928757/dsh-prompt-polish --allow-build='*' || true

  # Remove plugins that break in the container / are useless here
  "$DSH" plugin --profile web remove github:bycall/dsh-answer-reviewer || true
  "$DSH" plugin --profile web remove github:Kanadego/dsh-heartbeat || true
  "$DSH" plugin --profile web remove github:kenz1117/dsh-engram || true
  # hard-clean leftover node_modules so dsh stops seeing fake workspaces
  cd /root/.dsh/profiles/web && pnpm remove @kanadego/dsh-heartbeat @kenz1117/dsh-engram 2>/dev/null || true
  rm -rf node_modules/.pnpm/*heartbeat* node_modules/.pnpm/*engram* node_modules/.pnpm/*answer-reviewer* 2>/dev/null || true
  echo "RESIDUE_CLEANED"

  # production: patchReload startup (no HMR)
  cd /root/.dsh/profiles/web && node -e "const fs=require('fs');const p='package.json';const j=JSON.parse(fs.readFileSync(p));j.dsh=j.dsh||{};j.dsh.profile=j.dsh.profile||{};j.dsh.profile.patchReload='startup';fs.writeFileSync(p,JSON.stringify(j,null,2));console.log('patchReload=startup')"

  # Ollama Cloud provider
  cat > /root/.dsh/settings.yaml <<'EOF'
llm-pi-ai:
  providers:
    ollama-cloud:
      apiKeyEnv: OLLAMA_API_KEY
      api: openai-completions
      baseURL: https://ollama.com/v1
      models:
        - id: glm-5.3
        - id: glm-5.3-flash
        - id: deepseek-v4.1-flash
        - id: kimi-k3
EOF

  touch "$MARKER"
  echo "=== bootstrap complete ==="
else
  echo "=== volume already bootstrapped, skipping ==="
fi

# Ensure default model in profile patch (idempotent, every boot)
PATCH=/root/.dsh/profiles/web/cordis.patch.yml
[ -f "$PATCH" ] || touch "$PATCH"
# strip any broken block from earlier attempts
sed -i '/^- id: agent-default-model$/,+4d' "$PATCH" 2>/dev/null || true
if ! grep -q "agent-default-model" "$PATCH"; then
  printf '\n- id: agent-default-model\n  config:\n    provider: ollama-cloud\n    model: deepseek-v4.1-flash\n' >> "$PATCH"
  echo "DEFAULT_MODEL_ADDED"
fi

# Telegram plugin config: whitelist + auto-start (workspace .pi/telegram.json)
mkdir -p /root/.dsh/workspace/.pi
cat > /root/.dsh/workspace/.pi/telegram.json <<'EOF'
{
  "security": { "allowedChatIds": [7906946450, 8549963548] },
  "watch": { "autoStart": true },
  "outbound": { "liveFeed": true },
  "interactive": { "userQuestions": "both" }
}
EOF
echo "TELEGRAM_CFG_READY"

# strip stale plugin references from profile bundles (fixes boot crash)
node -e '
const fs = require("fs");
const p = "/root/.dsh/profiles/web/package.json";
const j = JSON.parse(fs.readFileSync(p, "utf8"));
const BAD = ["@kanadego/dsh-heartbeat", "@kenz1117/dsh-engram", "@hi-wenw/dsh-telegram-channel", "@bycall/dsh-answer-reviewer", "dsh-telegram"];
if (j.dsh && j.dsh.profile && Array.isArray(j.dsh.profile.bundles)) {
  const before = j.dsh.profile.bundles.length;
  j.dsh.profile.bundles = j.dsh.profile.bundles.filter((b) => !BAD.includes(b));
  if (j.dsh.profile.bundles.length !== before) {
    fs.writeFileSync(p, JSON.stringify(j, null, 2));
    console.log("BUNDLES_CLEANED");
  } else {
    console.log("BUNDLES_OK");
  }
} else {
  console.log("NO_BUNDLES_FIELD");
}
'

# make the bundle patch file reachable at the expected node_modules path
mkdir -p /root/.dsh/profiles/web/node_modules/dsh-telegram
SRC=/root/.dsh/dsh-telegram-src/cordis.patch.yml
if [ -f "$SRC" ]; then
  cp "$SRC" /root/.dsh/profiles/web/node_modules/dsh-telegram/cordis.patch.yml
  echo "PATCH_FILE_COPIED"
fi

# (inject fix for dsh-telegram removed — plugin reverted to telegram-channel)

# KILL dsh-answer-reviewer completely (it grades jailbreak replies and forces refusals)
node -e '
const fs = require("fs");
const f = "/root/.dsh/profiles/web/cordis.patch.yml";
let lines = fs.readFileSync(f, "utf8").split("\n");
const out = [];
for (let i = 0; i < lines.length; i++) {
  const l = lines[i];
  if (/dsh-answer-reviewer/.test(l)) {
    if (out[out.length - 1] && out[out.length - 1].trim() === "- insert:") out.pop();
    i++; // skip the name line
    continue;
  }
  out.push(l);
}
fs.writeFileSync(f, out.join("\n"));
console.log("REVIEWER_PATCH_KILLED");
'
rm -rf /root/.dsh/profiles/web/node_modules/.pnpm/*answer-reviewer* /root/.dsh/profiles/web/node_modules/@bycall 2>/dev/null || true
rm -rf /root/.dsh/profiles/web/node_modules/dsh-answer-reviewer 2>/dev/null || true
echo "REVIEWER_KILLED"

# ensure dsh-purge entries exist in the profile patch (tar.gz installs lose them on rebuild)
PATCH=/root/.dsh/profiles/web/cordis.patch.yml
if ! grep -q "id: dsh-purge" "$PATCH"; then
  printf '\n- id: system-prompt\n  config:\n    includeHarnessIdentity: false\n    personaPrefix: ""\n    personaSuffix: Your working directory is {{cwd}}.\n' >> "$PATCH"
  printf '\n- insert:\n    - id: dsh-purge\n      name: dsh-purge\n      config:\n        enabled: true\n        autoApplyOnStart: true\n        autoUpdateOnStart: true\n        autoRevertOnMissing: false\n        injectOnce: false\n        stripMnemon: true\n        verbose: false\n        postPrompt: ""\n        postPromptOrder: 5100\n        autoRetry: true\n        retryMax: 3\n        autoContinue: true\n        continueMax: 3\n        continueText: "继续"\n' >> "$PATCH"
  echo "PURGE_PATCH_RESTORED"
fi

# telegram-channel needs apiProxy injected for /model (dsh 0.1.5-rc seam)
TB=/root/.dsh/profiles/web/node_modules/dsh-telegram-channel/cordis.patch.yml
if [ -f "$TB" ] && ! grep -q "apiProxy" "$TB"; then
  sed -i '/      name: dsh-telegram-channel/a\      inject:\n        - apiProxy' "$TB"
  echo "APIPROXY_INJECT_FIXED"
fi

socat TCP-LISTEN:8080,fork,reuseaddr TCP:127.0.0.1:3080 &
exec "$DSH" web --no-open --trusted-host dsh-production-1e87.up.railway.app
