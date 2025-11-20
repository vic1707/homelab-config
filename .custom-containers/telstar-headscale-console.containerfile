# Bins
    FROM ghcr.io/rickli-cloud/headscale-console:0.5.0 as headscale

# FS
    FROM docker.io/library/alpine:3.22.1 as FS

    RUN mkdir -p \
        /FS/bin

    COPY --from=headscale /headscale-console /FS/bin/headscale-console

# Final image
    FROM scratch

    # nobody
    USER 65534:65534

    COPY --from=FS /FS /

    HEALTHCHECK --interval=5s --timeout=2s --retries=3 --start-period=2s \
        CMD ["/bin/headscale-console", "health"]

    # Check that binary can start
    RUN ["/bin/headscale-console", "--help"]

    ENTRYPOINT ["/bin/headscale-console"]
