<div align="center">

![banner](docs/assets/banner-v2.png)

# Thorium Browser — instalador para Arch / CachyOS

**O pacote oficial do AUR, compilado pelo GitHub Actions e instalado com `pacman -U`.**

[![licença](https://img.shields.io/badge/licença-MIT-blue.svg)](LICENSE)
[![shell](https://img.shields.io/badge/shell-bash-4E89B7.svg)](install.sh)
[![arch](https://img.shields.io/badge/arch-x86_64%20|%20aarch64-1793D1.svg)]()
[![release](https://img.shields.io/github/v/release/LucianoSkx/thorium-installer?label=release)](https://github.com/LucianoSkx/thorium-installer/releases)

[⬇ Instalar](#instalar) · [🗑 Desinstalar](#desinstalar) · [⚙️ Opções](#opções) · [🏗 Como funciona](#como-funciona)

</div>

---

## O que é

O [Thorium](https://github.com/Alex313031/thorium) é um fork do Chromium focado em
performance, com patchsets próprios e **uBlock Origin embutido**.

Este repositório **não reinventa a instalação**: o GitHub Actions clona o PKGBUILD do
AUR, compila com `makepkg` e publica o `.pkg.tar.zst`. O instalador só baixa o pacote
e roda `pacman -U` — o resultado é **byte a byte o mesmo que instalar pelo AUR**.

## 📥 Instalar

```bash
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/thorium-installer/main/install.sh | bash
```

O script detecta a variante de CPU, baixa o pacote certo e instala. Pede a senha do
`sudo` uma vez.

<details>
<summary>Instalar a partir de um arquivo salvo</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/thorium-installer/main/install.sh -o install.sh
sudo bash install.sh
```
</details>

## 🗑 Desinstalar

```bash
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/thorium-installer/main/uninstall.sh | bash
```

> Remove o pacote via `pacman -Rns`. **Seu perfil (`~/.config/thorium`) é preservado.**

## ⚙️ Opções

| Flag | O que faz |
|---|---|
| `--version <ver>` | usa uma release específica (ex: `v156.0.8078.28`) |
| `--stable` | instala a linha estável (138.0.7204.303) em vez da beta (156.0.8078.28) |
| `--local <pkg>` | instala a partir de um `.pkg.tar.zst` já baixado |
| `--uninstall` | remove o Thorium |
| `-h`, `--help` | mostra a ajuda |

## 📦 Variantes

O instalador escolhe pelo seu processador.

A linha **beta** é a 156.0.8078.28 — a mais recente do
[gz83/thorium](https://github.com/gz83/thorium/releases). A linha **estável** é a
138.0.7204.303, do upstream original.

| CPU | beta (156.0.8078.28) | estável (138.0.7204.303) |
|---|---|---|
| AVX-512 | `thorium-browser-beta-avx512` | — |
| AVX2 | `thorium-browser-beta-avx2` | `thorium-browser-avx2` |
| AVX | `thorium-browser-beta-avx` | `thorium-browser-avx` |
| SSE4 | `thorium-browser-beta-sse4` | — |
| SSE3 | `thorium-browser-beta-sse3` | `thorium-browser-sse3` |

## 🏗 Como funciona

1. **GitHub Actions** (`.github/workflows/build.yml`) roda em container Arch:
   clona o PKGBUILD do AUR e compila com `makepkg` → `.pkg.tar.zst`
2. O pacote vai para a [release](https://github.com/LucianoSkx/thorium-installer/releases)
3. `install.sh` baixa o `.pkg.tar.zst` da variante correta e roda `pacman -U`

Para recompilar, basta criar uma tag:

```bash
git tag v156.0.8078.28 && git push origin v156.0.8078.28
```

## 📄 Licença

MIT. O Thorium é um projeto independente — veja
[github.com/Alex313031/thorium](https://github.com/Alex313031/thorium).

---

<div align="center">
<sub>Feito para a comunidade Arch · PKGBUILD original do
<a href="https://aur.archlinux.org/packages?K=thorium-browser">AUR</a></sub>
</div>
