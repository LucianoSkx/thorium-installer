# Thorium Browser — instalador (Arch / CachyOS)

Instalador bash que baixa o `.deb` adequado ao CPU (auto-detect AVX/SSE) da
release [gz83/thorium](https://github.com/gz83/thorium/releases) e instala em
`/opt/thorium-browser` (ou `~/.local` no modo usuário).

## Instalar

```bash
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/thorium-installer/main/install.sh | bash
```

Ou salve e execute:

```bash
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/thorium-installer/main/install.sh -o install.sh
sudo bash install.sh
```

## Desinstalar

```bash
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/thorium-installer/main/uninstall.sh | bash
```

## Uso (flags)

```bash
sudo bash install.sh            # sistema (padrão)
bash install.sh --user          # só para você, em ~/.local
bash install.sh --uninstall     # remover
bash install.sh --version 156.0.8078.28
bash install.sh --local arquivo.deb
```

## Requisitos
- Arch Linux ou derivado (CachyOS, Manjaro, EndeavourOS, ...)
- `bsdtar`, `curl` (ou `wget`), `pacman`
