class_name TownSouth
extends Node3D
## Южная часть города за пятиэтажками: улица к вокзалу, вокзал у платформы
## «Каменка», рынок с прилавками и продавцами, школа, стадион (вечером там
## гоняют мяч), гаражный кооператив, завод «Искра» с дымящей трубой за
## железной дорогой. На перекрёстке центральных улиц — светофоры, по
## тротуарам ходят прохожие.

const Villagers := preload("res://scripts/world/villagers.gd")
const MARKET := Rect2(42, 128, 44, 32)
const STATION_HALL := Rect2(82, 189, 30, 8)
## Школьный двор в мире (School.YARD, сдвинутый на School.ORIGIN) и подъезд к нему.
const SCHOOL := Rect2(-16, 70, 54, 58)
const SCHOOL_ROAD := Rect2(5, 54, 36, 16)
const STADIUM := Rect2(130, 134, 60, 52)
const GARAGES := Rect2(207, 62, 27, 36)
const FACTORY := Rect2(140, 213, 76, 30)
const MARKET_PRICE := 60
## Перекрёсток центральных улиц — там светофоры.
const CROSS := Vector3(97.0, 0, 58.0)
const SEE := 260.0

var walkers: Array[Dictionary] = []
var players: Array[Dictionary] = []
var ball: MeshInstance3D
var _ball_to := Vector3.ZERO
var _lights: Array[Dictionary] = []
var _smoke: CPUParticles3D
var _rng := RandomNumberGenerator.new()
var _t := 0.0


