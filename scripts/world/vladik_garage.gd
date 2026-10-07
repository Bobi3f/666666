class_name VladikGarage
extends RefCounted
## Гараж Дяди Владика на западной окраине Каменки, у трассы: старый
## кирпично-железный бокс с облезлой зелёной краской и ржавыми потёками,
## распахнутые металлические ворота к трассе, внутри — верстак с тисками и
## ключами на щите, домкрат, сварочный аппарат, двигатель на подставке,
## мотоциклетные и автомобильные детали, аккумуляторы, канистры, коробки,
## железные шкафы, лампы. Снаружи — доски, покрышки, канистры, бочка, старый
## ИЖ без колеса и битая «копейка» на кирпичах (её разбирают по заданию).
##
## Всё — в общий MeshBuilder мира (статично, одним мешем с округой).
## Координаты внутри — свои (ворота смотрят в +Z), XF ставит гараж в мир.

const POS := Vector3(-214.0, 0, 24.0)
## Поворот: свои +Z (ворота) смотрят на север, к трассе.
const YAW := PI
const SIZE := Vector3(7.6, 3.2, 8.6)
const GATE_W := 3.6
const FLOOR := 0.05

## Места внутри (свои координаты) — куда ходит Владик и как стоит
## (поворот: 0 — лицом к задней стене, PI/2 — к верстаку слева).
const SPOTS := {
	"bench": [Vector3(-2.35, 0, -0.6), PI / 2.0],
	"tool": [Vector3(-2.35, 0, 0.9), PI / 2.0],
	"engine": [Vector3(1.7, 0, -1.9), 0.0],
	"inspect": [Vector3(1.45, 0, 1.4), PI / 2.0],
	"shelf": [Vector3(-1.4, 0, -3.0), 0.0],
	"chair": [Vector3(3.15, 0, 0.9), PI / 2.0],
	"door": [Vector3(0.6, 0, 5.2), PI],
	"wreck": [Vector3(5.6, 0, 2.6), -PI / 2.0],
}
## Куда ставить мопед на ремонт (свои), и битая «копейка» во дворе.
const MOPED_SPOT := Vector3(0.4, 0, 1.4)
const WRECK := Vector3(7.4, 0, 2.2)
const OLD_BIKE := Vector3(-5.2, 0, 3.6)


static func xf() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, YAW), POS)


## Своя точка → мир.
static func w(p: Vector3) -> Vector3:
	return xf() * p


## Внутри ли точка мира — в боксе (или в воротах).
static func inside(p: Vector3, margin := 0.0) -> bool:
	var l := xf().affine_inverse() * p
	return absf(l.x) < SIZE.x * 0.5 + margin and l.z > -SIZE.z * 0.5 and l.z < SIZE.z * 0.5 + 1.0 + margin


## Где не растут деревья и трава: бокс, двор и подъезд к трассе (мир).
static func clear_rect() -> Rect2:
	return Rect2(POS.x - 10.0, 2.5, 21.0, POS.z + 7.0 - 2.5)


