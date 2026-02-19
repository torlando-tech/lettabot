# Stage 1: Build patched letta-code bundle with Bun
FROM oven/bun:1 AS letta-code-builder
WORKDIR /build
COPY letta-code/ ./
RUN bun install && bun run build.js

# Stage 2: Build lettabot with Node
FROM node:22-slim AS lettabot-builder
WORKDIR /app
COPY lettabot/package*.json ./
RUN npm ci
# Replace the npm-installed letta-code bundle with our patched build
COPY --from=letta-code-builder /build/letta.js ./node_modules/@letta-ai/letta-code/letta.js
COPY --from=letta-code-builder /build/skills/ ./node_modules/@letta-ai/letta-code/skills/
COPY lettabot/ ./
RUN npm run build

# Stage 3: Runtime
FROM node:22-slim
WORKDIR /app

# Install curl (needed for conversation seeding at startup)
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

# Install signal-cli native binary (GraalVM-compiled, ~300MB)
ADD https://github.com/AsamK/signal-cli/releases/download/v0.13.23/signal-cli-0.13.23-Linux-native.tar.gz /tmp/signal-cli.tar.gz
RUN tar xf /tmp/signal-cli.tar.gz -C /opt/ \
    && chmod +x /opt/signal-cli \
    && ln -s /opt/signal-cli /usr/local/bin/signal-cli \
    && rm /tmp/signal-cli.tar.gz

# Copy built app
COPY --from=lettabot-builder /app ./

# Link bin entries so `node /usr/local/bin/lettabot` works
RUN ln -sf /app/dist/cli.js /usr/local/bin/lettabot \
    && chmod +x /app/dist/cli.js

ENTRYPOINT ["node", "/usr/local/bin/lettabot", "server"]
