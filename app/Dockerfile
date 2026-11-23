# syntax=docker/dockerfile:1
FROM node:22-alpine

# The version is baked into the image at build time.
ARG APP_VERSION=1.0.0
# BROKEN=true builds a deliberately bad image whose readiness probe never passes.
ARG BROKEN=false

LABEL org.opencontainers.image.title="pod-pulse" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.source="https://github.com/samuelshine/devops-lab-5" \
      org.opencontainers.image.authors="Samuel Shine"

ENV NODE_ENV=production \
    APP_VERSION=${APP_VERSION} \
    BROKEN=${BROKEN} \
    PORT=3000

WORKDIR /app
COPY package.json server.js ./
COPY public ./public
USER node
EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=3s CMD wget -qO- http://127.0.0.1:3000/healthz || exit 1
CMD ["node", "server.js"]
