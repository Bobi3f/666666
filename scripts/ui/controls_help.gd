extends CanvasLayer
## F1 — список управления поверх игры.

const TEXT := """УПРАВЛЕНИЕ  (F1 — закрыть)

ПЕШКОМ
  W A S D — идти        Shift — бежать       Пробел — прыжок
  Ctrl — присесть (держать)    C — присесть / встать
  Мышь или стрелки — осмотреться
  E — действие / поговорить    Q — съесть еду из запаса
  M — карта    Esc — меню: пауза, настройки, сохранение

В МАШИНЕ И НА МОТОЦИКЛЕ
  A D — руль   Пробел — ручник (на скорости — занос)   H — сигнал
  L — фары (в темноте сами)   V — вид из салона / сзади   T — автомат / механика
  E — выйти

  АВТОМАТ (по умолчанию): W — газ, мотор заведётся сам
    S — тормоз; стоя на месте держать S — задний ход
  МЕХАНИКА: Shift — СЦЕПЛЕНИЕ (держать = выжато), R — зажигание,
    ] / [ — передача выше / ниже
    Тронуться: Shift + R, Shift + ], плавно отпустить Shift, газ W

  На асфальте держит дорогу, на траве и в грязи — скользит.
  Ява стоит через дорогу от дома: быстрее Жигулей, но без заднего хода,
  а на сильном ударе можно вылететь из седла.

ГДЕ ЧТО
  Цель — вверху экрана: копи на новый дом, прораб — у твоей калитки
  Работа: склад в городе (+600), колхоз у стогов (+400), развоз хлеба (+500)
  Еда: сельмаг у съезда, ларёк в городе   Сон: кровать дома
  Бензин: АЗС у трассы    Ремонт: СТО рядом с АЗС
  Автобус в город и обратно — с остановки у трассы, 15 грн
  Рыбалка — с мостков на пруду, рыбу сдать в сельмаг (60 грн)
  Свой огород — за домом: посадить картошку, через 3 дня выкопать

F5 — сохранить        F9 — загрузить
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
