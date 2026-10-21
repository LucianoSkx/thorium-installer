#!/usr/bin/env bash
# Compila um pacote do AUR dentro do container Arch do GitHub Actions.
# Uso: build-package.sh <aur-pkgname>
set -euo pipefail

PKG="${1:?informe o nome do pacote AUR}"

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

cp /build/pkg/*.pkg.tar.zst /github/workspace/
ls -lh /github/workspace/*.pkg.tar.zst
