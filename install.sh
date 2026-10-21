#!/usr/bin/env bash
# Instalador do Thorium Browser para Arch Linux / CachyOS (e derivados).
if [ -z "${BASH_VERSION:-}" ]; then
	exec bash "$0" "$@"
fi
set -euo pipefail

REPO="gz83/thorium"
APP_CMD="thorium-browser"
APP_TITLE="Thorium Browser"
DESKTOP_ID="thorium-browser.desktop"
ICON_NAME="thorium-browser"
PREFIX_SYSTEM="/opt/thorium-browser"
PREFIX_USER="$HOME/.local/opt/thorium-browser"

VERSION=""
LOCAL=""
USER_MODE=0
UNINSTALL=0
ASSUME_YES=0
MODO_EXPLICITO=0

info() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==> ATENÇÃO:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mErro:\033[0m %s\n' "$*" >&2; exit 1; }

detect_system() {
	if [ ! -r /etc/os-release ]; then die "sem /etc/os-release"; fi
	# shellcheck disable=SC1091
	. /etc/os-release
	case " ${ID_LIKE:-} ${ID:-} " in
		*" arch "*|*" cachyos "*) ;;
		*) die "este instalador é para Arch/CachyOS (detectado: ${PRETTY_NAME:-$ID})" ;;
	esac
}

download() {
	if command -v curl >/dev/null 2>&1; then
		curl -fsSL --retry 3 --retry-all-errors -o "$2" "$1"
	elif command -v wget >/dev/null 2>&1; then
		wget -q -O "$2" "$1"
	else
		die "curl ou wget são necessários"
	fi
}

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

  --user            instala só para você, em ~/.local (sem sudo)
  --system          instala no sistema, em /opt (padrão; pode pedir sudo)
  --version <ver>   instala uma versão específica (ex: 156.0.8078.28)
  --local <deb>     instala a partir de um .deb já baixado
  --uninstall       remove o Thorium
  -y, --yes         não pergunta confirmação
  -h, --help        mostra esta ajuda

Exemplos:
  sudo bash install.sh
  bash install.sh --user
EOF
	exit "${1:-0}"
}

while [ $# -gt 0 ]; do
	case "$1" in
		--user) USER_MODE=1; MODO_EXPLICITO=1 ;;
		--system) USER_MODE=0; MODO_EXPLICITO=1 ;;
		--version) shift; VERSION="${1:-}" ;;
		--local) shift; LOCAL="${1:-}" ;;
		--uninstall) UNINSTALL=1 ;;
		-y|--yes) ASSUME_YES=1 ;;
		-h|--help) usage ;;
		*) die "opção desconhecida: $1" ;;
	esac
	shift
done

TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
trap 'printf "\n"; info "cancelado"; exit 130' INT TERM

detect_system

if [ "$MODO_EXPLICITO" = 0 ]; then
	tty=""
	[ -n "${CI:-}" ] || tty="$( [ -e /dev/tty ] && echo /dev/tty )"
	if [ -n "$tty" ]; then
		printf '\nComo quer instalar o Thorium?\n\n' > "$tty"
		printf '   1)  sistema  \033[1;33m★ recomendado\033[0m  (em /opt, sudo pode pedir senha)\n' > "$tty"
		printf '   2)  usuário  (em ~/.local, sem senha)\n\n' > "$tty"
		printf 'Escolha [1-2] (Enter = 1): ' > "$tty"
		escolha=""
		read -r escolha < "$tty" || true
		case "$escolha" in 2|2.|user|USER) USER_MODE=1 ;; *) USER_MODE=0 ;; esac
		printf '\n' > "$tty"
	fi
fi

if [ "$USER_MODE" = 1 ]; then
	PREFIX="$PREFIX_USER"
	BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
	DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
else
	PREFIX="$PREFIX_SYSTEM"
	BIN_DIR="/usr/bin"
	DATA_HOME="/usr/share"
	if [ "$(id -u)" != 0 ]; then
		[ -f "$0" ] || die "execute a partir de um arquivo salvo: sudo bash install.sh"
		command -v sudo >/dev/null 2>&1 || die "sem sudo: use --user"
		sudo -k 2>/dev/null || true
		exec sudo -E bash "$0" --system ${VERSION:+--version "$VERSION"} ${LOCAL:+--local "$LOCAL"} ${ASSUME_YES:+-y} ${UNINSTALL:+--uninstall}
	fi
fi

info "sistema: $(. /etc/os-release; echo "$PRETTY_NAME") · modo: $([ "$USER_MODE" = 1 ] && echo usuário || echo sistema)"

