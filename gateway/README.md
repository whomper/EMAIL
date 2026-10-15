# The Raspberry Pi mail gateway

Mail providers only accept encrypted connections (TLS) today, and a 16 MHz
Falcon can't do modern TLS at a usable speed. So EMail talks plain IMAP,
POP3 and SMTP to a Raspberry Pi on your home network, and the Pi talks TLS
to your provider. The Pi runs `emailgate.py` (standard Python 3, nothing
to install), set up as a service by `install.sh`.

```
Atari (EMAIL.PRG) --plain, home LAN--> Raspberry Pi (emailgate) --TLS--> imap.gmail.com:993
                                                                --TLS--> smtp.gmail.com:465
```

The gateway uses TLS 1.2 or newer and checks each provider's certificate
and name against the Pi's root certificates; when it can't (or can't
reach the provider), EMail's alert says so in a line that starts with
"emailgate:".

Any computer with Debian, Ubuntu or Raspberry Pi OS works as the gateway,
and the same Pi can also run Claude ST's bridge.

## Setting it up

On the Pi:

```
git clone https://github.com/whomper/EMail
cd EMail/gateway
sudo ./install.sh imap.gmail.com smtp.gmail.com pop.gmail.com
```

Name your provider's servers: the IMAP server, the SMTP server and,
if you want POP3, the POP3 server. The script installs the gateway as a
service (`emailgate`, running as its own user with no access to the rest
of the Pi), starts it now and at every boot, and prints what to type into
EMail. Run it again to change servers; `sudo ./install.sh --remove`
takes it away.

**Coming from EMail 1.x?** Its gateway was an stunnel set-up. Run
`install.sh` again as above: it removes `/etc/stunnel/atari-mail.conf`,
and stops stunnel unless something else uses it. The ports stay the same,
so nothing changes in EMail.

| Provider    | IMAP                  | SMTP                  | POP3                 |
|-------------|-----------------------|-----------------------|----------------------|
| Gmail       | imap.gmail.com        | smtp.gmail.com        | pop.gmail.com        |
| iCloud      | imap.mail.me.com      | smtp.mail.me.com *    |                      |
| Fastmail    | imap.fastmail.com     | smtp.fastmail.com     | pop.fastmail.com     |
| Yahoo       | imap.mail.yahoo.com   | smtp.mail.yahoo.com   | pop.mail.yahoo.com   |
| GMX         | imap.gmx.net          | mail.gmx.net          | pop.gmx.net          |

\* iCloud only offers SMTP with STARTTLS on port 587; see below.

Gmail, iCloud and Yahoo need an **app password** for programs like EMail:
create one in your account's security settings and use it as EMail's
password. Outlook.com and Microsoft 365 accept only OAuth sign-in, which
EMail can't do.

## In EMail

Options > Accounts, with the Pi's address (the script prints it):

| Field                 | Value                          |
|-----------------------|--------------------------------|
| Incoming mail         | IMAP (or POP3)                 |
| Server                | the Pi, e.g. 192.168.1.10      |
| Port                  | 143 (POP3: 110)                |
| User, Password        | your mail login / app password |
| Outgoing server       | the Pi again                   |
| Outgoing port         | 587                            |
| Outgoing user         | empty (the same login)         |

Use the Pi's IP address: plain TOS with STinG can't always resolve names
on the local network.

## Next to the Troll proxy

EMail converts mail to the Atari character set itself, Hebrew included, so
it only needs a plain TLS tunnel: this gateway. Troll has its own proxy
(`falcon_imap_logproxy.py` in
[whomper/AERA-Gateway](https://github.com/whomper/AERA-Gateway)), which rewrites
messages for Troll; EMail doesn't use it. The two run side by side: this
gateway on the standard ports (143, 587, 110), the Troll proxy on its own
(1143). To give this gateway other ports instead:

```
sudo ./install.sh --ports 1143,1025,1110 imap.mail.me.com smtp.mail.me.com:587
```

## Keeping it private

The gateway serves only addresses on private networks (192.168.x.x,
10.x.x.x, 172.16-31.x.x): never anyone on the internet, even if its port
were forwarded. If others share your network, `--allow` limits it to your
Atari's address:

```
sudo ./install.sh --allow 192.168.1.50 imap.gmail.com smtp.gmail.com
```

If the Pi's firewall (ufw) is on, `install.sh` lets the Atari in on the
gateway's ports (or the private networks, without `--allow`); if it can't
add a rule, it says which and stops.

Between the Atari and the Pi the connection is not encrypted, as on
every network in the 1990s: keep the gateway on your home network, never
forward its ports on your router. The gateway never writes down what goes
through it (your password does): its journal (`sudo journalctl -u
emailgate`) has only who connected where, and why a connection ended.

## Servers with STARTTLS only

`install.sh` uses the TLS ports (993, 995, 465). For an SMTP server that
takes mail only on port 587 with STARTTLS, such as iCloud, add `:587`: the
gateway then says EHLO and STARTTLS itself, and hands EMail the server's
greeting as if nothing had happened.

```
sudo ./install.sh imap.mail.me.com smtp.mail.me.com:587
```

## Tested

`make test` runs `test_emailgate.py`: a relay over TLS, STARTTLS, a
certificate nobody vouches for, the wrong name, a provider that can't be
reached, and the address rules. `TLS=1 make itest` runs EMail's whole
integration test through the gateway, against servers that only speak
TLS.
