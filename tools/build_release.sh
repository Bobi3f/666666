#!/bin/bash
# Сборка FIRST GEAR: веб-версия (docs/ — сайт на GitHub Pages), Windows
# (releases/FirstGear-Windows.zip) и, если есть Android SDK и ключ, APK
# (releases/FirstGear-Android.apk). Ничего не коммитит и не пушит.
#
#   tools/build_release.sh            — всё, что получится собрать
#   tools/build_release.sh web        — только веб
#
# Нужны шаблоны экспорта Godot 4.5.1 в
# ~/.local/share/godot/export_templates/4.5.1.stable (см. .claude/skills/firstgear-release).
# Android — если заданы ANDROID_SDK (путь к SDK) и ANDROID_KEYSTORE
# (+ ANDROID_KEYSTORE_USER / ANDROID_KEYSTORE_PASS), иначе пропускается.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
GODOT="${GODOT:-$(command -v godot || echo "$HOME/.local/bin/godot")}"
ONLY="${1:-all}"
TPL="$HOME/.local/share/godot/export_templates/4.5.1.stable"
if [ ! -f "$TPL/web_nothreads_release.zip" ]; then
	echo "Нет шаблонов экспорта в $TPL — см. .claude/skills/firstgear-release/SKILL.md" >&2
	exit 2
fi

# Собираем из чистой копии: без .git, docs и releases (там тяжёлые сборки)
WORK="$(mktemp -d /tmp/firstgear-build.XXXX)"
tar --exclude=.git --exclude=docs --exclude=releases --exclude=.godot -cf - . | (cd "$WORK" && tar -xf -)
cd "$WORK"
mkdir -p build/web build/win build/android
touch build/.gdignore
timeout 300 "$GODOT" --headless --import > /dev/null 2>&1 || true

echo "== Web"
timeout 300 "$GODOT" --headless --export-release "Web" build/web/index.html 2>&1 | grep -iE "error" || true
test -s build/web/index.pck
cp build/web/index.js build/web/index.wasm build/web/index.pck build/web/index.audio*.js "$ROOT/docs/"
PCK=$(stat -c %s build/web/index.pck)
# Страница docs/index.html своя: размер мира прописан в ней для полоски загрузки
sed -i -E "s/\"index.pck\": [0-9]+/\"index.pck\": $PCK/" "$ROOT/docs/index.html"
echo "   мир: $PCK байт"

if [ "$ONLY" = "all" ]; then
	echo "== Windows"
	timeout 300 "$GODOT" --headless --export-release "Windows Desktop" build/win/FirstGear.exe 2>&1 | grep -iE "error" || true
	if [ -s build/win/FirstGear.exe ]; then
		# Рядом с игрой: окно с ошибками (console.exe), запуск через DirectX и инструкция
		cp "$ROOT/tools/windows/FirstGear-DirectX.bat" "$ROOT/tools/windows/README-RU.txt" "$ROOT/tools/windows/LICENSE-Godot.txt" build/win/
		(cd build/win && rm -f "$ROOT/releases/FirstGear-Windows.zip" && zip -q -9 "$ROOT/releases/FirstGear-Windows.zip" ./*)
	fi
	if [ -n "${ANDROID_SDK:-}" ] && [ -n "${ANDROID_KEYSTORE:-}" ]; then
		echo "== Android"
		GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$ANDROID_KEYSTORE" \
		GODOT_ANDROID_KEYSTORE_RELEASE_USER="${ANDROID_KEYSTORE_USER:-firstgear}" \
		GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${ANDROID_KEYSTORE_PASS:-}" \
			timeout 400 "$GODOT" --headless --export-release "Android" build/android/FirstGear-Android.apk 2>&1 | grep -iE "error" || true
		[ -s build/android/FirstGear-Android.apk ] && cp build/android/FirstGear-Android.apk "$ROOT/releases/"
	else
		echo "== Android пропущен (нет ANDROID_SDK / ANDROID_KEYSTORE)"
	fi
fi
rm -rf "$WORK"
echo "Готово: docs/ и releases/ обновлены"
