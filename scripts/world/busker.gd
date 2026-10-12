class_name Busker
extends Node3D
## Уличный музыкант у сельмага: парень в длинном чёрном пальто, серой
## футболке, синих джинсах, белых кроссовках и чёрной кепке козырьком
## назад, в ушах наушники. Сидит на лавке с гитарой и играет песни —
## правая рука бьёт по струнам в такт. Перед ним на земле перевёрнутая
## кепка с мелочью и купюрами. По E — кинуть в кепку 10 грн: купюр в кепке
## прибавляется, музыкант кивает и, если молчал, сразу начинает новую песню.
## Днём играет (кроме дождя), поздно вечером уходит домой.

## Где сидит: у торца сельмага, лицом к тропинке от съезда.
const POS := Vector3(-50.6, 0, -30.2)
const YAW := PI
const HOURS := [9.0, 22.0]
const TIP := 10
## Сколько купюр видно в кепке сверх начальных.
const TIPS_SHOWN := 12
const SONGS := ["busker_0", "busker_1"]
## Бой — восьмыми: 100 и 112 ударов в минуту, как в песнях.
const STRUM_HZ := [100.0 / 30.0, 112.0 / 30.0]

const COAT := Color(0.07, 0.07, 0.08)
const TEE := Color(0.72, 0.72, 0.7)
const JEANS := Color(0.24, 0.34, 0.52)
const SNEAKER := Color(0.93, 0.93, 0.91)
const CAP := Color(0.06, 0.06, 0.07)
const SKIN := Color(0.88, 0.7, 0.58)
const HAIR := Color(0.16, 0.13, 0.11)
const WOOD := Color(0.8, 0.55, 0.28)

## Гитара на коленях: середина нижней деки и направление грифа (влево-вверх).
const G0 := Vector3(0.14, 0.64, -0.24)
const GU := Vector3(-0.928, 0.371, 0.0)
const GV := Vector3(0.371, 0.928, 0.0)
## Правый локоть лежит на гитаре — вокруг него рука бьёт по струнам.
const ELBOW := Vector3(0.29, 0.75, -0.1)

var tips := 0
var playing := false
var song := -1

var _body: MeshInstance3D
var _arm: Node3D
var _cap: MeshInstance3D
var _zone: InteractZone
var _player: AudioStreamPlayer3D
var _pause := 2.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("persist")
	_rng.randomize()
	position = POS
	rotation.y = YAW
	var b := MeshBuilder.new()
	body(b)
	_body = b.build_mesh()
	_body.name = "Body"
	add_child(_body)
	_arm = Node3D.new()
	_arm.name = "StrumArm"
	_arm.position = ELBOW
	add_child(_arm)
	var ab := MeshBuilder.new()
	strum_arm(ab)
	var am := ab.build_mesh()
	_arm.add_child(am)
	_build_cap()
	_player = AudioStreamPlayer3D.new()
	_player.unit_size = 5.0
	_player.max_distance = 45.0
	_player.volume_db = -2.0
	_player.finished.connect(func() -> void: _pause = _rng.randf_range(4.0, 9.0))
	add_child(_player)
	_zone = InteractZone.create("", Vector3(3.0, 2.0, 3.0))
	_zone.position = Vector3(0, 0, -1.0)
	_zone.prompt_fn = func() -> String: return "E — кинуть %d грн в кепку музыканту" % TIP
	_zone.activated.connect(tip)
	add_child(_zone)
	for n in [_body, am, _cap]:
		n.visibility_range_end = 120.0


