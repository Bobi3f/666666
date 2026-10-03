#!/bin/bash
# Настройки импорта для textures/ и sounds/ (после tools/bake_assets.gd):
# мипмапы у текстур, что видны в 3D под углом; петли у звуков, что играют
# по кругу (мотор, дождь, музыка). Потом Godot переимпортирует файлы.
set -eu
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$(command -v godot || echo godot)}"

# Первый импорт создаёт .import-файлы с настройками по умолчанию
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true

for f in textures/interior/*.png textures/world/*.png textures/sky/clouds.png textures/vehicles/dial.png; do
	sed -i 's/^mipmaps\/generate=.*/mipmaps\/generate=true/' "$f.import"
done
for f in textures/*/*.png; do
	sed -i 's/^detect_3d\/compress_to=.*/detect_3d\/compress_to=0/' "$f.import"
done
LOOPS="effects/engine effects/crickets effects/rain effects/skid effects/gravel effects/grass music/music music/disco music/radio_0 music/radio_1"
for n in $LOOPS; do
	sed -i 's/^edit\/loop_mode=.*/edit\/loop_mode=2/' "sounds/$n.wav.import"
done
# Сжатие QOA — в 3–4 раза меньше, распаковка на лету почти бесплатная
for f in sounds/*/*.wav; do
	sed -i 's/^compress\/mode=.*/compress\/mode=2/' "$f.import"
done
# Убираем старые импортированные копии — Godot сделает новые по настройкам
for f in textures/*/*.png sounds/*/*.wav; do
	rm -f .godot/imported/"$(basename "$f")"-*
done
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
echo "Импорт готов"
