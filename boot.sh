#!/bin/sh
set -eu

MARKER=/root/.dsh/.booted-v33
DSH=/usr/local/bin/dsh

if [ ! -f "$MARKER" ]; then
  echo "=== first boot: clean bootstrap (dsh 0.1.7-rc.1) ==="
  mkdir -p /root/.dsh/profiles/web /root/.dsh/workspace

  printf "dangerouslyAllowAllBuilds: true\n" \
    > /root/.dsh/profiles/web/pnpm-workspace.yaml

  # remove leftovers from earlier experiments
  "$DSH" plugin --profile web remove dsh-telegram-control || true
  "$DSH" plugin --profile web remove dsh-telegram-channel || true
  "$DSH" plugin --profile web remove dsh-telegram || true

  # Telegram native bridge (npm 0.2.0 — ships cordis.patch.yml; inject patched below)
  "$DSH" plugin --profile web add dsh-telegram --allow-build='*' || true

  # dsh-purge jailbreak
  "$DSH" plugin --profile web add https://github.com/YuJunZhiXue/dsh-purge/archive/refs/heads/master.tar.gz --allow-build='*' || true

  # plugin market
  "$DSH" plugin --profile web add dshmarket --allow-build='*' || true

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

  # default model
  printf '\n- id: agent-default-model\n  config:\n    provider: ollama-cloud\n    model: deepseek-v4.1-flash\n' >> /root/.dsh/profiles/web/cordis.patch.yml

  touch "$MARKER"
  echo "=== bootstrap complete ==="
else
  echo "=== volume already bootstrapped ==="
fi

# dsh-telegram 0.2.0 inject fix: add 'agent' to its bundle patch
TB=/root/.dsh/profiles/web/node_modules/dsh-telegram/cordis.patch.yml
if [ -f "$TB" ] && ! grep -qE '^[ ]*- agent$' "$TB"; then
  sed -i '/^[ ]*- agents$/i\        - agent' "$TB"
  echo "AGENT_INJECT_ADDED"
fi

# telegram whitelist + autostart
mkdir -p /root/.dsh/workspace/.pi
cat > /root/.dsh/workspace/.pi/telegram.json <<'EOF'
{
  "security": { "allowedChatIds": [7906946450, 8549963548] },
  "watch": { "autoStart": true },
  "outbound": { "liveFeed": true },
  "interactive": { "userQuestions": "both" }
}
EOF

socat TCP-LISTEN:8080,fork,reuseaddr TCP:127.0.0.1:3080 &
exec "$DSH" web --no-open --trusted-host dsh-production-1e87.up.railway.app
