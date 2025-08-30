# Build stage
FROM docker.io/library/caddy:2.10.2-builder-alpine AS builder

RUN xcaddy build \
	`# Use cloudflare dns validation` \
	--with github.com/caddy-dns/cloudflare \
	`# Automatically retreive cloudflare IPs` \
	--with github.com/WeidiDeng/caddy-cloudflare-ip \
	`# Auto update cloudflare DNS records` \
	--with github.com/mholt/caddy-dynamicdns \
	`# Allows merging trusted_proxies` \
	--with github.com/fvbommel/caddy-combine-ip-ranges \
	`# Layer 4 support` \
	--with github.com/mholt/caddy-l4 \
	`# Crowdsec bouncer module` \
	--with github.com/hslatman/caddy-crowdsec-bouncer/http \
	--with github.com/hslatman/caddy-crowdsec-bouncer/appsec \
	--with github.com/hslatman/caddy-crowdsec-bouncer/layer4

# Final image
FROM docker.io/library/caddy:2.10.2-alpine
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