## Лавка с гитаристом стоит у сельмага: доски и ножки — в общий меш мира.
static func bench(b: MeshBuilder) -> void:
	var xf := Transform3D(Basis(Vector3.UP, YAW), POS)
	var keep := b.xf
	b.xf = xf
	var wood := Color(0.5, 0.36, 0.22)
	var iron := Color(0.2, 0.2, 0.22)
	for x in [-0.75, 0.75]:
		b.box(Vector3(x - 0.04, 0, -0.2), Vector3(x + 0.04, 0.4, 0.2), iron)
		b.box(Vector3(x - 0.04, 0.4, 0.14), Vector3(x + 0.04, 0.9, 0.2), iron)
	for i in 3:
		var z := -0.2 + i * 0.13
		b.box(Vector3(-0.95, 0.4, z), Vector3(0.95, 0.44, z + 0.11), wood)
	for i in 2:
		var y := 0.58 + i * 0.16
		b.box(Vector3(-0.95, y, 0.2), Vector3(0.95, y + 0.11, 0.24), wood)
	b.add_collider(Vector3(-0.95, 0, -0.2), Vector3(0.95, 0.9, 0.24))
	b.xf = keep


## Музыкант сидя, с гитарой и левой рукой на грифе (правая — отдельно, она бьёт).
static func body(b: MeshBuilder) -> void:
	PersonModel._mark(b, true)
	var L := PersonModel
	# Ноги в джинсах чуть врозь, белые кроссовки
	for s in [-1.0, 1.0]:
		var hip := Vector3(s * 0.1, 0.5, 0.0)
		var knee := Vector3(s * 0.15, 0.5, -0.42)
		L.limb(b, hip, knee, Vector2(0.088, 0.088), Vector2(0.072, 0.072), JEANS)
		L.ball(b, knee, Vector3(0.07, 0.07, 0.07), JEANS, 3, 6)
		L.limb(b, knee + Vector3(0, -0.01, -0.01), Vector3(s * 0.16, 0.1, -0.47), Vector2(0.066, 0.066), Vector2(0.06, 0.06), JEANS)
		# Подвёрнутый низ штанины
		L.limb(b, Vector3(s * 0.16, 0.14, -0.468), Vector3(s * 0.16, 0.09, -0.47), Vector2(0.068, 0.068), Vector2(0.068, 0.068), JEANS.lightened(0.12), true)
		_sneaker(b, Vector3(s * 0.16, 0.0, -0.48))
	# Таз, ремень
	L.limb(b, Vector3(0, 0.48, 0.0), Vector3(0, 0.6, 0.0), Vector2(0.19, 0.12), Vector2(0.19, 0.12), JEANS)
	# Пальто: полы на коленях и по бокам лавки до самого низа
	for s in [-1.0, 1.0]:
		L.limb(b, Vector3(s * 0.12, 0.55, 0.06), Vector3(s * 0.16, 0.56, -0.36), Vector2(0.1, 0.05), Vector2(0.095, 0.04), COAT)
		L.limb(b, Vector3(s * 0.2, 0.6, 0.02), Vector3(s * 0.22, 0.12, 0.05), Vector2(0.03, 0.1), Vector2(0.025, 0.14), COAT)
	# Туловище: пальто нараспашку, под ним серая футболка
	var waist := 0.6
	var chest := 1.0
	L.limb(b, Vector3(0, waist, 0.0), Vector3(0, chest, 0.0), Vector2(0.18, 0.12), Vector2(0.21, 0.13), COAT)
	L.limb(b, Vector3(0, chest, 0.0), Vector3(0, chest + 0.06, 0.0), Vector2(0.21, 0.13), Vector2(0.12, 0.09), COAT)
	b.box(Vector3(-0.07, waist, -0.135), Vector3(0.07, chest + 0.02, -0.121), TEE)
	b.box(Vector3(-0.05, chest + 0.02, -0.11), Vector3(0.05, chest + 0.06, -0.08), TEE)
	# Лацканы и воротник-стойка
	for s in [-1.0, 1.0]:
		b.quad(Vector3(s * 0.07, waist + 0.15, -0.137), Vector3(s * 0.07, chest + 0.04, -0.125), Vector3(s * 0.15, chest - 0.02, -0.12), Vector3(s * 0.1, waist + 0.15, -0.13), COAT.lightened(0.06), true)
	L.limb(b, Vector3(0, chest + 0.03, 0.01), Vector3(0, chest + 0.1, 0.015), Vector2(0.085, 0.075), Vector2(0.08, 0.072), COAT)
	# Левая рука в рукаве пальто — пальцы на грифе
	var sh := Vector3(-0.2, chest - 0.03, 0.0)
	var fret := G0 + GU * 0.62 + Vector3(0, -0.01, -0.04)
	var el := Vector3(-0.34, 0.72, -0.06)
	L.ball(b, sh, Vector3(0.068, 0.06, 0.07), COAT, 4, 8)
	L.limb(b, sh, el, Vector2(0.058, 0.058), Vector2(0.05, 0.05), COAT)
	L.ball(b, el, Vector3(0.05, 0.05, 0.05), COAT, 3, 6)
	L.limb(b, el, fret + Vector3(0.03, -0.03, 0.02), Vector2(0.05, 0.05), Vector2(0.044, 0.044), COAT)
	L.ball(b, fret, Vector3(0.035, 0.045, 0.04), SKIN, 3, 6)
	L.ball(b, Vector3(0.19, chest - 0.02, 0.0), Vector3(0.068, 0.06, 0.07), COAT, 4, 8)
	# Правое плечо до локтя на деке (дальше — strum_arm)
	L.limb(b, Vector3(0.2, chest - 0.03, 0.0), ELBOW, Vector2(0.058, 0.058), Vector2(0.05, 0.05), COAT)
	L.ball(b, ELBOW, Vector3(0.05, 0.05, 0.05), COAT, 3, 6)
	guitar(b)
	# Шея и голова: кепка козырьком назад, наушники
	var neck := chest + 0.06
	L.limb(b, Vector3(0, neck - 0.03, 0.005), Vector3(0, neck + 0.06, 0.01), Vector2(0.05, 0.048), Vector2(0.046, 0.045), SKIN)
	var c := Vector3(0, neck + 0.145, 0.0)
	b.alpha = 0.5
	# seed 1: без кепки из общего кода, без усов и очков — кепка своя
	L._head_parts(b, c, SKIN, HAIR, CAP, false, 1)
	L.limb(b, c + Vector3(0, 0.055, 0.0), c + Vector3(0, 0.1, 0.0), Vector2(0.104, 0.112), Vector2(0.1, 0.108), CAP, true)
	L.ball(b, c + Vector3(0, 0.1, 0.0), Vector3(0.1, 0.035, 0.108), CAP, 2, 10, true)
	b.box(Vector3(c.x - 0.075, c.y + 0.05, c.z + 0.09), Vector3(c.x + 0.075, c.y + 0.062, c.z + 0.19), CAP.lightened(0.05))
	b.box(Vector3(c.x - 0.03, c.y + 0.06, c.z + 0.095), Vector3(c.x + 0.03, c.y + 0.09, c.z + 0.11), CAP.lightened(0.15))
	for s in [-1.0, 1.0]:
		L.ball(b, c + Vector3(s * 0.1, -0.01, 0.0), Vector3(0.012, 0.016, 0.016), Color(0.96, 0.96, 0.96), 2, 6)
	b.alpha = 1.0


