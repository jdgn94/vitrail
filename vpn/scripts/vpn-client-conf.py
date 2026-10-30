#!/usr/bin/env python3
"""/etc/hypraether/vpn/vpn-client-conf.py

Builds the config root's OpenVPN actually runs from the user's connection
file. The user's file is user-writable and the service starts without a
password, so nothing in it may make root run a program or open a path:
every option that does is refused, every key/cert must be inline, and the
script/credential lines are dropped and re-added here with fixed values.

Usage: vpn-client-conf.py <user> <source.conf> <output.conf> <auth-file>
"""

import os
import pwd
import re
import shlex
import stat
import sys

MAX_SIZE = 1024 * 1024
# C isspace(), what OpenVPN splits on; str.split() alone would also split on
# Unicode spaces OpenVPN keeps inside a word.
WHITESPACE = " \t\n\r\v\f"
# OpenVPN refuses lines over 256 bytes (2.7.7); releases that instead parsed
# the overflow as a line of its own would let an option hide there.
MAX_LINE = 250
UP_SCRIPT = "/etc/hypraether/vpn/vpn-up.sh"
DOWN_SCRIPT = "/etc/hypraether/vpn/vpn-down.sh"

# Regenerated below with root's own values, whatever the file said.
MANAGED = {"up", "down", "script-security", "auth-user-pass"}

# Run a program, load code, or write/read a path as root.
FORBIDDEN = {
    "auth-gen-token-secret",
    "auth-user-pass-verify",
    "askpass",
    "capath",
    "cd",
    "chroot",
    "client-config-dir",
    "client-connect",
    "client-crresponse",
    "client-disconnect",
    "config",
    "daemon",
    "dev-node",
    "engine",
    "ifconfig-pool-persist",
    "iproute",
    "ipchange",
    "learn-address",
    "log",
    "log-append",
    "plugin",
    "pkcs11-providers",
    "provider-path",
    "providers",
    "replay-persist",
    "route-pre-down",
    "route-up",
    "status",
    "tls-crypt-v2-verify",
    "tls-export-cert",
    "tls-verify",
    "tmp-dir",
    "writepid",
}

# Accepted only as `<option> [inline]` (or an inline <block>).
INLINE_ONLY = {
    "ca",
    "cert",
    "crl-verify",
    "dh",
    "extra-certs",
    "http-proxy-user-pass",
    "key",
    "pkcs12",
    "secret",
    "tls-auth",
    "tls-crypt",
    "tls-crypt-v2",
}

INLINE_BLOCKS = INLINE_ONLY | {"connection", "auth-user-pass"}

# setenv reaches the environment of root's up/down scripts.
SETENV_NAMES = re.compile(r"CLIENT_CERT|FORWARD_COMPATIBLE|PUSH_PEER_INFO|UV_[A-Za-z0-9_]+")


class Refused(Exception):
    pass


def check_option(tokens, line_no):
    """Returns False for a managed line to drop; raises Refused."""
    name = tokens[0].removeprefix("--")
    args = tokens[1:]
    if name in MANAGED:
        return False
    if name in FORBIDDEN or name.startswith(("management", "<")):
        raise Refused(f'option "{name}" (line {line_no}) is not allowed')
    if name in INLINE_ONLY and args and args[0] != "[inline]":
        raise Refused(f'option "{name}" (line {line_no}) must be an inline block')
    if name == "http-proxy" and len(args) > 2 and args[2] not in ("auto", "auto-nct"):
        raise Refused(f'option "http-proxy" (line {line_no}) may not name a file')
    if name == "socks-proxy" and len(args) > 2:
        raise Refused(f'option "socks-proxy" (line {line_no}) may not name a file')
    if name == "setenv":
        if args and args[0] == "opt":
            # `setenv opt <option>` still applies <option> when it is known.
            return bool(args[1:]) and check_option(args[1:], line_no)
        if not args or not SETENV_NAMES.fullmatch(args[0]):
            raise Refused(f'option "setenv" (line {line_no}) may not set that variable')
    return True


def check_line(line, line_no):
    """Checks the line both unquoted and as raw words, so a quoting rule
    OpenVPN reads differently from shlex can't hide an option name."""
    keep_unquoted = check_option(tokenize(line, line_no), line_no)
    keep_raw = check_option(re.split(f"[{re.escape(WHITESPACE)}]+", line), line_no)
    return keep_unquoted and keep_raw


def sanitize(text):
    kept = []
    block = None
    for line_no, line in enumerate(text.split("\n"), 1):
        if len(line.encode()) > MAX_LINE:
            raise Refused(f"line {line_no} is too long")
        stripped = line.strip(WHITESPACE)
        if block is not None:
            # OpenVPN closes a block on any line that starts with the tag.
            if stripped.startswith(f"</{block}>"):
                if stripped != f"</{block}>":
                    raise Refused(f"text after </{block}> (line {line_no})")
                if block != "auth-user-pass":
                    kept.append(line)
                block = None
                continue
            if block == "connection" and stripped and stripped[0] not in "#;":
                if not check_line(stripped, line_no):
                    continue
            if block != "auth-user-pass":
                kept.append(line)
            continue
        if not stripped or stripped[0] in "#;":
            continue
        match = re.fullmatch(r"<([a-z0-9-]+)>", stripped)
        if match:
            block = match.group(1)
            if block not in INLINE_BLOCKS:
                raise Refused(f"inline block <{block}> (line {line_no}) is not allowed")
            if block != "auth-user-pass":
                kept.append(line)
            continue
        if stripped.startswith("<"):
            raise Refused(f"malformed inline block (line {line_no})")
        if check_line(stripped, line_no):
            kept.append(line)
    if block is not None:
        raise Refused(f"inline block <{block}> is never closed")
    return kept


def tokenize(line, line_no):
    lexer = shlex.shlex(line, posix=True)
    lexer.whitespace = WHITESPACE
    lexer.whitespace_split = True
    lexer.commenters = ""
    try:
        tokens = list(lexer)
    except ValueError:
        raise Refused(f"unparsable line {line_no}") from None
    if not tokens:
        raise Refused(f"unparsable line {line_no}")
    return tokens


def read_owned(path, uid):
    """The file's text, only when it is a regular file the user owns — root
    must never be pointed at a file the user couldn't read themselves."""
    fd = os.open(path, os.O_RDONLY | os.O_NOCTTY)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != uid:
            raise Refused("the connection file is not a regular file owned by the user")
        if info.st_size > MAX_SIZE:
            raise Refused("the connection file is too large")
        with os.fdopen(fd, "rb", closefd=False) as fh:
            return fh.read(MAX_SIZE).decode("utf-8")
    finally:
        os.close(fd)


def main(argv):
    if len(argv) != 5:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    user, source, output, auth_file = argv[1:]
    try:
        uid = pwd.getpwnam(user).pw_uid
        if uid == 0:
            raise Refused("VPN_USER may not be root")
        lines = sanitize(read_owned(source, uid))
    except (Refused, OSError, KeyError, UnicodeDecodeError) as error:
        print(f"vpn-client-conf: {source}: {error}", file=sys.stderr)
        return 1
    lines += [
        "",
        f"auth-user-pass {auth_file}",
        "script-security 2",
        f"up {UP_SCRIPT}",
        f"down {DOWN_SCRIPT}",
        "",
    ]
    fd = os.open(output, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
