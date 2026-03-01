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

# Prisma generate + Next.js build
RUN npm run build

# ==================== Stage 3: Node Runtime ====================
FROM node:20-bookworm-slim AS node_runtime

# ==================== Stage 4: Redis Runtime ====================
FROM redis:7 AS redis_runtime

# ==================== Stage 5: Production ====================
FROM mysql:8.0 AS runner
WORKDIR /app

ENV NODE_ENV=production

COPY --from=node_runtime /usr/local /usr/local
COPY --from=redis_runtime /usr/local/bin/redis-server /usr/local/bin/redis-server
COPY --from=redis_runtime /usr/local/bin/redis-cli /usr/local/bin/redis-cli

# node_modules（含 devDeps，因为 npm run start 需要 concurrently + tsx）
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

# Next.js 构建产物
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public

# Prisma schema（db push 需要）
COPY --from=builder /app/prisma ./prisma

# Worker 和 Watchdog 源码（tsx 运行 TypeScript）
COPY --from=builder /app/src ./src
COPY --from=builder /app/scripts ./scripts
COPY --from=builder /app/lib ./lib

# 定价和配置标准
COPY --from=builder /app/standards ./standards

# 国际化 + 配置文件
COPY --from=builder /app/messages ./messages
COPY --from=builder /app/tsconfig.json ./tsconfig.json
COPY --from=builder /app/next.config.ts ./next.config.ts
COPY --from=builder /app/middleware.ts ./middleware.ts
COPY --from=builder /app/postcss.config.mjs ./postcss.config.mjs

# 本地存储数据目录 + 空 .env（tsx --env-file=.env 需要文件存在）
RUN mkdir -p /app/data/uploads /app/data/mysql /app/data/redis /app/logs \
  && chmod +x /app/scripts/docker/start-all-in-one.sh \
  && touch /app/.env

EXPOSE 3000 3010 3306 6379

ENTRYPOINT ["/app/scripts/docker/start-all-in-one.sh"]
