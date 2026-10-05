class_name PhoneUI
extends CanvasLayer
## Телефон (P, на экране телефона — кнопка «Телефон»): старый айфон —
## чёрный корпус, круглая кнопка «Домой», на экране девять приложений:
## звонки, сообщения, музыка, фото, такси, эвакуатор, банк, погода, часы.
## Пока открыт — игра на паузе. Значки нарисованы кодом: в шрифте игры
## нет нужных символов, а в браузере телефона других шрифтов нет.

## [id, подпись, цвет значка]
const APPS := [
	["calls", "Звонки", Color(0.2, 0.7, 0.3)],
	["sms", "Сообщения", Color(0.25, 0.75, 0.35)],
	["music", "Музыка", Color(0.95, 0.45, 0.15)],
	["photo", "Фото", Color(0.45, 0.47, 0.5)],
	["taxi", "Такси", Color(0.98, 0.78, 0.1)],
	["tow", "Эвакуатор", Color(0.85, 0.3, 0.12)],
	["bank", "Банк", Color(0.12, 0.45, 0.32)],
	["weather", "Погода", Color(0.25, 0.55, 0.9)],
	["clock", "Часы", Color(0.12, 0.12, 0.13)],
]
const WEEKDAYS_FULL := ["воскресенье", "понедельник", "вторник", "среда", "четверг", "пятница", "суббота"]
## Такси: посадка и за метр пути; ночью (22–6) — вдвое
const TAXI_BASE := 30
const TAXI_PER_KM := 40.0
## Эвакуатор: вызов и за метр; заодно доливает бензина
const TOW_BASE := 200
const TOW_PER_KM := 100.0
const TOW_FUEL := 3.0
## Фото: где лежат и сколько хранить
const PHOTO_DIR := "user://photos"
const PHOTO_MAX := 24

var _frame: Control
var _screen: Control
var _home: GridContainer
var _page: VBoxContainer
var _page_title: Label
var _content: VBoxContainer
var _scroll: ScrollContainer
var _app := ""
var _was_paused := false
## Ответ на звонок / итог действия — крупно вверху страницы
var _note := ""


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("phone")
	_frame = Control.new()
	_frame.draw.connect(_draw_body)
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.gui_input.connect(_frame_input)
	add_child(_frame)
	_screen = Control.new()
	_screen.clip_contents = true
	_screen.draw.connect(_draw_status)
	_frame.add_child(_screen)
	_home = GridContainer.new()
	_home.columns = 3
	_screen.add_child(_home)
	for a in APPS:
		_home.add_child(_app_icon(a))
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 4)
	_screen.add_child(_page)
	var bar := HBoxContainer.new()
	_page.add_child(bar)
	var back := _btn("‹ Назад", Color(0.2, 0.2, 0.22))
	back.autowrap_mode = TextServer.AUTOWRAP_OFF
	back.custom_minimum_size = Vector2(76, 30)
	back.pressed.connect(func() -> void: show_app(""))
	bar.add_child(back)
	_page_title = Label.new()
	_page_title.add_theme_font_size_override("font_size", 15)
	_page_title.add_theme_color_override("font_color", Color.WHITE)
	_page_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_page_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_page_title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 5)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	_frame.visible = false
	get_viewport().size_changed.connect(_layout)


func is_open() -> bool:
	return _frame.visible


func toggle() -> void:
	if _frame.visible:
		close_phone()
	elif not get_tree().paused:
		open()


func open(app := "") -> void:
	_was_paused = get_tree().paused
	_frame.visible = true
	get_tree().paused = true
	SoundLibrary.play("click", -6.0)
	_layout()
	show_app(app)


func close_phone() -> void:
	if not _frame.visible:
		return
	_frame.visible = false
	get_tree().paused = _was_paused


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_P:
		toggle()
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_ESCAPE and _frame.visible:
		if _app.is_empty():
			close_phone()
		else:
			show_app("")
		get_viewport().set_input_as_handled()


