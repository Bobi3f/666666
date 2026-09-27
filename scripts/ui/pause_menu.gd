extends CanvasLayer
## Главное меню при запуске и пауза по Esc (на телефоне — кнопка «Меню»,
## на геймпаде — Start).
##
## Три страницы: главная (играть, сохранить, загрузить, новая игра),
## «Настройки» (камера, громкость, детализация, коробка) и «Управление»
## (клавиатура, телефон или геймпад — что сейчас в руках). «Новая игра» при
## существующем сохранении сначала переспрашивает.
##
## Пока меню открыто, игра стоит на паузе. Для автотестов меню при запуске
## можно пропустить: godot ... -- --no-menu

## Главное меню показываем один раз за запуск, не после «Новой игры».
static var _started := false

const AMBER := Color(0.95, 0.7, 0.24)
const CREAM := Color(0.94, 0.9, 0.81)

var _panel: PanelContainer
var _title: Label
var _sub: Label
var _resume: Button
var _continue: Button
var _save: Button
var _new: Button
var _load: Button
var _main_mode := false
var _scroll: ScrollContainer
var _pages := {}  # имя → VBoxContainer
var _page := "main"
var _controls_text: RichTextLabel
var _back: Button


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	get_viewport().size_changed.connect(_fit_height)
	if not _started and not "--no-menu" in OS.get_cmdline_user_args():
		_open(true)
	else:
		_started = true
		GameManager.in_game = true
		_panel.visible = false


# --- Сборка ------------------------------------------------------------------

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.06, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.12, 0.13, 0.95)
	style.border_color = Color(0.3, 0.32, 0.34)
	style.set_border_width_all(1)
	style.set_content_margin_all(26)
	style.set_corner_radius_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	# Затемнение видно только вместе с панелью
	_panel.visibility_changed.connect(func() -> void: dim.visible = _panel.visible)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	_panel.add_child(outer)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 38)
	_title.add_theme_color_override("font_color", AMBER)
	outer.add_child(_title)
	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.modulate = Color(1, 1, 1, 0.6)
	outer.add_child(_sub)
	# На низком экране (телефон) страница не влезает — прокручиваем
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(pages)
	for pn in ["main", "settings", "controls", "confirm"]:
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 10)
		page.custom_minimum_size = Vector2(400, 0)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pages.add_child(page)
		_pages[pn] = page
	# «Назад» — под прокруткой, чтобы на длинной странице не искать его внизу
	_back = _button(outer, "Назад", func() -> void: _show("main"), true)
	_build_main(_pages.main)
	_build_settings(_pages.settings)
	_build_controls(_pages.controls)
	_build_confirm(_pages.confirm)


