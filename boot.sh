#!/bin/sh
set -eu

MARKER=/root/.dsh/.booted-v36
DSH=/usr/local/bin/dsh

if [ ! -f "$MARKER" ]; then
  echo "=== first boot: clean bootstrap (dsh 0.1.5-rc.3) ==="
  mkdir -p /root/.dsh/profiles/web /root/.dsh/workspace

  printf "dangerouslyAllowAllBuilds: true\n" > /root/.dsh/profiles/web/pnpm-workspace.yaml

  # install plugin packages
  "$DSH" plugin --profile web add github:hi-wenw/dsh-telegram-channel.git#v0.2.3 --allow-build='*' || true
  "$DSH" plugin --profile web add https://github.com/YuJunZhiXue/dsh-purge/archive/refs/heads/master.tar.gz --allow-build='*' || true

  cd /root/.dsh/profiles/web && node -e "const fs=require('fs');const p='package.json';const j=JSON.parse(fs.readFileSync(p));j.dsh=j.dsh||{};j.dsh.profile=j.dsh.profile||{};j.dsh.profile.patchReload='startup';fs.writeFileSync(p,JSON.stringify(j,null,2));console.log('patchReload=startup')"

  # MANUALLY write clean cordis.patch.yml (dsh's reconcile concat bug)
  cat > /root/.dsh/profiles/web/cordis.patch.yml <<'EOF'
- id: system-prompt
  config:
    includeHarnessIdentity: false
    personaPrefix: ""
    personaSuffix: Your working directory is {{cwd}}.
- insert:
    - id: dsh-telegram-channel
      name: dsh-telegram-channel
      inject:
        - session
- insert:
    - id: dsh-purge
      name: dsh-purge
      config:
        enabled: true
        autoApplyOnStart: true
        autoUpdateOnStart: true
        autoRevertOnMissing: false
        injectOnce: false
        stripMnemon: true
        verbose: false
        postPrompt: ""
        postPromptOrder: 5100
        autoRetry: true
        retryMax: 3
        autoContinue: true
        continueMax: 3
        continueText: "继续"
- id: agent-default-model
  config:
    provider: ollama-cloud
    model: deepseek-v4.1-flash
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

socat TCP-LISTEN:8080,fork,reuseaddr TCP:127.0.0.1:3080 &
exec "$DSH" web --no-open --trusted-host dsh-production-1e87.up.railway.app
