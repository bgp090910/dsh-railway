#!/bin/sh
set -eu

MARKER=/root/.dsh/.booted-v41
DSH=/usr/local/bin/dsh

if [ ! -f "$MARKER" ]; then
  echo "=== first boot: clean bootstrap (dsh 0.1.5-rc.3) ==="
  mkdir -p /root/.dsh/profiles/web /root/.dsh/workspace

  printf "dangerouslyAllowAllBuilds: true\noverrides:\n  '@deepseek-ai/dsh-type-meta': 'npm:@deepseek-ai/dsh-brand@0.1.7-rc.1'\n" > /root/.dsh/profiles/web/pnpm-workspace.yaml

  # install plugin packages
  "$DSH" plugin --profile web add dsh-notifier --allow-build='*' || true
  "$DSH" plugin --profile web add https://github.com/YuJunZhiXue/dsh-purge/archive/refs/heads/master.tar.gz --allow-build='*' || true

  cd /root/.dsh/profiles/web && node -e "const fs=require('fs');const p='package.json';const j=JSON.parse(fs.readFileSync(p));j.dsh=j.dsh||{};j.dsh.profile=j.dsh.profile||{};j.dsh.profile.patchReload='startup';fs.writeFileSync(p,JSON.stringify(j,null,2));console.log('patchReload=startup')"

  # Profile patch: default model + notifier channels (telegram)
  cat > /root/.dsh/profiles/web/cordis.patch.yml <<'EOF'
- id: agent-default-model
  config:
    provider: ollama-cloud
    model: deepseek-v4.1-flash
- id: dsh-notifier
  config:
    enabled: true
    debounceMs: 10000
    summaryMaxChars: 500
    channels:
      - type: telegram
        botToken: "${ENV:TELEGRAM_BOT_TOKEN}"
        chatId: "7906946450"
    admin:
      enabled: true
EOF
  echo "MANUAL_PATCH_WRITTEN"

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
  echo "=== volume already bootstrapped ==="
fi

# telegram-channel v0.2.3: strip apiProxy inject (removed seam in 0.1.5)
TB=/root/.dsh/profiles/web/node_modules/dsh-telegram-channel/cordis.patch.yml
if [ -f "$TB" ]; then
  sed -i '/apiProxy/d' "$TB"
  echo "APIPROXY_STRIPPED"
fi

# dsh-purge identity: GLM ZCODE jailbreak prompt (glm-5.3 specific, strong)
curl -fsSL "https://raw.githubusercontent.com/YuJunZhiXue/jailbreaks/main/GLM%20ZCODE.md" \
  -o /root/.dsh/prompt-inject.md 2>/dev/null || echo "ZCODE_DOWNLOAD_FAILED"
[ -s /root/.dsh/prompt-inject.md ] && echo "PROMPT_INJECT_READY"

# print notifier bootstrap pairing code to logs (user pairs via /pair <code>)
if [ -f /root/.dsh/dsh-notifier/bootstrap-paircode.txt ]; then
  echo "PAIRCODE: $(cat /root/.dsh/dsh-notifier/bootstrap-paircode.txt)"
fi

socat TCP-LISTEN:8080,fork,reuseaddr TCP:127.0.0.1:3080 &
exec "$DSH" web --no-open --trusted-host dsh-production-1e87.up.railway.app
