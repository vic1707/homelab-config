# Containers boot sequence

```mermaid
sequenceDiagram
    participant Headscale-console
    participant Headscale
    participant LLDAP
    participant Crowdsec
    participant Caddy
    participant Authelia
    participant Gatus

    Note over Headscale, Crowdsec: Start independently and in parallel<br/>Need backup restore to be completed

    Crowdsec->>Crowdsec: Starts

    Headscale->>Headscale: Starts
    Headscale-console-->>Headscale: Waits for
    Headscale-console-->>Headscale-console: Starts

    Caddy-->>Crowdsec: Waits for
    Caddy->>Caddy: Starts

    LLDAP->>LLDAP: Starts
    LLDAP->>LLDAP: Triggers one-shot LLDAP-Bootstrap

    Authelia-->>LLDAP: Waits for
    Authelia->>Authelia: Starts

    Note over Gatus: Waits for everyone to be ready
    Gatus->>Gatus: Starts
```
