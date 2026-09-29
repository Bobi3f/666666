---
name: firstgear-release
description: Собрать и выложить FIRST GEAR — веб-версию на сайт https://bobi3f.github.io/666666/ (ветка gh-pages), Windows-zip и Android-APK в releases/. Используй после законченной и проверенной тестами правки, когда пользователь должен увидеть изменения на телефоне или в браузере.
---

# Сборка и выкладка FIRST GEAR

Сначала тесты: навык `firstgear-test` (`tests/run_all.sh`). Выкладываем только
зелёное.

## 1. Шаблоны экспорта (один раз на сессию, ~1 ГБ)

```bash
TPL=~/.local/share/godot/export_templates/4.5.1.stable
if [ ! -f $TPL/web_nothreads_release.zip ]; then
  mkdir -p $TPL && cd /tmp
  curl -fL -o tpl.tpz https://github.com/godotengine/godot/releases/download/4.5.1-stable/Godot_v4.5.1-stable_export_templates.tpz
  unzip -q -o tpl.tpz -d tpl && cp tpl/templates/* $TPL/ && rm -rf tpl tpl.tpz
fi
```

## 2. Сборка

```bash
tools/build_release.sh web   # только сайт (быстро, ~20 с)
tools/build_release.sh       # сайт + Windows (+ Android, если есть SDK и ключ)
```

Скрипт собирает из чистой копии проекта и кладёт результат в `docs/`
(index.js, index.wasm, index.pck, аудио-ворклеты; размер `index.pck` сам
вписывает в `docs/index.html`) и в `releases/`. Страница `docs/index.html`
своя, не из Godot — её не перезаписывай экспортом.

Android: нужен Android SDK (`ANDROID_SDK`, прописан в настройках редактора
Godot `export/android/android_sdk_path`), JDK 17+ и ключ
`ANDROID_KEYSTORE` / `ANDROID_KEYSTORE_USER` / `ANDROID_KEYSTORE_PASS`.
Ключа в репозитории нет и быть не должно. Без них APK пропускается.

## 3. Проверка в браузере

Локально: `cd docs && python3 -m http.server 8770` и открыть через Playwright
(Chromium предустановлен) в режиме телефона: `devices['Pixel 7 landscape']`,
нажать «Играть», подождать, снять скриншот. Должны быть: HUD, мини-карта,
джойстик, персонаж со спины, без `PAGEERROR` в консоли. Кнопки меню могли
сдвинуться — тапай по видимым координатам.

## 4. Коммит и выкладка

```bash
git add -A scripts tests README.md          # код — отдельным коммитом
git add -A docs releases                     # сборка — вторым коммитом
git push -u origin <ветка разработки>
tools/publish_pages.sh                       # docs/ → worktree gh-pages
cd /tmp/firstgear-pages && git commit -m "Update web build: ..." && git push origin gh-pages
```

Публичный сайт обновляется через 1–2 минуты после пуша в gh-pages. Пуш в
gh-pages пользователь разрешил (сайт для проверки с телефона).

Сообщения коммитов — по-русски, первая строка о том, что изменилось для
игрока; в конце — строки подписи, которые требует среда.
