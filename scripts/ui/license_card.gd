class_name LicenseCard
extends CanvasLayer
## Водительское удостоверение — оборотная сторона, как настоящая: слева
## пояснения к графам, справа таблица всех категорий (A1 … T) со значками
## техники. Открытые категории отмечены: с какого дня действуют и что
## бессрочно. Показывается после сданного экзамена и из журнала (J).
## Пока открыто — игра на паузе. Рисуется кодом, без картинок.

const CATS := ["A1", "A", "B1", "B", "C1", "C", "D1", "D", "BE", "C1E", "CE", "D1E", "DE", "T"]
## Какой значок у категории
const ICONS := {"A1": "moped", "A": "moto", "B1": "trike", "B": "car", "C1": "van", "C": "truck",
	"D1": "minibus", "D": "bus", "BE": "car_trailer", "C1E": "van_trailer", "CE": "truck_trailer",
	"D1E": "minibus_trailer", "DE": "bus_trailer", "T": "tractor"}
const FIELDS := ["1.  Фамилия", "2.  Имя, отчество", "3.  Дата и место рождения", "4a. Дата выдачи",
	"4b. Действительно до", "4c. Кем выдано", "5.  Номер удостоверения", "7.  Подпись владельца",
	"9.  Категория", "10. Категория действует с", "11. Категория действует до", "12. Ограничения"]
const W := 740.0
const H := 470.0

signal closed

var _card: Control
var _close: Button
var _font: Font
var _was_paused := false


func _init() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	add_to_group("license_card")
	_font = ThemeDB.fallback_font
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.draw.connect(_draw_card)
	add_child(_card)
	_close = Button.new()
	_close.text = "Закрыть"
	_close.custom_minimum_size = Vector2(160, 46)
	_close.add_theme_font_size_override("font_size", 20)
	_close.pressed.connect(close_card)
	add_child(_close)
	get_viewport().size_changed.connect(_layout)
	_layout()


func open() -> void:
	_was_paused = get_tree().paused
	visible = true
	get_tree().paused = true
	_layout()
	_card.queue_redraw()


func close_card() -> void:
	visible = false
	# Открыли из журнала — он и дальше держит паузу
	get_tree().paused = _was_paused
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		close_card()


## Карточка — по центру, с запасом под кнопку; на низком экране телефона
## (~460 точек) ужимается целиком.
func _layout() -> void:
	if _card == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var k := minf((vs.x - 24.0) / W, (vs.y - 70.0) / H)
	_card.scale = Vector2(k, k)
	_card.size = Vector2(W, H)
	_card.position = Vector2((vs.x - W * k) * 0.5, 8.0)
	_close.position = Vector2((vs.x - _close.custom_minimum_size.x) * 0.5, 8.0 + H * k + 6.0)


func _text(p: Vector2, t: String, size: int, col: Color) -> void:
	_card.draw_string(_font, p, SettingsManager.t(t), HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_card() -> void:
	var ink := Color(0.12, 0.14, 0.2)
	var line := Color(0.1, 0.12, 0.16)
	# Бланк: голубой с волнистой защитной сеткой и зелёным узором понизу
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.73, 0.85, 0.94)
	bg.set_corner_radius_all(22)
	_card.draw_style_box(bg, Rect2(0, 0, W, H))
	for i in 26:
		var pts := PackedVector2Array()
		var y0 := 20.0 + i * 16.0
		for x in range(0, int(W) + 1, 12):
			pts.append(Vector2(x, y0 + sin(x * 0.035 + i * 0.7) * 5.0))
		_card.draw_polyline(pts, Color(0.62, 0.77, 0.9, 0.6), 1.0)
	_card.draw_rect(Rect2(14, 10, 170, 22), Color(0.95, 0.97, 1.0))
	var band := Rect2(12, H - 52, W - 24, 34)
	_card.draw_rect(band, Color(0.75, 0.86, 0.62))
	for x in range(int(band.position.x), int(band.end.x), 10):
		_card.draw_line(Vector2(x, band.position.y + 2), Vector2(x + 8, band.end.y - 2), Color(0.45, 0.65, 0.35), 1.5)
	# Пояснения к графам — слева
	for i in FIELDS.size():
		_text(Vector2(22, 66 + i * 29), FIELDS[i], 13, ink)
	# Таблица категорий
	var gx := 250.0
	var gy := 40.0
	var cw := [116.0, 118.0, 118.0, 118.0]
	var rh := 22.6
	var gw := 470.0
	var rows := CATS.size()
	_card.draw_rect(Rect2(gx, gy, gw, rh * (rows + 1)), Color(0.82, 0.9, 0.97, 0.75))
	var heads := ["9", "10", "11", "12"]
	var x := gx
	for c in 4:
		_text(Vector2(x + cw[c] * 0.5 - 6, gy + 17), heads[c], 15, ink)
		x += cw[c]
	for r in rows:
		var cat: String = CATS[r]
		var y := gy + rh * (r + 1)
		var has := _has(cat)
		if has:
			_card.draw_rect(Rect2(gx + 1, y + 1, gw - 2, rh - 2), Color(1.0, 0.95, 0.6, 0.85))
		_text(Vector2(gx + 6, y + 17), cat, 15, ink)
		_icon(String(ICONS[cat]), Vector2(gx + 44, y + 3), ink)
		if has:
			var day := int(Progress.category_days.get(cat, 0))
			_text(Vector2(gx + cw[0] + 10, y + 16), ("день %d" % day) if day > 0 else "есть", 13, ink)
			_text(Vector2(gx + cw[0] + cw[1] + 10, y + 16), "бессрочно", 13, ink)
			_text(Vector2(gx + cw[0] + cw[1] + cw[2] + 10, y + 16), "—", 13, ink)
	# Сетка
	for r in rows + 2:
		var y := gy + rh * r
		_card.draw_line(Vector2(gx, y), Vector2(gx + gw, y), line, 1.5)
	x = gx
	for c in 5:
		_card.draw_line(Vector2(x, gy), Vector2(x, gy + rh * (rows + 1)), line, 1.5)
		if c < 4:
			x += cw[c]
	# Номер бланка и кто выдал; без прав — пометка поперёк
	var no := Progress.license_no if Progress.license_no != "" else "ВХХ № 000000"
	_text(Vector2(W - 330, H - 64), "%s  ГАИ района · автошкола «Каменка»" % no, 12, ink)
	# Владелец — из профиля (меню → «Профиль»)
	if SettingsManager.full_name() != "":
		_text(Vector2(22, H - 64), SettingsManager.full_name().to_upper(), 13, ink)
	if not _any():
		_card.draw_set_transform(Vector2(W * 0.5 + 40, H * 0.5), -0.35, Vector2.ONE)
		_text(Vector2(-200, 10), "ПРАВ ПОКА НЕТ — СДАЙ В АВТОШКОЛЕ", 24, Color(0.75, 0.15, 0.12, 0.85))
		_card.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _has(cat: String) -> bool:
	return cat in ["A", "B", "C", "D"] and Progress.has_category(cat)


