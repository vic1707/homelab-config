# Bins
    FROM ghcr.io/twin/gatus:v5.33.0 as gatus

# Tools
    FROM ghcr.io/11notes/distroless:localhealth AS distroless-localhealth

# Updated ca-certificates
    FROM docker.io/library/alpine:3.23.0 as ssl

    RUN apk add --no-cache ca-certificates && \
        update-ca-certificates

    # Add any missing certs manually
    RUN wget -O /usr/local/share/ca-certificates/Cloudflare-TLS-Issuing-ECC-CA-1.pem https://ssl-tools.net/certificates/b4d9bf55ed18bda0ed3e6e6278f85a50dc0db6f9.pem && \
        wget -O /usr/local/share/ca-certificates/SSL.com-TLS-Transit-ECC-CA-R2.pem https://ssl-tools.net/certificates/5cd5961e1efd90ec72bbccc99a0f66ab1f61d464.pem && \
        update-ca-certificates
    # TODO: look for warning about certs being already present!

# FS
    FROM docker.io/library/alpine:3.23.0 as FS

    RUN mkdir -p \
        /FS/bin \
        /FS/config \
        /FS/data

    COPY --from=distroless-localhealth /usr/local/bin/localhealth /FS/bin/localhealth
    COPY --from=gatus /gatus /FS/bin/gatus
    COPY --from=ssl /etc/ssl/certs/ca-certificates.crt /FS/etc/ssl/certs/ca-certificates.crt

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
