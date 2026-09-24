#!/bin/sh
set -eu

# Clean rebuild bootstrap (volume is fresh).
MARKER=/root/.dsh/.booted-v30
DSH=/usr/local/bin/dsh

if [ ! -f "$MARKER" ]; then
  echo "=== first boot: clean bootstrap ==="
  mkdir -p /root/.dsh/profiles/web /root/.dsh/workspace

  # pnpm: allow all builds + override unpublished dsh-type-meta
  printf "dangerouslyAllowAllBuilds: true\noverrides:\n  '@deepseek-ai/dsh-type-meta': 'npm:@deepseek-ai/dsh-brand@0.1.7-rc.1'\n" \
    > /root/.dsh/profiles/web/pnpm-workspace.yaml

  # missing sandbox plugin referenced by the web profile
  cd /root/.dsh/profiles/web && pnpm add @deepseek-ai/dsh-sandbox-local@0.1.5-rc.3 || true

  # 1. Telegram bridge: dsh-telegram-control (zero runtime deps, direct chat)
  "$DSH" plugin --profile web add github:jackControls/dsh-telegram-control || true

  # 2. dsh-purge jailbreak plugin (auto-apply on start)
  "$DSH" plugin --profile web add https://github.com/YuJunZhiXue/dsh-purge/archive/refs/heads/master.tar.gz || true

  # 3. plugin market (optional convenience)
  "$DSH" plugin --profile web add dshmarket || true

  # production: patchReload startup (no HMR in container)
  cd /root/.dsh/profiles/web && node -e "const fs=require('fs');const p='package.json';const j=JSON.parse(fs.readFileSync(p));j.dsh=j.dsh||{};j.dsh.profile=j.dsh.profile||{};j.dsh.profile.patchReload='startup';fs.writeFileSync(p,JSON.stringify(j,null,2));console.log('patchReload=startup')"

  # Ollama Cloud provider (OpenAI-completions compatible)
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

socat TCP-LISTEN:8080,fork,reuseaddr TCP:127.0.0.1:3080 &
exec "$DSH" web --no-open --trusted-host dsh-production-1e87.up.railway.app
