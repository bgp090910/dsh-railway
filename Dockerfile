FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates socat \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g pnpm @deepseek-ai/dsh@0.1.5-rc.2

# Pre-create profile with pnpm allowBuilds + override for the unpublished
# @deepseek-ai/dsh-type-meta package (npm publish gap in dsh preview builds)
RUN mkdir -p /root/.dsh/profiles/web && \
    printf "allowBuilds:\n  'dsh-telegram-channel@git+https://github.com/hi-wenw/dsh-telegram-channel.git': true\noverrides:\n  '@deepseek-ai/dsh-type-meta': 'npm:@deepseek-ai/dsh-brand@0.1.7-rc.1'\n" \
    > /root/.dsh/profiles/web/pnpm-workspace.yaml

# Telegram bridge plugin (polling mode, outbound only)
RUN dsh plugin --profile web add github:hi-wenw/dsh-telegram-channel

# dsh-purge jailbreak plugin (auto-apply on start per its cordis.patch.yml)
RUN dsh plugin --profile web add https://github.com/YuJunZhiXue/dsh-purge/archive/refs/heads/master.tar.gz

# Profile references this plugin but the npm dep list lags — install explicitly
RUN cd /root/.dsh/profiles/web && pnpm add @deepseek-ai/dsh-sandbox-local@0.1.5-rc.3 || true

# Production has no Cordis HMR service: switch patchReload from "live" to "startup"
RUN cd /root/.dsh/profiles/web && node -e "const fs=require('fs');const p='package.json';const j=JSON.parse(fs.readFileSync(p));j.dsh=j.dsh||{};j.dsh.profile=j.dsh.profile||{};j.dsh.profile.patchReload='startup';fs.writeFileSync(p,JSON.stringify(j,null,2));console.log('patchReload=startup')"

# Ollama Cloud as a custom provider (OpenAI-completions compatible)
RUN mkdir -p /root/.dsh && cat > /root/.dsh/settings.yaml <<'EOF'
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

WORKDIR /root

EXPOSE 3080 8080
CMD ["sh", "-c", "socat TCP-LISTEN:8080,fork,reuseaddr TCP:127.0.0.1:3080 & exec dsh web --no-open --trusted-host dsh-production-1e87.up.railway.app"]