## Кроссовок: белый, толстая подошва, шнурки.
static func _sneaker(b: MeshBuilder, at: Vector3) -> void:
	b.box(at + Vector3(-0.052, 0.0, -0.16), at + Vector3(0.052, 0.035, 0.07), Color(0.98, 0.98, 0.97))
	PersonModel.ball(b, at + Vector3(0, 0.05, -0.085), Vector3(0.05, 0.042, 0.078), SNEAKER, 3, 6)
	PersonModel.limb(b, at + Vector3(0, 0.035, 0.035), at + Vector3(0, 0.12, 0.025), Vector2(0.052, 0.055), Vector2(0.05, 0.052), SNEAKER, true)
	b.box(at + Vector3(-0.02, 0.085, -0.07), at + Vector3(0.02, 0.095, -0.02), Color(0.85, 0.85, 0.85))


## Акустическая гитара: дека с талией, розетка, подставка, гриф, головка
## с колками и струны.
static func guitar(b: MeshBuilder) -> void:
	var L := PersonModel
	var front := G0.z - 0.05
	_guitar_body(b)
	# Розетка и подставка
	var hole := G0 + GU * 0.25
	L.ball(b, Vector3(hole.x, hole.y, front), Vector3(0.062, 0.062, 0.003), Color(0.3, 0.2, 0.12), 4, 14)
	L.ball(b, Vector3(hole.x, hole.y, front - 0.0015), Vector3(0.048, 0.048, 0.003), Color(0.05, 0.04, 0.03), 4, 14)
	var br := G0 - GU * 0.08
	L.limb(b, br - GV * 0.06 + Vector3(0, 0, -0.045), br + GV * 0.06 + Vector3(0, 0, -0.045), Vector2(0.012, 0.01), Vector2(0.012, 0.01), Color(0.15, 0.1, 0.06), true)
	# Гриф с ладами и головка
	var n0 := G0 + GU * 0.4 + Vector3(0, 0, -0.02)
	var n1 := G0 + GU * 0.82 + Vector3(0, 0, -0.02)
	L.limb(b, n0, n1, Vector2(0.026, 0.016), Vector2(0.023, 0.015), Color(0.25, 0.15, 0.08), true)
	for i in 6:
		var p := n0.lerp(n1, 0.1 + i * 0.15) + Vector3(0, 0, -0.016)
		L.limb(b, p - GV * 0.024, p + GV * 0.024, Vector2(0.003, 0.003), Vector2(0.003, 0.003), Color(0.8, 0.8, 0.75))
	var h1 := G0 + GU * 0.98 + Vector3(0, 0.0, -0.01)
	L.limb(b, n1, h1, Vector2(0.034, 0.012), Vector2(0.036, 0.012), Color(0.12, 0.08, 0.05), true)
	for k in 3:
		for s in [-1.0, 1.0]:
			L.ball(b, n1.lerp(h1, 0.25 + k * 0.28) + GV * s * 0.045, Vector3(0.012, 0.012, 0.008), Color(0.8, 0.78, 0.7), 2, 6)
	# Струны — от подставки до головки
	for i in 6:
		var o := GV * (-0.017 + i * 0.007)
		L.limb(b, br + o + Vector3(0, 0, -0.06), n1 + o + Vector3(0, 0, -0.04), Vector2(0.0012, 0.0012), Vector2(0.0012, 0.0012), Color(0.85, 0.85, 0.8))