## Занято ли место постройками южной части (для леса и травы района).
static func occupied(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	return FACTORY.grow(4.0).has_point(p) or GARAGES.grow(2.0).has_point(p)


func build(b: MeshBuilder, glow: MeshBuilder, veg: Vegetation) -> void:
	_rng.seed = 4242
	for r in [MARKET, STATION_HALL, SCHOOL, SCHOOL_ROAD, STADIUM, GARAGES, FACTORY, Rect2(78, 176, 38, 14), Rect2(91, 98, 12, 80), Rect2(100, 149, 31, 8), Rect2(85, 140, 10, 8), Rect2(189, 54, 18, 18)]:
		var g := (r as Rect2).grow(1.5)
		veg.block(g.position.x, g.position.y, g.end.x, g.end.y)
	_streets(b)
	_station(b, glow)
	_market(b)
	_school(b, glow)
	_stadium(b, glow)
	_garages(b)
	_factory(b, glow)
	_traffic_lights(b)
	_pedestrians()


# --- Улицы --------------------------------------------------------------------

func _streets(b: MeshBuilder) -> void:
	var asphalt := Color(0.3, 0.3, 0.31)
	var curb := Color(0.6, 0.6, 0.58)
	# Улица к вокзалу — продолжение центральной на юг, тротуары по бокам
	b.box(Vector3(94, 0, 99), Vector3(100, 0.05, 177), asphalt)
	# Бордюры с разрывами под съезды к рынку и стадиону
	for c in [[92.0, 101.0, 141.0], [92.0, 147.0, 172.0], [100.0, 112.0, 150.0], [100.0, 156.0, 172.0]]:
		b.box(Vector3(c[0], 0, c[1]), Vector3(c[0] + 2.0, 0.12, c[2]), curb)
	var z := 104.0
	while z < 174.0:
		b.box(Vector3(96.9, 0.05, z), Vector3(97.1, 0.06, z + 3.0), Color(0.92, 0.92, 0.9))
		z += 6.0
	# Привокзальная площадь
	b.box(Vector3(78, 0, 176), Vector3(116, 0.06, 189), Color(0.5, 0.5, 0.49))
	# Проезд к гаражам — продолжение поперечной улицы
	b.box(Vector3(190, 0, 55), Vector3(200, 0.05, 61), asphalt)
	b.box(Vector3(200, 0, 55), Vector3(206, 0.04, 71), Color(0.46, 0.43, 0.38))
	# К стадиону и рынку — съезды с улицы
	b.box(Vector3(100, 0, 150), Vector3(STADIUM.position.x, 0.05, 156), asphalt)
	b.box(Vector3(MARKET.end.x, 0, 141), Vector3(94, 0.05, 147), asphalt)
	# Зебры у вокзала и на перекрёстке
	for i in 7:
		b.box(Vector3(94.3 + i * 0.85, 0.05, 172), Vector3(94.8 + i * 0.85, 0.07, 175), Color(0.92, 0.92, 0.9))
	for i in 7:
		b.box(Vector3(94.3 + i * 0.85, 0.05, 63), Vector3(94.8 + i * 0.85, 0.07, 66), Color(0.92, 0.92, 0.9))


# --- Вокзал -------------------------------------------------------------------

## Вокзал: жёлтое здание с белыми пилястрами, часами и надписью, двери на
## площадь и к платформе, фонари.
func _station(b: MeshBuilder, glow: MeshBuilder) -> void:
	var r := STATION_HALL
	var wall := Color(0.9, 0.78, 0.45)
	var white := Color(0.93, 0.92, 0.88)
	b.box(Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 6.0, r.end.y), wall, true)
	b.box(Vector3(r.position.x - 0.3, 6.0, r.position.y - 0.3), Vector3(r.end.x + 0.3, 6.4, r.end.y + 0.3), white)
	b.box(Vector3(r.position.x, 6.4, r.position.y + 0.5), Vector3(r.end.x, 7.4, r.end.y - 0.5), Color(0.4, 0.45, 0.42))
	# Центральный портал выше, с часами
	var cx := r.get_center().x
	b.box(Vector3(cx - 5, 0, r.position.y - 0.4), Vector3(cx + 5, 8.5, r.end.y + 0.4), wall.lightened(0.05), true)
	b.box(Vector3(cx - 5.2, 8.5, r.position.y - 0.6), Vector3(cx + 5.2, 8.9, r.end.y + 0.6), white)
	for zf in [r.position.y - 0.45, r.end.y + 0.41]:
		b.box(Vector3(cx - 0.8, 6.6, zf), Vector3(cx + 0.8, 8.2, zf + 0.04), white)
		b.box(Vector3(cx - 0.05, 7.4, zf - 0.01), Vector3(cx + 0.05, 8.0, zf + 0.06), Color(0.1, 0.1, 0.1))
		b.box(Vector3(cx - 0.05, 7.35, zf - 0.01), Vector3(cx + 0.45, 7.45, zf + 0.06), Color(0.1, 0.1, 0.1))
		b.box(Vector3(cx - 1.2, 0, zf), Vector3(cx + 1.2, 3.0, zf + 0.04), Color(0.4, 0.28, 0.2))
	# Окна-арки и пилястры
	var x := r.position.x + 2.0
	while x < r.end.x - 1.0:
		if absf(x - cx) > 5.5:
			for zf in [r.position.y - 0.02, r.end.y - 0.02]:
				b.box(Vector3(x - 0.8, 1.2, zf), Vector3(x + 0.8, 4.2, zf + 0.04), white)
				glow.box(Vector3(x - 0.65, 1.3, zf - 0.01), Vector3(x + 0.65, 4.0, zf + 0.05), Color(0.95, 0.85, 0.55))
			b.box(Vector3(x + 1.4, 0, r.position.y - 0.12), Vector3(x + 1.7, 6.0, r.end.y + 0.12), white)
		x += 3.2
	_label("ВОКЗАЛ", Vector3(cx, 5.6, r.position.y - 0.46), PI, 110)
	_label("КАМЕНКА", Vector3(cx, 5.6, r.end.y + 0.46), 0.0, 110)
	for lx in [80.0, 114.0]:
		b.box(Vector3(lx - 0.1, 0, 180), Vector3(lx + 0.1, 5.5, 180.2), Color(0.3, 0.3, 0.32))
		glow.box(Vector3(lx - 0.3, 5.3, 179.8), Vector3(lx + 0.3, 5.6, 180.6), Color(1.0, 0.85, 0.55))
	# Скамейки на площади
	for bx in [84.0, 90.0, 104.0, 110.0]:
		b.box(Vector3(bx - 1.0, 0.4, 184), Vector3(bx + 1.0, 0.47, 184.5), Color(0.5, 0.38, 0.25), true)


func _label(text: String, p: Vector3, yaw: float, size: int) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = 0
	l.position = p
	l.rotation.y = yaw
	l.modulate = Color(1, 1, 1)
	l.visibility_range_end = 250.0
	add_child(l)


# --- Рынок --------------------------------------------------------------------