## Корпус по высоте экрана: на низком телефоне (~460 точек) тоже влезает.
func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var h := clampf(vp.y - 20.0, 360.0, 640.0)
	var w := h * 0.52
	_frame.size = Vector2(w, h)
	_frame.position = (vp - _frame.size) * 0.5
	var r := screen_rect()
	_screen.position = r.position
	_screen.size = r.size
	var top := 22.0
	_home.position = Vector2(8, top + 10)
	_home.size = Vector2(r.size.x - 16, r.size.y - top - 14)
	var cell := (r.size.x - 16.0 - 2.0 * 8.0) / 3.0
	_home.add_theme_constant_override("h_separation", 8)
	_home.add_theme_constant_override("v_separation", 6)
	for c in _home.get_children():
		(c as Control).custom_minimum_size = Vector2(cell, cell + 16.0)
	_page.position = Vector2(6, top)
	_page.size = Vector2(r.size.x - 12, r.size.y - top - 4)
	_frame.queue_redraw()


## Экран внутри корпуса (в координатах корпуса).
func screen_rect() -> Rect2:
	var s := _frame.size
	return Rect2(Vector2(s.x * 0.07, s.y * 0.14), Vector2(s.x * 0.86, s.y * 0.7))


func _home_button() -> Vector2:
	return Vector2(_frame.size.x * 0.5, _frame.size.y * 0.92)


func _frame_input(event: InputEvent) -> void:
	var press: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if press and (event.position as Vector2).distance_to(_home_button()) < _frame.size.y * 0.05:
		SoundLibrary.play("click", -8.0)
		if _app.is_empty():
			close_phone()
		else:
			show_app("")


# --- Рисование ---------------------------------------------------------------

func _draw_body() -> void:
	var s := _frame.size
	var rad := s.x * 0.16
	_round_rect(_frame, Rect2(Vector2.ZERO, s), rad, Color(0.72, 0.73, 0.76))
	_round_rect(_frame, Rect2(Vector2(3, 3), s - Vector2(6, 6)), rad - 2.0, Color(0.05, 0.05, 0.06))
	# Динамик и камера сверху
	var sp := Rect2(s.x * 0.38, s.y * 0.065, s.x * 0.24, s.y * 0.012)
	_round_rect(_frame, sp, sp.size.y * 0.5, Color(0.22, 0.22, 0.24))
	_frame.draw_circle(Vector2(s.x * 0.5, s.y * 0.035), s.y * 0.007, Color(0.15, 0.15, 0.2))
	# Экран — чуть светлее по краю
	var r := screen_rect()
	_frame.draw_rect(r.grow(1.5), Color(0.15, 0.15, 0.16))
	# Кнопка «Домой»: кружок с квадратиком
	var hb := _home_button()
	var hr := s.y * 0.042
	_frame.draw_circle(hb, hr, Color(0.1, 0.1, 0.11))
	_frame.draw_arc(hb, hr, 0.0, TAU, 32, Color(0.32, 0.32, 0.35), 2.0)
	var q := hr * 0.4
	_frame.draw_rect(Rect2(hb - Vector2(q, q), Vector2(q, q) * 2.0), Color(0.55, 0.55, 0.58), false, 1.5)