## Корпус «восьмёркой»: дека и низ по контуру, обечайка между ними.
## Контур — полуширина по длине корпуса от низа (−0.2) к грифу (+0.42).
static func _guitar_body(b: MeshBuilder) -> void:
	var prof: Array[Vector2] = []
	for i in 25:
		var t := lerpf(-0.205, 0.43, float(i) / 24.0)
		var w: float
		if t < 0.16:
			# Нижняя половина — круг радиусом 0.2 с центром в 0
			w = sqrt(maxf(0.2 * 0.2 - t * t, 0.0)) if t < 0.0 else lerpf(0.2, 0.125, smoothstep(0.0, 0.16, t))
		else:
			# Талия и верхняя половина — круг радиусом 0.155 вокруг 0.29
			var k := t - 0.29
			w = maxf(sqrt(maxf(0.155 * 0.155 - k * k, 0.0)), lerpf(0.125, 0.0, smoothstep(0.16, 0.2, t)))
		prof.append(Vector2(t, maxf(w, 0.004)))
	var fz := Vector3(0, 0, -0.05)
	var bz := Vector3(0, 0, 0.05)
	var side := WOOD.darkened(0.45)
	for i in prof.size() - 1:
		var p0: Vector2 = prof[i]
		var p1: Vector2 = prof[i + 1]
		var l0 := G0 + GU * p0.x + GV * p0.y
		var r0 := G0 + GU * p0.x - GV * p0.y
		var l1 := G0 + GU * p1.x + GV * p1.y
		var r1 := G0 + GU * p1.x - GV * p1.y
		# Дека (к зрителю) и низ
		b.quad(r0 + fz, l0 + fz, l1 + fz, r1 + fz, WOOD, true)
		b.quad(r0 + bz, r1 + bz, l1 + bz, l0 + bz, WOOD.darkened(0.3), true)
		# Обечайка с двух сторон
		b.quad(l0 + fz, l0 + bz, l1 + bz, l1 + fz, side, true)
		b.quad(r0 + fz, r1 + fz, r1 + bz, r0 + bz, side, true)
	# Торец снизу
	var e0: Vector2 = prof[0]
	var el := G0 + GU * e0.x + GV * e0.y
	var er := G0 + GU * e0.x - GV * e0.y
	b.quad(er + fz, er + bz, el + bz, el + fz, side, true)
	# Светлый кант по краю деки
	for i in prof.size() - 1:
		for sgn: float in [1.0, -1.0]:
			var a := G0 + GU * prof[i].x + GV * prof[i].y * sgn + fz + Vector3(0, 0, -0.002)
			var c := G0 + GU * prof[i + 1].x + GV * prof[i + 1].y * sgn + fz + Vector3(0, 0, -0.002)
			var inward := -GV * sgn * 0.012
			b.quad(a, c, c + inward, a + inward, Color(0.95, 0.9, 0.78), true)


