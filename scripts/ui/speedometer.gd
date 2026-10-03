extends Control
## Приборы за рулём: круглый спидометр со стрелкой и шкалой, внутри —
## дуга тахометра (краснеет у отсечки), по центру — скорость цифрами,
## внизу — передача и бензин. Жигули — шкала до 160, Ява — до 140,
## ГАЗ-53 — до 120, трактор — до 40.
##
## На компьютере стоит справа внизу, на телефоне — внизу посередине,
## между рулём и педалями.

const START := deg_to_rad(135.0)  # 0 км/ч — слева внизу
const SWEEP := deg_to_rad(270.0)

var _shown := 0.0  # скорость на стрелке — догоняет настоящую плавно
var _shown_rpm := 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	visible = false


func _vehicle() -> Vehicle:
	var v := GameManager.vehicle as Vehicle
	return v if v and v.driver else null


func _max_speed(v: Vehicle) -> float:
	return {"moto": 140.0, "izh": 140.0, "moped": 60.0, "truck": 120.0, "tractor": 40.0}.get(v.kind, 160.0)


func _process(delta: float) -> void:
	var v := _vehicle()
	visible = v != null
	if v == null:
		_shown = 0.0
		return
	var r := _radius()
	size = Vector2(r * 2.0 + 8.0, r * 2.0 + 8.0)
	# «Ява» — два прибора рядом и пульт лампочек между ними
	if _jawa(v):
		r = _jawa_r()
		size = Vector2(r * 4.0 + r * 0.9 + 8.0, r * 2.0 + 26.0)
	elif v.kind == "izh":
		r = _jawa_r()
		size = Vector2(r * 2.0 + r * 2.5 + 16.0, r * 2.0 + 26.0)
	var vs := get_viewport_rect().size
	if GameManager.touch_mode:
		# Между рулём (слева до ~300) и педалями (справа от ~600 до края)
		var mid := (310.0 + vs.x - 400.0) * 0.5
		if SettingsManager.left_hand:
			mid = vs.x - mid
		position = Vector2(mid - size.x * 0.5, vs.y - size.y - 6.0)
	else:
		position = Vector2(vs.x - size.x - 18.0, vs.y - size.y - 18.0)
	_shown = lerpf(_shown, v.speed_kmh(), minf(delta * 8.0, 1.0))
	_shown_rpm = lerpf(_shown_rpm, v.rpm, minf(delta * 10.0, 1.0))
	queue_redraw()


func _radius() -> float:
	return 62.0 if GameManager.touch_mode else 88.0


func _jawa(v: Vehicle) -> bool:
	return v.kind == "moto"


## Приборы «Явы» мельче: два в ряд должны влезть между рулём и педалями.
func _jawa_r() -> float:
	return 40.0 if GameManager.touch_mode else 62.0


func _at(c: Vector2, ang: float, rad: float) -> Vector2:
	return c + Vector2(cos(ang), sin(ang)) * rad


