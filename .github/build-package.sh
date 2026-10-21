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
source=('${DEB_URL}/${DEB}')
noextract=('${DEB}')
sha256sums=('SKIP')

package() {
	bsdtar -C "\$srcdir" -xf "\$srcdir/${DEB}" data.tar.xz
	bsdtar -C "\$pkgdir" -xJf "\$srcdir/data.tar.xz"
	# o .deb traz dois .desktop com conteudo identico: sem isso o menu do
	# sistema mostra 2 icones do Thorium
	rm -f -- "\$pkgdir/usr/share/applications/org.chromium.Thorium.desktop"
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
