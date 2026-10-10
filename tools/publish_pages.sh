#!/bin/bash
# Кладёт содержимое docs/ в ветку gh-pages (сайт https://bobi3f.github.io/666666/).
# Коммит и пуш — вручную по подсказке в конце (сообщение коммита с подписью).
set -euo pipefail
cd "$(dirname "$0")/.."
DIR="${PAGES_DIR:-/tmp/firstgear-pages}"
if [ ! -d "$DIR/.git" ] && [ ! -f "$DIR/.git" ]; then
	git fetch -q origin gh-pages
	git worktree add -f "$DIR" origin/gh-pages > /dev/null
	(cd "$DIR" && git checkout -q -B gh-pages origin/gh-pages)
else
	(cd "$DIR" && git fetch -q origin gh-pages && git reset -q --hard origin/gh-pages)
fi
find "$DIR" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a docs/. "$DIR/"
(cd "$DIR" && git add -A && git status --short | head)
echo "Дальше: cd $DIR && git commit -m '...' && git push origin gh-pages"