## Рынок: два ряда прилавков под полосатыми навесами, на прилавках —
## овощи, фрукты, банки; за прилавками — продавцы. Купить — у любого.
func _market(b: MeshBuilder) -> void:
	var r := MARKET
	b.box(Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0.05, r.end.y), Color(0.5, 0.5, 0.48))
	var awn := [Color(0.8, 0.2, 0.15), Color(0.2, 0.45, 0.75), Color(0.25, 0.6, 0.3), Color(0.9, 0.7, 0.15)]
	var goods := [Color(0.85, 0.2, 0.1), Color(0.95, 0.6, 0.1), Color(0.5, 0.35, 0.2), Color(0.3, 0.55, 0.2), Color(0.9, 0.85, 0.3), Color(0.6, 0.2, 0.4)]
	var k := 0
	for row in [r.position.y + 8.0, r.position.y + 22.0]:
		var x := r.position.x + 4.0
		while x < r.end.x - 5.0:
			var a: Color = awn[k % awn.size()]
			# Прилавок, стойки, полосатый навес
			b.box(Vector3(x, 0, row), Vector3(x + 5.0, 1.0, row + 1.2), Color(0.55, 0.42, 0.28), true)
			for px in [x, x + 4.9]:
				for pz in [row, row + 2.9]:
					b.box(Vector3(px, 0, pz), Vector3(px + 0.1, 2.5, pz + 0.1), Color(0.4, 0.4, 0.42))
			var s := 0.0
			while s < 5.0:
				b.quad(Vector3(x + s, 2.7, row - 0.3), Vector3(x + s + 0.5, 2.7, row - 0.3), Vector3(x + s + 0.5, 2.4, row + 3.2), Vector3(x + s, 2.4, row + 3.2),
					a if int(s * 2.0) % 2 == 0 else Color(0.95, 0.95, 0.92), true)
				s += 0.5
			# Товар кучками и ящиками
			for g in 5:
				var gc: Color = goods[(k * 3 + g) % goods.size()]
				var gx := x + 0.3 + g * 0.95
				b.box(Vector3(gx, 1.0, row + 0.15), Vector3(gx + 0.8, 1.12, row + 1.05), Color(0.6, 0.48, 0.3))
				b.box(Vector3(gx + 0.08, 1.12, row + 0.25), Vector3(gx + 0.72, 1.3, row + 0.95), gc)
			# Продавец за прилавком
			var pb := MeshBuilder.new()
			pb.ground_shade = false
			Villagers.person_model(pb, awn[(k + 1) % awn.size()].lightened(0.2), Color(0.3, 0.25, 0.2), false, k % 2 == 0)
			var seller := pb.build_mesh()
			seller.position = Vector3(x + 2.5, 0, row + 2.1)
			seller.rotation.y = 0.0
			seller.visibility_range_end = 150.0
			add_child(seller)
			var zone := InteractZone.create("", Vector3(4.6, 2.0, 1.6))
			zone.position = Vector3(x + 2.5, 0, row - 0.8)
			zone.prompt_fn = func() -> String:
				var h := TimeManager.hour()
				if h < 7.0 or h >= 16.0:
					return "Рынок работает с 7:00 до 16:00"
				return "E — купить овощи, сало и молоко (%d грн)" % MARKET_PRICE
			zone.activated.connect(buy)
			add_child(zone)
			x += 7.0
			k += 1
	# Ворота с вывеской «РЫНОК» со стороны улицы
	for gz in [r.position.y + 12.0, r.position.y + 20.0]:
		b.box(Vector3(r.end.x - 0.3, 0, gz), Vector3(r.end.x + 0.3, 4.2, gz + 0.3), Color(0.35, 0.4, 0.45), true)
	b.box(Vector3(r.end.x - 0.3, 3.6, r.position.y + 12.0), Vector3(r.end.x + 0.3, 4.6, r.position.y + 20.3), Color(0.2, 0.4, 0.65))
	_label("РЫНОК", Vector3(r.end.x + 0.32, 4.1, r.position.y + 16.15), PI / 2.0, 100)
	# Ограда из сетки по периметру
	for seg in [[Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y)], [Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y)],
			[Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y)]]:
		var a2: Vector2 = seg[0]
		var e2: Vector2 = seg[1]
		b.box(Vector3(minf(a2.x, e2.x) - 0.04, 0, minf(a2.y, e2.y) - 0.04), Vector3(maxf(a2.x, e2.x) + 0.04, 1.6, maxf(a2.y, e2.y) + 0.04), Color(0.55, 0.58, 0.6), true)


