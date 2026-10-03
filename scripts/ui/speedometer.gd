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
	if _jawa(v):
		_draw_jawa(v)
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
