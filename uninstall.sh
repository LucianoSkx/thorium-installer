#!/usr/bin/env bash
if [ -z "${BASH_VERSION:-}" ]; then
	exec bash "$0" "$@"
fi
set -euo pipefail

info() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==> ATENÇÃO:\033[0m %s\n' "$*" >&2; }

RAW_BASE="https://raw.githubusercontent.com/LucianoSkx/thorium-installer/main"
PREFIX_SYSTEM="/opt/thorium-browser"
PREFIX_USER="$HOME/.local/opt/thorium-browser"

if [ ! -r /etc/os-release ]; then warn "sem /etc/os-release"; fi
# shellcheck disable=SC1091
. /etc/os-release 2>/dev/null || true
case " ${ID_LIKE:-} ${ID:-} " in *" arch "*|*" cachyos "*) ;; *) warn "distro não é Arch/CachyOS; prosseguindo mesmo assim" ;; esac

# executado via "curl ... | bash": $0 nao e um arquivo, entao copia o script
# para um arquivo de verdade antes do re-exec com sudo.
if [ ! -f "$0" ] || [ "${0#/dev/fd/}" != "$0" ]; then
	TMPD="$(mktemp -d)"
	trap 'rm -rf "$TMPD"' EXIT
	SELF="$TMPD/uninstall.sh"
	if command -v curl >/dev/null 2>&1; then
		curl -fsSL --retry 3 -o "$SELF" "$RAW_BASE/uninstall.sh" || { warn "nao consegui baixar o uninstall.sh"; exit 1; }
	else
		wget -q -O "$SELF" "$RAW_BASE/uninstall.sh" || { warn "nao consegui baixar o uninstall.sh"; exit 1; }
	fi
	bash "$SELF" "$@"
	exit $?
fi

if [ "$(id -u)" != 0 ]; then
	if command -v sudo >/dev/null 2>&1; then
		exec sudo -E bash "$0" "$@"
	else
		warn "sem sudo: remoção do sistema pode falhar"
	fi
fi

info "removendo Thorium"
rm -f /usr/local/bin/thorium-browser /usr/bin/thorium-browser 2>/dev/null || true
rm -f /usr/local/bin/thorium-shell 2>/dev/null || true
rm -rf "$PREFIX_SYSTEM" "$PREFIX_USER" 2>/dev/null || true
rm -rf /usr/lib/thorium-browser "$HOME/.local/lib/thorium-browser" 2>/dev/null || true
rm -f /usr/local/bin/thorium-shell 2>/dev/null || true
rm -f "$HOME/.local/share/metainfo/org.chromium.Thorium.metainfo.xml" 2>/dev/null || true
rm -f /usr/share/metainfo/org.chromium.Thorium.metainfo.xml 2>/dev/null || true
rm -f "$HOME/.local/share/metainfo/org.chromium.Thorium.metainfo.xml" 2>/dev/null || true
rm -f /usr/share/applications/thorium-browser.desktop 2>/dev/null || true
rm -f "$HOME/.local/share/applications/thorium-browser.desktop" 2>/dev/null || true
rm -f /usr/share/icons/hicolor/256x256/apps/thorium-browser.png 2>/dev/null || true
rm -f "$HOME/.local/share/icons/hicolor/256x256/apps/thorium-browser.png" 2>/dev/null || true
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
info "Thorium removido (configurações em ~/.config/thorium preservadas)"