## Покупка на рынке: две порции еды в запас.
func buy() -> void:
	var h := TimeManager.hour()
	if h < 7.0 or h >= 16.0:
		GameManager.notify("Рынок работает с 7:00 до 16:00")
		return
	if GameManager.spend(MARKET_PRICE):
		NeedsManager.snacks += 2
		QuestManager.event("market")
		GameManager.notify("Купил на рынке овощей, сала и молока. Съесть — Q")


# --- Школа --------------------------------------------------------------------

## Школа с двором — school.gd: коробка и двор ложатся в общий меш города.
func _school(b: MeshBuilder, glow: MeshBuilder) -> void:
	var school := School.new()
	school.name = "School"
	add_child(school)
	school.build(b, glow)


# --- Стадион ------------------------------------------------------------------

## Стадион «Колос»: поле с разметкой, воротами, беговая дорожка, трибуна
## и мачты освещения. Вечером мальчишки гоняют мяч.
func _stadium(b: MeshBuilder, glow: MeshBuilder) -> void:
	var r := STADIUM
	var track := Rect2(r.position.x + 2, r.position.y + 2, 48, 48)
	b.box(Vector3(track.position.x, 0, track.position.y), Vector3(track.end.x, 0.04, track.end.y), Color(0.62, 0.3, 0.22))
	var f := track.grow(-4.0)
	b.box(Vector3(f.position.x, 0, f.position.y), Vector3(f.end.x, 0.06, f.end.y), Color(0.3, 0.55, 0.25))
	var white := Color(0.95, 0.95, 0.92)
	# Разметка: края, средняя линия, штрафные
	for zz in [f.position.y + 0.5, f.end.y - 0.6]:
		b.box(Vector3(f.position.x + 0.5, 0.06, zz), Vector3(f.end.x - 0.5, 0.07, zz + 0.1), white)
	for xx in [f.position.x + 0.5, f.end.x - 0.6]:
		b.box(Vector3(xx, 0.06, f.position.y + 0.5), Vector3(xx + 0.1, 0.07, f.end.y - 0.5), white)
	var cz := f.get_center().y
	b.box(Vector3(f.position.x + 0.5, 0.06, cz - 0.05), Vector3(f.end.x - 0.5, 0.07, cz + 0.05), white)
	for e in [-1.0, 1.0]:
		var gz: float = cz + e * (f.size.y * 0.5 - 0.6)
		var cx := f.get_center().x
		# Ворота: две штанги и перекладина
		for gx in [cx - 3.66, cx + 3.56]:
			b.box(Vector3(gx, 0, gz - 0.05), Vector3(gx + 0.1, 2.44, gz + 0.05), white, true)
		b.box(Vector3(cx - 3.66, 2.34, gz - 0.05), Vector3(cx + 3.66, 2.44, gz + 0.05), white)
		b.box(Vector3(cx - 8.0, 0.06, gz - e * 8.0 - 0.05), Vector3(cx + 8.0, 0.07, gz - e * 8.0 + 0.05), white)
	# Трибуна вдоль восточной стороны: три ступени с лавками
	var sx := track.end.x + 1.0
	for st in 4:
		b.box(Vector3(sx + st * 1.2, 0, track.position.y + 6), Vector3(sx + 1.2 + st * 1.2, 0.5 + st * 0.5, track.end.y - 6), Color(0.6, 0.6, 0.58), true)
		b.box(Vector3(sx + st * 1.2 + 0.2, 0.5 + st * 0.5, track.position.y + 6), Vector3(sx + st * 1.2 + 0.8, 0.62 + st * 0.5, track.end.y - 6),
			[Color(0.8, 0.2, 0.15), Color(0.2, 0.45, 0.75)][st % 2])
	b.box(Vector3(sx, 3.5, track.position.y + 6), Vector3(sx + 5.2, 3.7, track.end.y - 6), Color(0.45, 0.45, 0.47))
	_label("СТАДИОН «КОЛОС»", Vector3(sx + 5.25, 3.0, track.get_center().y), PI / 2.0, 90)
	# Мачты освещения по углам
	for c in [track.position, Vector2(track.end.x, track.position.y), Vector2(track.position.x, track.end.y), track.end]:
		var p: Vector2 = c
		b.box(Vector3(p.x - 0.2, 0, p.y - 0.2), Vector3(p.x + 0.2, 16.0, p.y + 0.2), Color(0.5, 0.5, 0.52), true)
		b.box(Vector3(p.x - 1.2, 16.0, p.y - 0.3), Vector3(p.x + 1.2, 17.2, p.y + 0.3), Color(0.35, 0.35, 0.37))
		glow.box(Vector3(p.x - 1.1, 16.1, p.y - 0.32), Vector3(p.x + 1.1, 17.1, p.y + 0.32), Color(1.0, 0.98, 0.9))
	# Мяч и игроки
	var bm := SphereMesh.new()
	bm.radius = 0.12
	bm.height = 0.24
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 0.95)
	bm.material = mat
	ball = MeshInstance3D.new()
	ball.mesh = bm
	ball.visibility_range_end = SEE
	ball.position = Vector3(f.get_center().x, 0.12, cz)
	add_child(ball)
	_ball_to = ball.position
	for i in 6:
		var pb := MeshBuilder.new()
		pb.ground_shade = false
		Villagers.person_model(pb, Color(0.8, 0.2, 0.15) if i % 2 == 0 else Color(0.2, 0.4, 0.75), Color(0.25, 0.2, 0.15), false, false)
		var mi := Villagers.walking_mesh(pb)
		mi.scale = Vector3.ONE * 0.8
		mi.visibility_range_end = SEE
		mi.position = ball.position + Vector3(_rng.randf_range(-10, 10), -0.12, _rng.randf_range(-10, 10))
		add_child(mi)
		players.append({"mesh": mi, "phase": i * 0.9, "off": Vector3(_rng.randf_range(-4, 4), 0, _rng.randf_range(-4, 4))})


