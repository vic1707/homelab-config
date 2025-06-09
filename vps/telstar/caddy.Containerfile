# Build stage
## can be docker.io/<user> || registry.fedoraproject.org || registry.access.redhat.com
ARG CONTAINER_REGISTRY=docker.io/library
ARG CADDY_VERSION=2.10.0
# FROM ${CONTAINER_REGISTRY}/caddy:${CADDY_VERSION}-builder-alpine AS builder

# RUN xcaddy build \
# 	`# foo module` \
# 	--with foo

# Final image
FROM ${CONTAINER_REGISTRY}/caddy:${CADDY_VERSION}-alpine
# COPY --from=builder /usr/bin/caddy /usr/bin/caddy