## Кнопки в цветах игры: тёмные, при наведении и фокусе — янтарная рамка.
func _theme() -> Theme:
	var t := Theme.new()
	var touch := GameManager.touch_mode
	t.default_font_size = 19 if touch else 18
	var mk := func(bg: Color, border: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = bg
		s.border_color = border
		s.set_border_width_all(2)
		s.set_corner_radius_all(8)
		s.content_margin_left = 16
		s.content_margin_right = 16
		s.content_margin_top = 10
		s.content_margin_bottom = 10
		return s
	t.set_stylebox("normal", "Button", mk.call(Color(0.18, 0.19, 0.21), Color(0.18, 0.19, 0.21)))
	t.set_stylebox("hover", "Button", mk.call(Color(0.23, 0.24, 0.26), AMBER.darkened(0.3)))
	t.set_stylebox("pressed", "Button", mk.call(AMBER.darkened(0.45), AMBER))
	t.set_stylebox("focus", "Button", mk.call(Color(0, 0, 0, 0), AMBER))
	t.set_stylebox("disabled", "Button", mk.call(Color(0.14, 0.14, 0.15), Color(0.14, 0.14, 0.15)))
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_color", "Label", CREAM)
	return t


func _build_main(box: VBoxContainer) -> void:
	_resume = _button(box, "Продолжить", _close, true)
	_continue = _button(box, "Продолжить с сохранения", func() -> void:
		_close()
		SaveManager.load_game(), true)
	_save = _button(box, "Сохранить" if GameManager.touch_mode else "Сохранить (F5)", func() -> void:
		SaveManager.save_game()
		_refresh())
	_load = _button(box, "Загрузить" if GameManager.touch_mode else "Загрузить (F9)", func() -> void:
		_close()
		SaveManager.load_game())
	_new = _button(box, "Новая игра", func() -> void:
		# Есть что терять — переспросим
		if SaveManager.has_save() or not _main_mode:
			_show("confirm")
		else:
			_new_game())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for b in [_button(row, "Настройки", func() -> void: _show("settings")),
			_button(row, "Управление", func() -> void: _show("controls"))]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# В браузере игра не может закрыть вкладку — кнопки выхода там нет
	if not OS.has_feature("web"):
		_button(box, "Выйти из игры", func() -> void:
			SaveManager.autosave()
			get_tree().quit())


func _build_settings(box: VBoxContainer) -> void:
	_slider(box, "Чувствительность камеры" if GameManager.touch_mode else "Чувствительность мыши",
		0.2, 3.0, SettingsManager.mouse_sens, SettingsManager.set_mouse_sens)
	_slider(box, "Громкость", 0.0, 1.0, SettingsManager.volume, SettingsManager.set_volume)
	var detail_label := Label.new()
	detail_label.text = "Детализация"
	box.add_child(detail_label)
	var detail := HBoxContainer.new()
	detail.add_theme_constant_override("separation", 6)
	box.add_child(detail)
	var detail_buttons: Array[Button] = []
	var group := ButtonGroup.new()
	for i in 3:
		var b := Button.new()
		b.text = ["Низкая", "Средняя", "Высокая"][i]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = SettingsManager.detail == i
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, _btn_h())
		b.pressed.connect(func() -> void:
			SoundLibrary.play("click", -6.0)
			SettingsManager.set_detail(i))
		detail.add_child(b)
		detail_buttons.append(b)
	var hint := Label.new()
	hint.text = "Низкая — быстрее всего, для телефона. Высокая — трава и тени."
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.add_theme_font_size_override("font_size", 14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(380, 0)
	box.add_child(hint)
	# На телефоне кнопок сцепления и передач нет — там всегда автомат
	if not GameManager.touch_mode:
		var gearbox := CheckButton.new()
		gearbox.text = "Автоматическая коробка передач (T)"
		gearbox.button_pressed = SettingsManager.auto_gearbox
		gearbox.toggled.connect(SettingsManager.set_auto_gearbox)
		# T в машине тоже переключает — держим галочку в согласии
		SettingsManager.changed.connect(func() -> void: gearbox.set_pressed_no_signal(SettingsManager.auto_gearbox))
		box.add_child(gearbox)


func _build_controls(box: VBoxContainer) -> void:
	_controls_text = RichTextLabel.new()
	_controls_text.bbcode_enabled = true
	_controls_text.fit_content = true
	_controls_text.scroll_active = false
	_controls_text.custom_minimum_size = Vector2(560, 0)
	_controls_text.add_theme_font_size_override("normal_font_size", 16)
	_controls_text.add_theme_font_size_override("bold_font_size", 17)
	box.add_child(_controls_text)


func _build_confirm(box: VBoxContainer) -> void:
	var q := Label.new()
	q.text = "Начать заново?\nДеньги, дом и задания начнутся с нуля.\nСохранение перезапишется при следующей записи."
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(q)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var no := _button(row, "Нет, назад", func() -> void: _show("main"), true)
	var yes := _button(row, "Да, новая игра", _new_game)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _btn_h() -> float:
	return 54.0 if GameManager.touch_mode else 44.0


func _button(box: Container, text: String, fn: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, _btn_h())
	if accent:
		b.add_theme_color_override("font_color", AMBER.lightened(0.2))
	b.pressed.connect(func() -> void:
		SoundLibrary.play("click", -6.0)
		fn.call())
	box.add_child(b)
	return b


func _slider(box: VBoxContainer, text: String, lo: float, hi: float, value: float, fn: Callable) -> void:
	var label := Label.new()
	box.add_child(label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(0, 36 if GameManager.touch_mode else 24)
	var set_label := func(v: float) -> void: label.text = "%s: %d%%" % [text, int(round(v * 100.0))]
	set_label.call(value)
	s.value_changed.connect(func(v: float) -> void:
		set_label.call(v)
		fn.call(v))
	box.add_child(s)


# --- Текст управления ---------------------------------------------------------

func _controls_bbcode() -> String:
	var h := func(t: String) -> String: return "[b][color=#f2b33d]%s[/color][/b]\n" % t
	var t := ""
	if GameManager.touch_mode:
		t += h.call("ПЕШКОМ")
		t += "  Джойстик слева — идти: чуть отклонил — шагом, до края — бегом\n"
		t += "  Палец по правой половине экрана — осмотреться\n"
		t += "  «E» — действие: сесть, поговорить, купить, подсечь рыбу\n"
		t += "  «Прыжок», «Присесть», «Еда» — съесть из запаса\n"
		t += h.call("В МАШИНЕ И НА МОТОЦИКЛЕ")
		t += "  Слева руль: «Влево» и «Вправо». Справа «Газ» и «Тормоз»\n"
		t += "  Держать «Тормоз» стоя — задний ход. «Ручник» на скорости — занос\n"
		t += "  «Вид» — из салона или сзади, «Сигнал», «Выйти»\n"
		t += "  Газ и руль можно жать одновременно двумя пальцами\n"
	else:
		t += h.call("ПЕШКОМ")
		t += "  W A S D — идти, Shift — бежать, Пробел — прыжок\n"
		t += "  C — присесть / встать (Ctrl — держать), мышь или стрелки — осмотреться\n"
		t += "  E — действие, Q — съесть еду из запаса\n"
		t += h.call("В МАШИНЕ И НА МОТОЦИКЛЕ")
		t += "  W — газ, S — тормоз (стоя держать — назад), A D — руль\n"
		t += "  Пробел — ручник, H — сигнал, L — фары, V — вид, E — выйти\n"
		t += "  T — автомат / механика. Механика: Shift — сцепление, R — зажигание, ] [ — передачи\n"
		t += h.call("ГЕЙМПАД")
		t += "  Левый стик — идти / руль, правый — камера. RT — газ, LT — тормоз\n"
		t += "  A — прыжок / ручник, X — действие / выйти, B — присесть / вид, Y — еда / сигнал\n"
		t += "  Start — меню, Back — карта, крестовина вверх — журнал\n"
	t += h.call("ИГРА")
	t += "  Задание — слева вверху. У кого просьба — в подсказке «(!)»\n"
	t += "  Рыбалка: закинь, жди, пока поплавок нырнёт, — и сразу подсекай\n"
	t += "  Развоз хлеба: вези аккуратно — битый хлеб вычтут, быстро — премия\n"
	t += "  Не забывай есть и спать — иначе обморок и потеря денег\n"
	if not GameManager.touch_mode:
		t += "  M — карта, J — журнал, F5 — сохранить, F9 — загрузить, F1 — подсказка\n"
	else:
		t += "  «Карта» и «Журнал» — справа вверху\n"
	return t


# --- Открыть и закрыть ----------------------------------------------------------

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_ESCAPE:
		if _panel.visible and _page != "main":
			_show("main")
		elif _panel.visible and not _main_mode:
			_close()
		elif not _panel.visible:
			_open(false)
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _panel.visible


## Свернули игру или ушли на другую вкладку — ставим на паузу, чтобы
## в фоне не тратились сытость и время. Вернулся — нажми «Продолжить».
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if _panel and not _panel.visible and GameManager.in_game and not get_tree().paused:
			_open(false)


func _open(main: bool) -> void:
	_main_mode = main
	_title.text = "FIRST GEAR" if main else "Пауза"
	_sub.text = "Жизнь в Каменке на первой передаче" if main else "%s   ·   %d грн" % [TimeManager.clock_text(), GameManager.money]
	_panel.visible = true
	_show("main")
	# Размер окна в браузере и на телефоне устанавливается чуть позже — подгоняем ещё раз
	_fit_height.call_deferred()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Показать страницу меню; первая кнопка получает фокус — для геймпада и клавиатуры.
func _show(page: String) -> void:
	_page = page
	if page == "main":
		_refresh()
	if page == "controls":
		_controls_text.text = _controls_bbcode()
	for pn in _pages:
		(_pages[pn] as Control).visible = pn == page
	_back.visible = page == "settings" or page == "controls"
	_fit_height()
	_scroll.scroll_vertical = 0
	_focus_first.call_deferred(_back if _back.visible else _pages[page])


func _focus_first(node: Node) -> void:
	if not _panel.visible or GameManager.touch_mode:
		return
	if node is BaseButton:
		(node as BaseButton).grab_focus()
		return
	for c in node.find_children("*", "BaseButton", true, false):
		var b := c as BaseButton
		if b.is_visible_in_tree() and not b.disabled:
			b.grab_focus()
			return


## Высота меню — по содержимому, но не выше экрана.
func _fit_height() -> void:
	var page := _pages[_page] as Control
	var need := page.get_combined_minimum_size()
	var room := get_viewport().get_visible_rect().size.y - (240.0 if _back.visible else 170.0)
	_scroll.custom_minimum_size = Vector2(need.x + 12.0, minf(need.y, maxf(room, 160.0)))


func _refresh() -> void:
	var has := SaveManager.has_save()
	_resume.text = "Начать" if _main_mode and not has else "Продолжить"
	_continue.visible = _main_mode and has
	_resume.visible = not (_main_mode and has)
	_new.visible = not (_main_mode and not has)
	_save.visible = not _main_mode
	_load.visible = not _main_mode and has


func _close() -> void:
	_started = true
	GameManager.in_game = true
	_main_mode = false
	_panel.visible = false
	get_tree().paused = false
	if not GameManager.touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Новая игра: сбросить деньги, время, потребности, погоду и цели, мир — заново.
func _new_game() -> void:
	_started = true
	GameManager.in_game = true
	GameManager.load_state({})
	TimeManager.load_state({})
	NeedsManager.load_state({})
	WeatherManager.load_state({})
	Progress.load_state({})
	Progress.tutorial_done = false
	QuestManager.reset()
	get_tree().paused = false
	if not GameManager.touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()
