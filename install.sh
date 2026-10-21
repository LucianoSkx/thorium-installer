#!/usr/bin/env bash
# Instalador do Thorium Browser para Arch Linux / CachyOS.
# Baixa o .pkg.tar.zst compilado pelo GitHub Actions (a partir do PKGBUILD do
# AUR) e instala com pacman -U: exatamente como o AUR faria.
if [ -z "${BASH_VERSION:-}" ]; then
	exec bash "$0" "$@"
fi
set -euo pipefail

REPO="LucianoSkx/thorium-installer"
RAW_BASE="https://raw.githubusercontent.com/$REPO/main"
API="https://api.github.com/repos/$REPO/releases"

ORIG_ARGS=("$@")
VERSION=""
LOCAL=""
UNINSTALL=0
CHANNEL="beta"

info() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==> ATENÇÃO:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mErro:\033[0m %s\n' "$*" >&2; exit 1; }

download() {
	if command -v curl >/dev/null 2>&1; then
		curl -fsSL --retry 3 --retry-all-errors -o "$2" "$1"
	elif command -v wget >/dev/null 2>&1; then
		wget -q -O "$2" "$1"
	else
		die "curl ou wget são necessários"
	fi
}

# Variante de CPU -> sufixo do pacote (mesmo mapeamento do AUR).
detect_variant() {
	local machine; machine=$(uname -m)
	case "$machine" in
		aarch64|arm64) echo "arm64"; return ;;
		i?86) echo "i386"; return ;;
		x86_64|amd64)
			local flags
			flags=$(awk '
				/^flags[[:space:]]*:/ {
					line=$0; sub(/^[^:]*:[[:space:]]*/, "", line)
					n=split(line, cur, /[[:space:]]+/)
					delete pres
					for (i=1;i<=n;i++) if (cur[i]!="") pres[cur[i]]=1
					if (!seen) { for (f in pres) common[f]=1; seen=1 }
					else { for (f in common) if (!(f in pres)) delete common[f] }
				}
				END { for (f in common) print f }
			' /proc/cpuinfo)
			has() { grep -qx "$1" <<< "$flags"; }
			if has avx512f && has avx512cd && has avx512vl && has avx512bw && has avx512dq \
			   && has avx2 && has fma && has f16c && has avx; then echo "AVX512"
			elif has avx2 && has fma && has f16c && has avx; then echo "AVX2"
			elif has avx; then echo "AVX"
			elif has sse4_1 && has ssse3; then echo "SSE4"
			else echo "SSE3"
			fi
			;;
		*) die "arquitetura não suportada: $machine" ;;
	esac
}

usage() {
	cat <<EOF
Uso: $0 [opções]

  --version <tag>   usa uma release específica (ex: M156.0.8078.28)
  --stable          instala a linha estável (138.0.7204.303) em vez da beta (156.0.8078.28)
  --local <pkg>     instala a partir de um .pkg.tar.zst já baixado
  --uninstall       remove o Thorium
  -h, --help        mostra esta ajuda

Instala o pacote oficial do AUR (compilado no GitHub Actions) com pacman -U.
EOF
	exit "${1:-0}"
}

while [ $# -gt 0 ]; do
	case "$1" in
		--version) shift; VERSION="${1:-}" ;;
		--stable) CHANNEL="stable" ;;
		--local) shift; LOCAL="${1:-}" ;;
		--uninstall) UNINSTALL=1 ;;
		-h|--help) usage ;;
		*) die "opção desconhecida: $1" ;;
	esac
	shift
done

TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
trap 'printf "\n"; info "cancelado"; exit 130' INT TERM

