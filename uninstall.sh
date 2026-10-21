#!/usr/bin/env bash
# Remove o Thorium Browser instalado em /opt (sistema).
if [ -z "${BASH_VERSION:-}" ]; then
	exec bash "$0" "$@"
fi
set -euo pipefail

RAW_BASE="https://raw.githubusercontent.com/LucianoSkx/thorium-installer/main"
PREFIX="/opt/thorium-browser"
CHECK_DIR="/usr/lib/thorium-browser"
DATA_HOME="/usr/share"

info() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==> ATENÇÃO:\033[0m %s\n' "$*" >&2; }

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
		sudo -k 2>/dev/null || true
		sudo -E bash "$0" "$@"
		exit $?
	fi
	warn "sem sudo: a remoção do sistema pode falhar"
fi

info "removendo Thorium"
rm -f /usr/bin/thorium-browser /usr/bin/thorium-shell 2>/dev/null || true
rm -f /usr/local/bin/thorium-browser /usr/local/bin/thorium-shell 2>/dev/null || true
rm -rf "$PREFIX" "$CHECK_DIR" 2>/dev/null || true
rm -f "$DATA_HOME/applications/thorium-browser.desktop" 2>/dev/null || true
rm -f "$DATA_HOME/icons/hicolor/256x256/apps/thorium-browser.png" 2>/dev/null || true
rm -f "$DATA_HOME/metainfo/org.chromium.Thorium.metainfo.xml" 2>/dev/null || true
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$DATA_HOME/applications" >/dev/null 2>&1 || true
info "Thorium removido (perfil e configurações em ~/.config/thorium preservados)"