## Фон экрана: обои на главной, тёмный в приложениях; строка состояния.
func _draw_status() -> void:
	var s := _screen.size
	if _app.is_empty():
		_screen.draw_rect(Rect2(Vector2.ZERO, s), Color(0.1, 0.2, 0.38))
		for i in 6:
			var y := s.y * (0.2 + i * 0.14)
			_screen.draw_line(Vector2(0, y), Vector2(s.x, y - s.y * 0.25), Color(0.2, 0.35, 0.6, 0.35), 18.0)
	else:
		_screen.draw_rect(Rect2(Vector2.ZERO, s), Color(0.06, 0.06, 0.07))
	_screen.draw_rect(Rect2(0, 0, s.x, 20), Color(0, 0, 0, 0.55))
	var f := ThemeDB.fallback_font
	var h := int(TimeManager.hour())
	var m := int((TimeManager.hour() - h) * 60.0)
	_screen.draw_string(f, Vector2(6, 15), "%02d:%02d" % [h, m], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	_screen.draw_string(f, Vector2(0, 15), SettingsManager.t("Каменка-Связь"), HORIZONTAL_ALIGNMENT_CENTER, s.x, 11, Color(0.85, 0.85, 0.85))
	# Сеть — столбики, батарея — рамка с зарядом
	for i in 4:
		_screen.draw_rect(Rect2(s.x - 52 + i * 5, 14 - i * 2.5, 3, 3 + i * 2.5), Color.WHITE)
	_screen.draw_rect(Rect2(s.x - 26, 6, 18, 9), Color.WHITE, false, 1.0)
	_screen.draw_rect(Rect2(s.x - 8, 8.5, 2, 4), Color.WHITE)
	_screen.draw_rect(Rect2(s.x - 24.5, 7.5, 12, 6), Color(0.4, 0.9, 0.4))


static func _round_rect(c: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	c.draw_rect(Rect2(r.position + Vector2(rad, 0), r.size - Vector2(rad * 2.0, 0)), col)
	c.draw_rect(Rect2(r.position + Vector2(0, rad), r.size - Vector2(0, rad * 2.0)), col)
	for p in [r.position + Vector2(rad, rad), Vector2(r.end.x - rad, r.position.y + rad),
			Vector2(r.position.x + rad, r.end.y - rad), r.end - Vector2(rad, rad)]:
		c.draw_circle(p, rad, col)


## Значок приложения: скруглённый квадрат с рисунком и подпись под ним.
func _app_icon(a: Array) -> Control:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.name = "App_" + String(a[0])
	b.pressed.connect(func() -> void:
		SoundLibrary.play("click", -8.0)
		show_app(a[0]))
	b.draw.connect(func() -> void:
		var w := b.size.x
		var r := Rect2(Vector2(w * 0.12, 2), Vector2(w * 0.76, w * 0.76))
		_round_rect(b, r, r.size.x * 0.22, a[2])
		b.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.1, 1), Vector2(r.size.x * 0.8, r.size.y * 0.4)), Color(1, 1, 1, 0.12))
		_glyph(b, a[0], r)
		var f := ThemeDB.fallback_font
		b.draw_string(f, Vector2(0, r.end.y + 13), SettingsManager.t(a[1]), HORIZONTAL_ALIGNMENT_CENTER, w, 11, Color.WHITE))
	return b


