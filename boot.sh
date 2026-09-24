#!/bin/sh
set -eu

MARKER=/root/.dsh/.booted-v36
DSH=/usr/local/bin/dsh

if [ ! -f "$MARKER" ]; then
  echo "=== first boot: clean bootstrap ==="
  mkdir -p /root/.dsh/profiles/web /root/.dsh/workspace

  printf "dangerouslyAllowAllBuilds: true\n" > /root/.dsh/profiles/web/pnpm-workspace.yaml

  # install plugin packages (patches written manually below to avoid dsh's YAML concat bug)
  "$DSH" plugin --profile web add dsh-telegram --allow-build='*' || true
  "$DSH" plugin --profile web add https://github.com/YuJunZhiXue/dsh-purge/archive/refs/heads/master.tar.gz --allow-build='*' || true

  cd /root/.dsh/profiles/web && node -e "const fs=require('fs');const p='package.json';const j=JSON.parse(fs.readFileSync(p));j.dsh=j.dsh||{};j.dsh.profile=j.dsh.profile||{};j.dsh.profile.patchReload='startup';fs.writeFileSync(p,JSON.stringify(j,null,2));console.log('patchReload=startup')"

  # MANUALLY write a clean, complete cordis.patch.yml (bypasses dsh's buggy reconcile)
  cat > /root/.dsh/profiles/web/cordis.patch.yml <<'EOF'
- id: system-prompt
  config:
    includeHarnessIdentity: false
    personaPrefix: ""
    personaSuffix: Your working directory is {{cwd}}.
- insert:
    - id: telegram
      name: dsh-telegram
      inject:
        - agent
        - agents
        - llm
        - credentials
        - userQuestions
        - agentDefaultModel
        - attachments
        - workspaceRegistry
      config:
        enabled: true
        tokenRef: TELEGRAM_BOT_TOKEN
        streaming: true
        showToolActivity: true
        allowedUsers: []
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
