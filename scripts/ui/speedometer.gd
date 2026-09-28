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
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	visible = false


func _vehicle() -> Vehicle:
	var v := GameManager.vehicle as Vehicle
	return v if v and v.driver else null


func _max_speed(v: Vehicle) -> float:
	return {"moto": 140.0, "truck": 120.0, "tractor": 40.0}.get(v.kind, 160.0)


func _process(delta: float) -> void:
	var v := _vehicle()
	visible = v != null
	if v == null:
		_shown = 0.0
		return
	var r := _radius()
	size = Vector2(r * 2.0 + 8.0, r * 2.0 + 8.0)
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
	queue_redraw()


func _radius() -> float:
	return 62.0 if GameManager.touch_mode else 88.0


func _at(c: Vector2, ang: float, rad: float) -> Vector2:
	return c + Vector2(cos(ang), sin(ang)) * rad


func _draw() -> void:
	var v := _vehicle()
	if v == null:
		return
	var r := _radius()
	var c := size * 0.5
	var top := _max_speed(v)
	var amber := Color(0.95, 0.7, 0.24)
	var cream := Color(0.94, 0.9, 0.81)
	# Корпус прибора
	draw_circle(c, r + 3.0, Color(0.05, 0.05, 0.06, 0.75))
	draw_arc(c, r + 2.0, 0.0, TAU, 64, Color(0.55, 0.55, 0.58, 0.9), 2.5)
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
	# Бензин — полоска под прибором
	var fuel := clampf(v.fuel / v.tank(), 0.0, 1.0)
	var w := r * 0.8
	var fy := c.y + r * 0.78
	draw_rect(Rect2(c.x - w * 0.5, fy, w, 5.0), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(c.x - w * 0.5, fy, w * fuel, 5.0), Color(0.95, 0.3, 0.2) if fuel < 0.15 else Color(0.4, 0.8, 0.45))
