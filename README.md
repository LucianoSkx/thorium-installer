# Thorium Browser — instalador (Arch / CachyOS)

Instalador bash que baixa o .deb adequado ao CPU (auto-detect AVX/SSE) da
release gz83/thorium e instala em /opt/thorium-browser (ou ~/.local no modo usuario).

## Uso

    sudo bash install.sh          # sistema
    bash install.sh --user        # so para voce
    bash install.sh --uninstall   # remover

## Requisitos
- Arch Linux ou derivado (CachyOS, Manjaro, EndeavourOS, ...)
- bsdtar, curl (ou wget), pacman
