#!/usr/bin/env bash
# Compila um pacote do AUR dentro do container Arch do GitHub Actions.
# Uso: build-package.sh <aur-pkgname> <sufixo> [CARCH]
#
# O nome do artefato segue o do release original do upstream:
#   thorium-browser_<versao>_<sufixo>.pkg.tar.zst
# onde <sufixo> é SSE3, SSE4, AVX, AVX2, AVX512, arm64 ou i386.
set -euo pipefail

PKG="${1:?informe o nome do pacote AUR}"
SUFFIX="${2:?informe o sufixo (SSE3, SSE4, AVX, AVX2, AVX512, arm64 ou i386)}"
CARCH_TARGET="${3:-}"

pacman -Sy --noconfirm --needed git rpm-tools cpio libarchive

# makepkg não roda como root
useradd -m builder
mkdir -p /build
chown builder /build

if [ -n "$CARCH_TARGET" ]; then
	# build para outra arquitetura: makepkg usa CARCH do makepkg.conf
	sed "s/^CARCH=.*/CARCH=\"$CARCH_TARGET\"/" /etc/makepkg.conf > /build/makepkg.conf
	CONF="--config /build/makepkg.conf --ignorearch"
else
	CONF=""
fi

su builder -c "
  git clone --depth 1 https://aur.archlinux.org/${PKG}.git /build/pkg
  cd /build/pkg
  cat >> PKGBUILD <<'PATCH'

# o .deb traz thorium-browser.desktop e org.chromium.Thorium.desktop com
# conteudo identico: sem isso o menu do sistema mostra 2 icones do Thorium
eval \"\$(declare -f package | sed '1s/^package/package_orig/')\"
package() {
  package_orig
  rm -f \"\${pkgdir}/usr/share/applications/org.chromium.Thorium.desktop\"
}
PATCH
  makepkg -f --noconfirm --noprogressbar --nodeps ${CONF}
"

cd /build/pkg
pkg=$(ls *.pkg.tar.zst | grep -v -- '-debug-')
# versao sem o pkgrel (o .SRCINFO traz "156.0.8078.28")
versao=$(awk -F'= ' '/^[[:space:]]*pkgver[[:space:]]*=/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' .SRCINFO)
saida="thorium-browser_${versao}_${SUFFIX}.pkg.tar.zst"
cp "$pkg" "/github/workspace/$saida"
ls -lh "/github/workspace/$saida"
