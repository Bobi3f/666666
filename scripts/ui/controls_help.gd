extends CanvasLayer
## F1 — список управления поверх игры.

const TEXT := """УПРАВЛЕНИЕ  (F1 — закрыть)

ПЕШКОМ
  W A S D — идти        Shift — бежать       Пробел — прыжок
  Мышь — осмотреться    E — действие         Q — съесть еду из запаса
  Esc — отпустить мышь (клик — снова захватить)

В МАШИНЕ
  W — газ   S — тормоз   A D — руль   Пробел — ручник
  Shift — СЦЕПЛЕНИЕ (держать = выжато)
  R — зажигание         ] / [ — передача выше / ниже
  E — выйти

КАК ТРОНУТЬСЯ
  1. Выжать сцепление (держать Shift) и завести (R)
  2. Не отпуская Shift, включить первую ( ] )
  3. Плавно отпустить Shift — машина поползёт сама
  4. Газ (W). Переключаться: Shift + ]

ИГРА
  F5 — сохранить        F9 — загрузить
  Работа — склад в городе, спать — кровать дома, еда — ларёк у дороги
"""

var _panel: PanelContainer


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.set_content_margin_all(24)
	style.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	var label := Label.new()
	label.text = TEXT
	label.add_theme_font_size_override("font_size", 17)
	_panel.add_child(label)
	_panel.visible = false
	add_child(_panel)
	# Центрируем после того, как панель узнает свой размер
	_panel.resized.connect(func() -> void:
		_panel.position = (_panel.get_viewport_rect().size - _panel.size) * 0.5)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F1:
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()
