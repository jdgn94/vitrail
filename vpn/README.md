> Vendored into Vitrail from the Hypraether project. The runtime paths keep
> the `hypraether` name (`/etc/hypraether/vpn`, `~/.config/hypraether/vpn`,
> the `hypraether-vpn` CLI) so the existing installation keeps working.
> Renaming them is a separate migration.

# Hypraether Domain-Based Split-Tunnel VPN

Route **only** a curated list of domains through an OpenVPN tunnel (e.g.
ProtonVPN free, US exit) while **everything else** keeps using your normal
connection. Built for Arch Linux and Arch-based distros using `systemd`,
`OpenVPN`, `dnsmasq` (via NetworkManager) and `nftables`.

Multiple connections are supported, each with its **own** `.ovpn` and its
**own** username/password. Credentials live in a private **sqlite vault**
(`~/.config/hypraether/vpn/vault.db`, mode 600) — never in a plaintext
auth file. Every connection is tagged with a **provider** (proton, mullvad,
...) and a **region** (US, JP, DE, ...) so the desktop shell can group them.

## Why

Some services (Anthropic/Claude, OpenAI/ChatGPT, ...) are geo-blocked in many
countries. A VPN solves that, but sending your _entire_ internet connection
through a free VPN is slow. This setup tunnels **only** the blocked domains
and keeps the rest of your traffic on your local connection, at OS level.

## How it works

```
browser/curl ── DNS query ──> dnsmasq (NetworkManager, 127.0.0.1)
                                 │  domain in list?
                                 ├─ yes ──> add IP to nftables set (vpn_ips)
                                 │
client connects to that IP ──> nftables output hook: fwmark 0x4555
                                     │
                                     v
                        ip rule: fwmark 0x4555 -> table vpn
                                     │  default route = tun0
                                     v
                            OpenVPN tunnel (US exit)
```

1. **dnsmasq** (managed by NetworkManager) resolves your configured domains
   and, for each match, inserts the resolved IPs into an nftables set
   (`config/vpn-split.conf`). Domains match all of their subdomains too.
2. **nftables** marks any outbound packet destined to those IPs with fwmark
   `0x4555` (`config/nftables.conf`). IPv6 addresses for those domains are
   rejected so clients fall back to IPv4.
3. **Policy routing** sends marked traffic to the `vpn` routing table, whose
   default route is the OpenVPN tunnel. Everything else stays on the normal
   default route.
4. **SNAT** rewrites the source of tunnel-bound packets to the tunnel IP.
   Handled dynamically in `config/vpn-up.sh`.

Only **one** tunnel is active at a time (the routing table is shared);
switching region/provider stops the current tunnel and starts the new one.

## Two traffic modes

The VPN works in two **global** modes (chosen at install time, stored as
`VPN_MODE` in `/etc/hypraether/vpn/env`):

| Mode    | Meaning                                                          | The dnsmasq domain list holds |
| ------- | ---------------------------------------------------------------- | ----------------------------- |
| `split` | only the listed domains go through the tunnel (default)          | domains **to tunnel**         |
| `full`  | everything goes through the tunnel **except** the listed domains | domains **to exclude**        |

Both use the same building blocks — dnsmasq feeds nftables sets, nftables
sets fwmark `0x4555`, policy routing sends marked traffic to the `vpn`
table whose default route is the tunnel. The difference is the _marking
criterion_:

- **split**: only packets to `vpn_ips` get marked → tunnel; everything else
  stays direct. IPv6 to listed domains is rejected (falls back to IPv4).
- **full**: every packet is marked `0x4555` (→ tunnel), then the mark is
  **cleared** for packets to `bypass_ips` → those stay direct. IPv6 is
  accepted only for excluded IPs and rejected otherwise (the tunnel is
  IPv4-only). Starts with an **empty** exclusion list = pure full tunnel.

The tunnel never becomes the system default route in either mode — it is
only ever reachable through the `vpn` table, so single-active, `vpn-up.sh`
and the `.ovpn` conversion are identical.