## Строит гараж в b (стены, вещи) и glow; возвращает меш ламп под
## потолком (светятся сами — без источников света).
static func build(b: MeshBuilder, glow: MeshBuilder) -> MeshInstance3D:
	var saved := b.xf
	var gsaved := glow.xf
	b.xf = xf()
	glow.xf = xf()
	var paint := Color(0.33, 0.42, 0.33)
	var rust := Color(0.45, 0.25, 0.13)
	var inner := Color(0.55, 0.53, 0.5)
	var concrete := Color(0.46, 0.45, 0.43)
	var lamps := MeshBuilder.new()
	lamps.ground_shade = false
	lamps.xf = xf()
	WalkIn.shell(b, SIZE, FLOOR, paint, inner, concrete, 0.0, GATE_W, 2.6, lamps)
	var hx := SIZE.x * 0.5
	var hz := SIZE.z * 0.5
	var h := SIZE.y
	# Профнастил: вертикальные рёбра по стенам, облезлая краска и потёки ржавчины
	var rng := RandomNumberGenerator.new()
	rng.seed = 1999
	var x := -hx + 0.15
	while x < hx:
		for side in [-1.0, 1.0]:
			if absf(x) > GATE_W * 0.5 + 0.1:
				b.box(Vector3(x, 0.1, side * hz - 0.03 * side), Vector3(x + 0.05, h - 0.05, side * hz + 0.02 * side), paint.darkened(0.12))
		x += 0.35
	var z := -hz + 0.2
	while z < hz:
		for side in [-1.0, 1.0]:
			b.box(Vector3(side * hx - 0.03 * side, 0.1, z), Vector3(side * hx + 0.02 * side, h - 0.05, z + 0.05), paint.darkened(0.12))
		z += 0.35
	for i in 22:
		var side := rng.randi() % 3
		var y0 := rng.randf_range(0.1, 1.4)
		var hh := rng.randf_range(0.4, 1.6)
		var col := rust if rng.randf() < 0.6 else paint.lightened(0.25)
		match side:
			0:
				var px := rng.randf_range(-hx + 0.2, hx - 0.4)
				if absf(px) < GATE_W * 0.5 + 0.2:
					continue
				b.box(Vector3(px, y0, hz + 0.02), Vector3(px + rng.randf_range(0.1, 0.5), y0 + hh, hz + 0.035), col)
			1:
				var pz := rng.randf_range(-hz + 0.2, hz - 0.5)
				b.box(Vector3(hx + 0.02, y0, pz), Vector3(hx + 0.035, y0 + hh, pz + rng.randf_range(0.1, 0.5)), col)
			_:
				var pz2 := rng.randf_range(-hz + 0.2, hz - 0.5)
				b.box(Vector3(-hx - 0.035, y0, pz2), Vector3(-hx - 0.02, y0 + hh, pz2 + rng.randf_range(0.1, 0.5)), col)
	# Крыша — рубероид с наклоном назад, свесы
	b.box(Vector3(-hx - 0.25, h, -hz - 0.3), Vector3(hx + 0.25, h + 0.12, hz + 0.35), Color(0.2, 0.2, 0.21))
	b.box(Vector3(-hx - 0.25, h + 0.12, -hz - 0.3), Vector3(hx + 0.25, h + 0.2, hz - 1.5), Color(0.24, 0.23, 0.23))
	# Ворота нараспашку: две ржавые створки с рёбрами и засовом
	for s in [-1.0, 1.0]:
		var hinge := Vector3(s * GATE_W * 0.5, 0, hz)
		var open_xf := Transform3D(Basis(Vector3.UP, -s * 1.25), hinge)
		var leaf := b.xf
		b.xf = leaf * open_xf
		var w := GATE_W * 0.5
		b.box(Vector3(-w if s > 0 else 0.0, 0.05, 0.0), Vector3(0.0 if s > 0 else w, 2.6, 0.05), paint.darkened(0.05), true)
		for k in 3:
			var yy := 0.4 + k * 0.9
			b.box(Vector3(-w if s > 0 else 0.0, yy, 0.05), Vector3(0.0 if s > 0 else w, yy + 0.08, 0.09), paint.darkened(0.25))
		b.box(Vector3(-w * 0.8 if s > 0 else w * 0.1, 0.9, 0.051), Vector3(-w * 0.1 if s > 0 else w * 0.8, 1.5, 0.06), rust)
		b.box(Vector3(-0.3 if s > 0 else 0.1, 1.2, 0.09), Vector3(-0.1 if s > 0 else 0.3, 1.26, 0.13), Color(0.3, 0.3, 0.3))
		b.xf = leaf
	# Вывеска краской над воротами
	b.box(Vector3(-1.6, 2.72, hz + 0.02), Vector3(1.6, 3.1, hz + 0.05), Color(0.85, 0.82, 0.7))
	_inside(b, glow, lamps, hx, hz, h, rng)
	_yard(b, hx, hz, rng)
	b.xf = saved
	glow.xf = gsaved
	var lm := lamps.build_mesh(true)
	lm.name = "VladikGarageLamps"
	lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return lm