## Рисунок на значке: трубка, облачко, нота, фотоаппарат, машина, тягач,
## банк, солнце с облаком, циферблат.
static func _glyph(c: CanvasItem, id: String, r: Rect2) -> void:
	var o := r.get_center()
	var u := r.size.x / 10.0
	var wh := Color.WHITE
	match id:
		"calls":
			c.draw_arc(o + Vector2(0.6, 0.6) * u, 3.0 * u, PI * 0.55, PI * 1.45, 12, wh, 1.6 * u)
			c.draw_circle(o + Vector2(-1.5, -2.2) * u, 1.1 * u, wh)
			c.draw_circle(o + Vector2(-1.5, 3.4) * u, 1.1 * u, wh)
		"sms":
			c.draw_set_transform(o + Vector2(0, -0.4) * u, 0.0, Vector2(1.0, 0.75))
			c.draw_circle(Vector2.ZERO, 3.4 * u, wh)
			c.draw_set_transform(Vector2.ZERO)
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(-2.6, 1.0) * u, o + Vector2(-0.8, 2.0) * u, o + Vector2(-3.6, 3.4) * u]), wh)
		"music":
			c.draw_circle(o + Vector2(-1.6, 2.4) * u, 1.2 * u, wh)
			c.draw_circle(o + Vector2(2.0, 1.6) * u, 1.2 * u, wh)
			c.draw_line(o + Vector2(-0.5, 2.4) * u, o + Vector2(-0.5, -3.0) * u, wh, 0.7 * u)
			c.draw_line(o + Vector2(3.1, 1.6) * u, o + Vector2(3.1, -3.6) * u, wh, 0.7 * u)
			c.draw_line(o + Vector2(-0.5, -3.0) * u, o + Vector2(3.1, -3.6) * u, wh, 1.1 * u)
		"photo":
			c.draw_rect(Rect2(o + Vector2(-3.6, -2.0) * u, Vector2(7.2, 4.8) * u), wh)
			c.draw_rect(Rect2(o + Vector2(-1.2, -2.9) * u, Vector2(2.4, 1.0) * u), wh)
			c.draw_circle(o + Vector2(0, 0.4) * u, 1.7 * u, Color(0.3, 0.32, 0.35))
			c.draw_circle(o + Vector2(0, 0.4) * u, 1.0 * u, Color(0.55, 0.7, 0.85))
		"taxi":
			var k := Color(0.1, 0.1, 0.1)
			c.draw_rect(Rect2(o + Vector2(-3.8, -0.4) * u, Vector2(7.6, 2.4) * u), k)
			c.draw_rect(Rect2(o + Vector2(-2.2, -2.2) * u, Vector2(4.2, 1.9) * u), k)
			c.draw_circle(o + Vector2(-2.2, 2.2) * u, 0.9 * u, k)
			c.draw_circle(o + Vector2(2.2, 2.2) * u, 0.9 * u, k)
			for i in 4:
				c.draw_rect(Rect2(o + Vector2(-1.6 + i * 0.8, -3.6 + (i % 2) * 0.5) * u, Vector2(0.8, 0.5) * u), k)
		"tow":
			c.draw_rect(Rect2(o + Vector2(-3.8, -0.6) * u, Vector2(5.0, 2.0) * u), wh)
			c.draw_rect(Rect2(o + Vector2(1.2, -2.2) * u, Vector2(2.6, 3.6) * u), wh)
			c.draw_line(o + Vector2(-3.4, -0.6) * u, o + Vector2(-1.0, -3.4) * u, wh, 0.6 * u)
			c.draw_arc(o + Vector2(-1.0, -2.6) * u, 0.8 * u, -PI * 0.5, PI * 0.8, 8, wh, 0.5 * u)
			c.draw_circle(o + Vector2(-2.4, 1.9) * u, 1.0 * u, wh)
			c.draw_circle(o + Vector2(2.4, 1.9) * u, 1.0 * u, wh)
		"bank":
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(-4.0, -1.6) * u, o + Vector2(0, -4.0) * u, o + Vector2(4.0, -1.6) * u]), wh)
			for i in 4:
				c.draw_rect(Rect2(o + Vector2(-3.2 + i * 2.0, -1.0) * u, Vector2(0.9, 3.4) * u), wh)
			c.draw_rect(Rect2(o + Vector2(-4.0, 2.6) * u, Vector2(8.0, 0.9) * u), wh)
		"weather":
			c.draw_circle(o + Vector2(-1.2, -1.2) * u, 2.2 * u, Color(1.0, 0.85, 0.2))
			c.draw_circle(o + Vector2(0.4, 1.4) * u, 1.8 * u, wh)
			c.draw_circle(o + Vector2(2.4, 1.0) * u, 1.6 * u, wh)
			c.draw_rect(Rect2(o + Vector2(-1.0, 1.4) * u, Vector2(4.6, 1.6) * u), wh)
		"clock":
			c.draw_circle(o, 3.8 * u, wh)
			var hh := TimeManager.hour()
			var ah := TAU * fmod(hh, 12.0) / 12.0
			var am := TAU * fmod(hh, 1.0)
			var k := Color(0.1, 0.1, 0.1)
			c.draw_line(o, o + Vector2(sin(ah), -cos(ah)) * 2.0 * u, k, 0.6 * u)
			c.draw_line(o, o + Vector2(sin(am), -cos(am)) * 3.0 * u, k, 0.4 * u)
			c.draw_line(o, o + Vector2(sin(am + 2.5), -cos(am + 2.5)) * 3.0 * u, Color(0.9, 0.2, 0.1), 0.2 * u)


# --- Страницы ----------------------------------------------------------------

