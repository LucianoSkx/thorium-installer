#!/usr/bin/env bash
# Compila um pacote do AUR dentro do container Arch do GitHub Actions.
# Uso: build-package.sh <aur-pkgname> <variante: SSE3|SSE4|AVX|AVX2|AVX512>
#
# O nome do artefato segue o do release original do upstream:
#   thorium-browser_<versao>_<VARIANT>.pkg.tar.zst
set -euo pipefail

PKG="${1:?informe o nome do pacote AUR}"
VARIANT="${2:?informe a variante (SSE3, SSE4, AVX, AVX2 ou AVX512)}"

pacman -Sy --noconfirm --needed git rpm-tools cpio libarchive

# makepkg não roda como root
useradd -m builder
mkdir -p /build
chown builder /build

su builder -c "
  git clone --depth 1 https://aur.archlinux.org/${PKG}.git /build/pkg
  cd /build/pkg
  makepkg -f --noconfirm --noprogressbar --nodeps
"

cd /build/pkg
pkg=$(ls *.pkg.tar.zst | grep -v -- '-debug-')
# versao sem o pkgrel (o .PKGINFO traz "156.0.8078.28-1")
versao=$(awk -F'= ' '/^pkgver/ {print $2; exit}' .SRCINFO)
saida="thorium-browser_${versao}_${VARIANT}.pkg.tar.zst"
cp "$pkg" "/github/workspace/$saida"
ls -lh "/github/workspace/$saida"
