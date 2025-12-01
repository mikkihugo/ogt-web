# Medusa.js v2 on Fly.io
# Build cache buster: 2025-11-30-medusa-v1

FROM node:20-alpine AS base
RUN corepack enable

# Dependencies stage
FROM base AS deps
WORKDIR /app

# Copy package files
COPY package.json yarn.lock .yarnrc.yml ./

# Install dependencies
RUN yarn install --immutable

# Build stage
FROM base AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build Medusa
RUN yarn build

# Production stage
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=9000

# Create non-root user
RUN addgroup --system --gid 1001 medusa && \
    adduser --system --uid 1001 medusa

# Copy built application
COPY --from=builder --chown=medusa:medusa /app/package.json ./
COPY --from=builder --chown=medusa:medusa /app/yarn.lock ./
COPY --from=builder --chown=medusa:medusa /app/.yarnrc.yml ./
COPY --from=builder --chown=medusa:medusa /app/node_modules ./node_modules
COPY --from=builder --chown=medusa:medusa /app/.medusa ./.medusa
COPY --from=builder --chown=medusa:medusa /app/medusa-config.ts ./

# Copy source files needed at runtime
COPY --from=builder --chown=medusa:medusa /app/src ./src

USER medusa

EXPOSE 9000

# Medusa start command
CMD ["yarn", "start"]
