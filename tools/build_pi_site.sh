#!/bin/bash
# Сайт для Cloudflare Pages: игра (docs/) + сервер оплаты Pi (functions/).
# Собирает server/cloudflare/public; если рядом лежит validation-key.txt
# (ключ проверки домена из Pi Developer Portal) — кладёт его в корень сайта.
# Потом:  cd server/cloudflare && npx wrangler pages deploy public --project-name firstgear
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=server/cloudflare/public
rm -rf "$OUT"
mkdir -p "$OUT"
cp -a docs/. "$OUT/"
rm -f "$OUT/.gdignore"
if [ -f server/cloudflare/validation-key.txt ]; then
	cp server/cloudflare/validation-key.txt "$OUT/validation-key.txt"
	echo "validation-key.txt — в корне сайта"
else
	echo "Нет server/cloudflare/validation-key.txt — домен в Pi Developer Portal не подтвердится"
fi
echo "Готово: $OUT ($(du -sh "$OUT" | cut -f1))"
echo "Дальше: cd server/cloudflare && npx wrangler pages deploy public --project-name firstgear"