func _draw() -> void:
	var v := _vehicle()
	if v == null:
		return
	# Механика на компьютере — слева от приборов схема рычага и сцепление
	if not SettingsManager.auto_gearbox and not GameManager.touch_mode:
		_draw_gearbox(v)
	if _jawa(v):
		_draw_jawa(v)
		return
	if v.kind == "izh":
		_draw_izh(v)
		return
	var r := _radius()
	var c := size * 0.5
	var top := _max_speed(v)
	var amber := Color(0.95, 0.7, 0.24)
	var cream := Color(0.94, 0.9, 0.81)
	var rim := Color(0.55, 0.55, 0.58, 0.9)
	# Спидометр с базара — с зелёной подсветкой и хромовым ободом
	if v.has_part("speedo"):
		amber = Color(0.35, 1.0, 0.55)
		cream = Color(0.7, 1.0, 0.8)
		rim = Color(0.85, 0.88, 0.92)
		draw_circle(c, r + 7.0, Color(0.2, 1.0, 0.45, 0.18))
	# Корпус прибора
	draw_circle(c, r + 3.0, Color(0.05, 0.05, 0.06, 0.75))
	draw_arc(c, r + 2.0, 0.0, TAU, 64, rim, 3.5 if v.has_part("speedo") else 2.5)
	# Деления: мелкие каждые 10 км/ч, крупные с цифрами — каждые 20
	var s := 0
	while s <= int(top):
		var a := START + SWEEP * s / top
		# На маленьком приборе (телефон) цифры реже — иначе теснятся
		var big := s % (40 if r < 70.0 else 20) == 0
		var col := cream if s < top - 20 else Color(1.0, 0.35, 0.25)
		draw_line(_at(c, a, r - (12.0 if big else 7.0)), _at(c, a, r - 2.0), col, 2.5 if big else 1.5)
		if big:
			var txt := str(s)
			var fs := 12 if r < 70.0 else 15
			var p := _at(c, a, r - (21.0 if r < 70.0 else 24.0)) - Vector2(_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5, -fs * 0.35)
			draw_string(_font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cream)
		s += 10
	# Тахометр — внутренняя дуга, у отсечки красная
	var k := clampf(v.rpm / (v.spec.redline as float), 0.0, 1.0)
	var tr := r * 0.52
	draw_arc(c, tr, START, START + SWEEP, 40, Color(1, 1, 1, 0.12), 5.0)
	if k > 0.01:
		var tcol := amber if k < 0.85 else Color(1.0, 0.3, 0.2)
		draw_arc(c, tr, START, START + SWEEP * k, 40, tcol, 5.0)
	# Стрелка
	var a := START + SWEEP * clampf(_shown / top, 0.0, 1.02)
	draw_line(_at(c, a + PI, r * 0.12), _at(c, a, r - 6.0), Color(1.0, 0.35, 0.2), 3.0)
	draw_circle(c, 5.0, Color(0.2, 0.2, 0.22))
	# Скорость цифрами, передача и бензин
	var fs_big := 24 if r < 70.0 else 30
	var sp := str(int(round(_shown)))
	draw_string(_font, c + Vector2(-_font.get_string_size(sp, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_big).x * 0.5, r * 0.42),
		sp, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_big, Color.WHITE)
	var unit := "км/ч"
	draw_string(_font, c + Vector2(-_font.get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x * 0.5, r * 0.58),
		unit, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
	var gear := v.gear_name()
	draw_string(_font, c + Vector2(-_font.get_string_size(gear, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * 0.5, -r * 0.18),
		gear, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, amber)
	# Зелёные стрелки поворотников по бокам от передачи
	for d in [-1, 1]:
		var lit: bool = v.blink_on() and v.turn == d
		var ac: Vector2 = c + Vector2(d * r * 0.36, -r * 0.24)
		var w := r * 0.11
		draw_colored_polygon(PackedVector2Array([ac + Vector2(d * w, 0), ac + Vector2(-d * w * 0.6, -w * 0.8), ac + Vector2(-d * w * 0.6, w * 0.8)]),
			Color(0.2, 0.95, 0.35) if lit else Color(1, 1, 1, 0.12))
	# Бензин — полоска под прибором
	var fuel := clampf(v.fuel / v.tank(), 0.0, 1.0)
	var w := r * 0.8
	var fy := c.y + r * 0.78
	draw_rect(Rect2(c.x - w * 0.5, fy, w, 5.0), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(c.x - w * 0.5, fy, w * fuel, 5.0), Color(0.95, 0.3, 0.2) if fuel < 0.15 else Color(0.4, 0.8, 0.45))


## Приборы «Явы 350», как настоящие: слева спидометр, справа тахометр —
## чёрные циферблаты в хромированных ободках, белые цифры, белые стрелки с
## большой белой серединой; у тахометра зелёный сектор «ECONOMIC» и красная
## риска на отсечке. Между ними пульт «JAWA» с лампочками: зарядка (мотор
## заглушён), дальний свет, нейтраль, поворот. Внизу — передача и бензин.
func _draw_jawa(v: Vehicle) -> void:
	var r := _jawa_r()
	var gapw := r * 0.9
	var cs := Vector2(4.0 + r, 4.0 + r)
	var ct := Vector2(4.0 + r * 3.0 + gapw, 4.0 + r)
	var white := Color(0.96, 0.96, 0.94)
	var fs := 10 if r < 50.0 else 13
	# Спидометр 0–140 км/ч, цифры через 20 и одометр
	_jawa_face(cs, r)
	var top := 140.0
	var s := 0
	while s <= int(top):
		var a := START + SWEEP * s / top
		var big := s % 20 == 0
		draw_line(_at(cs, a, r - (9.0 if big else 5.0)), _at(cs, a, r - 3.0), white, 2.0 if big else 1.2)
		if big:
			var txt := str(s)
			var p := _at(cs, a, r - (17.0 if r < 50.0 else 22.0)) - Vector2(_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5, -fs * 0.35)
			draw_string(_font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, white)
		s += 10
	var km := int(float(Achievements.counts.get("drive_m", 0.0)) / 1000.0) % 100000
	var odo := "%05d" % km
	var ow := _font.get_string_size(odo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_rect(Rect2(cs + Vector2(-ow * 0.5 - 3.0, r * 0.18), Vector2(ow + 6.0, fs + 4.0)), Color(0.85, 0.85, 0.82))
	draw_string(_font, cs + Vector2(-ow * 0.5, r * 0.18 + fs), odo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.05, 0.05, 0.05))
	draw_string(_font, cs + Vector2(-_font.get_string_size("km/h", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2).x * 0.5, -r * 0.3), "km/h", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2, white)
	_jawa_needle(cs, r, clampf(_shown / top, 0.0, 1.02))
	# Тахометр 0–10 ×1000: зелёный «ECONOMIC», красная риска на 6
	_jawa_face(ct, r)
	draw_arc(ct, r * 0.62, START + SWEEP * 0.26, START + SWEEP * 0.4, 12, Color(0.2, 0.75, 0.35), r * 0.5)
	for i in 11:
		var a := START + SWEEP * i / 10.0
		draw_line(_at(ct, a, r - 9.0), _at(ct, a, r - 3.0), white, 2.0)
		var txt := str(i)
		var p := _at(ct, a, r - (17.0 if r < 50.0 else 22.0)) - Vector2(_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5, -fs * 0.35)
		draw_string(_font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, white)
	var red := clampf(float(v.spec.redline) / 10000.0, 0.0, 1.0)
	draw_line(_at(ct, START + SWEEP * red, r - 12.0), _at(ct, START + SWEEP * red, r - 2.0), Color(0.95, 0.2, 0.15), 3.0)
	var rpmt := "r.p.m. ×1000"
	draw_string(_font, ct + Vector2(-_font.get_string_size(rpmt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 3).x * 0.5, r * 0.42), rpmt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 3, white)
	_jawa_needle(ct, r, clampf(_shown_rpm / 10000.0, 0.0, 1.0))
	# Пульт между приборами: «JAWA» и четыре лампочки
	var pc := Vector2(4.0 + r * 2.0 + gapw * 0.5, 4.0 + r)
	var pw := gapw * 0.95
	draw_rect(Rect2(pc - Vector2(pw * 0.5, r * 0.75), Vector2(pw, r * 1.5)), Color(0.07, 0.07, 0.08, 0.92))
	var jt := "JAWA"
	draw_string(_font, pc + Vector2(-_font.get_string_size(jt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 1).x * 0.5, -r * 0.48), jt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 1, Color(0.75, 0.75, 0.78))
	var on := [not v.engine_on, v.headlights_on(), v.gear == 0, v.blink_on()]
	var cols := [Color(0.95, 0.15, 0.12), Color(0.2, 0.45, 1.0), Color(0.15, 0.85, 0.35), Color(0.15, 0.85, 0.6)]
	var lr := r * 0.13
	for i in 4:
		var lp := pc + Vector2((-1.0 if i % 2 == 0 else 1.0) * pw * 0.24, -r * 0.08 + (i / 2) * r * 0.42)
		draw_circle(lp, lr + 2.0, Color(0.25, 0.25, 0.27))
		var col: Color = cols[i]
		draw_circle(lp, lr, col if on[i] else col.darkened(0.75))
	# Передача и бензин — под приборами
	var gear := v.gear_name()
	var gy := r * 2.0 + 20.0
	draw_string(_font, Vector2(pc.x - _font.get_string_size(gear, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x * 0.5, gy), gear, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.7, 0.24))
	var fuel := clampf(v.fuel / v.tank(), 0.0, 1.0)
	var fw := r * 1.4
	draw_rect(Rect2(ct.x - fw * 0.5, gy - 9.0, fw, 5.0), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(ct.x - fw * 0.5, gy - 9.0, fw * fuel, 5.0), Color(0.95, 0.3, 0.2) if fuel < 0.15 else Color(0.4, 0.8, 0.45))
	var sp := str(int(round(_shown)))
	draw_string(_font, Vector2(cs.x - _font.get_string_size(sp, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x * 0.5, gy), sp, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, white)


func _jawa_face(c: Vector2, r: float) -> void:
	draw_circle(c, r + 3.0, Color(0.55, 0.56, 0.58))
	draw_circle(c, r + 1.0, Color(0.82, 0.83, 0.85))
	draw_circle(c, r - 1.0, Color(0.03, 0.03, 0.035, 0.96))


func _jawa_needle(c: Vector2, r: float, k: float) -> void:
	var a := START + SWEEP * k
	draw_line(_at(c, a + PI, r * 0.1), _at(c, a, r - 8.0), Color(0.97, 0.97, 0.95), 3.0)
	draw_circle(c, r * 0.17, Color(0.97, 0.97, 0.95))


## Схема коробки для механики: у машины — «H» (1 и 2, 3 и 4, 5 и R по
## колонкам, посередине нейтраль), у мотоцикла — столбик 1-N-2-3-4.
## Включённая передача горит янтарём. Справа — полоска сцепления (насколько
## выжато), внизу — подсказка, какими клавишами переключать.
func _draw_gearbox(v: Vehicle) -> void:
	var pw := 150.0
	var ph := 128.0
	var o := Vector2(-pw - 10.0, size.y - ph - 4.0)
	draw_rect(Rect2(o, Vector2(pw, ph)), Color(0.05, 0.05, 0.06, 0.75))
	draw_rect(Rect2(o, Vector2(pw, ph)), Color(0.55, 0.55, 0.58, 0.9), false, 2.0)
	var amber := Color(0.95, 0.7, 0.24)
	var dim := Color(0.85, 0.85, 0.82, 0.8)
	var top: int = v._top_gear()
	var has_r := float(v.spec.ratios.get(-1, 0.0)) != 0.0
	var slots: Array = []
	for g in range(1, top + 1):
		slots.append(g)
	if has_r:
		slots.append(-1)
	var area := Rect2(o + Vector2(12, 12), Vector2(pw - 50, ph - 44))
	if v.spec.two_wheels:
		# Мотоцикл: вниз — первая, вверх — вторая и дальше, между ними нейтраль
		var order: Array = [1, 0]
		for g in range(2, top + 1):
			order.append(g)
		order.reverse()
		var step := area.size.y / maxf(order.size() - 1, 1)
		var x := area.get_center().x
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), dim, 3.0)
		for i in order.size():
			var g: int = order[i]
			_gear_dot(Vector2(x, area.position.y + i * step), "N" if g == 0 else str(g), v.gear == g, amber, dim)
	else:
		var cols := int(ceil(slots.size() / 2.0))
		var cw := area.size.x / maxf(cols - 1, 1)
		var mid := area.get_center().y
		draw_line(Vector2(area.position.x, mid), Vector2(area.position.x + cw * (cols - 1), mid), dim, 3.0)
		for c in cols:
			var x := area.position.x + c * cw
			draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), dim, 3.0)
		for i in slots.size():
			var g: int = slots[i]
			var p := Vector2(area.position.x + (i / 2) * cw, area.position.y if i % 2 == 0 else area.end.y)
			_gear_dot(p, "R" if g == -1 else str(g), v.gear == g, amber, dim)
		# Нейтраль — точка посередине
		_gear_dot(Vector2(area.get_center().x, mid), "N", v.gear == 0, amber, dim, 9.0)
	# Сцепление: полоска справа, заполнена настолько, насколько выжато
	var cb := Rect2(o + Vector2(pw - 26, 12), Vector2(12, ph - 44))
	draw_rect(cb, Color(1, 1, 1, 0.15))
	var k := clampf(1.0 - v.clutch, 0.0, 1.0)
	draw_rect(Rect2(cb.position + Vector2(0, cb.size.y * (1.0 - k)), Vector2(cb.size.x, cb.size.y * k)), Color(0.4, 0.8, 1.0))
	draw_string(_font, cb.position + Vector2(-6, cb.size.y + 14), "сц.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, dim)
	var hint := "%s сц. · 1–5 · 0 N · %s R" % [KeyRemap.key_name(KeyRemap.key_for(KEY_SHIFT)), KeyRemap.key_name(KeyRemap.key_for(KEY_MINUS))]
	draw_string(_font, o + Vector2(6, ph - 8), hint, HORIZONTAL_ALIGNMENT_LEFT, pw - 8, 10, dim)


func _gear_dot(p: Vector2, label: String, on: bool, amber: Color, dim: Color, r := 11.0) -> void:
	draw_circle(p, r, amber if on else Color(0.15, 0.15, 0.17))
	draw_arc(p, r, 0.0, TAU, 20, dim, 1.5)
	var fs := 13
	var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, p + Vector2(-w * 0.5, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.05, 0.05, 0.05) if on else Color.WHITE)


