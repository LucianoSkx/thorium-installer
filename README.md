<div align="center">

![banner](docs/assets/banner-v2.png)

# Thorium Browser — instalador para Arch / CachyOS

**Chromium mais rápido, com detecção automática de AVX e instalação nos mesmos
caminhos do AUR.**

[![licença](https://img.shields.io/badge/licença-MIT-blue.svg)](LICENSE)
[![shell](https://img.shields.io/badge/shell-bash-4E89B7.svg)](install.sh)
[![arch](https://img.shields.io/badge/arch-x86_64%20|%20aarch64-1793D1.svg)]()
[![release](https://img.shields.io/badge/release-M156%20Beta-1A73E8.svg)](https://github.com/gz83/thorium/releases)

[⬇ Instalar](#instalar) · [🗑 Desinstalar](#desinstalar) · [⚙️ Opções](#opções) · [📁 O que é instalado](#o-que-é-instalado)

</div>

---

## O que é

O [Thorium](https://github.com/Alex313031/thorium) é um fork do Chromium focado em
performance, empacotado com patchsets próprios e **uBlock Origin embutido** (instalação
offline em perfis novos).

O instalador baixa o pacote oficial da release
[gz83/thorium](https://github.com/gz83/thorium/releases), escolhe a variante correta
para o seu processador e instala **nos mesmos diretórios do pacote AUR** — de modo que
`/opt/thorium-browser`, `/usr/bin/thorium-browser` e `/usr/lib/thorium-browser`
ficam idênticos.

## ✨ Recursos

- 🧠 **Auto-detect de CPU** — AVX512 / AVX2 / AVX / SSE4 / SSE3, com interseção de
  flags entre todos os núcleos (não só o primeiro core).
- 📦 **Layout idêntico ao AUR** — mesmos caminhos, metainfo, check de CPU e flags.
- 🧹 **Limpeza automática** — remove cron, docs e menus que vêm no `.deb`.
- 🔐 **Checksum implícito** — o pacote vem do release oficial do upstream.
- 🧑 **Dois modos** — sistema (`/opt`, com sudo) ou usuário (`~/.local`, sem senha).
- 🧵 **Sem dependência de AUR** — não precisa de helper (`yay`, `paru`).

## 📥 Instalar

```bash
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/thorium-installer/main/install.sh | bash
```

<details>
<summary>Instalar a partir de um arquivo salvo (recomendado)</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/thorium-installer/main/install.sh -o install.sh
sudo bash install.sh
```
</details>

## 🗑 Desinstalar

```bash
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/thorium-installer/main/uninstall.sh | bash
```

> O desinstalador remove o app, o atalho e os ícones. **Suas configurações e perfil
> (`~/.config/thorium`, `~/.cache/thorium`) são preservados.**

## ⚙️ Opções

| Flag | O que faz |
|---|---|
| `--system` | instala no sistema em `/opt/thorium-browser` (padrão) |
| `--user` | instala só para você em `~/.local/opt/thorium-browser` (sem sudo) |
| `--version <ver>` | instala uma versão específica (ex: `156.0.8078.28`) |
| `--local <deb>` | instala a partir de um `.deb` já baixado (offline) |
| `--uninstall` | remove o Thorium |
| `-y`, `--yes` | não pergunta confirmação |
| `-h`, `--help` | mostra a ajuda |

## 📁 O que é instalado

| Caminho | Conteúdo |
|---|---|
| `/opt/thorium-browser/` | o navegador (binários, bibliotecas, Widevine) |
| `/usr/bin/thorium-browser` | launcher (lê `~/.config/thorium-flags.conf`) |
| `/usr/lib/thorium-browser/check-cpu-support` | verificação de compatibilidade da CPU |
| `/usr/share/applications/thorium-browser.desktop` | atalho do menu |
| `/usr/share/icons/hicolor/256x256/apps/thorium-browser.png` | ícone |
| `/usr/share/metainfo/org.chromium.Thorium.metainfo.xml` | metadados AppStream |

No modo `--user` os mesmos arquivos vão para `~/.local/…`.

## 🧩 Flags extras

Crie `~/.config/thorium-flags.conf` (uma flag por linha):

```
--disable-thorium-icons
--enable-features=UseOzonePlatform
```

## 🧰 Requisitos

- Arch Linux ou derivado (CachyOS, Manjaro, EndeavourOS, Garuda, Artix…)
- `bash`, `bsdtar`, `curl` (ou `wget`), `pacman`

## 📄 Licença

MIT. O Thorium é um projeto independente — veja
[github.com/Alex313031/thorium](https://github.com/Alex313031/thorium).

---

<div align="center">
<sub>Feito para a comunidade Arch · Releases do Chromium por <a href="https://github.com/gz83/thorium/releases">gz83/thorium</a></sub>
</div>