## Внутри: верстак, щит с ключами, тиски, полки и шкафы, двигатель на
## подставке, домкрат, сварка, покрышки, канистры, аккумуляторы, детали.
static func _inside(b: MeshBuilder, glow: MeshBuilder, lamps: MeshBuilder, hx: float, hz: float, h: float, rng: RandomNumberGenerator) -> void:
	var wood := Color(0.42, 0.3, 0.2)
	var steel := Color(0.5, 0.51, 0.53)
	var dark := Color(0.12, 0.12, 0.13)
	var oil := Color(0.2, 0.19, 0.17)
	var f := FLOOR
	# Масляные пятна на полу
	for p in [Vector3(0.4, 0, 1.4), Vector3(1.6, 0, -1.4), Vector3(-1.0, 0, 2.6)]:
		b.box(p + Vector3(-0.5, f, -0.4), p + Vector3(0.5, f + 0.004, 0.4), oil)
	# Верстак вдоль левой стены: столешница, ножки, тиски, ящик
	var bx := -hx + 0.2
	WalkIn.counter(b, Vector3(bx, 0, -1.6), Vector3(bx + 0.75, 0.95, 1.6), wood.darkened(0.2), wood)
	b.box(Vector3(bx + 0.25, 0.95, -0.9), Vector3(bx + 0.45, 1.06, -0.6), steel.darkened(0.3))
	b.box(Vector3(bx + 0.2, 1.06, -0.95), Vector3(bx + 0.5, 1.16, -0.55), steel)
	b.box(Vector3(bx + 0.1, 0.95, 0.2), Vector3(bx + 0.5, 1.15, 0.7), Color(0.75, 0.15, 0.12))
	# Карбюратор и детали на верстаке
	b.box(Vector3(bx + 0.4, 0.95, -0.2), Vector3(bx + 0.55, 1.05, -0.05), steel.lightened(0.15))
	b.box(Vector3(bx + 0.45, 0.95, 1.0), Vector3(bx + 0.62, 0.98, 1.4), Color(0.85, 0.82, 0.75))
	# Щит над верстаком с ключами
	b.box(Vector3(-hx + 0.21, 1.2, -1.5), Vector3(-hx + 0.24, 2.2, 1.5), Color(0.55, 0.45, 0.3))
	for i in 14:
		var zz := -1.35 + i * 0.2
		var ln := 0.12 + (i % 4) * 0.05
		b.box(Vector3(-hx + 0.25, 1.85 - ln, zz), Vector3(-hx + 0.27, 1.85, zz + 0.03), steel.lightened(0.2))
	for i in 5:
		b.box(Vector3(-hx + 0.25, 1.35, -1.3 + i * 0.5), Vector3(-hx + 0.3, 1.5, -1.15 + i * 0.5), [Color(0.8, 0.15, 0.12), Color(0.2, 0.4, 0.75), Color(0.9, 0.7, 0.15)][i % 3])
	# Полки у задней стены: коробки, банки, детали
	WalkIn.shelf(b, Vector3(-hx + 0.3, 0, -hz + 0.25), Vector3(-0.2, 2.3, -hz + 0.75), rng)
	# Железные шкафы
	for i in 3:
		var x0 := 0.2 + i * 0.75
		b.box(Vector3(x0, 0, -hz + 0.22), Vector3(x0 + 0.7, 1.9, -hz + 0.72), Color(0.45, 0.5, 0.52) if i != 1 else Color(0.5, 0.48, 0.42), i == 0)
		b.box(Vector3(x0 + 0.34, 0.05, -hz + 0.72), Vector3(x0 + 0.36, 1.85, -hz + 0.73), dark)
		b.box(Vector3(x0 + 0.5, 0.9, -hz + 0.72), Vector3(x0 + 0.54, 1.05, -hz + 0.75), steel.lightened(0.2))
	b.add_collider(Vector3(0.2, 0, -hz + 0.22), Vector3(2.45, 1.9, -hz + 0.72))
	# Двигатель на подставке: блок, рёбра, картер
	var e := Vector3(1.7, 0, -2.6)
	b.box(e + Vector3(-0.35, 0, -0.3), e + Vector3(0.35, 0.55, 0.3), Color(0.35, 0.2, 0.15), true)
	b.box(e + Vector3(-0.3, 0.55, -0.25), e + Vector3(0.3, 0.85, 0.25), Color(0.45, 0.46, 0.48))
	for k in 5:
		b.box(e + Vector3(-0.34, 0.6 + k * 0.05, -0.2), e + Vector3(0.34, 0.62 + k * 0.05, 0.2), Color(0.5, 0.51, 0.53))
	b.box(e + Vector3(-0.15, 0.85, -0.12), e + Vector3(0.15, 1.0, 0.12), Color(0.3, 0.3, 0.32))
	# Домкрат подкатной, сварочный аппарат с кабелями и маской
	var j := Vector3(-1.0, 0, 3.2)
	b.box(j + Vector3(-0.2, 0, -0.5), j + Vector3(0.2, 0.15, 0.4), Color(0.8, 0.15, 0.1))
	VehicleModels.tube(b, j + Vector3(0, 0.15, 0.35), j + Vector3(0, 0.75, 0.95), 0.02, Color(0.8, 0.15, 0.1))
	var wd := Vector3(2.9, 0, -0.9)
	b.box(wd + Vector3(-0.25, 0, -0.3), wd + Vector3(0.25, 0.6, 0.3), Color(0.15, 0.35, 0.65))
	b.box(wd + Vector3(-0.2, 0.6, -0.25), wd + Vector3(0.2, 0.62, 0.25), dark)
	VehicleModels.pipe(b, [wd + Vector3(-0.25, 0.4, 0.1), wd + Vector3(-0.6, 0.02, 0.3), wd + Vector3(-1.1, 0.02, 0.1)], 0.015, dark)
	b.box(wd + Vector3(-0.15, 0.62, -0.1), wd + Vector3(0.1, 0.9, 0.05), Color(0.18, 0.18, 0.19))
	# Покрышки стопкой, канистры, аккумуляторы в ряд, коробки
	for k in 4:
		var t := Vector3(2.9, 0.12 + k * 0.24, 3.4)
		PersonModel.limb(b, t - Vector3(0, 0.11, 0), t + Vector3(0, 0.11, 0), Vector2(0.32, 0.32), Vector2(0.32, 0.32), dark, true)
	for k in 3:
		b.box(Vector3(-hx + 0.3 + k * 0.32, 0, 2.2), Vector3(-hx + 0.55 + k * 0.32, 0.45, 2.55), [Color(0.7, 0.12, 0.1), Color(0.2, 0.42, 0.22), Color(0.7, 0.12, 0.1)][k])
	for k in 4:
		var bt := Vector3(-0.2 + k * 0.32, 0, -hz + 1.0)
		b.box(bt, bt + Vector3(0.26, 0.22, 0.18), Color(0.1, 0.1, 0.1))
		b.box(bt + Vector3(0.04, 0.22, 0.05), bt + Vector3(0.08, 0.26, 0.09), Color(0.75, 0.15, 0.1))
	for p in [Vector3(-2.6, 0, -3.3), Vector3(-2.1, 0, 3.4), Vector3(-1.75, 0.4, 3.45)]:
		b.box(p, p + Vector3(0.45, 0.4, 0.4), Color(0.58, 0.45, 0.28))
	# Мотоциклетные детали: колесо у стены, бак, крыло; автомобильные — дверь, бампер
	PersonModel.limb(b, Vector3(hx - 0.3, 0.32, -3.0), Vector3(hx - 0.22, 0.32, -3.0), Vector2(0.3, 0.3), Vector2(0.3, 0.3), dark, true)
	PersonModel.ball(b, Vector3(1.0, 1.98, -hz + 0.47), Vector3(0.16, 0.09, 0.22), Color(0.7, 0.12, 0.1), 4, 10)
	b.box(Vector3(hx - 0.25, 0, 1.6), Vector3(hx - 0.2, 1.1, 2.6), Color(0.55, 0.15, 0.12))
	b.box(Vector3(hx - 0.35, 0, -0.5), Vector3(hx - 0.22, 0.25, 0.9), Color(0.72, 0.72, 0.74))
	# Табурет и столик с чайником — где Владик отдыхает
	var ch := Vector3(3.15, 0, 0.9)
	b.box(ch + Vector3(-0.2, 0.42, -0.2), ch + Vector3(0.2, 0.47, 0.2), Color(0.45, 0.32, 0.2))
	for p in [Vector2(-0.16, -0.16), Vector2(0.16, -0.16), Vector2(-0.16, 0.16), Vector2(0.16, 0.16)]:
		b.box(ch + Vector3(p.x - 0.02, 0, p.y - 0.02), ch + Vector3(p.x + 0.02, 0.42, p.y + 0.02), Color(0.35, 0.25, 0.15))
	b.box(Vector3(hx - 0.55, 0, 1.6 + 0.0), Vector3(hx - 0.25, 0.6, 1.95), Color(0.4, 0.3, 0.2))
	PersonModel.ball(b, Vector3(hx - 0.4, 0.68, 1.78), Vector3(0.08, 0.08, 0.08), Color(0.75, 0.75, 0.72), 4, 10)
	# Лампы под потолком и переноска у мотора
	WalkIn.lamp(lamps, Vector3(0, h - 0.15, -1.5))
	WalkIn.lamp(lamps, Vector3(0, h - 0.15, 1.8))
	glow.box(Vector3(1.4, 1.35, -2.1), Vector3(1.48, 1.45, -2.0), Color(1.0, 0.9, 0.6))