## Мальчишки играют с 16 до 21 — пинают мяч, бегают за ним. В другое время
## мяча и ребят нет.
func _update_football(delta: float) -> void:
	var h := TimeManager.hour()
	var on := h >= 16.0 and h < 21.0
	ball.visible = on
	for p in players:
		(p.mesh as Node3D).visible = on
	if not on:
		return
	var f := Rect2(STADIUM.position.x + 6, STADIUM.position.y + 6, 40, 40)
	var to := _ball_to - ball.position
	if to.length() < 0.3:
		_ball_to = Vector3(_rng.randf_range(f.position.x, f.end.x), 0.12, _rng.randf_range(f.position.y, f.end.y))
	else:
		ball.position += to.normalized() * minf(delta * 5.0, to.length())
	for p in players:
		var mi: MeshInstance3D = p.mesh
		var target: Vector3 = ball.position + (p.off as Vector3)
		target.y = 0.0
		var d := target - mi.position
		d.y = 0.0
		if d.length() > 0.5:
			mi.position += d.normalized() * minf(delta * 3.2, d.length())
			mi.rotation.y = atan2(-d.x, -d.z)
			Villagers.set_walk(mi, _t * 7.0 + float(p.phase), 1.0)
		else:
			Villagers.set_walk(mi, 0.0, 0.0)


# --- Гаражи -------------------------------------------------------------------

