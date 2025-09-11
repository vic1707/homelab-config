# Bins
    FROM ghcr.io/twin/gatus:v5.23.2 as gatus

# Tools
    FROM ghcr.io/11notes/distroless:localhealth AS distroless-localhealth

# FS
    FROM docker.io/library/alpine:3.22.1 as FS

    RUN mkdir -p \
        /FS/bin \
        /FS/config \
        /FS/data

    COPY --from=distroless-localhealth /usr/local/bin/localhealth /FS/bin/localhealth
    COPY --from=gatus /gatus /FS/bin/gatus

# Final image
    FROM scratch

    # nobody
    USER 65534:65534

    COPY --from=FS /FS /

    HEALTHCHECK --interval=5s --timeout=2s --retries=3 --start-period=2s \
        CMD ["/bin/localhealth", "http://127.0.0.1:8080/", "-I"]

    # # Check that binary can start
    # RUN ["/bin/gatus", "--version"] # unsupported

    ENTRYPOINT ["/bin/gatus"]
