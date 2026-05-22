# Stage 1: install deps and build the React SPA
FROM node:24-slim AS builder
WORKDIR /usr/src/medplum
COPY . .
RUN npm ci
RUN npx turbo run build --filter=@medplum/app...

# Stage 2: nginx serving static files
FROM nginxinc/nginx-unprivileged:alpine
USER root
COPY nginx.app.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /usr/src/medplum/packages/app/dist /usr/share/nginx/html
COPY packages/app/docker-entrypoint.sh /docker-entrypoint.sh
RUN chown -R 101:101 /usr/share/nginx/html && \
    chown 101:101 /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh
EXPOSE 3000
USER 101
ENTRYPOINT ["/docker-entrypoint.sh"]