## Гаражный кооператив: два ряда кирпичных боксов с железными воротами
## друг напротив друга, проезд между ними.
func _garages(b: MeshBuilder) -> void:
	var r := GARAGES
	b.box(Vector3(r.position.x - 7.0, 0, r.position.y + 8.0), Vector3(r.end.x, 0.04, r.end.y - 8.0), Color(0.46, 0.43, 0.38))
	var gates := [Color(0.35, 0.45, 0.35), Color(0.4, 0.4, 0.45), Color(0.55, 0.35, 0.25), Color(0.3, 0.35, 0.5)]
	for row in [[r.position.y, r.position.y + 7.5, 1.0], [r.end.y - 7.5, r.end.y, -1.0]]:
		var z0: float = row[0]
		var z1: float = row[1]
		var face: float = z1 if row[2] > 0.0 else z0
		b.box(Vector3(r.position.x, 0, z0), Vector3(r.end.x, 2.6, z1), Color(0.62, 0.36, 0.28), true)
		b.box(Vector3(r.position.x - 0.2, 2.6, z0 - 0.2), Vector3(r.end.x + 0.2, 2.8, z1 + 0.2), Color(0.3, 0.3, 0.32))
		var x := r.position.x + 0.4
		var k := 0
		while x + 3.3 < r.end.x:
			var g: Color = gates[(k * 3 + int(z0)) % gates.size()]
			b.box(Vector3(x + 0.35, 0, face - 0.03), Vector3(x + 3.05, 2.2, face + 0.03), g)
			b.box(Vector3(x + 1.68, 0, face - 0.05), Vector3(x + 1.72, 2.2, face + 0.05), g.darkened(0.3))
			x += 3.4
			k += 1
	# Пара машин у ворот и мужики у открытого гаража
	var car := MeshBuilder.new()
	car.ground_shade = false
	car.xf = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(r.position.x + 9.0, 0.05, r.get_center().y - 2.0))
	VehicleModels.zhiguli(car, Color(0.8, 0.75, 0.6), false)
	car.xf = Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(r.position.x + 26.0, 0.05, r.get_center().y + 3.0))
	VehicleModels.zhiguli(car, Color(0.5, 0.15, 0.12), false)
	var cm := car.build_mesh()
	cm.visibility_range_end = 250.0
	add_child(cm)
	for i in 2:
		var pb := MeshBuilder.new()
		pb.ground_shade = false
		Villagers.person_model(pb, Color(0.3, 0.35, 0.45) if i == 0 else Color(0.45, 0.4, 0.3), Color(0.2, 0.2, 0.22), false, false)
		var mi := pb.build_mesh()
		mi.position = Vector3(r.position.x + 12.0 + i * 1.3, 0, r.position.y + 10.0)
		mi.rotation.y = PI * 0.8 + i * 1.8
		mi.visibility_range_end = 150.0
		add_child(mi)
	_label("ГСК «МОТОР»", Vector3(r.position.x - 0.05, 1.8, r.position.y + 3.75), -PI / 2.0, 70)


# --- Завод --------------------------------------------------------------------