func _any() -> bool:
	for c in ["A", "B", "C", "D"]:
		if Progress.has_category(c):
			return true
	return false


## Значок техники 56×16 в точке p: силуэты из прямоугольников и колёс.
func _icon(kind: String, p: Vector2, col: Color) -> void:
	var wheel := func(cx: float, r: float) -> void:
		_card.draw_circle(p + Vector2(cx, 13), r, col)
	var rect := func(x0: float, y0: float, w: float, h: float) -> void:
		_card.draw_rect(Rect2(p + Vector2(x0, y0), Vector2(w, h)), col)
	var base := kind.trim_suffix("_trailer")
	match base:
		"moped", "moto":
			wheel.call(4.0, 3.5 if base == "moto" else 3.0)
			wheel.call(22.0, 3.5 if base == "moto" else 3.0)
			rect.call(6.0, 6.0, 14.0, 4.0)
			rect.call(17.0, 2.0, 3.0, 6.0)
		"trike":
			wheel.call(4.0, 3.0)
			wheel.call(20.0, 3.0)
			rect.call(2.0, 4.0, 10.0, 6.0)
			rect.call(12.0, 1.0, 12.0, 9.0)
		"car":
			rect.call(0.0, 6.0, 28.0, 5.0)
			rect.call(6.0, 2.0, 14.0, 5.0)
			wheel.call(6.0, 3.0)
			wheel.call(22.0, 3.0)
		"van":
			rect.call(0.0, 2.0, 22.0, 9.0)
			rect.call(22.0, 5.0, 6.0, 6.0)
			wheel.call(5.0, 3.0)
			wheel.call(22.0, 3.0)
		"truck":
			rect.call(0.0, 0.0, 24.0, 10.0)
			rect.call(25.0, 3.0, 7.0, 8.0)
			wheel.call(5.0, 3.0)
			wheel.call(12.0, 3.0)
			wheel.call(28.0, 3.0)
		"minibus":
			rect.call(0.0, 2.0, 26.0, 9.0)
			wheel.call(5.0, 3.0)
			wheel.call(21.0, 3.0)
		"bus":
			rect.call(0.0, 1.0, 36.0, 10.0)
			wheel.call(6.0, 3.0)
			wheel.call(30.0, 3.0)
		"tractor":
			rect.call(4.0, 3.0, 14.0, 6.0)
			rect.call(10.0, -1.0, 6.0, 5.0)
			wheel.call(5.0, 5.0)
			wheel.call(20.0, 3.0)
			# Прицеп-тележка у трактора, как на бланке
			rect.call(30.0, 4.0, 18.0, 6.0)
			wheel.call(40.0, 3.0)
	if kind.ends_with("_trailer"):
		var x0 := 38.0 if base == "bus" else (34.0 if base in ["truck"] else 31.0)
		_card.draw_line(p + Vector2(x0 - 4, 9), p + Vector2(x0, 9), col, 1.5)
		rect.call(x0, 3.0, 14.0, 8.0)
		wheel.call(x0 + 7.0, 3.0)
