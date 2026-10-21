#!/usr/bin/env bash
# Gera docs/assets/banner.png (cabeçalho do README).
# Precisa de ImageMagick (magick) e do ícone em docs/assets/product_logo_256.png.
#
# Uso: bash docs/make-banner.sh
set -euo pipefail

A="$(cd "$(dirname "$0")/assets" && pwd)"
FONT_B=/usr/share/fonts/noto/NotoSans-Bold.ttf
FONT_R=/usr/share/fonts/noto/NotoSans-Regular.ttf
W=1280
H=480

magick -size ${W}x${H} xc:'#0d1520' /tmp/thorium-banner.png
magick -size 1280x1280 radial-gradient:'#1A73E828-#1A73E800' \
	-gravity center -crop ${W}x${H}+0+0 +repage /tmp/thorium-glow.png
magick /tmp/thorium-banner.png /tmp/thorium-glow.png \
	-compose over -composite /tmp/thorium-banner.png

magick "$A/product_logo_256.png" -resize 210x210 \
	\( +clone -background '#000000' -shadow 70x10+0+12 \) \
	+swap -background none -layers merge +repage /tmp/thorium-icon.png
magick /tmp/thorium-banner.png /tmp/thorium-icon.png \
	-gravity west -geometry +115-13 -composite /tmp/thorium-banner.png

magick /tmp/thorium-banner.png \
	-fill white -font "$FONT_B" -pointsize 104 -gravity northwest \
	-annotate +352+95 'Thorium' \
	-fill '#8ab4f8' -font "$FONT_R" -pointsize 32 -gravity northwest \
	-annotate +358+190 'Chromium faster  ·  instalador para Arch / CachyOS' \
	/tmp/thorium-banner.png

x=358
y=270
for label in AVX512 AVX2 AVX SSE4 SSE3; do
	len=${#label}
	w=$(( len * 21 + 54 ))
	magick /tmp/thorium-banner.png \
		-fill '#132033' -stroke '#1A73E8' -strokewidth 2 \
		-draw "roundrectangle ${x},${y},$((x+w)),$((y+62)) 14,14" \
		-fill '#dbeafe' -font "$FONT_R" -pointsize 28 -gravity northwest \
		-annotate +$((x+26))+$((y+15)) "$label" /tmp/thorium-banner.png
	x=$(( x + w + 18 ))
done

cp /tmp/thorium-banner.png "$A/banner.png"
rm -f /tmp/thorium-banner.png /tmp/thorium-glow.png /tmp/thorium-icon.png
echo "$A/banner.png"
