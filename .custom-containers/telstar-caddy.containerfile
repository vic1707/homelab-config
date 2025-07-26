# Build stage
## can be docker.io/<user> || registry.fedoraproject.org || registry.access.redhat.com
ARG CONTAINER_REGISTRY=docker.io/library
ARG CADDY_VERSION=2.10.0

FROM ${CONTAINER_REGISTRY}/caddy:${CADDY_VERSION}-builder-alpine AS builder

RUN xcaddy build \
	`# Use cloudflare dns validation` \
	--with github.com/caddy-dns/cloudflare \
	`# Automatically retreive cloudflare IPs` \
	--with github.com/WeidiDeng/caddy-cloudflare-ip \
	`# Auto update cloudflare DNS records` \
	--with github.com/mholt/caddy-dynamicdns

# Final image
FROM ${CONTAINER_REGISTRY}/caddy:${CADDY_VERSION}-alpine
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
