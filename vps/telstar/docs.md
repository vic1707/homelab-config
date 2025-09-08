# Containers boot sequence

```mermaid
sequenceDiagram
    participant LLDAP
    participant Crowdsec
    participant Caddy
    participant Authelia
    participant Gatus

    Note over Crowdsec, LLDAP: Start independently and in parallel<br/>Need backup restore to be completed

    Crowdsec->>Crowdsec: Starts

    Caddy-->>Crowdsec: Waits for
    Caddy->>Caddy: Starts

    LLDAP->>LLDAP: Starts
    LLDAP->>LLDAP: Triggers one-shot LLDAP-Bootstrap

    Authelia-->>LLDAP: Waits for
    Authelia->>Authelia: Starts

    Note over Gatus: Waits for everyone to be ready
    Gatus->>Gatus: Starts
```