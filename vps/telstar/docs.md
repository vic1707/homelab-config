# Containers boot sequence

```mermaid
sequenceDiagram
    participant LLDAP
    participant Crowdsec
    participant Caddy
    participant Authelia

    Note over Crowdsec, LLDAP: Start independently and in parallel<br/>Need backup restore to be completed

    Caddy-->>Crowdsec: Waits for
    Caddy->>Caddy: Starts

    LLDAP->>LLDAP: Starts
    LLDAP->>LLDAP: Triggers one-shot LLDAP-Bootstrap
    Authelia-->>LLDAP: Waits for
    Authelia->>Authelia: Starts
```