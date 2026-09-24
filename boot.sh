#!/bin/sh
set -eu

# Bootstraps the persistent $DSH_HOME volume on first boot only.
# Idempotent: later restarts/redeploys keep plugins, credentials,
# settings, and bound sessions on the mounted volume.

MARKER=/root/.dsh/.booted-v5
DSH=/usr/local/bin/dsh

if [ ! -f "$MARKER" ]; then
  echo "=== first boot: bootstrapping persistent dsh home ==="
  mkdir -p /root/.dsh/profiles/web

  # allow ALL package builds (pnpm 11+ blocks git-plugin prepare scripts)
  printf "allowBuilds:\n  '*': true\noverrides:\n  '@deepseek-ai/dsh-type-meta': 'npm:@deepseek-ai/dsh-brand@0.1.7-rc.1'\n" \
    > /root/.dsh/profiles/web/pnpm-workspace.yaml

  # missing sandbox plugin referenced by the web profile
  cd /root/.dsh/profiles/web && pnpm add @deepseek-ai/dsh-sandbox-local@0.1.5-rc.3 || true

  # Telegram bridge (polling)
  "$DSH" plugin --profile web add github:hi-wenw/dsh-telegram-channel --allow-build='*' || true

  # dsh-purge jailbreak plugin
  "$DSH" plugin --profile web add https://github.com/YuJunZhiXue/dsh-purge/archive/refs/heads/master.tar.gz --allow-build='*' || true

  # Plugin market (further plugins one-click from the Web UI)
  "$DSH" plugin --profile web add dshmarket --allow-build='*' || true

  # Long-term cross-session memory
  "$DSH" plugin --profile web add github:kenz1117/dsh-engram --allow-build='*' || true

  # Autonomous heartbeat tasks
  "$DSH" plugin --profile web add github:Kanadego/dsh-heartbeat --allow-build='*' || true

  # Answer quality reviewer
  "$DSH" plugin --profile web add github:bycall/dsh-answer-reviewer --allow-build='*' || true

  # Prompt optimizer
  "$DSH" plugin --profile web add github:1321928757/dsh-prompt-polish --allow-build='*' || true

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

socat TCP-LISTEN:8080,fork,reuseaddr TCP:127.0.0.1:3080 &
exec "$DSH" web --no-open --trusted-host dsh-production-1e87.up.railway.app
