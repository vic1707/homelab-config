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

    # Allows to not set the NET_BIND_SERVICE capability to the container
    RUN setcap cap_net_bind_service=+p /usr/bin/caddy

# Tools
    FROM ghcr.io/11notes/distroless:localhealth AS distroless-localhealth

# FS
    FROM docker.io/library/alpine:3.23.3 as FS

    RUN mkdir -p \
        /FS/bin \
        /FS/config \
        /FS/data \
        /FS/log

    COPY --from=distroless-localhealth /usr/local/bin/localhealth /FS/bin/localhealth
    COPY --from=builder /usr/bin/caddy /FS/bin/caddy

# Final image
    FROM scratch

    # nobody
    USER 65534:65534

    COPY --from=FS /FS /

    HEALTHCHECK --interval=5s --timeout=2s --retries=3 --start-period=2s \
        CMD ["/bin/localhealth", "http://127.0.0.1:80/health", "-I"]

    # Check that binary can start
    RUN ["/bin/caddy", "--version"]

    # See https://caddyserver.com/docs/conventions#file-locations
    ENV XDG_DATA_HOME /data
    ENTRYPOINT ["/bin/caddy"]
    CMD ["run", "--config", "/config/Caddyfile", "--adapter", "caddyfile"]