## Правое предплечье с кистью — от локтя к струнам у розетки (в координатах
## от локтя). Его покачивает _process: рука бьёт по струнам.
static func strum_arm(b: MeshBuilder) -> void:
	var hand := G0 + GU * 0.17 + Vector3(0, -0.02, -0.08) - ELBOW
	PersonModel.limb(b, Vector3.ZERO, hand * 0.82, Vector2(0.05, 0.05), Vector2(0.042, 0.042), COAT)
	PersonModel.limb(b, hand * 0.8, hand * 0.88, Vector2(0.04, 0.04), Vector2(0.04, 0.04), TEE.darkened(0.3))
	PersonModel.ball(b, hand, Vector3(0.04, 0.034, 0.05), SKIN, 3, 6)
	# Медиатор
	b.box(hand + Vector3(-0.012, -0.012, -0.05), hand + Vector3(0.012, 0.012, -0.046), Color(0.85, 0.2, 0.15))


## Ось взмаха руки: поперёк предплечья и струн.
static func strum_axis() -> Vector3:
	var hand := G0 + GU * 0.17 + Vector3(0, -0.02, -0.08) - ELBOW
	return hand.normalized().cross(GV).normalized()


## Кепка донышком вниз перед лавкой: мелочь и купюры, чем больше кинули — тем больше.
func _build_cap() -> void:
	if _cap:
		remove_child(_cap)
		_cap.queue_free()
	var b := MeshBuilder.new()
	cap_mesh(b, tips)
	_cap = b.build_mesh()
	_cap.name = "Cap"
	_cap.visibility_range_end = 120.0
	add_child(_cap)