## Открыть приложение id ("" — главный экран).
func show_app(id: String) -> void:
	if _app != id:
		_note = ""
	_app = id
	_home.visible = id.is_empty()
	_page.visible = not id.is_empty()
	_screen.queue_redraw()
	if id.is_empty():
		for c in _home.get_children():
			(c as Control).queue_redraw()
		return
	for a in APPS:
		if a[0] == id:
			_page_title.text = a[1]
	for c in _content.get_children():
		c.queue_free()
	if not _note.is_empty():
		_text(_note, 14, Color(1.0, 0.9, 0.55))
	match id:
		"calls": _page_calls()
		"sms": _page_sms()
		"music": _page_music()
		"photo": _page_photo()
		"taxi": _page_taxi()
		"tow": _page_tow()
		"bank": _page_bank()
		"weather": _page_weather()
		"clock": _page_clock()
	_scroll.scroll_vertical = 0


func _redo(note: String) -> void:
	_note = note
	show_app(_app)


func _page_calls() -> void:
	var girl := get_tree().get_first_node_in_group("girl") as Girl
	if girl and girl.met:
		var who := "Жена Оля" if girl.married else "Оля"
		_contact(who, func() -> void: _redo(call_girl()))
	_contact("Такси «Каменка»", func() -> void: show_app("taxi"))
	_contact("Эвакуатор", func() -> void: show_app("tow"))
	_contact("Мастер СТО", func() -> void:
		_redo("Мастер СТО: «Работаем с 8 до 20. Подгоняй — покрасим, поменяем что стёрлось»"))
	_contact("Дядя Гриша, свалка", func() -> void:
		_redo("Дядя Гриша: «Свалка открыта с %d до %d. Лом беру, запчасти б/у есть»" % [Landmarks.JUNK_OPEN, Landmarks.JUNK_CLOSE]))


func _contact(who: String, fn: Callable) -> void:
	var row := HBoxContainer.new()
	_content.add_child(row)
	var l := _label(who, 14, Color.WHITE)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var b := _btn("Позвонить", Color(0.2, 0.62, 0.3))
	b.autowrap_mode = TextServer.AUTOWRAP_OFF
	b.pressed.connect(fn)
	row.add_child(b)


## Позвонить Оле: позвать гулять. Далеко — приедет на автобусе к тебе.
func call_girl() -> String:
	var girl := get_tree().get_first_node_in_group("girl") as Girl
	if girl == null or not girl.met:
		return "Номера нет"
	if girl.state == Girl.State.FOLLOW or girl.state == Girl.State.RIDE:
		return "Оля: «Так я же рядом с тобой!»"
	if girl.rel < Girl.FRIEND and not girl.married:
		return "Оля: «Ой, а кто это? …А, привет. Давай лучше при встрече поговорим»"
	var reply := girl.invite()
	var p := GameManager.player as Node3D
	if girl.state == Girl.State.FOLLOW and p and girl.global_position.distance_to(p.global_position) > 40.0:
		var back := -p.global_transform.basis.z
		girl.global_position = p.global_position + Vector3(back.x, 0, back.z).normalized() * -2.5 + Vector3(1.5, 0, 0)
		reply += " (Оля приехала к тебе)"
	QuestManager.event("phone_call")
	return "Оля: «%s»" % reply


func _page_sms() -> void:
	var errand := Daily.tracker_line()
	if not errand.is_empty():
		_text(errand.trim_prefix("» "), 13, Color(1.0, 0.85, 0.5))
	if GameManager.history.is_empty():
		_text("Сообщений пока нет", 13, Color(0.7, 0.7, 0.7))
	for i in range(GameManager.history.size() - 1, -1, -1):
		var h: Array = GameManager.history[i]
		_text(h[0], 11, Color(0.6, 0.6, 0.65))
		_text(h[1], 13, Color.WHITE)


func _page_music() -> void:
	var radio := get_tree().get_first_node_in_group("radio")
	if radio == null:
		return
	_text("Играет и пешком — в наушниках. В машине — то же радио.", 12, Color(0.7, 0.7, 0.72))
	for i in radio.STATIONS.size():
		var on: bool = radio.station == i
		var b := _btn(("Играет: %s" if on else "Включить: %s") % radio.STATIONS[i].name, Color(0.95, 0.45, 0.15) if on else Color(0.25, 0.25, 0.28))
		b.pressed.connect(func() -> void:
			radio.play_on_phone(i)
			_redo("Музыка: «%s»" % radio.STATIONS[i].name))
		_content.add_child(b)
	var off := _btn("Выключить", Color(0.25, 0.25, 0.28))
	off.pressed.connect(func() -> void:
		radio.stop_phone()
		_redo("Музыка выключена"))
	_content.add_child(off)