## Приборы «ИЖ Юпитер-5», как настоящий щиток: два чёрных корпуса. Слева
## блок лампочек с подписями — ПОВОРОТ (мигает), ЗАЖИГАНИЕ (мотор не
## заведён), ДАЛЬНИЙ СВЕТ, НЕЙТРАЛЬ, МАСЛО (мотор стоит — давления нет)
## и значок «ИЖ»; справа спидометр до 160 с одометром и суточным счётчиком.
func _draw_izh(v: Vehicle) -> void:
	var r := _jawa_r()
	var white := Color(0.96, 0.96, 0.94)
	var bw := r * 2.5
	var lb := Rect2(Vector2(4, 4), Vector2(bw, r * 2.0))
	var cs := Vector2(lb.end.x + 8.0 + r, 4.0 + r)
	# Корпуса: скруглённые, чёрные, с серым краем
	var body := StyleBoxFlat.new()
	body.bg_color = Color(0.06, 0.06, 0.07, 0.95)
	body.border_color = Color(0.35, 0.35, 0.37)
	body.set_border_width_all(2)
	body.set_corner_radius_all(int(r * 0.35))
	draw_style_box(body, lb)
	draw_style_box(body, Rect2(cs - Vector2(r + 3.0, r + 3.0), Vector2(r * 2.0 + 6.0, r * 2.0 + 6.0)))
	# Лампочки: верхний ряд — поворот и зажигание, нижний — дальний, нейтраль, масло
	var fs := 7 if r < 50.0 else 9
	var q := r * 0.36
	var lamps := [
		["ПОВОРОТ", Color(0.95, 0.5, 0.15), v.blink_on(), "turn"],
		["ЗАЖИГАНИЕ", Color(0.85, 0.15, 0.2), not v.engine_on, "battery"],
		["ДАЛЬН. СВЕТ", Color(0.25, 0.45, 1.0), v.headlights_on(), "beam"],
		["НЕЙТРАЛЬ", Color(0.2, 0.75, 0.4), v.gear == 0, "N"],
		["МАСЛО", Color(0.85, 0.15, 0.2), not v.engine_on, "oil"],
	]
	for i in lamps.size():
		var L: Array = lamps[i]
		var row := 0 if i < 2 else 1
		var col: float = 0.0 if row == 0 else (i - 2.0)
		var cx := lb.position.x + bw * (0.3 + i * 0.4) if row == 0 else lb.position.x + bw * (1.0 / 6.0 + col / 3.0)
		var cy := lb.position.y + r * (0.42 if row == 0 else 1.02)
		var c: Color = L[1]
		var on: bool = L[2]
		var sq := Rect2(Vector2(cx - q * 0.5, cy - q * 0.5), Vector2(q, q))
		draw_rect(sq, c if on else c.darkened(0.72))
		draw_rect(sq, Color(0.6, 0.6, 0.62), false, 1.0)
		_izh_icon(String(L[3]), sq, Color.WHITE if on else Color(1, 1, 1, 0.55))
		# Подпись — не шире своей колонки: шрифт мельче, пока не влезет
		var t: String = L[0]
		var tf := fs
		var tw := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tf).x
		var room := bw * (0.4 if row == 0 else 1.0 / 3.0) - 3.0
		while tw > room and tf > 5:
			tf -= 1
			tw = _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tf).x
		draw_string(_font, Vector2(cx - tw * 0.5, sq.end.y + tf + 1.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, tf, Color(0.9, 0.85, 0.7))
	var logo := "ИЖ"
	var lw := _font.get_string_size(logo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 5).x
	draw_string(_font, Vector2(lb.get_center().x - lw * 0.5, lb.end.y - 6.0), logo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 5, Color(0.4, 0.4, 0.42))
	# Спидометр 0–160: деления через 10, цифры через 20, одометр и суточный
	draw_circle(cs, r - 1.0, Color(0.03, 0.03, 0.035))
	var top := 160.0
	var sfs := 10 if r < 50.0 else 13
	var s := 0
	while s <= int(top):
		var a := START + SWEEP * s / top
		var big := s % 20 == 0
		draw_line(_at(cs, a, r - (9.0 if big else 5.0)), _at(cs, a, r - 2.0), white, 2.0 if big else 1.2)
		if big:
			var txt := str(s)
			var p := _at(cs, a, r - (17.0 if r < 50.0 else 22.0)) - Vector2(_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x * 0.5, -sfs * 0.35)
			draw_string(_font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, white)
		s += 10
	var km := int(float(Achievements.counts.get("drive_m", 0.0)) / 1000.0) % 100000
	# Счётчики — внизу, в просвете шкалы между 0 и 160: суточный выше,
	# общий ниже; надпись km/h — над осью стрелки
	var cf := maxi(sfs - 3, 6)
	if r >= 50.0:
		_izh_counter(cs + Vector2(0, r * 0.46), "%04d" % (int(float(Achievements.counts.get("drive_m", 0.0)) / 100.0) % 10000), true, cf)
		_izh_counter(cs + Vector2(0, r * 0.74), "%05d" % km, false, cf)
	else:
		# На маленьком приборе (телефон) — только общий пробег
		_izh_counter(cs + Vector2(0, r * 0.66), "%05d" % km, false, cf)
	var unit := "km/h"
	draw_string(_font, cs + Vector2(-_font.get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, cf).x * 0.5, -r * 0.26), unit, HORIZONTAL_ALIGNMENT_LEFT, -1, cf, white)
	_jawa_needle(cs, r, clampf(_shown / top, 0.0, 1.02))
	# Передача и бензин
	var gy := r * 2.0 + 20.0
	var gear := v.gear_name()
	draw_string(_font, Vector2(lb.get_center().x - _font.get_string_size(gear, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x * 0.5, gy), gear, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.7, 0.24))
	var fuel := clampf(v.fuel / v.tank(), 0.0, 1.0)
	var fw := r * 1.4
	draw_rect(Rect2(cs.x - fw * 0.5, gy - 9.0, fw, 5.0), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(cs.x - fw * 0.5, gy - 9.0, fw * fuel, 5.0), Color(0.95, 0.3, 0.2) if fuel < 0.15 else Color(0.4, 0.8, 0.45))


