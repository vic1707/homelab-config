# Build stage
## can be docker.io || registry.fedoraproject.org || registry.access.redhat.com
ARG CONTAINER_REGISTRY=docker.io
ARG CADDY_VERSION=2.10.0

FROM ${CONTAINER_REGISTRY}/library/caddy:${CADDY_VERSION}-builder-alpine AS builder

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

## https://github.com/caddyserver/caddy-docker/issues/396
RUN setcap cap_net_bind_service=+p /usr/bin/caddy

# Helper images
FROM 11notes/distroless:curl AS curl

FROM scratch

COPY --from=curl /usr/local/bin/curl /usr/local/bin/curl
COPY --from=builder /usr/bin/caddy /usr/local/bin/caddy

HEALTHCHECK --interval=5s --timeout=2s --start-period=5s \
	CMD ["/usr/local/bin/curl", "-kILs", "--fail", "-o", "/dev/null", "http://localhost:9999/health"]

USER 1001:1001
VOLUME [ "/data/caddy", "/var/caddy" ]
ENTRYPOINT ["/usr/local/bin/caddy"]
CMD ["run", "--config", "/etc/caddy/Caddyfile"]
