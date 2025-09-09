# Bins
    FROM ghcr.io/lldap/lldap:v0.6.2 as lldap

# FS
    FROM docker.io/library/alpine:3.22.1 as FS

    RUN mkdir -p \
        /FS/bin \
        /FS/config \
        /FS/data \
        /FS/assets

    COPY --from=lldap /app/lldap /FS/bin/lldap
    COPY --from=lldap /app/app /FS/assets

# Final image
    FROM scratch

    # nobody
    USER 65534:65534

    COPY --from=FS /FS /

    HEALTHCHECK --interval=5s --timeout=2s --retries=3 --start-period=2s \
        CMD ["/bin/lldap", "healthcheck", "--config-file", "/config/lldap_config.toml"]

    # Check that binary can start
    RUN ["/bin/lldap", "--version"]

    ENTRYPOINT ["/bin/lldap"]
    CMD ["run", "--config-file", "/config/lldap_config.toml"]