static func cap_mesh(b: MeshBuilder, n_tips: int) -> void:
	var c := Vector3(0.45, 0.0, -0.85)
	var seg := 14
	# Тулья — чаша изнутри и снаружи, пуговка снизу, козырёк лежит на земле
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		b.quad(c + d0 * 0.065 + Vector3(0, 0.004, 0), c + d1 * 0.065 + Vector3(0, 0.004, 0), c + d1 * 0.1 + Vector3(0, 0.06, 0), c + d0 * 0.1 + Vector3(0, 0.06, 0), CAP, true)
		# Шов по кромке
		b.quad(c + d0 * 0.1 + Vector3(0, 0.06, 0), c + d1 * 0.1 + Vector3(0, 0.06, 0), c + d1 * 0.104 + Vector3(0, 0.066, 0), c + d0 * 0.104 + Vector3(0, 0.066, 0), CAP.lightened(0.12), true)
	PersonModel.ball(b, c + Vector3(0, 0.005, 0), Vector3(0.066, 0.004, 0.066), CAP.lightened(0.05), 2, seg)
	var vc := c + Vector3(0, 0.004, -0.085)
	for i in 8:
		var a0 := PI + PI * i / 8.0
		var a1 := PI + PI * (i + 1) / 8.0
		b.tri(vc, vc + Vector3(cos(a0) * 0.095, 0, sin(a0) * 0.075), vc + Vector3(cos(a1) * 0.095, 0, sin(a1) * 0.075), CAP.lightened(0.04), true)
	# Деньги: купюры (синие, зелёные, рыжие, сиреневые) и мелочь, часть — через край
	var notes := [Color(0.45, 0.6, 0.8), Color(0.55, 0.72, 0.5), Color(0.85, 0.6, 0.35), Color(0.7, 0.55, 0.75)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for i in 4 + mini(n_tips, TIPS_SHOWN):
		var yaw := rng.randf_range(0.0, PI)
		var p := c + Vector3(rng.randf_range(-0.035, 0.035), 0.012 + i * 0.004, rng.randf_range(-0.035, 0.035))
		b.box_rot(p, Vector3(0.12, 0.003, 0.06), yaw, notes[i % notes.size()])
	b.box_rot(c + Vector3(0.12, 0.003, 0.04), Vector3(0.12, 0.003, 0.06), 0.4, notes[0])
	for i in 10:
		var inside := i < 7
		var p := c + (Vector3(rng.randf_range(-0.04, 0.04), 0.03 + i * 0.003, rng.randf_range(-0.04, 0.04)) if inside
				else Vector3(rng.randf_range(0.11, 0.16), 0.0, rng.randf_range(-0.08, 0.08)))
		PersonModel.limb(b, p, p + Vector3(0, 0.004, 0), Vector2(0.012, 0.012), Vector2(0.012, 0.012),
				Color(0.86, 0.74, 0.36) if i % 2 else Color(0.78, 0.78, 0.76), true)


func _process(delta: float) -> void:
	var h := TimeManager.minutes / 60.0
	var here := h >= HOURS[0] and h < HOURS[1]
	visible = here
	_zone.monitoring = here
	var can_play := here and not WeatherManager.wet()
	if not can_play:
		if _player.playing:
			_player.stop()
		playing = false
		_arm.basis = Basis.IDENTITY
		return
	var near := false
	var cam := get_viewport().get_camera_3d()
	if cam:
		near = cam.global_position.distance_squared_to(global_position) < 60.0 * 60.0
	if not _player.playing:
		playing = false
		_pause -= delta
		if _pause <= 0.0 and near:
			start_song((song + 1) % SONGS.size())
	if playing and near:
		_t += delta
		# Вниз-вверх восьмыми; на переборе рука почти на месте
		var amp := 0.28 if song == 0 else 0.07
		_arm.basis = Basis(strum_axis(), sin(_t * PI * STRUM_HZ[song]) * amp)


## Заиграть песню n.
func start_song(n: int) -> void:
	song = n
	_t = 0.0
	_player.stream = SoundLibrary.stream(SONGS[n])
	_player.play()
	playing = true


## Кинуть музыканту в кепку.
func tip() -> void:
	if not GameManager.spend(TIP):
		return
	tips += 1
	_build_cap()
	QuestManager.event("busker_tip", 1)
	GameManager.notify("Музыкант кивнул: «Спасибо, друг! Эту — для тебя»")
	if not _player.playing and not WeatherManager.wet():
		start_song((song + 1) % SONGS.size())


func save_state() -> Dictionary:
	return {"tips": tips}


func load_state(d: Dictionary) -> void:
	tips = int(d.get("tips", 0))
	if is_inside_tree():
		_build_cap()
