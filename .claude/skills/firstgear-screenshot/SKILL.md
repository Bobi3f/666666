---
name: firstgear-screenshot
description: Снять скриншоты FIRST GEAR из нужной точки мира (город, деревня, салон машины, телефонный интерфейс, ночь, зима) — чтобы своими глазами проверить новую модель, вид, интерфейс или показать пользователю результат. Используй после визуальных правок.
---

# Скриншоты FIRST GEAR

Снимки делает Godot под виртуальным экраном (xvfb, OpenGL Compatibility —
как на телефоне и в браузере):

```bash
SHOTS=/tmp/shots mkdir -p /tmp/shots
SHOTS=/tmp/shots xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" \
  --rendering-driver opengl3 --path . --script tests/shots_seasons.gd -- --no-menu
```

Готовые сценарии в `tests/shots_*.gd` (времена года, небо, трактор, ярмарка,
салон машины, прохожие, пыль, вода). Для телефона добавь `--touch` и размер
экрана телефона, например `-screen 0 1600x740x24` и `root.size = Vector2i(1600, 740)`
в начале скрипта.

Свой сценарий — по образцу: загрузить `res://scenes/World.tscn`, закрыть меню
и обучение, выставить `TimeManager.minutes` / `TimeManager.day`, погоду
`WeatherManager.set_kind(...)`, поставить свою `Camera3D` (`far = 700`,
`current = true`, `look_at(...)`), подождать ~12 кадров и сохранить
`root.get_viewport().get_texture().get_image().save_png(...)`. HUD прячется
через `hud.gd` → `visible = false`.

Смотри снимки инструментом чтения файлов, а пользователю отправляй лучшие.
Проверяй: ничего не перекрывает кнопки телефона (особенно на низком экране
~460 точек), модели не проваливаются в землю, надписи читаются.
