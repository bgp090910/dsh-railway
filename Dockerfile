FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g pnpm @deepseek-ai/dsh@0.1.5-rc.2

# Allow the git-hosted plugin's build step (pnpm allowBuilds requirement)
RUN mkdir -p /root/.dsh/profiles/web && \
    printf "allowBuilds:\n  'dsh-telegram-channel@git+https://github.com/hi-wenw/dsh-telegram-channel.git': true\n" \
    > /root/.dsh/profiles/web/pnpm-workspace.yaml

# Telegram bridge plugin (polling mode, outbound only)
RUN dsh plugin --profile web add github:hi-wenw/dsh-telegram-channel

WORKDIR /root

EXPOSE 3080
CMD ["dsh", "web", "--no-open"]