## Завод «Искра»: цеха с шедовой крышей, административный корпус,
## бело-красная труба с дымом, бетонный забор с проходной.
func _factory(b: MeshBuilder, glow: MeshBuilder) -> void:
	var r := FACTORY
	var brick := Color(0.6, 0.34, 0.26)
	b.box(Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0.04, r.end.y), Color(0.45, 0.44, 0.42))
	# Цех с пилообразной крышей
	var hx0 := r.position.x + 4.0
	var hx1 := r.position.x + 44.0
	var hz0 := r.position.y + 6.0
	var hz1 := r.end.y - 3.0
	b.box(Vector3(hx0, 0, hz0), Vector3(hx1, 8.0, hz1), brick, true)
	var x := hx0
	while x < hx1 - 0.1:
		b.quad(Vector3(x, 8.0, hz0), Vector3(x, 8.0, hz1), Vector3(x + 4.0, 10.5, hz1), Vector3(x + 4.0, 10.5, hz0), Color(0.45, 0.45, 0.47), true)
		b.quad(Vector3(x + 4.0, 10.5, hz0), Vector3(x + 4.0, 10.5, hz1), Vector3(x + 4.0, 8.0, hz1), Vector3(x + 4.0, 8.0, hz0), Color(0.7, 0.8, 0.85), true)
		x += 4.0
	x = hx0 + 1.5
	while x < hx1 - 2.0:
		b.box(Vector3(x, 3.0, hz0 - 0.03), Vector3(x + 2.5, 6.5, hz0), Color(0.3, 0.35, 0.38))
		glow.box(Vector3(x + 0.1, 3.1, hz0 - 0.05), Vector3(x + 2.4, 6.4, hz0 - 0.02), Color(0.95, 0.85, 0.6))
		x += 4.0
	b.box(Vector3(hx0 + 16, 0, hz0 - 0.05), Vector3(hx0 + 22, 5.5, hz0), Color(0.35, 0.4, 0.38))
	# Административный корпус
	var ax0 := r.position.x + 50.0
	b.box(Vector3(ax0, 0, hz0), Vector3(ax0 + 18.0, 7.0, hz0 + 10.0), Color(0.8, 0.8, 0.76), true)
	for f in 2:
		var wx := ax0 + 1.0
		while wx < ax0 + 17.0:
			b.box(Vector3(wx, 1.2 + f * 3.0, hz0 - 0.03), Vector3(wx + 1.6, 2.7 + f * 3.0, hz0), Color(0.25, 0.3, 0.35))
			wx += 2.4
	_label("ЗАВОД «ИСКРА»", Vector3(ax0 + 9.0, 7.8, hz0 - 0.1), PI, 110)
	b.box(Vector3(ax0 + 2.0, 7.0, hz0 - 0.1), Vector3(ax0 + 16.0, 8.6, hz0), Color(0.2, 0.35, 0.6))
	# Труба: бело-красные полосы, дым сверху
	var tc := Vector2(r.end.x - 6.0, r.end.y - 8.0)
	var y := 0.0
	var k := 0
	while y < 36.0:
		var w := 1.6 - y * 0.015
		b.box(Vector3(tc.x - w, y, tc.y - w), Vector3(tc.x + w, y + 4.0, tc.y + w), Color(0.9, 0.9, 0.88) if k % 2 == 0 else Color(0.8, 0.2, 0.15), y < 4.0)
		y += 4.0
		k += 1
	glow.box(Vector3(tc.x - 1.2, 35.0, tc.y - 1.2), Vector3(tc.x + 1.2, 35.3, tc.y + 1.2), Color(1.0, 0.2, 0.1))
	_smoke = CPUParticles3D.new()
	_smoke.amount = 14
	_smoke.lifetime = 9.0
	_smoke.position = Vector3(tc.x, 36.5, tc.y)
	_smoke.direction = Vector3(0.3, 1, 0.1)
	_smoke.spread = 12.0
	_smoke.initial_velocity_min = 1.5
	_smoke.initial_velocity_max = 2.5
	_smoke.gravity = Vector3(0.6, 0.3, 0.2)
	_smoke.scale_amount_min = 2.0
	_smoke.scale_amount_max = 3.5
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 2.2))
	_smoke.scale_amount_curve = curve
	var pm := QuadMesh.new()
	pm.size = Vector2(2.0, 2.0)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	pm.material = sm
	_smoke.mesh = pm
	var grad := Gradient.new()
	grad.set_color(0, Color(0.75, 0.75, 0.75, 0.55))
	grad.set_color(1, Color(0.85, 0.85, 0.85, 0.0))
	_smoke.color_ramp = grad
	_smoke.visibility_range_end = 1500.0
	add_child(_smoke)
	# Бетонный забор с проходной и воротами со стороны пути
	var fence := Color(0.7, 0.7, 0.67)
	b.box(Vector3(r.position.x, 0, r.position.y), Vector3(r.position.x + 0.2, 2.5, r.end.y), fence, true)
	b.box(Vector3(r.end.x - 0.2, 0, r.position.y), Vector3(r.end.x, 2.5, r.end.y), fence, true)
	b.box(Vector3(r.position.x, 0, r.end.y - 0.2), Vector3(r.end.x, 2.5, r.end.y), fence, true)
	b.box(Vector3(r.position.x, 0, r.position.y), Vector3(r.position.x + 30.0, 2.5, r.position.y + 0.2), fence, true)
	b.box(Vector3(r.position.x + 38.0, 0, r.position.y), Vector3(r.end.x, 2.5, r.position.y + 0.2), fence, true)
	b.box(Vector3(r.position.x + 30.0, 0, r.position.y - 0.1), Vector3(r.position.x + 38.0, 0.3, r.position.y + 0.1), Color(0.4, 0.4, 0.42))
	b.box(Vector3(r.position.x + 38.0, 0, r.position.y + 0.2), Vector3(r.position.x + 42.0, 3.0, r.position.y + 3.5), Color(0.8, 0.8, 0.76), true)


# --- Светофоры ----------------------------------------------------------------

## Светофоры на перекрёстке центральных улиц: улица к вокзалу и поперечная
## по очереди. Лампы — отдельные маленькие меши, меняют цвет.
func _traffic_lights(b: MeshBuilder) -> void:
	for c in [[Vector2(-4.2, -4.2), true], [Vector2(4.2, 4.2), true], [Vector2(4.2, -4.2), false], [Vector2(-4.2, 4.2), false]]:
		var o: Vector2 = c[0]
		var p := CROSS + Vector3(o.x, 0, o.y)
		b.box(p + Vector3(-0.07, 0, -0.07), p + Vector3(0.07, 3.0, 0.07), Color(0.3, 0.3, 0.32), true)
		b.box(p + Vector3(-0.18, 2.1, -0.18), p + Vector3(0.18, 3.2, 0.18), Color(0.12, 0.12, 0.12))
		var lamps := {}
		for n in [["red", 2.95, Color(1, 0.15, 0.1)], ["yellow", 2.65, Color(1, 0.8, 0.1)], ["green", 2.35, Color(0.2, 1, 0.3)]]:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.38, 0.2, 0.38)
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = (n[2] as Color).darkened(0.8)
			bm.material = mat
			mi.mesh = bm
			mi.position = p + Vector3(0, float(n[1]), 0)
			mi.visibility_range_end = 250.0
			add_child(mi)
			lamps[n[0]] = [mat, n[2]]
		_lights.append({"lamps": lamps, "ns": c[1]})


