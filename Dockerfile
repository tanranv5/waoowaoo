# ==================== Stage 1: Dependencies ====================
FROM node:20-bookworm-slim AS deps
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

# ==================== Stage 2: Build ====================
FROM node:20-bookworm-slim AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# ==================== Stage 3: Production ====================
FROM node:20-bookworm-slim AS runner
WORKDIR /app

ENV NODE_ENV=production

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    tini bash mariadb-server mariadb-client redis-server redis-tools ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/src ./src
COPY --from=builder /app/scripts ./scripts
COPY --from=builder /app/lib ./lib
COPY --from=builder /app/standards ./standards
COPY --from=builder /app/messages ./messages
COPY --from=builder /app/tsconfig.json ./tsconfig.json
COPY --from=builder /app/next.config.ts ./next.config.ts
COPY --from=builder /app/middleware.ts ./middleware.ts
COPY --from=builder /app/postcss.config.mjs ./postcss.config.mjs

RUN mkdir -p /app/data/uploads /app/data/mysql /app/data/redis /app/logs /run/mysqld \
  && chown -R mysql:mysql /app/data/mysql /run/mysqld \
  && chmod +x /app/scripts/docker/start-all-in-one.sh \
  && touch /app/.env

EXPOSE 3000 3010 3306 6379

ENTRYPOINT ["/usr/bin/tini", "--", "/app/scripts/docker/start-all-in-one.sh"]