## Двор: доски, покрышки, канистры, бочка, старый ИЖ без колеса, битая
## «копейка» на кирпичах, подъезд от трассы.
static func _yard(b: MeshBuilder, hx: float, hz: float, rng: RandomNumberGenerator) -> void:
	var dirt := Color(0.4, 0.34, 0.26)
	var dark := Color(0.1, 0.1, 0.11)
	# Утоптанная площадка перед воротами и дорожка к трассе (в мир — на север)
	b.box(Vector3(-3.0, 0, hz), Vector3(9.5, 0.02, hz + 4.0), dirt)
	b.box(Vector3(-2.0, 0, hz + 4.0), Vector3(2.0, 0.02, POS.z - 3.0), dirt)
	# Доски у стены, покрышки, канистры, бочка
	for k in 5:
		b.box_rot(Vector3(-hx - 0.4, 0.05 + k * 0.05, -1.5 + k * 0.1), Vector3(0.2, 0.04, 2.6), 0.04 * k, Color(0.5, 0.4, 0.28))
	for k in 3:
		var t := Vector3(-hx - 0.6, 0.12 + k * 0.24, 2.2)
		PersonModel.limb(b, t - Vector3(0, 0.11, 0), t + Vector3(0, 0.11, 0), Vector2(0.3, 0.3), Vector2(0.3, 0.3), dark, true)
	PersonModel.limb(b, Vector3(-hx - 1.3, 0.3, 3.2), Vector3(-hx - 1.1, 0.33, 3.4), Vector2(0.3, 0.3), Vector2(0.3, 0.3), dark, true)
	for k in 2:
		b.box(Vector3(hx + 0.15, 0, -1.2 + k * 0.35), Vector3(hx + 0.4, 0.42, -0.95 + k * 0.35), [Color(0.7, 0.12, 0.1), Color(0.2, 0.42, 0.22)][k])
	PersonModel.limb(b, Vector3(hx + 0.6, 0, -2.6), Vector3(hx + 0.6, 0.85, -2.6), Vector2(0.28, 0.28), Vector2(0.28, 0.28), Color(0.25, 0.3, 0.45), true)
	b.box(Vector3(hx + 0.4, 0.4, -2.85), Vector3(hx + 0.8, 0.5, -2.82), Color(0.45, 0.25, 0.13))
	# Старый ИЖ у стены: без переднего колеса, на чурбаке
	var saved := b.xf
	b.xf = saved * Transform3D(Basis(Vector3.UP, 0.15), OLD_BIKE)
	VehicleModels.izh(b, Color(0.35, 0.18, 0.12))
	b.xf = saved * Transform3D(Basis(Vector3.UP, 0.15), OLD_BIKE + Vector3(0, 0.32, 0.64))
	VehicleModels.moto_wheel(b, 0.32)
	b.xf = saved
	b.box(OLD_BIKE + Vector3(-0.15, 0, -0.95), OLD_BIKE + Vector3(0.15, 0.3, -0.6), Color(0.45, 0.32, 0.2))
	# Битая «копейка» на кирпичах: без колёс, ржавая, без капота
	b.xf = saved * Transform3D(Basis(Vector3.UP, PI / 2.0), WRECK + Vector3(0, 0.25, 0))
	VehicleModels.zhiguli(b, Color(0.42, 0.36, 0.3), false)
	b.xf = saved
	for p in [Vector3(-1.2, 0, -0.7), Vector3(1.2, 0, -0.7), Vector3(-1.2, 0, 0.7), Vector3(1.2, 0, 0.7)]:
		var q := WRECK + Vector3(p.z, 0, p.x)
		b.box(q + Vector3(-0.15, 0, -0.12), q + Vector3(0.15, 0.3, 0.12), Color(0.6, 0.3, 0.22))
	b.add_collider(WRECK + Vector3(-2.1, 0, -0.85), WRECK + Vector3(2.1, 1.4, 0.85))
	for i in 6:
		var p := WRECK + Vector3(rng.randf_range(-2.2, 2.2), 0, rng.randf_range(-2.8, 2.8))
		b.box(p, p + Vector3(rng.randf_range(0.1, 0.4), rng.randf_range(0.03, 0.1), rng.randf_range(0.1, 0.4)), Color(0.42, 0.3, 0.2) if i % 2 else Color(0.5, 0.5, 0.52))