To switch modes after install: use the **Settings → Network & Wi-Fi → VPN**
traffic-mode control in the shell, or `hypraether-vpn mode <split|full>` from
the CLI (both go through the root helper via pkexec, allowed passwordless by
the installer's polkit rule). The domain list keeps its contents but changes
meaning — re-edit it to match.

## Default tunneled domains (split mode)

`anthropic.com`, `claude.ai`, `openai.com`, `chatgpt.com`, `oaistatic.com`,
`oaiusercontent.com`, `auth0.com` (plus every subdomain).

Edit `config/vpn-split.conf` to add/remove domains, then restart
NetworkManager. In **full** mode the equivalent list is the exclusion list
in `config/vpn-bypass.conf` (starts empty).

## Installation

The installer sets up the **system infrastructure** (packages, dnsmasq/
nftables/routing, the `hypraether-vpn@.service` template, credential
wrappers, polkit rule, CLI symlink). Connections are imported **per user**
afterwards, since credentials belong to the user's session, not to root.

```bash
sudo ./install.sh [--mode split|full]
```

Then, as your normal user, import each `.ovpn` (each can have its own
credentials):

```bash
hypraether-vpn import ./us-free-21.protonvpn.udp.ovpn --user MyOpenVpnUser --pass-file ./password.txt
hypraether-vpn connect us-free-21-protonvpn-udp
```

Provider and region are auto-detected from the filename/`remote` lines
(`us-free-21.protonvpn...` → `proton` / `US`); override them with
`--provider` / `--region` if detection misses.

### install.sh options

| Option          | Description                                                |
| --------------- | ---------------------------------------------------------- |
| `--mode`        | Traffic mode: `split` (default) or `full`                  |
| `--user <name>` | Desktop user for polkit + env paths (default: `SUDO_USER`) |
| `--no-watchdog` | Install config but do NOT enable/start the watchdog        |
| `-h, --help`    | Show help                                                  |

## The credential vault

`~/.config/hypraether/vpn/vault.db` (sqlite, mode 600, owned by you) holds
**two** things: saved **credentials** (named username/password pairs) and
**connections** (generated split-tunnel configs), each linked to the
credential it uses. One credential can serve several connections — e.g. a
single ProtonVPN OpenVPN credential across as many `.ovpn` files as you
want; nothing ties a credential to a single file.

`connect`, `disconnect` and the removals also keep an `enabled` marker in
that directory in sync with "is any tunnel active". The desktop shell
reads it at login: when it exists, the shell connects the **best**
connection (measured latency/packet loss) back automatically; with no
marker nothing is started. Because the marker belongs to the CLI,
connecting or disconnecting from a terminal counts exactly like the
Settings UI. A tunnel found already running at shell start with no marker
(started outside the CLI, or up since before the marker existed) is
recorded into it instead, so it survives the next reboot too.

At runtime the root wrapper `vpn-auth-prep.sh` (the `ExecStartPre` of each
`hypraether-vpn@<id>.service`) reads the vault, follows the connection →
credential link, and writes a transient `0600` auth file under `/run`
(tmpfs) that OpenVPN reads via `auth-user-pass`. It is regenerated on every
start and removed on stop; the only plaintext copy that ever exists is that
transient tmpfs file. OpenVPN never reads the user's `connections/<id>.conf`
directly: `vpn-client-conf.py` builds a root copy next to the auth file,
refusing any option that runs a program or opens a path by name (`plugin`,
`route-up`, `config`, `log`, `setenv PATH`, a `ca`/`key` that isn't inline,
…) and re-adding the `up`/`down`/`auth-user-pass` lines itself — the user
can start the service without a password, so their file must not be able to
run anything as root. A refused file fails the start with the reason in the
unit's journal. The shell's Settings → Network & Wi-Fi → VPN section
manages both lists (add/rename/change-password/delete credentials, import
connections, assign a credential to a connection).

## CLI reference (`hypraether-vpn`)

### Connections

| Command                                                                                                                                     | What it does                                                                                                                                  |
| ------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `import <file.ovpn> [--id] [--name] [--provider] [--region] [--credential <name> \| --credential-name <name> --user --pass-file] [--force]` | Convert the `.ovpn` to a split-tunnel config, link it to a credential (`--credential` reuses an existing one; `--credential-name` creates it) |
| `list [--json]`                                                                                                                             | All connections with provider/region/credential/active state (`--json` for the shell)                                                         |
| `connect <id>`                                                                                                                              | Stop any active tunnel and start `<id>` (single-active); fails if the connection has no credential                                            |
| `disconnect [<id>]`                                                                                                                         | Stop a tunnel, or all active ones                                                                                                             |
| `creds <id> [--user] [--pass/--pass-file]`                                                                                                  | Rotate the credentials of `<id>`'s linked credential; restarts the tunnel if active                                                           |
| `remove <id>`                                                                                                                               | Stop, delete the config and the connection row                                                                                                |
| `status`                                                                                                                                    | Show the active tunnel                                                                                                                        |

### Credentials

| Command                                                             | What it does                                                                                                           |
| ------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `credential add <name> [--user] [--pass/--pass-file]`               | Save a new username/password pair (prompted if flags are omitted)                                                      |
| `credential list [--json]`                                          | Saved credentials + how many connections use each one (`--json` for the shell)                                         |
| `credential update <name> [--rename] [--user] [--pass/--pass-file]` | Rename / change user / change password (only what's given changes; bare invocation prompts a full rotation)            |
| `credential assign <name> <id...>`                                  | Link one credential to one or more connections — the "one credential, several files" case                              |
| `credential remove <name>`                                          | Delete a credential; connections using it keep existing but lose their credentials (reassign with `credential assign`) |

Importing, listing and rotating credentials run entirely as your user.
`connect`/`disconnect`/`remove` touch systemd; the installer's polkit rule
grants _your user only_ passwordless control over `hypraether-vpn@*` units.

## Getting ProtonVPN credentials

1. Create a free account at <https://account.protonvpn.com> (no card).
2. **Downloads → OpenVPN configuration files** → pick a US server → download
   the `.ovpn`.
3. **Settings → OpenVPN / IKEv2 username/password** → generate your OpenVPN
   username and password (these are different from your login credentials).

> **Security notes**
>
> - These are your **OpenVPN / IKEv2** credentials, _not_ your Proton account
>   e-mail and password.
> - Never commit a `.ovpn` or a password file (see `.gitignore`), and prefer
>   `--pass-file` over `--pass` (which leaks to shell history).
> - If your provider supports it (ProtonVPN does), append a server-suffix to
>   the **username** to pin the exit server, e.g. `9kXvLqW2xMoT5PbA+b:0` to
>   force exiting through server `US-FREE#21`.

## Multi-server auto-pivot

Free ProtonVPN servers occasionally go down. List **several free US servers**
in the imported config and let OpenVPN pick whichever answers:

1. Download the `.ovpn` of 2–5 free **US** servers.
2. In `~/.config/hypraether/vpn/connections/<id>.conf`, keep **all** the
   `remote` lines (e.g. 5 servers × 5 ports). The config has `remote-random`,
   so OpenVPN tries them until one connects.
3. Use the **username without suffix** in the vault so each entry IP can
   assign any valid free exit.
4. `hypraether-vpn disconnect <id> && hypraether-vpn connect <id>`.

## Verifying it works

```bash
# Tunnel is up
systemctl status hypraether-vpn@<id>

# A tunneled domain's IP routes via the tunnel (table vpn)
ip route get 160.79.104.10 mark 0x4555

# The nftables set is being populated by dnsmasq
nft list set ip vpn_split vpn_ips

# DNS goes through local dnsmasq
cat /etc/resolv.conf        # must show: nameserver 127.0.0.1

# Normal traffic still direct (your local IP)
curl -s https://api.ipify.org

# Tunneled domain responds (401/403/redirect are fine — the server answered)
curl -4 -s -o /dev/null -w '%{http_code}\n' https://api.openai.com/v1/models
```

If the last command hangs, DNS-over-HTTPS is likely bypassing dnsmasq.

## Important: disable DNS-over-HTTPS (DoH)

The split tunnel depends on dnsmasq seeing the DNS queries for your domains.

- **Firefox:** Settings → Privacy & Security → DNS over HTTPS → **Off**
- **Chrome:** uses the system resolver by default — no action needed

## Management

| Task                | Command                                                          |
| ------------------- | ---------------------------------------------------------------- |
| List connections    | `hypraether-vpn list`                                            |
| Check active tunnel | `hypraether-vpn status` / `systemctl status hypraether-vpn@<id>` |
| Stop tunnel         | `hypraether-vpn disconnect <id>`                                 |
| Rotate credentials  | `hypraether-vpn creds <id> --pass-file f`                        |
| Show traffic mode   | `hypraether-vpn mode`                                            |
| Switch traffic mode | `hypraether-vpn mode split\|full` (or the Settings UI)           |
| See tunnel IP       | `ip addr show tun0`                                              |
| Uninstall           | `sudo ./uninstall.sh`                                            |

## AUTH_FAILED recovery (assisted manual)

Free-tier ProtonVPN OpenVPN credentials get rotated/expired server-side from
time to time, which makes OpenVPN fail with `AUTH_FAILED`. The watchdog
(`vpn-auth-watchdog.service`) makes recovery quick:

1. Sends you a **critical desktop notification** and **opens the Proton
   dashboard** where the OpenVPN/IKEv2 password is reset.
2. **Watches the vault** — the moment you run `hypraether-vpn creds <id>`
   (which updates `vault.db`), it **restarts the active tunnel**.
3. A 900s **cooldown** prevents notification spam while credentials are still
   wrong.

```
AUTH_FAILED (journal)
        │
        ▼
vpn-auth-watchdog (cooldown ok)
        ├─► notify-send (critical) + xdg-open Proton dashboard
        │
        │   ...you reset the OpenVPN password on the Proton page and run:
        │   hypraether-vpn creds <id> --pass-file <new-password.txt>
        ▼
watchdog sees vault.db changed → systemctl restart hypraether-vpn@<id>
        ▼
tunnel back up
```

> **Why not fully automatic?** Proton's anonymous `/credentialless` endpoint
> now returns **CAPTCHA** (HTTP 422 code 9001). `scripts/proton-anon-refresh.py`
> is kept as an experimental tool but is **not** invoked by the watchdog.

## Adding more domains later

Domains are managed from the **settings UI** (Settings → Network & Wi-Fi →
VPN → Domains) or the CLI — no manual config editing:

```bash
hypraether-vpn domain add anthropic.com     # resolves its IPs + applies
hypraether-vpn domain remove openai.com
hypraether-vpn domain list                  # shows each domain + its IPs
hypraether-vpn domain refresh               # re-resolve every domain
```

Adding a domain (or refreshing) regenerates the dnsmasq config at
`/etc/NetworkManager/dnsmasq.d/vpn-mode.conf` from the list
(`~/.config/hypraether/vpn/domains`, one per line) **and** inserts the
domain's current A/AAAA records into the active mode's nftables set
(`vpn_ips`/`vpn_ips6` in split, `bypass_ips`/`bypass_ips6` in full) — it
takes effect immediately, while dnsmasq keeps the entries fresh as the
domain's IPs change. What the list _means_ depends on the mode: **split** →
domains to tunnel, **full** → domains to exclude.

Use the **bare registrable domain**; dnsmasq matches subdomains
automatically.

**Verify** — `getent hosts <new-domain>`, then check the IP appears in
`nft list set ip vpn_split vpn_ips` (split) or `... vpn_split bypass_ips`
(full) and routes via the tunnel with
`ip route get <resolved-ip> mark 0x4555`.

To remove a domain, delete it in the settings UI or
`hypraether-vpn domain remove <domain>`.

## Project layout

```
vpn/
├── install.sh                  # System infrastructure installer (run with sudo)
├── uninstall.sh                # Removes all system config (not your vault)
├── config/
│   ├── dns.conf                # NetworkManager: dns=dnsmasq
│   ├── vpn-split.conf          # split mode: domains to tunnel (edit me)
│   ├── vpn-bypass.conf         # full mode: domains to exclude (edit me)
│   ├── nftables.conf           # split-mode fwmark ruleset (additive)
│   ├── nftables-bypass.conf    # full-mode ruleset (mark all, clear exclusions)
│   ├── vpn-up.sh / vpn-down.sh # policy routing + SNAT on tunnel up/down
│   ├── hypraether-vpn@.service # systemd template: one instance per connection
│   ├── env.example             # /etc/hypraether/vpn/env (vault/conf dir paths)
│   ├── 50-hypraether-vpn.rules # polkit: passwordless tunnel control
│   └── vpn-auth-watchdog.service/.conf
├── scripts/
│   ├── vpn_manager.py          # the `hypraether-vpn` CLI (vault + systemd + domains)
│   ├── ovpn2split.py           # converts a stock .ovpn into a split config
│   ├── vpn-mode.sh             # root: switch split<->full mode (real root copy)
│   ├── vpn-domain.sh           # root: apply domain list (regen dnsmasq + insert IPs)
│   ├── vpn-auth-prep.sh        # root: vault -> transient /run auth file + client config
│   ├── vpn-client-conf.py      # root: checked copy of the user's connection config
│   ├── vpn-auth-clean.sh       # root: removes that transient file
│   ├── vpn-auth-watchdog.sh    # connection-problem notifications + vault-change restart
│   └── proton-anon-refresh.py  # EXPERIMENTAL anonymous minting (CAPTCHA-blocked)
└── openvpn/                    # reference examples (config format)
```

Per-user state (never committed):

```
~/.config/hypraether/vpn/
├── vault.db                    # sqlite credential vault (600)
├── mode                        # current traffic mode, for the settings UI
├── domains                     # tunnel domain list (one per line)
├── enabled                     # exists while a tunnel is active (shell auto-connect marker)
└── connections/<id>.conf       # generated split-tunnel configs
```

Installed (system) state: `/etc/hypraether/vpn/` holds every root script
(up/down, prep/clean, watchdog, `vpn-client-conf.py`, `vpn-mode.sh`,
`vpn-domain.sh`) plus `config/` (the mode rulesets) as **real root-owned
copies**, and the env file. Never symlinks into the clone: root runs them
and the user may start the service without a password, so a user-writable
target is a root shell. A repo change to any of them reaches the system by
re-running `sudo vpn/install.sh`. The root helpers also never write into
the user's tree as root (they drop to `VPN_USER` with `setpriv`), and only
read files there the user owns.

## Troubleshooting

- **Tunnel connects but immediately gets `AUTH_FAILED`** — the OpenVPN
  credentials were rejected. Rotate them: reset at `account.protonvpn.com →
Settings → OpenVPN / IKEv2 username/password`, then
  `hypraether-vpn creds <id> --pass-file <file>`.
- **`hypraether-vpn connect` fails with polkit denial** — the installer's
  polkit rule may be missing (`/etc/polkit-1/rules.d/50-hypraether-vpn.rules`)
  or installed for a different user than the one running the command.
- **Domain hangs but `nft list set ip vpn_split vpn_ips` is empty** — DoH is
  enabled in the browser, or dnsmasq isn't the resolver (`resolv.conf` must
  contain `127.0.0.1`).
- **Tunnel up but no traffic routed** — check `ip rule` contains
  `fwmark 0x4555 lookup vpn` and that `ip route show table vpn` has a default
  route. Both are created by `vpn-up.sh` on connect.
- **Packets egress the tunnel but connection times out** — the SNAT rule is
  missing. `nft list chain ip vpn_nat postrouting` should show a
  `snat to <tunnel-ip>` rule.
- **Reconnect changes tunnel IP** — normal. `vpn-up.sh` re-reads the current
  tunnel IP on every connect and updates the route + SNAT rule.

## License

MIT. See [LICENSE](LICENSE). Provider config files and credentials remain
your own responsibility.
