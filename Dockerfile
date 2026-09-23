FROM node:22-slim

RUN npm install -g pnpm @deepseek-ai/dsh

# Telegram bridge plugin (polling mode, outbound only)
RUN dsh plugin --profile web add github:hi-wenw/dsh-telegram-channel

WORKDIR /root

EXPOSE 3080
CMD ["dsh", "web", "--no-open"]