SELF_PATH="$0"
case "$SELF_PATH" in
	/*) ;;
	*) SELF_PATH="$PWD/$SELF_PATH" ;;
esac

# executado via "curl ... | bash": $0 nao e um arquivo, entao o script
# re-executa a si mesmo a partir de um arquivo (o re-exec com sudo exige isso).
if [ ! -f "$0" ] || [ "${0#/dev/fd/}" != "$0" ]; then
	info "obtendo o instalador (execucao via pipe)"
	SELF="$TMPD/install.sh"
	download "$RAW_BASE/install.sh" "$SELF" || die "nao consegui baixar o instalador"
	bash "$SELF" ${ORIG_ARGS[@]+"${ORIG_ARGS[@]}"}
	exit $?
fi

if [ ! -r /etc/os-release ]; then die "sem /etc/os-release"; fi
# shellcheck disable=SC1091
. /etc/os-release
case " ${ID_LIKE:-} ${ID:-} " in
	*" arch "*|*" cachyos "*) ;;
	*) die "este instalador é para Arch/CachyOS (detectado: ${PRETTY_NAME:-$ID})" ;;
esac

# tudo via pacman: precisa de root
if [ "$(id -u)" != 0 ]; then
	command -v sudo >/dev/null 2>&1 || die "sem sudo: rode como root"
	sudo -k 2>/dev/null || true
	args=(--system)
	[ -n "$VERSION" ] && args+=(--version "$VERSION")
	[ -n "$LOCAL" ] && args+=(--local "$LOCAL")
	[ "$UNINSTALL" = 1 ] && args+=(--uninstall)
	sudo -E bash "$SELF_PATH" "${args[@]}"
	exit $?
fi

info "sistema: $(. /etc/os-release; echo "$PRETTY_NAME")"

if [ "$UNINSTALL" = 1 ]; then
	PKGS="$(pacman -Qq 2>/dev/null | grep -E '^thorium-browser' || true)"
	if [ -n "$PKGS" ]; then
		info "removendo: $PKGS"
		# shellcheck disable=SC2086
		pacman -Rns --noconfirm $PKGS
		info "Thorium removido (perfil em ~/.config/thorium preservado)"
	else
		info "nenhum pacote do Thorium instalado"
	fi
	exit 0
fi

if [ -n "$LOCAL" ]; then
	PKG_FILE="$LOCAL"
	[ -f "$PKG_FILE" ] || die "arquivo não encontrado: $PKG_FILE"
else
	VARIANT="$(detect_variant)"
	info "variante de CPU: $VARIANT"

	if [ -n "$VERSION" ]; then
		TAG="v${VERSION#v}"
		API_URL="$API/tags/$TAG"
	else
		API_URL="$API/latest"
	fi
	info "consultando a release em github.com/$REPO"
	download "$API_URL" "$TMPD/rel.json"
	grep -q '"browser_download_url"' "$TMPD/rel.json" || die "falha ao consultar a release"

	# pares "url nome" de todos os assets
	ASSETS="$(awk '
		/"name"[ \t]*:/ {
			n=$0
			sub(/.*"name"[ \t]*:[ \t]*"/, "", n)
			sub(/".*/, "", n)
			name=n
			next
		}
		/"browser_download_url"[ \t]*:/ {
			u=$0
			sub(/.*"browser_download_url"[ \t]*:[ \t]*"/, "", u)
			sub(/".*/, "", u)
			print u " " name
		}
	' "$TMPD/rel.json")"

	# versoes presentes nos assets: a beta e a mais nova, a estavel a mais antiga
	VERS="$(printf '%s\n' "$ASSETS" | awk '{n=$2; sub(/^thorium-browser_/,"",n); sub(/_[A-Za-z0-9]+\.pkg\.tar\.zst$/,"",n); print n}' | sort -u -V)"
	TAG_VER="$(awk -F'"' '/"tag_name"[ \t]*:/ {print $4; exit}' "$TMPD/rel.json")"
	TAG_VER="${TAG_VER#v}"; TAG_VER="${TAG_VER#M}"
	if printf '%s\n' "$VERS" | grep -qx "$TAG_VER"; then
		BETA_VER="$TAG_VER"
		STABLE_VER="$(printf '%s\n' "$VERS" | grep -vx "$BETA_VER" | head -1)"
	else
		BETA_VER="$(printf '%s\n' "$VERS" | tail -1)"
		STABLE_VER="$(printf '%s\n' "$VERS" | head -1)"
	fi
	[ -n "$STABLE_VER" ] || STABLE_VER="$BETA_VER"

	VER="$BETA_VER"
	[ "$CHANNEL" = "stable" ] && VER="$STABLE_VER"

	# a linha estavel (M138) so tem x86_64/i686: em arm64 cai para a beta
	ASSET="thorium-browser_${VER}_${VARIANT}.pkg.tar.zst"
	if [ "$CHANNEL" = "stable" ] && [ "$VARIANT" = "arm64" ]; then
		VER="$BETA_VER"
		ASSET="thorium-browser_${VER}_${VARIANT}.pkg.tar.zst"
	fi

	URL="$(printf '%s\n' "$ASSETS" | awk -v want="$ASSET" '$2 == want {print $1; exit}')"
	[ -n "$URL" ] || die "a release não tem o pacote $ASSET"

	PKG_FILE="$TMPD/$ASSET"
	info "baixando: $URL"
	download "$URL" "$PKG_FILE" || die "não consegui baixar $ASSET"
fi

info "instalando com: pacman -U"
pacman -U --noconfirm "$PKG_FILE"

# limpa o lixo
rm -f "$PKG_FILE" 2>/dev/null || true

cat <<EOF

✔ Thorium Browser $(pacman -Q 2>/dev/null | grep -E '^thorium-browser' | awk '{print $2}' | head -1 | sed 's/-[0-9]*$//') instalado.
  pacote:  $(pacman -Qq 2>/dev/null | grep -E '^thorium-browser' | tr '\n' ' ')

Execute:        thorium-browser
Remover:        sudo bash install.sh --uninstall
EOF
