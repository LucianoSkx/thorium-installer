#!/usr/bin/env bash
# Remove o Thorium Browser instalado via pacman.
if [ -z "${BASH_VERSION:-}" ]; then
	exec bash "$0" "$@"
fi
set -euo pipefail

info() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==> ATENÇÃO:\033[0m %s\n' "$*" >&2; }

if [ "$(id -u)" != 0 ]; then
	if command -v sudo >/dev/null 2>&1; then
		sudo -k 2>/dev/null || true
		sudo -E bash "$0" "$@"
		exit $?
	fi
	warn "sem sudo: a remoção pode falhar"
fi

PKGS="$(pacman -Qq 2>/dev/null | grep -E '^thorium-browser' || true)"
if [ -n "$PKGS" ]; then
	info "removendo: $PKGS"
	# shellcheck disable=SC2086
	pacman -Rns --noconfirm $PKGS
	info "Thorium removido (perfil em ~/.config/thorium preservado)"
else
	info "nenhum pacote do Thorium instalado"
fi
