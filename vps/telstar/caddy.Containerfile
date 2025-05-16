# Build stage
ARG CADDY_VERSION=2.10.0
FROM caddy:${CADDY_VERSION}-builder-alpine AS builder

RUN xcaddy build \
	`# Cloudflare DNS module` \
    --with github.com/caddy-dns/cloudflare

# Final stage
FROM caddy:${CADDY_VERSION}-alpine
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
