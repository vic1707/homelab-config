This folder assumes a few things about the switch :

#### Initial setup

-   [latest firmware](https://fohdeesha.com/docs/brocade-overview.html) is installed
-   [initial setup](https://fohdeesha.com/docs/icx6450.html) has been completed
-   [license is activated](https://fohdeesha.com/docs/6450.html)
-   new factory reset has been done `factory set-default` (to remove setup static IP).

#### Post init

-   [Key generation](https://fohdeesha.com/docs/icx6xxx-adv.html#key-generation-security-web-ui)
-   `root` user created
-   enable local auth
-   `telnet` & `webui` are disabled
-   `serial` is password protected with `root` password

    <details>
    <summary> SPOILERS </summary>

    ```
	enable
	conf t
	tftp disable
    crypto key zeroize
    crypto key generate rsa modulus 2048
    username root password [REDACTED]
    aaa authentication login default local
    no telnet server
    enable aaa console
    no web-management http
    write memory
	exit
	reload
    ```

    </details>
