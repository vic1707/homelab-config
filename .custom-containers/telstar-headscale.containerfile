# Bins
	# keep in sync with headscale-console env config
    FROM ghcr.io/juanfont/headscale:v0.27.1 as headscale

# Tools
    FROM ghcr.io/11notes/distroless:localhealth AS distroless-localhealth

# FS
    FROM docker.io/library/alpine:3.22.1 as FS

    RUN mkdir -p \
        /FS/bin \
        /FS/config \
        /FS/data

    COPY --from=distroless-localhealth /usr/local/bin/localhealth /FS/bin/localhealth
    COPY --from=headscale /ko-app/headscale /FS/bin/headscale
    COPY --from=headscale /etc/ssl/certs/ca-certificates.crt /FS/etc/ssl/certs/ca-certificates.crt

# Final image
    FROM scratch

    # nobody
    USER 65534:65534

    COPY --from=FS /FS /

    # TODO: probably not right
    HEALTHCHECK --interval=5s --timeout=2s --retries=3 --start-period=2s \
        CMD ["/bin/localhealth", "http://127.0.0.1:8080/api/v1/health", "-I"]

    # Check that binary can start
    RUN ["/bin/headscale", "version"]

    ENV HEADSCALE_CONFIG /config/config.yaml
    ENTRYPOINT ["/bin/headscale", "serve"]
