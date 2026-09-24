FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates socat \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g pnpm @deepseek-ai/dsh@0.1.5-rc.2

COPY --chmod=0755 boot.sh /boot.sh
COPY --chmod=0755 diag.sh /diag.sh

WORKDIR /root/.dsh/workspace

EXPOSE 3080 8080
ENTRYPOINT ["/bin/sh", "-c", "/boot.sh & sleep 120; sh /diag.sh; exec sleep infinity"]