func _page_photo() -> void:
	var shot := _btn("Сфотографировать", Color(0.82, 0.1, 0.08))
	shot.pressed.connect(take_photo)
	_content.add_child(shot)
	var files := photos()
	if files.is_empty():
		_text("Фотографий пока нет. Сними — телефон спрячется на миг, на снимке будет мир без кнопок.", 12, Color(0.7, 0.7, 0.72))
		return
	_text("Снимков: %d из %d" % [files.size(), PHOTO_MAX], 12, Color(0.7, 0.7, 0.72))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	_content.add_child(grid)
	var w := (_screen.size.x - 24.0) * 0.5
	for f in files:
		var img := Image.load_from_file(PHOTO_DIR.path_join(f))
		if img == null or img.is_empty():
			continue
		var tb := TextureButton.new()
		tb.texture_normal = ImageTexture.create_from_image(img)
		tb.ignore_texture_size = true
		tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		tb.custom_minimum_size = Vector2(w, w * 0.6)
		tb.pressed.connect(_view_photo.bind(f, tb.texture_normal))
		grid.add_child(tb)


## Снимок крупно и кнопка «Удалить».
func _view_photo(f: String, tex: Texture2D) -> void:
	for c in _content.get_children():
		c.queue_free()
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(_screen.size.x - 16.0, (_screen.size.x - 16.0) * 0.75)
	_content.add_child(tr)
	var del := _btn("Удалить", Color(0.5, 0.15, 0.12))
	del.pressed.connect(func() -> void:
		DirAccess.remove_absolute(PHOTO_DIR.path_join(f))
		_redo("Снимок удалён"))
	_content.add_child(del)


## Снимки — новые сначала.
static func photos() -> Array:
	var d := DirAccess.open(PHOTO_DIR)
	if d == null:
		return []
	var out := []
	for f in d.get_files():
		if f.ends_with(".png"):
			out.append(f)
	out.sort()
	out.reverse()
	return out