## Цикл: 12 с зелёный улице к вокзалу, 3 с жёлтый, 12 с поперечной, 3 с жёлтый.
static func light_state(t: float, ns: bool) -> String:
	var q := fmod(t, 30.0)
	var s: String
	if q < 12.0:
		s = "green" if ns else "red"
	elif q < 15.0:
		s = "yellow"
	elif q < 27.0:
		s = "red" if ns else "green"
	else:
		s = "yellow"
	return s


# --- Прохожие -----------------------------------------------------------------

## Маршруты прохожих по тротуарам: от пятиэтажек к рынку, вокзалу, школе.
const ROUTES := [
	[Vector3(92.8, 0, 66), Vector3(92.8, 0, 144), Vector3(87.5, 0, 144)],
	[Vector3(101.2, 0, 66), Vector3(101.2, 0, 174), Vector3(97, 0, 180), Vector3(97, 0, 188)],
	# Школьница: по подъезду к воротам школы и по дорожке к крыльцу
	[Vector3(40, 0, 59), Vector3(11, 0, 59), Vector3(11, 0, 96)],
	[Vector3(101.2, 0, 110), Vector3(101.2, 0, 153), Vector3(128, 0, 153)],
	[Vector3(45, 0, 62.5), Vector3(150, 0, 62.5)],
	[Vector3(84, 0, 186), Vector3(110, 0, 186)],
	[Vector3(47, 0, 144.5), Vector3(83, 0, 144.5)],
	[Vector3(101.2, 0, 50), Vector3(101.2, 0, 8.5), Vector3(150, 0, 8.5)],
]


func _pedestrians() -> void:
	var shirts := [Color(0.6, 0.3, 0.25), Color(0.3, 0.4, 0.6), Color(0.45, 0.5, 0.3), Color(0.55, 0.45, 0.6), Color(0.7, 0.6, 0.3), Color(0.35, 0.35, 0.38)]
	for i in ROUTES.size():
		var pb := MeshBuilder.new()
		pb.ground_shade = false
		Villagers.person_model(pb, shirts[i % shirts.size()], Color(0.3, 0.25, 0.2).lightened(0.1 * (i % 3)), false, i % 2 == 1)
		var mi := Villagers.walking_mesh(pb)
		mi.visibility_range_end = SEE
		add_child(mi)
		var route: Array = ROUTES[i]
		walkers.append({"mesh": mi, "route": route, "k": 0, "dir": 1, "t": _rng.randf(), "wait": 0.0, "phase": i * 0.7})
		mi.position = route[0]


func _update_walker(w: Dictionary, delta: float) -> void:
	var mi: MeshInstance3D = w.mesh
	var route: Array = w.route
	if float(w.wait) > 0.0:
		w.wait = float(w.wait) - delta
		Villagers.set_walk(mi, 0.0, 0.0)
		return
	var k: int = w.k
	var nxt: int = k + int(w.dir)
	if nxt < 0 or nxt >= route.size():
		w.dir = -int(w.dir)
		w.wait = _rng.randf_range(3.0, 12.0)
		return
	var target: Vector3 = route[nxt]
	var d := target - mi.position
	if d.length() < 0.2:
		w.k = nxt
		return
	mi.position += d.normalized() * minf(delta * 1.3, d.length())
	mi.rotation.y = atan2(-d.x, -d.z)
	Villagers.set_walk(mi, _t * 4.0 + float(w.phase), 1.0)


func _process(delta: float) -> void:
	_t += delta
	var cam3 := get_viewport().get_camera_3d()
	var cam := cam3.global_position if cam3 else Vector3.ZERO
	var near := Vector2(cam.x, cam.z).distance_to(Vector2(120, 120)) < 350.0
	if near:
		for w in walkers:
			_update_walker(w, delta)
		_update_football(delta)
		for l in _lights:
			var st := light_state(_t, l.ns)
			for n in l.lamps:
				var pair: Array = l.lamps[n]
				(pair[0] as StandardMaterial3D).albedo_color = (pair[1] as Color) if n == st else (pair[1] as Color).darkened(0.8)
