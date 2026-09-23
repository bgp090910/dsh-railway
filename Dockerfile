FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g pnpm @deepseek-ai/dsh@0.1.5-rc.2

# Pre-create profile with pnpm allowBuilds + override for the unpublished
# @deepseek-ai/dsh-type-meta package (npm publish gap in dsh preview builds)
RUN mkdir -p /root/.dsh/profiles/web && \
    printf "allowBuilds:\n  'dsh-telegram-channel@git+https://github.com/hi-wenw/dsh-telegram-channel.git': true\noverrides:\n  '@deepseek-ai/dsh-type-meta': 'npm:@deepseek-ai/dsh-brand@0.1.7-rc.1'\n" \
    > /root/.dsh/profiles/web/pnpm-workspace.yaml

# Telegram bridge plugin (polling mode, outbound only)
RUN dsh plugin --profile web add github:hi-wenw/dsh-telegram-channel

WORKDIR /root

EXPOSE 3080
CMD ["dsh", "web", "--no-open"]
