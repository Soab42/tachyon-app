#!/bin/sh
# TACHYON installer. Installs for the current user only and never asks for root.
# https://soab42.github.io/tachyon-app/
set -eu

BASE="https://github.com/Soab42/tachyon-app/releases/latest/download"
DIR="$HOME/.local/bin"

say() { printf '%s\n' "$*"; }
die() { printf 'TACHYON install failed: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Linux" ] || die "TACHYON runs on Linux only."
[ "$(uname -m)" = "x86_64" ] || die "TACHYON needs a 64-bit Intel or AMD processor (found $(uname -m))."
command -v tar >/dev/null 2>&1 || die "tar is not installed."
command -v sha256sum >/dev/null 2>&1 || die "sha256sum is not installed."

if command -v curl >/dev/null 2>&1; then
    get() { curl -fsSL "$1" -o "$2"; }
elif command -v wget >/dev/null 2>&1; then
    get() { wget -q "$1" -O "$2"; }
else
    die "please install curl or wget first."
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

say "Downloading TACHYON..."
get "$BASE/latest.json" "$TMP/latest.json" || die "could not reach the download server."
get "$BASE/tachyon-linux-x86_64.tar.gz" "$TMP/t.tar.gz" || die "the download failed."

WANT="$(sed -n 's/.*"sha256": *"\([0-9a-f]*\)".*/\1/p' "$TMP/latest.json")"
GOT="$(sha256sum "$TMP/t.tar.gz" | cut -d' ' -f1)"
[ -n "$WANT" ] && [ "$WANT" = "$GOT" ] || die "the download is damaged (checksum mismatch)."

tar -xzf "$TMP/t.tar.gz" -C "$TMP"
"$TMP/tachyon" --version >/dev/null 2>&1 || die "TACHYON needs glibc 2.35 or newer (Ubuntu 22.04 or later)."

mkdir -p "$DIR"
# Replace by rename, so a copy that is already running keeps working.
cp "$TMP/tachyon" "$DIR/.tachyon-install.$$"
chmod 755 "$DIR/.tachyon-install.$$"
mv -f "$DIR/.tachyon-install.$$" "$DIR/tachyon"

"$DIR/tachyon" install >/dev/null
# Alarms, the screensaver and update checks run from this background service.
if ! pgrep -u "$(id -u)" -f "^$DIR/tachyon daemon\$" >/dev/null 2>&1; then
    nohup "$DIR/tachyon" daemon >/dev/null 2>&1 &
fi

say ""
say "$("$DIR/tachyon" --version) installed in $DIR"
say "Open TACHYON from your applications menu, or run: $DIR/tachyon"
case ":$PATH:" in
    *":$DIR:"*) ;;
    *) say "Tip: add $DIR to your PATH to run 'tachyon' from anywhere." ;;
esac
say "To remove it: tachyon uninstall, then delete $DIR/tachyon"