install_deps() {
	local deps=(alsa-lib at-spi2-core cairo dbus expat glib2 gtk3 hicolor-icon-theme libcups gcc-libs libnotify libx11 libxcb libxcomposite libxdamage libxext libxfixes libxkbcommon libxrandr mesa nspr nss pango systemd-libs ttf-liberation xdg-utils)
	if [ "$USER_MODE" = 1 ]; then
		warn "modo usuário: dependências do sistema não serão instaladas automaticamente"
		warn "se faltar algo, rode: sudo pacman -S --needed ${deps[*]}"
		return 0
	fi
	info "instalando dependências"
	pacman -S --needed --noconfirm "${deps[@]}" || warn "alguma dependência não pôde ser instalada"
}

uninstall() {
	info "removendo Thorium"
	rm -f "$BIN_DIR/$APP_CMD" 2>/dev/null || true
	rm -f "$DATA_HOME/applications/$DESKTOP_ID" 2>/dev/null || true
	rm -f "$HOME/.local/share/applications/$DESKTOP_ID" 2>/dev/null || true
	rm -rf "$PREFIX_SYSTEM" "$PREFIX_USER" 2>/dev/null || true
	rm -f /usr/local/bin/thorium-shell 2>/dev/null || true
	rm -f "$DATA_HOME/icons/hicolor/256x256/apps/$ICON_NAME.png" 2>/dev/null || true
	rm -f "$HOME/.local/share/icons/hicolor/256x256/apps/$ICON_NAME.png" 2>/dev/null || true
	command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$DATA_HOME/applications" >/dev/null 2>&1 || true
	command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
	info "Thorium removido (configurações em ~/.config/thorium preservadas)"
}

if [ "$UNINSTALL" = 1 ]; then
	uninstall
	exit 0
fi

install_deps

if [ -n "$LOCAL" ]; then
	[ -f "$LOCAL" ] || die "arquivo não encontrado: $LOCAL"
	DEB_FILE="$LOCAL"
	base="$(basename "$DEB_FILE")"
	case "$base" in thorium-browser_*_*.deb) VERSION="${base#thorium-browser_}"; VERSION="${VERSION%.deb}"; VERSION="${VERSION%_*}" ;; esac
	[ -n "$VERSION" ] || VERSION="local"
else
	if [ -z "$VERSION" ]; then
		info "consultando última versão em github.com/$REPO"
		download "https://api.github.com/repos/$REPO/releases/latest" "$TMPD/rel.json"
		grep -q '"tag_name"' "$TMPD/rel.json" || die "falha ao consultar releases"
		VERSION="$(awk -F'"' '/"tag_name"/ {print $4; exit}' "$TMPD/rel.json" | sed 's/^M//')"
		[ -n "$VERSION" ] || die "não foi possível determinar a versão"
	fi
	VARIANT="$(detect_variant)"
	info "variante de CPU: $VARIANT"
	SUFFIX="$VARIANT"
	DEB="thorium-browser_${VERSION}_${SUFFIX}.deb"
	URL="https://github.com/$REPO/releases/download/M${VERSION}/$DEB"
	DEB_FILE="$TMPD/$DEB"
	info "baixando: $URL"
	download "$URL" "$DEB_FILE"
fi

STAGE="$TMPD/stage"
mkdir -p "$STAGE"
info "extraindo pacote"
bsdtar -C "$TMPD" -xf "$DEB_FILE" data.tar.xz
bsdtar -C "$STAGE" -xJf "$TMPD/data.tar.xz"

[ -d "$STAGE/opt/chromium.org/thorium" ] || die "layout inesperado do .deb (faltou opt/chromium.org/thorium)"

info "instalando em $PREFIX"
rm -rf "$PREFIX"
mkdir -p "$(dirname "$PREFIX")"
mv "$STAGE/opt/chromium.org/thorium" "$PREFIX"

[ -f "$PREFIX/thorium-browser" ] && \
	sed -i 's#export CHROME_VERSION_EXTRA="stable#export CHROME_VERSION_EXTRA="beta#' "$PREFIX/thorium-browser"
chmod 755 "$PREFIX/thorium-browser" 2>/dev/null || true
[ -f "$PREFIX/chrome-sandbox" ] && chmod 4755 "$PREFIX/chrome-sandbox"

for f in "$PREFIX/default-app-block"; do
	[ -f "$f" ] && sed -i "s#/opt/chromium.org/thorium/#/opt/thorium-browser/#g" "$f"
done
if [ -f "$STAGE/usr/share/gnome-control-center/default-apps/thorium-browser.xml" ]; then
	sed -i "s#/opt/chromium.org/thorium/#/opt/thorium-browser/#g" "$STAGE/usr/share/gnome-control-center/default-apps/thorium-browser.xml"
fi

