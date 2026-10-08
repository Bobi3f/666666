#!/bin/bash
# Архив веб-версии для itch.io: та же сборка, что на сайте (docs/), но без
# Pi Network и без ссылки на GitHub — Windows и Android лежат на самой
# странице itch.io. Сначала tools/build_release.sh, потом этот скрипт.
#   → releases/itch/FirstGear-Web-itch.zip (index.html в корне архива)
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$PWD/releases/itch/FirstGear-Web-itch.zip"
TMP="$(mktemp -d /tmp/firstgear-itch.XXXX)"
cp docs/index.html docs/index.js docs/index.wasm docs/index.pck docs/index.audio*.js docs/index.icon.png "$TMP/"
cp tools/windows/LICENSE-Godot.txt "$TMP/"
# Pi работает только в Pi Browser и со своим сервером — на itch.io не нужен
sed -i '/<script src="pi.js"><\/script>/d' "$TMP/index.html"
sed -i 's|Версия для Windows — <a [^>]*>FirstGear-Windows.zip</a>.|Версия для Windows и Android — ниже на этой странице.|' "$TMP/index.html"
# По-английски страница вставляла ту же ссылку — теперь её нет
sed -i '/const a = document.querySelector(".note a").outerHTML;/d' "$TMP/index.html"
sed -i 's|Windows version — " + a + ".";|Windows and Android versions — below on this page.";|' "$TMP/index.html"
sed -i '/const ua = document.querySelector(".note a").outerHTML;/d' "$TMP/index.html"
sed -i 's|Версія для Windows — " + ua + ".";|Версії для Windows і Android — нижче на цій сторінці.";|' "$TMP/index.html"
grep -q 'FirstGear-Windows.zip\|outerHTML' "$TMP/index.html" && { echo "ссылка на GitHub осталась в index.html" >&2; exit 1; }
grep -q 'pi.js' "$TMP/index.html" && { echo "pi.js остался в index.html" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
(cd "$TMP" && zip -q -9 -r "$OUT" .)
rm -rf "$TMP"
ls -la "$OUT"
