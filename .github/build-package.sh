#!/usr/bin/env bash
# Reempacota o .deb oficial do upstream (gz83/thorium) para pacman, dentro do
# container Arch do GitHub Actions.
# Uso: build-package.sh <sufixo> [VER] [CARCH]
set -euo pipefail

VARIANT="${1:?informe o sufixo (SSE3, SSE4, AVX, AVX2, AVX512, arm64 ou i386)}"
VER_UP="${2:-}"; VER_UP="${VER_UP#v}"; VER_UP="${VER_UP#M}"
CARCH_TARGET="${3:-x86_64}"
[ -n "$VER_UP" ] || { echo "informe a versão do upstream (ex.: 156.0.8078.28)" >&2; exit 1; }

DEB_URL="https://github.com/gz83/thorium/releases/download/M${VER_UP}"
DEB="thorium-browser_${VER_UP}_${VARIANT}.deb"

pacman -Sy --noconfirm --needed libarchive

# makepkg não roda como root
useradd -m builder
mkdir -p /build
chown builder /build

# Wrapper que le ~/.config/thorium-flags.conf e checagem runtime de CPU, dos
# scripts do PKGBUILD thorium-browser-beta-avx2-bin (RubenKelevra); os thresholds
# SIMD sao os do gz83/thorium M156 (thorium_x86_profile / check_simd.py).
cat > /build/thorium-browser.sh <<'WRAPZ'
#!/usr/bin/env bash

set -euo pipefail

/usr/lib/thorium-browser/check-cpu-support @VARIANT@

name=thorium
flags_file="${XDG_CONFIG_HOME:-$HOME/.config}/${name}-flags.conf"

lines=()
if [[ -f $flags_file ]]; then
    mapfile -t lines < "$flags_file"
fi

flags=()
for line in "${lines[@]}"; do
    if [[ $line =~ [^[:space:]] ]] && [[ ! $line =~ ^[[:space:]]*#.* ]]; then
        flags+=("$line")
    fi
done

exec /opt/chromium.org/thorium/thorium-browser "${flags[@]}" "$@"
WRAPZ
sed -i "s/@VARIANT@/${VARIANT}/" /build/thorium-browser.sh

cat > /build/check-cpu-support <<'CHECKZ'
#!/usr/bin/env bash

set -euo pipefail

if (( $# != 1 )); then
	printf 'Usage: %s <SSE3|SSE4|AVX|AVX2|AVX512|i386|arm64>\n' "${0##*/}" >&2
	exit 2
fi
variant=$1
case $variant in
	SSE3|SSE4|AVX|AVX2|AVX512|i386|arm64) ;;
	*)
		printf 'Usage: %s <SSE3|SSE4|AVX|AVX2|AVX512|i386|arm64>\n' "${0##*/}" >&2
		exit 2
		;;
esac

# interseção das flags de todos os processadores x86 reportados
cpu_flags() {
	awk '
		/^flags[[:space:]]*:/ {
			line = $0
			sub(/^[^:]*:[[:space:]]*/, "", line)
			count = split(line, current, /[[:space:]]+/)

			delete present
			for (field = 1; field <= count; field++) {
				if (current[field] != "") {
					present[current[field]] = 1
				}
			}

			if (!seen) {
				for (flag in present) {
					common[flag] = 1
				}
				seen = 1
			} else {
				for (flag in common) {
					if (!(flag in present)) {
						delete common[flag]
					}
				}
			}
		}
		END {
			if (!seen) {
				exit 2
			}
			for (flag in common) {
				print flag
			}
		}
	' /proc/cpuinfo
}

has_all_flags() {
	local available=$1
	shift
	local required

	for required in "$@"; do
		grep -qx -- "$required" <<< "$available" || return 1
	done
}

# SIMD baseline de cada build (gz83/thorium M156)
required_flags() {
	case $1 in
		SSE3)   printf '%s\n' pni ;;
		SSE4)   printf '%s\n' pni ssse3 sse4_1 ;;
		AVX)    printf '%s\n' pni avx ;;
		AVX2)   printf '%s\n' pni avx avx2 fma f16c ;;
		AVX512) printf '%s\n' pni avx avx2 fma f16c \
				avx512f avx512cd avx512vl avx512bw avx512dq ;;
		i386)   printf '%s\n' sse2 ;;
		arm64)  return 0 ;;
	esac
}

show_popup() {
	local message=$1 urgency=$2

	printf '%s\n' "$message" >&2
	if [[ -n ${DISPLAY:-} || -n ${WAYLAND_DISPLAY:-} ]]; then
		notify-send --app-name='Thorium Browser' --urgency="$urgency" \
			'Thorium Browser CPU warning' "$message" >/dev/null 2>&1 &
	fi
}

