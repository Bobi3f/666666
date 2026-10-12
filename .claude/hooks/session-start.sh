#!/bin/bash
# Подготовка облачной сессии Claude Code: ставит Godot 4.5.1 (если нет)
# и импортирует проект, чтобы сразу работали тесты: tests/run_all.sh
set -euo pipefail

# Только в облаке (Claude Code on the web); на своём компьютере — ничего
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
	exit 0
fi

VER="4.5.1"
BIN="$HOME/.local/bin/godot"
HAVE=""
if [ -x "$BIN" ]; then
	HAVE="$("$BIN" --version 2>/dev/null || true)"
fi
# Уже стоит нужная версия (кэш контейнера) — не качаем заново
if [[ "$HAVE" != "$VER".* ]]; then
	mkdir -p "$(dirname "$BIN")"
	tmp="$(mktemp -d)"
	curl -fsSL --retry 3 -o "$tmp/godot.zip" \
		"https://github.com/godotengine/godot/releases/download/$VER-stable/Godot_v$VER-stable_linux.x86_64.zip"
	unzip -q "$tmp/godot.zip" -d "$tmp"
	mv "$tmp/Godot_v$VER-stable_linux.x86_64" "$BIN"
	chmod +x "$BIN"
	rm -rf "$tmp"
fi

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
	echo "export GODOT=\"$BIN\"" >> "$CLAUDE_ENV_FILE"
	echo "export PATH=\"$HOME/.local/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

# Импорт: кэш .godot с классами и ресурсами — без него скрипты тестов
# не находят class_name. Ошибки импорта не мешают старту сессии.
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"
timeout 300 "$BIN" --headless --path . --import > /dev/null 2>&1 || true