# check-cpu-support (compatibilidade com o AUR)
CHECK_DIR="$HOME/.local/lib/thorium-browser"
if [ "$USER_MODE" = 0 ]; then CHECK_DIR="/usr/lib/thorium-browser"; fi
mkdir -p "$CHECK_DIR"
cat > "$CHECK_DIR/check-cpu-support" <<'CS'
#!/usr/bin/env bash
exit 0
CS
chmod 755 "$CHECK_DIR/check-cpu-support"

mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/$APP_CMD" <<EOF
#!/usr/bin/env bash
set -euo pipefail
name=thorium
flags_file="\${XDG_CONFIG_HOME:-\$HOME/.config}/\${name}-flags.conf"
flags=()
if [[ -f \$flags_file ]]; then
	mapfile -t lines < "\$flags_file"
	for line in "\${lines[@]}"; do
		[[ \$line =~ [^[:space:]] ]] && [[ ! \$line =~ ^[[:space:]]*# ]] && flags+=("\$line")
	done
fi
CHECK="$CHECK_DIR/check-cpu-support"
[ -x "$CHECK" ] && "$CHECK" runtime || true
exec "$PREFIX/thorium-browser" "\${flags[@]}" "\$@"
EOF
chmod 755 "$BIN_DIR/$APP_CMD"

mkdir -p "$DATA_HOME/applications"
if [ -f "$STAGE/usr/share/applications/thorium-browser.desktop" ]; then
	install -m644 "$STAGE/usr/share/applications/thorium-browser.desktop" "$DATA_HOME/applications/$DESKTOP_ID"
	sed -i "s#Exec=/usr/bin/thorium-browser#Exec=$BIN_DIR/$APP_CMD#" "$DATA_HOME/applications/$DESKTOP_ID"
	sed -i "s#Exec=thorium-browser#Exec=$BIN_DIR/$APP_CMD#" "$DATA_HOME/applications/$DESKTOP_ID"
else
	cat > "$DATA_HOME/applications/$DESKTOP_ID" <<EOF
[Desktop Entry]
Name=$APP_TITLE
Exec=$BIN_DIR/$APP_CMD %U
Icon=$ICON_NAME
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
EOF
fi

# appdata/metainfo (igual ao AUR)
if [ -f "$STAGE/usr/share/appdata/thorium-browser.appdata.xml" ]; then
	mkdir -p "$DATA_HOME/metainfo"
	install -m644 "$STAGE/usr/share/appdata/thorium-browser.appdata.xml" "$DATA_HOME/metainfo/org.chromium.Thorium.metainfo.xml"
	sed -i 's#<id>thorium-browser[.]desktop</id>#<id>org.chromium.Thorium</id>#' "$DATA_HOME/metainfo/org.chromium.Thorium.metainfo.xml"
fi

# limpeza de arquivos do .deb que o AUR também remove
rm -rf "$PREFIX/cron" 2>/dev/null || true
rm -f /etc/cron.daily/thorium-browser 2>/dev/null || true
rm -rf "$DATA_HOME/doc/thorium-browser" 2>/dev/null || true
rm -rf "$DATA_HOME/menu" 2>/dev/null || true
rm -f "$PREFIX"/product_logo_*.xpm 2>/dev/null || true

mkdir -p "$DATA_HOME/icons/hicolor/256x256/apps"
if [ -f "$PREFIX/product_logo_256.png" ]; then
	install -m644 "$PREFIX/product_logo_256.png" "$DATA_HOME/icons/hicolor/256x256/apps/$ICON_NAME.png"
fi
if [ -f "$STAGE/usr/share/icons/hicolor/256x256/apps/thorium-browser.png" ]; then
	install -m644 "$STAGE/usr/share/icons/hicolor/256x256/apps/thorium-browser.png" "$DATA_HOME/icons/hicolor/256x256/apps/$ICON_NAME.png"
fi

if [ -f "$STAGE/usr/bin/thorium-shell" ]; then
	install -m755 "$STAGE/usr/bin/thorium-shell" "$BIN_DIR/thorium-shell" 2>/dev/null || true
fi

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$DATA_HOME/applications" >/dev/null 2>&1 || true

cat <<EOF

✔ $APP_TITLE $VERSION instalado.
  binário:  $BIN_DIR/$APP_CMD
  app:      $PREFIX/thorium-browser

Execute:        $APP_CMD
Remover:        bash $(dirname "$0")/uninstall.sh   (ou reexecute com --uninstall)
EOF

if [ "$USER_MODE" = 1 ]; then
	case ":$PATH:" in
		*":$BIN_DIR:"*) ;;
		*) warn "adicione $BIN_DIR ao PATH: echo 'export PATH=\$PATH:$BIN_DIR' >> ~/.bashrc" ;;
	esac
fi
