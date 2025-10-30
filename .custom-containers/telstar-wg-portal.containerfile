# Bins
    FROM ghcr.io/h44z/wg-portal:v2.1.0-beta.3 as wg-portal

    # Get all needed libs
    COPY import-libs.sh /bin/import-libs.sh
    RUN /bin/import-libs.sh /bin/bash
# Tools
    FROM ghcr.io/11notes/distroless:localhealth AS distroless-localhealth

# FS
    FROM docker.io/library/alpine:3.22.1 as FS

    RUN mkdir -p \
        /FS/bin \
        /FS/config \
        /FS/data

    COPY --from=wg-portal /app/wg-portal /FS/bin/wg-portal
    COPY --from=wg-portal /bin/bash /FS/bin/bash
    COPY --from=wg-portal /usr/sbin/resolvconf /FS/bin/resolvconf
    COPY --from=distroless-localhealth /usr/local/bin/localhealth /FS/bin/localhealth

    ## Import dynamic libs needed by wg-portal
    COPY --from=wg-portal /lib/dyn /FS/lib
    # flemme de faire les choses bien
    RUN ln -s lib /FS/lib64

# Final image
    FROM scratch

    # nobody
    USER 65534:65534

    COPY --from=FS /FS /

    HEALTHCHECK --interval=5s --timeout=2s --retries=3 --start-period=2s \
        CMD ["/bin/localhealth", "http://127.0.0.1:8888/", "-I"]

    # Check that binary can start
    # RUN ["/bin/wg-portal", "--version"] # doesn't exist yet

    ENV WG_PORTAL_CONFIG /config/config.yaml
    ENTRYPOINT ["/bin/wg-portal"]