## Счётчик километров: белые цифры в чёрных окошках; у суточного последняя
## цифра — на красном.
func _izh_counter(c: Vector2, digits: String, trip: bool, fs: int) -> void:
	var dw := _font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 2.0
	var w := dw * digits.length()
	var x0 := c.x - w * 0.5
	draw_rect(Rect2(Vector2(x0 - 2.0, c.y - fs * 0.85), Vector2(w + 4.0, fs + 3.0)), Color(0.75, 0.75, 0.72))
	for i in digits.length():
		var red := trip and i == digits.length() - 1
		var cell := Rect2(Vector2(x0 + i * dw, c.y - fs * 0.8), Vector2(dw - 1.0, fs + 1.0))
		draw_rect(cell, Color(0.75, 0.12, 0.1) if red else Color(0.04, 0.04, 0.05))
		draw_string(_font, Vector2(cell.position.x + 1.0, c.y + fs * 0.15), digits[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## Значки на лампочках: стрелки поворота, аккумулятор, фара, «N», маслёнка.
func _izh_icon(kind: String, sq: Rect2, col: Color) -> void:
	var c := sq.get_center()
	var u := sq.size.x * 0.32
	match kind:
		"turn":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 1.2, 0), c + Vector2(-u * 0.3, -u * 0.6), c + Vector2(-u * 0.3, u * 0.6)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(u * 1.2, 0), c + Vector2(u * 0.3, -u * 0.6), c + Vector2(u * 0.3, u * 0.6)]), col)
		"battery":
			draw_rect(Rect2(c - Vector2(u, u * 0.6), Vector2(u * 2.0, u * 1.3)), col, false, 1.5)
			draw_line(c + Vector2(-u * 0.6, -u * 0.6), c + Vector2(-u * 0.6, -u * 0.85), col, 2.0)
			draw_line(c + Vector2(u * 0.6, -u * 0.6), c + Vector2(u * 0.6, -u * 0.85), col, 2.0)
		"beam":
			draw_arc(c + Vector2(-u * 0.2, 0), u * 0.7, PI * 0.5, PI * 1.5, 10, col, 1.5)
			for k in 3:
				var y := -u * 0.5 + k * u * 0.5
				draw_line(c + Vector2(u * 0.1, y), c + Vector2(u * 1.1, y), col, 1.5)
		"N":
			var fsz := int(sq.size.y * 0.8)
			var w := _font.get_string_size("N", HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
			draw_string(_font, Vector2(c.x - w * 0.5, c.y + fsz * 0.35), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, col)
		"oil":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-u, 0), c + Vector2(u * 0.5, 0), c + Vector2(u * 0.5, u * 0.7), c + Vector2(-u, u * 0.7)]), col)
			draw_line(c + Vector2(u * 0.5, u * 0.1), c + Vector2(u * 1.2, -u * 0.4), col, 2.0)
			draw_circle(c + Vector2(u * 1.25, -u * 0.1), u * 0.12, col)
