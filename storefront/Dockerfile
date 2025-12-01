# Build stage
FROM node:22-slim AS builder
WORKDIR /app

ARG PUBLIC_MEDUSA_BACKEND_URL=https://api.orgasmtoy.com
ARG PUBLIC_MEDUSA_PUBLISHABLE_KEY
ENV PUBLIC_MEDUSA_BACKEND_URL=$PUBLIC_MEDUSA_BACKEND_URL
ENV PUBLIC_MEDUSA_PUBLISHABLE_KEY=$PUBLIC_MEDUSA_PUBLISHABLE_KEY

# Copy package files
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Copy source and build
COPY . .
RUN yarn build

# Production stage
FROM node:22-slim AS runner
WORKDIR /app

# Create non-root user
RUN groupadd -g 1001 astro && \
    useradd -u 1001 -g astro astro

# Copy only production files
COPY --from=builder --chown=astro:astro /app/dist ./dist
COPY --from=builder --chown=astro:astro /app/node_modules ./node_modules
COPY --from=builder --chown=astro:astro /app/package.json ./

USER astro
EXPOSE 4321

ENV HOST=0.0.0.0
ENV PORT=4321

CMD ["node", "./dist/server/entry.mjs"]
