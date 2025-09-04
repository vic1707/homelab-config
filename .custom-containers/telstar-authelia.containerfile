# Cheating stage
    FROM ghcr.io/authelia/authelia:4.39.6 as authelia
    FROM docker.io/library/debian:12.11 as bins

    COPY --from=authelia /app/authelia /bin/authelia

    # Get all needed libs
    COPY import-libs.sh /bin/import-libs.sh
    RUN /bin/import-libs.sh /bin/authelia

# Tools
    FROM ghcr.io/11notes/distroless:localhealth AS distroless-localhealth

# FS
    FROM docker.io/library/alpine:3.22.1 as FS
    RUN mkdir -p \
        /FS/bin \
        /FS/config \
        /FS/data \
        /FS/log
    ## Imports trusted certs
    COPY --from=authelia /etc/ssl/certs /FS/etc/ssl/certs
    ## Import dynamic libs needed by authelia
    COPY --from=bins /lib/dyn /FS/lib
    # flemme de faire les choses bien
    RUN ln -s lib /FS/lib64

    COPY --from=distroless-localhealth /usr/local/bin/localhealth /FS/bin/localhealth
    COPY --from=authelia /app/authelia /FS/bin/authelia

# Final image
    FROM scratch

    # nobody
    USER 65534:65534

    COPY --from=FS /FS /

    HEALTHCHECK --interval=5s --timeout=2s --retries=3 --start-period=2s \
        CMD ["/bin/localhealth", "http://127.0.0.1:9091/api/health", "-I"]

    # Check that binary can start
    RUN ["/bin/authelia", "--version"]

    ENV X_AUTHELIA_CONFIG /config/configuration.yml
    ENTRYPOINT ["/bin/authelia"]
