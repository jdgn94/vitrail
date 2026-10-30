#!/usr/bin/env python3
"""Convert a stock OpenVPN .ovpn file into the split-tunnel client config.

Usage:
    ovpn2split.py <input.ovpn> <output.conf> [--auth-file PATH]
                  [--up PATH] [--down PATH]

What it does:
  - Strips any lines the installer manages itself (auth-user-pass,
    update-resolv-conf up/down hooks, redirect-gateway, script-security)
    so re-importing is idempotent.
  - Injects the split-tunnel option block (pull-filters, route-nopull,
    auto-reconnect, up/down scripts) just before the first inline block
    tag (<ca>/<cert>/<key>/<tls-auth>/<tls-crypt>), which the stock
    provider .ovpn files contain verbatim.

Credentials are never embedded here: `--auth-file` points at the transient
tmpfs file that vpn-auth-prep.sh writes per connection (vpn_manager.py
passes it), so nothing on disk holds the password persistently.
"""
from __future__ import annotations

import argparse
import re

DEFAULT_AUTH_FILE = "/run/hypraether-vpn/<id>/auth.txt"
DEFAULT_UP = "/etc/hypraether/vpn/vpn-up.sh"
DEFAULT_DOWN = "/etc/hypraether/vpn/vpn-down.sh"


def build_split_block(auth_file: str, up_script: str, down_script: str) -> str:
    """The option block that turns a normal client into a domain split tunnel."""
    return f"""auth-user-pass {auth_file}

pull-filter ignore "redirect-gateway"
pull-filter ignore "dhcp-option DNS"
route-nopull

ping 10
ping-restart 60
connect-retry 5 60
connect-timeout 30
explicit-exit-notify
resolv-retry infinite

script-security 2
up {up_script}
down {down_script}

"""


def strip_managed_lines(text: str) -> str:
    """Remove config lines that are regenerated from scratch."""
    managed_prefixes = (
        "auth-user-pass",
        "script-security",
        "up /etc/openvpn/update-resolv-conf",
        "down /etc/openvpn/update-resolv-conf",
        "up /etc/hypraether/vpn/vpn-up.sh",
        "down /etc/hypraether/vpn/vpn-down.sh",
        "redirect-gateway",
    )
    kept: list[str] = []
    for line in text.splitlines(keepends=True):
        stripped = line.strip()
        if any(stripped.startswith(p) for p in managed_prefixes):
            continue
        kept.append(line)
    return "".join(kept)


def convert(
    input_path: str,
    output_path: str,
    auth_file: str = DEFAULT_AUTH_FILE,
    up_script: str = DEFAULT_UP,
    down_script: str = DEFAULT_DOWN,
) -> None:
    """Read input .ovpn and write the split-tunnel config to output_path."""
    text = open(input_path, encoding="utf-8").read()
    text = strip_managed_lines(text)

    split_block = build_split_block(auth_file, up_script, down_script)

    # Insert the split block right before the first inline block tag.
    match = re.search(r"^\s*<", text, flags=re.MULTILINE)
    if match:
        text = text[: match.start()] + split_block + text[match.start() :]
    else:
        # No inline blocks (unusual): just append the block at the end.
        text = text.rstrip() + "\n\n" + split_block

    with open(output_path, "w", encoding="utf-8") as fh:
        fh.write(text)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input")
    parser.add_argument("output")
    parser.add_argument("--auth-file", default=DEFAULT_AUTH_FILE)
    parser.add_argument("--up", default=DEFAULT_UP)
    parser.add_argument("--down", default=DEFAULT_DOWN)
    args = parser.parse_args()
    convert(args.input, args.output, args.auth_file, args.up, args.down)
    print(f"Split-tunnel config written to {args.output}")


if __name__ == "__main__":
    main()
