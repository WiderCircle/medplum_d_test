# Stage 1: build the React SPA
FROM node:24-slim AS builder
WORKDIR /usr/src/medplum

# Dependency manifests — copied first so npm ci is layer-cached
COPY package.json package-lock.json turbo.json tsconfig.json ./
COPY packages/app/package.json        ./packages/app/
COPY packages/core/package.json       ./packages/core/
COPY packages/definitions/package.json ./packages/definitions/
COPY packages/fhirtypes/package.json  ./packages/fhirtypes/
COPY packages/mock/package.json       ./packages/mock/
COPY packages/react/package.json      ./packages/react/
COPY packages/react-hooks/package.json ./packages/react-hooks/
RUN npm ci

# Source files for app and its workspace dependencies
COPY packages/app        ./packages/app
COPY packages/core       ./packages/core
COPY packages/definitions ./packages/definitions
COPY packages/fhirtypes  ./packages/fhirtypes
COPY packages/mock       ./packages/mock
COPY packages/react      ./packages/react
COPY packages/react-hooks ./packages/react-hooks

RUN npx turbo run build --filter=@medplum/app...

# Stage 2: nginx serving static files
FROM nginxinc/nginx-unprivileged:alpine
USER root

COPY <<EOF /etc/nginx/conf.d/default.conf
server {
    listen 3000;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, no-transform";
    }
}
EOF

COPY --from=builder /usr/src/medplum/packages/app/dist /usr/share/nginx/html
COPY packages/app/docker-entrypoint.sh /docker-entrypoint.sh

RUN chown -R 101:101 /usr/share/nginx/html && \
    chown 101:101 /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

EXPOSE 3000
USER 101
ENTRYPOINT ["/docker-entrypoint.sh"]