status=2
better=''
case $variant in
	arm64)
		machine=$(uname -m)
		if [[ $machine == aarch64 || $machine == arm64 ]]; then
			exit 0
		fi
		status=1
		;;
	i386|SSE3|SSE4|AVX|AVX2|AVX512)
		available=$(cpu_flags) || available=''
		if [[ -z $available ]]; then
			status=2
		elif ! has_all_flags "$available" $(required_flags "$variant"); then
			status=1
		else
			status=0
			for v in AVX512 AVX2 AVX SSE4; do
				if has_all_flags "$available" $(required_flags "$v"); then
					better=$v
					break
				fi
			done
		fi
		;;
esac

case $status in
	0)
		if [[ -n $better && $better != "$variant" ]]; then
			message="Thorium ${variant} pode rodar, mas este CPU permite o build ${better}, que performa melhor. Trocar de pacote é opcional."
			show_popup "$message" low
		fi
		;;
	1)
		message="O build ${variant} do Thorium é incompatível com este CPU e não deve rodar."
		if [[ -n $better ]]; then
			message+=" Build compatível: ${better} (veja a página de releases)."
		fi
		show_popup "$message" critical
		exit 1
		;;
	2)
		show_popup 'Não foi possível verificar a compatibilidade do CPU.' normal
		exit 2
		;;
esac
CHECKZ

cat > /build/PKGBUILD <<EOF
pkgname='thorium-browser'
pkgver=${VER_UP}
pkgrel=1
pkgdesc='Chromium fork focused on performance and security (${VARIANT} build)'
url='https://github.com/gz83/thorium'
license=('BSD-3-Clause' 'LicenseRef-Google-Widevine-CDM')
arch=('${CARCH_TARGET}')
depends=('alsa-lib' 'at-spi2-core' 'cairo' 'dbus' 'expat' 'glib2' 'gtk3'
	'hicolor-icon-theme' 'libcups' 'libgcc' 'libnotify' 'libx11' 'libxcb'
	'libxcomposite' 'libxdamage' 'libxext' 'libxfixes' 'libxkbcommon'
	'libxrandr' 'mesa' 'nspr' 'nss' 'pango' 'systemd-libs' 'ttf-liberation'
	'xdg-utils')
conflicts=('thorium-browser-bin' 'thorium-browser-sse3-bin'
	'thorium-browser-sse4-bin' 'thorium-browser-avx-bin'
	'thorium-browser-avx2-bin' 'thorium-browser-avx512-bin'
	'thorium-browser-beta-bin' 'thorium-browser-beta-sse4-bin'
	'thorium-browser-beta-avx-bin' 'thorium-browser-beta-avx2-bin'
	'thorium-browser-beta-avx512-bin')
options=('!strip' '!debug' '!emptydirs')
source=('${DEB_URL}/${DEB}' 'thorium-browser.sh' 'check-cpu-support')
noextract=('${DEB}')
sha256sums=('SKIP' 'SKIP' 'SKIP')

package() {
	bsdtar -C "\$srcdir" -xf "\$srcdir/${DEB}" data.tar.xz
	bsdtar -C "\$pkgdir" -xJf "\$srcdir/data.tar.xz"
	# o .deb traz dois .desktop com conteudo identico: sem isso o menu do
	# sistema mostra 2 icones do Thorium
	rm -f -- "\$pkgdir/usr/share/applications/org.chromium.Thorium.desktop"
	# substitui o wrapper do .deb (symlink) pelo leitor de thorium-flags.conf;
	# sem o rm, o install seguiria o symlink e sobrescreveria o launcher real
	rm -f -- "\$pkgdir/usr/bin/thorium-browser"
	install -Dm755 -- "\$srcdir/thorium-browser.sh" "\$pkgdir/usr/bin/thorium-browser"
	install -Dm755 -- "\$srcdir/check-cpu-support" "\$pkgdir/usr/lib/thorium-browser/check-cpu-support"
	chmod 4755 -- "\$pkgdir/opt/chromium.org/thorium/chrome-sandbox"
}
EOF
chown builder /build/PKGBUILD

if [ "$CARCH_TARGET" != "x86_64" ]; then
	# build para outra arquitetura: makepkg usa CARCH do makepkg.conf
	sed "s/^CARCH=.*/CARCH=\"$CARCH_TARGET\"/" /etc/makepkg.conf > /build/makepkg.conf
	CONF="--config /build/makepkg.conf --ignorearch"
else
	CONF=""
fi

cd /build
su builder -c "makepkg -f --noconfirm --noprogressbar --nodeps ${CONF}"

pkg=$(ls *.pkg.tar.zst | grep -v -- '-debug-')
saida="thorium-browser_${VER_UP}_${VARIANT}.pkg.tar.zst"
cp "$pkg" "/github/workspace/$saida"
ls -lh "/github/workspace/$saida"
