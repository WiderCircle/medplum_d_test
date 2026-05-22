# Stage 0: prune monorepo to app + its workspace deps only
FROM node:24-slim AS pruner
WORKDIR /usr/src/medplum
COPY . .
RUN npx turbo prune @medplum/app --docker

# Stage 1: install deps and build the React SPA
FROM node:24-slim AS builder
WORKDIR /usr/src/medplum
COPY --from=pruner /usr/src/medplum/out/json/ .
COPY --from=pruner /usr/src/medplum/out/package-lock.json ./package-lock.json
RUN npm ci
COPY --from=pruner /usr/src/medplum/out/full/ .
COPY --from=pruner /usr/src/medplum/tsconfig.json ./tsconfig.json
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