## Сфотографировать: всё, что поверх мира (телефон, кнопки, надписи),
## прячется на два кадра — на снимке только мир.
func take_photo() -> void:
	var hidden: Array[CanvasLayer] = []
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := n as CanvasLayer
		if cl.visible:
			cl.visible = false
			hidden.append(cl)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	for cl in hidden:
		cl.visible = true
	if img.get_width() > 960:
		img.resize(960, int(960.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_BILINEAR)
	DirAccess.make_dir_recursive_absolute(PHOTO_DIR)
	var name := "photo_%04d_%05d.png" % [TimeManager.day, int(Time.get_ticks_msec() / 100) % 100000]
	img.save_png(PHOTO_DIR.path_join(name))
	var files := photos()
	for i in range(PHOTO_MAX, files.size()):
		DirAccess.remove_absolute(PHOTO_DIR.path_join(files[i]))
	SoundLibrary.play("click", 0.0, 1.6)
	QuestManager.event("photo")
	_redo("Снято! День %d, %s" % [TimeManager.day, TimeManager.clock_text()])


# --- Такси и эвакуатор ---------------------------------------------------------

## Куда возит такси: [название, точка в мире, поворот лицом].
func taxi_places() -> Array:
	# Телефон — ребёнок мира: оттуда — где калитка своего двора
	var door := float(get_parent().get("_home_door_x")) if get_parent() else 0.0
	var home := _house()
	return [
		["Домой", Vector3(home.x + door, 0.1, home.y + 15.5), PI],
		["В город, к остановке", Town.w(_world_const("STOP_TOWN", Vector3.ZERO)) + Vector3(0, 0.1, -2.2), PI],
	]


## Свой двор и остановки — константы мира. Мир — родитель телефона: прямой
## preload мира дал бы петлю зависимостей (мир сам создаёт телефон).
func _house() -> Vector2:
	return _world_const("PLAYER_HOUSE", Vector2(-125, -56))


func _world_const(n: String, fallback: Variant) -> Variant:
	var w := get_parent()
	if w and w.get_script():
		return (w.get_script() as Script).get_script_constant_map().get(n, fallback)
	return fallback


func taxi_price(to: Vector3) -> int:
	var p := GameManager.player as Node3D
	var d := p.global_position.distance_to(to) if p else 0.0
	var k := 2.0 if TimeManager.hour() >= 22.0 or TimeManager.hour() < 6.0 else 1.0
	return int(round((TAXI_BASE + d / 1000.0 * TAXI_PER_KM) * k / 10.0)) * 10


func _page_taxi() -> void:
	if GameManager.vehicle != null:
		_text("Ты за рулём — такси не нужно", 13, Color(0.8, 0.8, 0.8))
		return
	_text("Приедет минут через десять. Ночью — вдвое дороже.", 12, Color(0.7, 0.7, 0.72))
	for pl in taxi_places():
		var p := GameManager.player as Node3D
		if p and p.global_position.distance_to(pl[1]) < 60.0:
			continue
		var b := _btn("%s — %d грн" % [pl[0], taxi_price(pl[1])], Color(0.85, 0.65, 0.05))
		b.add_theme_color_override("font_color", Color.BLACK)
		b.pressed.connect(taxi.bind(pl[0]))
		_content.add_child(b)


## Уехать на такси в place (название из taxi_places). true — уехал.
func taxi(place: String) -> bool:
	var p := GameManager.player as Player
	if p == null or GameManager.vehicle != null:
		return false
	for pl in taxi_places():
		if pl[0] != place:
			continue
		var price := taxi_price(pl[1])
		if not GameManager.spend(price):
			_redo("Не хватает денег: такси — %d грн" % price)
			return false
		var d := p.global_position.distance_to(pl[1])
		TimeManager.advance(10.0 + d / 1000.0 * 1.2)
		p.global_position = pl[1]
		p.velocity = Vector3.ZERO
		p.rotation.y = pl[2]
		# Оля, что гуляет рядом, едет с тобой
		var girl := get_tree().get_first_node_in_group("girl") as Girl
		if girl and girl.state == Girl.State.FOLLOW:
			girl.global_position = pl[1] + Vector3(1.5, 0, 0)
		QuestManager.event("taxi")
		close_phone()
		GameManager.notify("Такси: %s — %d грн. %s" % [String(pl[0]).to_lower(), price, TimeManager.clock_text()])
		return true
	return false


## Где эвакуатор оставляет технику у дома: вдоль улицы у твоего двора.
func tow_spots() -> Array:
	var out := []
	for i in 4:
		out.append(Vector3(_house().x - 4.0 - i * 5.5, 0.1, -39.5))
	return out


func own_vehicles() -> Array:
	var out := []
	for v in get_tree().get_nodes_in_group("vehicles"):
		var veh := v as Vehicle
		if veh and veh.owned() and not veh.school and veh.kind != "tractor":
			out.append(veh)
	return out


func tow_price(v: Vehicle) -> int:
	var d := v.global_position.distance_to(tow_spots()[0])
	return int(round((TOW_BASE + d / 1000.0 * TOW_PER_KM) / 10.0)) * 10


func _page_tow() -> void:
	_text("Привезём твою технику к дому и дольём %d л бензина." % int(TOW_FUEL), 12, Color(0.7, 0.7, 0.72))
	var any := false
	for v: Vehicle in own_vehicles():
		if v.global_position.distance_to(tow_spots()[0]) < 40.0:
			continue
		any = true
		_text("%s — %d м от дома" % [v.spec.title, int(v.global_position.distance_to(tow_spots()[0]))], 13, Color.WHITE)
		var b := _btn("К дому — %d грн" % tow_price(v), Color(0.85, 0.3, 0.12))
		b.disabled = v.driver != null
		b.pressed.connect(tow.bind(v))
		_content.add_child(b)
	if not any:
		_text("Вся твоя техника и так у дома", 13, Color(0.8, 0.8, 0.8))


## Отвезти технику v к дому. true — получилось.
func tow(v: Vehicle) -> bool:
	if v == null or v.driver != null:
		return false
	var price := tow_price(v)
	if not GameManager.spend(price):
		_redo("Не хватает денег: эвакуатор — %d грн" % price)
		return false
	var spot: Vector3 = tow_spots()[0]
	for s in tow_spots():
		var free := true
		for o in get_tree().get_nodes_in_group("vehicles"):
			if o != v and (o as Node3D).global_position.distance_to(s) < 3.5:
				free = false
		if free:
			spot = s
			break
	v.speed = 0.0
	v.lateral = 0.0
	v.velocity = Vector3.ZERO
	v.engine_on = false
	v.global_transform = Transform3D(Basis(Vector3.UP, -PI / 2.0), spot)
	v.fuel = maxf(v.fuel, TOW_FUEL)
	TimeManager.advance(60.0)
	QuestManager.event("tow")
	GameManager.notify("Эвакуатор привёз «%s» к дому (−%d грн)" % [v.spec.title, price])
	_redo("«%s» уже у твоего дома" % v.spec.title)
	return true


# --- Банк, погода, часы --------------------------------------------------------

func _page_bank() -> void:
	_text("Наличные: %d грн" % GameManager.money, 15, Color.WHITE)
	_text("Вклад: %d грн, 10%% годовых — проценты каждое утро" % Daily.deposit, 13, Color(0.85, 0.95, 0.85))
	var per_day := 0
	for id in Daily.owned:
		per_day += Daily.income(id)
	if per_day > 0:
		_text("Своё дело приносит %d грн в день" % per_day, 13, Color(0.85, 0.95, 0.85))
	var put := _btn("Положить на вклад (300 грн оставить)", Color(0.12, 0.45, 0.32))
	put.disabled = GameManager.money <= 300
	put.pressed.connect(func() -> void:
		var sum := Daily.put_money()
		_redo("Положил %d грн" % sum if sum > 0 else "Нечего класть"))
	_content.add_child(put)
	var take := _btn("Снять весь вклад", Color(0.25, 0.25, 0.28))
	take.disabled = Daily.deposit <= 0
	take.pressed.connect(func() -> void:
		_redo("Снял %d грн" % Daily.take_money()))
	_content.add_child(take)


func _page_weather() -> void:
	var now := WeatherManager.name_text()
	_text("Сейчас: %s" % now, 17, Color.WHITE)
	_text("Сезон: %s" % WeatherManager.season_text(), 14, Color(0.85, 0.9, 1.0))
	var hours := maxi(1, int(round(WeatherManager.minutes_left() / 60.0)))
	_text("Продержится ещё около %d ч, потом — %s" % [hours, WeatherManager.NAMES[WeatherManager.forecast()]], 14, Color(0.85, 0.9, 1.0))
	var left := WeatherManager.SEASON_DAYS - (TimeManager.day - 1) % WeatherManager.SEASON_DAYS
	_text("До смены сезона: %d дн." % left, 13, Color(0.7, 0.7, 0.72))


func _page_clock() -> void:
	var h := int(TimeManager.hour())
	var m := int((TimeManager.hour() - h) * 60.0)
	_text("%02d:%02d" % [h, m], 44, Color.WHITE)
	_text("День %d, %s" % [TimeManager.day, WEEKDAYS_FULL[TimeManager.day % 7]], 15, Color(0.85, 0.85, 0.9))
	_text("Сезон: %s" % WeatherManager.season_text(), 13, Color(0.7, 0.7, 0.72))


# --- Мелочи интерфейса ---------------------------------------------------------

func _label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _text(t: String, size: int, col: Color) -> Label:
	var l := _label(t, size, col)
	l.custom_minimum_size.x = maxf(_screen.size.x - 24.0, 60.0)
	_content.add_child(l)
	return l


func _btn(t: String, col: Color) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 34)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color.WHITE)
	var st := StyleBoxFlat.new()
	st.bg_color = col
	st.set_corner_radius_all(6)
	st.set_content_margin_all(5)
	b.add_theme_stylebox_override("normal", st)
	var hv := st.duplicate() as StyleBoxFlat
	hv.bg_color = col.lightened(0.12)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	var ds := st.duplicate() as StyleBoxFlat
	ds.bg_color = col.darkened(0.45)
	b.add_theme_stylebox_override("disabled", ds)
	return b
