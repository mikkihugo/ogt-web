FROM node:22-alpine AS builder

WORKDIR /app

# Install system dependencies (needed for some native modules)
RUN apk add --no-cache python3 make g++

COPY package.json yarn.lock ./

# Install dependencies with cache
RUN --mount=type=cache,target=/root/.yarn YARN_CACHE_FOLDER=/root/.yarn yarn install --frozen-lockfile

COPY . .

# Build Medusa
RUN yarn build

FROM node:22-alpine AS runner

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S medusa -u 1001

# Copy built artifacts and modules
COPY --from=builder --chown=medusa:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=medusa:nodejs /app/.medusa ./
COPY --from=builder --chown=medusa:nodejs /app/package.json ./
# Copy other necessary files if any (e.g. medusa-config)
COPY --from=builder --chown=medusa:nodejs /app .

USER medusa
EXPOSE 9000

CMD ["yarn", "start"]
