class_name PersonModel
extends RefCounted
## Люди не из кубиков: руки и ноги — сужающиеся многогранники, плечи,
## кисти и голова — округлые, на лице глаза с бровями, нос, губы, уши;
## волосы, кепка или косынка, рубашка с воротником и пуговицами, ремень,
## брюки, ботинки с подошвой. Всё — в общий меш MeshBuilder, гладкие
## нормали, цвет в вершинах — на телефоне это один вызов отрисовки.
##
## Внешность жителя (цвет кожи и волос, причёска, усы, полнота) выводится из
## цвета его рубашки: у каждого своя, но всегда одна и та же.
##
## Шаг и взгляд делает шейдер SHADER: метки в альфе цвета — левая нога 0.9,
## правая 0.8 (качаются вокруг 0.85 м), левая рука 0.7, правая 0.6 (вокруг
## 1.4 м), голова 0.5 (поворачивается на look). turn — поворот всего тела.
## Человек смотрит в −Z, ступни на нуле. Отдельный человек (свой
## MeshBuilder) получает этот шейдер сам и попадает в группу "people" —
## его голову поворачивает к игроку PeopleLook.

const SEG := 8

const SHADER := """
shader_type spatial;

uniform float phase = 0.0;
uniform float amount = 0.0;
uniform float look = 0.0;
uniform float turn = 0.0;

// Поворот точки p вокруг оси X, проходящей на высоте pivot_y
vec3 swing(vec3 p, float pivot_y, float a) {
	float dy = p.y - pivot_y;
	float c = cos(a);
	float s = sin(a);
	return vec3(p.x, pivot_y + dy * c - p.z * s, dy * s + p.z * c);
}

// Поворот вокруг вертикали (как Basis(UP, a))
vec3 yaw(vec3 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c);
}

void vertex() {
	float tag = COLOR.a;
	float a = sin(phase) * 0.5 * amount;
	float y = turn;
	if (tag < 0.95 && tag > 0.85) {
		VERTEX = swing(VERTEX, 0.85, a);
	} else if (tag < 0.85 && tag > 0.75) {
		VERTEX = swing(VERTEX, 0.85, -a);
	} else if (tag < 0.75 && tag > 0.65) {
		VERTEX = swing(VERTEX, 1.4, -a * 0.8);
	} else if (tag < 0.65 && tag > 0.55) {
		VERTEX = swing(VERTEX, 1.4, a * 0.8);
	} else if (tag < 0.55 && tag > 0.45) {
		y += look;
	}
	VERTEX = yaw(VERTEX, y);
	NORMAL = yaw(NORMAL, y);
}

void fragment() {
	ALBEDO = COLOR.rgb * 1.05;
	ROUGHNESS = 0.9;
}
"""

static var _shader: Shader


## Свой материал человеку: шаг и взгляд у каждого свои.
static func material() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	return mat


## Пустой построитель без сдвига, в котором будет один человек, — его меш
## смотрит на игрока (голова крутится вокруг начала координат меша).
static func _mark(b: MeshBuilder, sit: bool) -> void:
	if b._count == 0 and b.xf.origin.length() < 0.01:
		b.set_meta("person", sit)
const SKINS := [Color(0.88, 0.7, 0.58), Color(0.82, 0.63, 0.5), Color(0.92, 0.76, 0.66), Color(0.76, 0.57, 0.45)]
const HAIRS := [Color(0.3, 0.22, 0.15), Color(0.16, 0.13, 0.11), Color(0.55, 0.42, 0.28), Color(0.62, 0.6, 0.58), Color(0.42, 0.3, 0.2)]


## Сужающийся многогранник от a до c: сечение — эллипс с полуосями ra у a
## и rc у c (x — вбок, y — вперёд-назад для вертикальных частей).
static func limb(b: MeshBuilder, a: Vector3, c: Vector3, ra: Vector2, rc: Vector2, col: Color, caps := false) -> void:
	var d := c - a
	if d.length() < 0.0001:
		return
	var ax := d.normalized()
	var u := Vector3.RIGHT if absf(ax.x) < 0.9 else Vector3.FORWARD
	var v := ax.cross(u).normalized()
	u = v.cross(ax).normalized()
	var pa: Array[Vector3] = []
	var pc: Array[Vector3] = []
	var nn: Array[Vector3] = []
	for i in SEG + 1:
		var t := TAU * i / SEG
		var cs := cos(t)
		var sn := sin(t)
		pa.append(a + u * cs * ra.x + v * sn * ra.y)
		pc.append(c + u * cs * rc.x + v * sn * rc.y)
		nn.append((u * cs / maxf(ra.x, 0.001) + v * sn / maxf(ra.y, 0.001)).normalized())
	# Порядок обхода: лицевой стороной наружу
	var n0 := (pa[0] - pa[1]).cross(pc[1] - pa[1])
	var out := n0.dot(nn[0] + nn[1]) > 0.0
	for i in SEG:
		if out:
			b.smooth_quad([pa[i + 1], pa[i], pc[i], pc[i + 1]], [nn[i + 1], nn[i], nn[i], nn[i + 1]], col)
		else:
			b.smooth_quad([pa[i], pa[i + 1], pc[i + 1], pc[i]], [nn[i], nn[i + 1], nn[i + 1], nn[i]], col)
	if caps:
		for i in SEG:
			if out:
				b.smooth_quad([a, a, pa[i], pa[i + 1]], [-ax, -ax, -ax, -ax], col)
				b.smooth_quad([c, c, pc[i + 1], pc[i]], [ax, ax, ax, ax], col)
			else:
				b.smooth_quad([a, a, pa[i + 1], pa[i]], [-ax, -ax, -ax, -ax], col)
				b.smooth_quad([c, c, pc[i], pc[i + 1]], [ax, ax, ax, ax], col)


## Эллипсоид с полуосями r: голова, кисти, плечи, причёска. lat — колец.
static func ball(b: MeshBuilder, c: Vector3, r: Vector3, col: Color, lat := 4, lon := SEG, top_only := false) -> void:
	var j0 := lat / 2 if top_only else 0
	for j in range(j0, lat):
		var t0 := -PI * 0.5 + PI * j / lat
		var t1 := -PI * 0.5 + PI * (j + 1) / lat
		for i in lon:
			var p0 := _sph(t0, TAU * i / lon)
			var p1 := _sph(t0, TAU * (i + 1) / lon)
			var p2 := _sph(t1, TAU * (i + 1) / lon)
			var p3 := _sph(t1, TAU * i / lon)
			var q := [c + p0 * r, c + p1 * r, c + p2 * r, c + p3 * r]
			var n := [_en(p0, r), _en(p1, r), _en(p2, r), _en(p3, r)]
			b.smooth_quad([q[1], q[0], q[3], q[2]], [n[1], n[0], n[3], n[2]], col)


static func _sph(lat: float, lon: float) -> Vector3:
	return Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))


static func _en(p: Vector3, r: Vector3) -> Vector3:
	return Vector3(p.x / r.x, p.y / r.y, p.z / r.z).normalized()


## Житель: shirt — рубашка (или кофта), hat — кепка у мужчины, косынка у
## женщины; sit — сидит на лавке (ноги вперёд, руки на коленях).
static func person(b: MeshBuilder, shirt: Color, hat: Color, sit: bool, woman: bool) -> void:
	_mark(b, sit)
	var seed := int(shirt.r * 97.0 + shirt.g * 57.0 + shirt.b * 31.0 + hat.r * 13.0) + (7 if woman else 0)
	var skin: Color = SKINS[seed % SKINS.size()]
	var hair: Color = HAIRS[(seed / 3) % HAIRS.size()]
	var plump := 1.0 + 0.12 * float((seed / 7) % 3) / 2.0
	var pants := Color(0.2, 0.21, 0.26) if seed % 2 == 0 else Color(0.28, 0.25, 0.2)
	var shoe := Color(0.11, 0.09, 0.08)
	var base := 0.5 if sit else 0.88
	# --- Ноги
	if sit:
		for x in [-0.1, 0.1]:
			var leg_col: Color = pants if not woman else Color(0.78, 0.7, 0.62)
			limb(b, Vector3(x, 0.5, 0.0), Vector3(x, 0.5, -0.42), Vector2(0.085, 0.085), Vector2(0.07, 0.07), pants if not woman else shirt.darkened(0.3))
			ball(b, Vector3(x, 0.5, -0.42), Vector3(0.068, 0.068, 0.068), pants if not woman else leg_col, 3, 6)
			limb(b, Vector3(x, 0.5, -0.43), Vector3(x, 0.09, -0.46), Vector2(0.065, 0.065), Vector2(0.05, 0.05), leg_col)
			_shoe(b, Vector3(x, 0.0, -0.47), shoe)
	elif woman:
		for i in 2:
			var x := -0.09 if i == 0 else 0.09
			b.alpha = 0.9 if i == 0 else 0.8
			limb(b, Vector3(x, 0.62, 0.0), Vector3(x, 0.09, 0.0), Vector2(0.055, 0.055), Vector2(0.042, 0.045), Color(0.8, 0.72, 0.64))
			_shoe(b, Vector3(x, 0.0, 0.0), shoe)
		b.alpha = 1.0
	else:
		for i in 2:
			var x := -0.1 if i == 0 else 0.1
			b.alpha = 0.9 if i == 0 else 0.8
			# Бедро и голень: штанина сужается к низу, складка на колене
			limb(b, Vector3(x, 0.92, 0.0), Vector3(x, 0.5, -0.005), Vector2(0.088, 0.09) * plump, Vector2(0.07, 0.075), pants)
			limb(b, Vector3(x, 0.5, -0.005), Vector3(x, 0.1, 0.01), Vector2(0.07, 0.075), Vector2(0.058, 0.062), pants)
			b.box(Vector3(x - 0.004, 0.12, -0.075), Vector3(x + 0.004, 0.88, -0.07), pants.darkened(0.2))
			_shoe(b, Vector3(x, 0.0, 0.0), shoe)
		b.alpha = 1.0
	# --- Таз и пояс
	if woman and not sit:
		# Юбка колоколом до колен, фартук
		limb(b, Vector3(0, 0.98, 0.0), Vector3(0, 0.5, 0.0), Vector2(0.17, 0.13) * plump, Vector2(0.27, 0.22) * plump, shirt.darkened(0.25), true)
		b.box(Vector3(-0.15, 0.56, -0.235 * plump), Vector3(0.15, 0.96, -0.2 * plump), Color(0.93, 0.91, 0.85))
	elif not woman:
		limb(b, Vector3(0, base - 0.02, 0.0), Vector3(0, base + 0.08, 0.0), Vector2(0.19, 0.12) * plump, Vector2(0.19, 0.12) * plump, pants)
		limb(b, Vector3(0, base + 0.06, 0.0), Vector3(0, base + 0.11, 0.0), Vector2(0.195, 0.125) * plump, Vector2(0.195, 0.125) * plump, Color(0.22, 0.16, 0.1))
		b.box(Vector3(-0.035, base + 0.065, -0.13 * plump - 0.004), Vector3(0.035, base + 0.105, -0.12 * plump), Color(0.78, 0.72, 0.5))
	else:
		limb(b, Vector3(0, base - 0.02, 0.0), Vector3(0, base + 0.1, 0.0), Vector2(0.19, 0.13) * plump, Vector2(0.18, 0.12) * plump, shirt.darkened(0.25))
	# --- Туловище: шире в плечах, рубашка с воротником и пуговицами
	var waist := base + 0.1
	var chest := base + 0.5
	limb(b, Vector3(0, waist, 0.0), Vector3(0, chest, 0.0), Vector2(0.17, 0.115) * plump, Vector2(0.2, 0.125) * plump, shirt)
	limb(b, Vector3(0, chest, 0.0), Vector3(0, chest + 0.06, 0.0), Vector2(0.2, 0.125) * plump, Vector2(0.12, 0.09), shirt)
	# Воротник уголками
	for s in [-1.0, 1.0]:
		b.quad(Vector3(0.0, chest + 0.06, -0.095), Vector3(0.0, chest + 0.0, -0.13), Vector3(0.07 * s, chest + 0.0, -0.115), Vector3(0.065 * s, chest + 0.065, -0.085),
			shirt.lightened(0.25), true)
	if not woman:
		for i in 4:
			var y := waist + 0.06 + i * 0.1
			b.box(Vector3(-0.008, y, -0.121 * plump - 0.012 * (y - waist)), Vector3(0.008, y + 0.016, -0.115 * plump - 0.012 * (y - waist)), Color(0.88, 0.86, 0.8))
		# Карман на груди
		b.box(Vector3(0.05, chest - 0.16, -0.128 * plump - 0.004), Vector3(0.13, chest - 0.07, -0.122 * plump), shirt.darkened(0.12))
	# --- Руки: плечо, рукав, локоть, предплечье, кисть с большим пальцем
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var sh := Vector3(s * 0.19 * plump, chest - 0.03, 0.0)
		ball(b, sh + Vector3(-s * 0.01, 0.01, 0), Vector3(0.062, 0.055, 0.065) * plump, shirt, 4, 8)
		if sit:
			var el := Vector3(s * 0.24, base + 0.24, -0.06)
			var wr := Vector3(s * 0.17, base + 0.06, -0.33)
			limb(b, sh, el, Vector2(0.052, 0.052), Vector2(0.046, 0.046), shirt)
			limb(b, el, wr, Vector2(0.046, 0.046), Vector2(0.036, 0.036), shirt)
			_hand(b, wr + Vector3(0, -0.02, -0.04), skin, s, true)
		else:
			b.alpha = 0.7 if i == 0 else 0.6
			var el := sh + Vector3(s * 0.025, -0.29, 0.015)
			var wr := el + Vector3(s * 0.008, -0.25, -0.02)
			limb(b, sh, el, Vector2(0.052, 0.052) * plump, Vector2(0.046, 0.046), shirt)
			ball(b, el, Vector3(0.046, 0.046, 0.046), shirt, 3, 6)
			limb(b, el, wr, Vector2(0.044, 0.044), Vector2(0.038, 0.036), shirt)
			limb(b, wr + Vector3(0, 0.03, 0), wr - Vector3(0, 0.01, 0), Vector2(0.041, 0.039), Vector2(0.041, 0.039), shirt.darkened(0.15))
			_hand(b, wr - Vector3(0, 0.06, 0), skin, s, false)
			b.alpha = 1.0
	# --- Шея и голова
	var neck := chest + 0.06
	limb(b, Vector3(0, neck - 0.03, 0.005), Vector3(0, neck + 0.06, 0.01), Vector2(0.05, 0.048), Vector2(0.046, 0.045), skin)
	var hc := Vector3(0, neck + 0.145, 0.0)
	_head(b, hc, skin, hair, hat, woman, seed)


## Ботинок: подошва, носок вперёд, задник.
static func _shoe(b: MeshBuilder, at: Vector3, col: Color) -> void:
	b.box(at + Vector3(-0.05, 0.0, -0.15), at + Vector3(0.05, 0.025, 0.07), Color(0.06, 0.05, 0.05))
	ball(b, at + Vector3(0, 0.045, -0.085), Vector3(0.052, 0.045, 0.075), col, 3, 6)
	limb(b, at + Vector3(0, 0.025, 0.035), at + Vector3(0, 0.11, 0.025), Vector2(0.052, 0.055), Vector2(0.05, 0.052), col, true)


## Кисть: ладонь, пальцы вместе, большой палец к телу. Сидя — лежит на колене.
static func _hand(b: MeshBuilder, at: Vector3, skin: Color, side: float, flat: bool) -> void:
	if flat:
		ball(b, at, Vector3(0.042, 0.022, 0.06), skin, 3, 6)
		ball(b, at + Vector3(-side * 0.035, 0.0, 0.0), Vector3(0.014, 0.014, 0.03), skin, 2, 6)
		return
	ball(b, at, Vector3(0.026, 0.055, 0.042), skin, 3, 6)
	ball(b, at + Vector3(0, -0.055, 0.005), Vector3(0.02, 0.035, 0.036), skin, 3, 6)
	ball(b, at + Vector3(-side * 0.02, -0.005, -0.03), Vector3(0.014, 0.03, 0.014), skin, 2, 6)


## Голова с меткой 0.5 в альфе — её поворачивает шейдер (смотрит на игрока).
static func _head(b: MeshBuilder, c: Vector3, skin: Color, hair: Color, hat: Color, woman: bool, seed: int) -> void:
	var a0 := b.alpha
	b.alpha = 0.5
	_head_parts(b, c, skin, hair, hat, woman, seed)
	b.alpha = a0


## Голова: лицо, глаза с бровями, нос, губы, уши, причёска и головной убор.
static func _head_parts(b: MeshBuilder, c: Vector3, skin: Color, hair: Color, hat: Color, woman: bool, seed: int) -> void:
	ball(b, c, Vector3(0.092, 0.118, 0.104), skin, 8, 12)
	# Подбородок — чуть вперёд, светлый (не тенью, как щетина)
	ball(b, c + Vector3(0, -0.07, -0.035), Vector3(0.045, 0.04, 0.06), skin.lightened(0.04), 3, 8)
	# Уши
	for s in [-1.0, 1.0]:
		ball(b, c + Vector3(s * 0.092, -0.005, 0.005), Vector3(0.016, 0.03, 0.022), skin.darkened(0.06), 2, 6)
	# Глаза: белок, радужка, бровь
	var front := c.z - 0.1
	for s in [-1.0, 1.0]:
		var e := Vector3(c.x + s * 0.034, c.y + 0.014, front + 0.008)
		b.box(e + Vector3(-0.017, -0.008, -0.004), e + Vector3(0.017, 0.008, 0.0), Color(0.95, 0.95, 0.93))
		b.box(e + Vector3(-0.007, -0.007, -0.006), e + Vector3(0.007, 0.007, -0.003), Color(0.2, 0.25, 0.3) if seed % 3 else Color(0.3, 0.22, 0.14))
		b.box(e + Vector3(-0.021, 0.019, -0.004), e + Vector3(0.019, 0.027, 0.002), hair.darkened(0.25))
	# Нос и губы
	limb(b, Vector3(c.x, c.y + 0.01, front + 0.006), Vector3(c.x, c.y - 0.028, front - 0.008), Vector2(0.009, 0.008), Vector2(0.016, 0.011), skin.darkened(0.04), true)
	b.box(Vector3(c.x - 0.028, c.y - 0.058, front + 0.012), Vector3(c.x + 0.028, c.y - 0.046, front + 0.017), Color(0.66, 0.36, 0.33))
	# Очки в тонкой оправе — у каждого пятого
	if seed % 5 == 2:
		var rim := Color(0.12, 0.1, 0.09)
		for s in [-1.0, 1.0]:
			var e := Vector3(c.x + s * 0.034, c.y + 0.014, front - 0.006)
			b.box(e + Vector3(-0.024, 0.014, -0.004), e + Vector3(0.024, 0.019, 0.0), rim)
			b.box(e + Vector3(-0.024, -0.017, -0.004), e + Vector3(0.024, -0.012, 0.0), rim)
			b.box(e + Vector3(s * 0.024 - 0.003, -0.017, -0.004), e + Vector3(s * 0.024 + 0.003, 0.019, 0.0), rim)
			b.box(Vector3(c.x + s * 0.088, c.y + 0.026, front + 0.004), Vector3(c.x + s * 0.092, c.y + 0.031, c.z + 0.04), rim)
		b.box(Vector3(c.x - 0.01, c.y + 0.026, front - 0.01), Vector3(c.x + 0.01, c.y + 0.03, front - 0.006), rim)
	# Усы — у каждого третьего мужчины
	if not woman and seed % 3 == 0:
		b.box(Vector3(c.x - 0.03, c.y - 0.042, front + 0.006), Vector3(c.x + 0.03, c.y - 0.03, front + 0.013), hair.darkened(0.1))
	if woman:
		# Причёска и косынка, завязанная под подбородком
		ball(b, c + Vector3(0, 0.02, 0.012), Vector3(0.1, 0.112, 0.105), hair, 4, 10, true)
		ball(b, c + Vector3(0, 0.035, 0.01), Vector3(0.106, 0.105, 0.112), hat, 4, 10, true)
		limb(b, c + Vector3(-0.098, 0.04, 0.01), c + Vector3(-0.07, -0.11, -0.02), Vector2(0.018, 0.04), Vector2(0.014, 0.03), hat)
		limb(b, c + Vector3(0.098, 0.04, 0.01), c + Vector3(0.07, -0.11, -0.02), Vector2(0.018, 0.04), Vector2(0.014, 0.03), hat)
		ball(b, c + Vector3(0, -0.125, -0.04), Vector3(0.03, 0.018, 0.02), hat.darkened(0.1), 2, 6)
		# Узел косынки сзади
		ball(b, c + Vector3(0, 0.0, 0.11), Vector3(0.04, 0.03, 0.025), hat.darkened(0.1), 2, 6)
	else:
		# Стрижка: затылок и виски, кепка с козырьком
		ball(b, c + Vector3(0, 0.025, 0.014), Vector3(0.099, 0.11, 0.104), hair, 4, 10, true)
		ball(b, c + Vector3(0, -0.01, 0.03), Vector3(0.096, 0.08, 0.085), hair, 4, 10)
		if seed % 4 != 1:
			limb(b, c + Vector3(0, 0.055, 0.0), c + Vector3(0, 0.1, 0.0), Vector2(0.104, 0.112), Vector2(0.1, 0.108), hat, true)
			ball(b, c + Vector3(0, 0.1, 0.0), Vector3(0.1, 0.03, 0.108), hat, 2, 10, true)
			b.box(Vector3(c.x - 0.085, c.y + 0.052, c.z - 0.18), Vector3(c.x + 0.085, c.y + 0.064, c.z - 0.09), hat.darkened(0.25))


## Оля: платье в горошек с поясом и короткими рукавами, белые гольфы,
## туфли, длинные русые волосы с чёлкой и хвостом, белый бант, румянец.
static func girl(b: MeshBuilder, sit: bool) -> void:
	_mark(b, sit)
	var skin := Color(0.93, 0.76, 0.65)
	var dress := Color(0.85, 0.2, 0.3)
	var dots := Color(0.98, 0.95, 0.9)
	var hair := Color(0.62, 0.42, 0.22)
	var socks := Color(0.97, 0.97, 0.95)
	var shoe := Color(0.45, 0.12, 0.12)
	var base := 0.5 if sit else 0.86
	if sit:
		for x in [-0.08, 0.08]:
			limb(b, Vector3(x, 0.5, 0.0), Vector3(x, 0.5, -0.4), Vector2(0.075, 0.07), Vector2(0.06, 0.058), skin)
			limb(b, Vector3(x, 0.5, -0.41), Vector3(x, 0.08, -0.44), Vector2(0.055, 0.052), Vector2(0.045, 0.045), socks)
			_shoe(b, Vector3(x, 0.0, -0.45), shoe)
		limb(b, Vector3(0, 0.5, 0.05), Vector3(0, 0.56, -0.32), Vector2(0.21, 0.04), Vector2(0.22, 0.04), dress, true)
	else:
		for i in 2:
			var x := -0.075 if i == 0 else 0.075
			b.alpha = 0.9 if i == 0 else 0.8
			limb(b, Vector3(x, 0.66, 0.0), Vector3(x, 0.33, 0.0), Vector2(0.058, 0.058), Vector2(0.047, 0.05), skin)
			limb(b, Vector3(x, 0.34, 0.0), Vector3(x, 0.09, 0.0), Vector2(0.05, 0.053), Vector2(0.042, 0.045), socks)
			_shoe(b, Vector3(x, 0.0, 0.0), shoe)
		b.alpha = 1.0
		# Юбка колоколом чуть выше колен, подол темнее
		limb(b, Vector3(0, base + 0.08, 0.0), Vector3(0, 0.56, 0.0), Vector2(0.15, 0.11), Vector2(0.25, 0.2), dress, true)
		limb(b, Vector3(0, 0.585, 0.0), Vector3(0, 0.555, 0.0), Vector2(0.245, 0.198), Vector2(0.255, 0.205), dress.darkened(0.2))
	# Лиф, пояс, горошек
	var chest := base + 0.46
	limb(b, Vector3(0, base + 0.06, 0.0), Vector3(0, chest, 0.0), Vector2(0.14, 0.1), Vector2(0.16, 0.11), dress)
	limb(b, Vector3(0, chest, 0.0), Vector3(0, chest + 0.05, 0.0), Vector2(0.16, 0.11), Vector2(0.09, 0.075), dress)
	limb(b, Vector3(0, base + 0.06, 0.0), Vector3(0, base + 0.11, 0.0), Vector2(0.145, 0.104), Vector2(0.148, 0.106), Color(0.2, 0.2, 0.25))
	for p in [Vector2(-0.08, 0.2), Vector2(0.05, 0.3), Vector2(-0.02, 0.38), Vector2(0.09, 0.14), Vector2(-0.1, 0.33)]:
		b.box(Vector3(p.x, base + p.y, -0.115), Vector3(p.x + 0.035, base + p.y + 0.035, -0.105), dots)
	if not sit:
		for p in [Vector2(-0.16, 0.66), Vector2(0.12, 0.7), Vector2(-0.04, 0.62), Vector2(0.18, 0.62), Vector2(0.02, 0.74)]:
			b.box(Vector3(p.x, p.y, -0.205), Vector3(p.x + 0.04, p.y + 0.04, -0.19), dots)
	b.box(Vector3(-0.07, chest + 0.0, -0.1), Vector3(0.07, chest + 0.045, -0.085), dots)
	# Руки: короткий рукав-фонарик, руки до кистей
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var sh := Vector3(s * 0.165, chest - 0.03, 0.0)
		ball(b, sh, Vector3(0.065, 0.06, 0.06), dress, 4, 8)
		if sit:
			var el := Vector3(s * 0.19, base + 0.22, -0.06)
			var wr := Vector3(s * 0.12, base + 0.07, -0.3)
			limb(b, sh, el, Vector2(0.04, 0.04), Vector2(0.036, 0.036), skin)
			limb(b, el, wr, Vector2(0.036, 0.036), Vector2(0.03, 0.03), skin)
			_hand(b, wr + Vector3(0, -0.015, -0.035), skin, s, true)
		else:
			b.alpha = 0.7 if i == 0 else 0.6
			var el := sh + Vector3(s * 0.025, -0.27, 0.01)
			var wr := el + Vector3(s * 0.005, -0.23, -0.02)
			limb(b, sh, el, Vector2(0.04, 0.04), Vector2(0.035, 0.035), skin)
			limb(b, el, wr, Vector2(0.035, 0.035), Vector2(0.029, 0.028), skin)
			_hand(b, wr - Vector3(0, 0.05, 0), skin, s, false)
			b.alpha = 1.0
	# Шея и голова
	var neck := chest + 0.05
	limb(b, Vector3(0, neck - 0.03, 0.005), Vector3(0, neck + 0.06, 0.008), Vector2(0.042, 0.04), Vector2(0.039, 0.038), skin)
	var c := Vector3(0, neck + 0.14, 0.0)
	b.alpha = 0.5
	ball(b, c, Vector3(0.086, 0.11, 0.097), skin, 8, 12)
	ball(b, c + Vector3(0, -0.065, -0.032), Vector3(0.04, 0.036, 0.055), skin.lightened(0.04), 3, 8)
	var front := c.z - 0.093
	for s in [-1.0, 1.0]:
		var e := Vector3(c.x + s * 0.032, c.y + 0.012, front + 0.008)
		b.box(e + Vector3(-0.017, -0.009, -0.004), e + Vector3(0.017, 0.009, 0.0), Color(0.97, 0.97, 0.97))
		b.box(e + Vector3(-0.008, -0.008, -0.006), e + Vector3(0.008, 0.008, -0.003), Color(0.2, 0.45, 0.35))
		b.box(e + Vector3(-0.02, 0.009, -0.005), e + Vector3(0.02, 0.014, 0.0), Color(0.08, 0.06, 0.06))
		b.box(e + Vector3(-0.018, 0.024, -0.004), e + Vector3(0.016, 0.029, 0.002), hair.darkened(0.3))
		# Румянец
		b.box(Vector3(c.x + s * 0.05 - 0.018, c.y - 0.03, front + 0.016), Vector3(c.x + s * 0.05 + 0.018, c.y - 0.012, front + 0.02), Color(0.96, 0.62, 0.6))
	limb(b, Vector3(c.x, c.y + 0.008, front + 0.006), Vector3(c.x, c.y - 0.024, front - 0.006), Vector2(0.008, 0.007), Vector2(0.014, 0.01), skin.darkened(0.04), true)
	b.box(Vector3(c.x - 0.024, c.y - 0.052, front + 0.012), Vector3(c.x + 0.024, c.y - 0.04, front + 0.017), Color(0.85, 0.25, 0.3))
	# Волосы: шапка, чёлка, пряди до плеч, хвост с бантом
	ball(b, c + Vector3(0, 0.02, 0.012), Vector3(0.096, 0.112, 0.104), hair, 4, 12, true)
	ball(b, c + Vector3(0, -0.005, 0.03), Vector3(0.094, 0.1, 0.09), hair, 4, 12)
	limb(b, c + Vector3(0, 0.075, -0.07), c + Vector3(0, 0.035, -0.098), Vector2(0.08, 0.02), Vector2(0.075, 0.012), hair)
	for s in [-1.0, 1.0]:
		limb(b, c + Vector3(s * 0.085, 0.03, -0.02), c + Vector3(s * 0.08, -0.17, 0.02), Vector2(0.022, 0.05), Vector2(0.018, 0.045), hair)
	limb(b, c + Vector3(0, 0.0, 0.1), c + Vector3(0, -0.3, 0.14), Vector2(0.045, 0.035), Vector2(0.02, 0.018), hair, true)
	for s in [-1.0, 1.0]:
		ball(b, c + Vector3(s * 0.045, 0.02, 0.115), Vector3(0.04, 0.028, 0.02), Color(0.97, 0.97, 1.0), 2, 6)
	b.alpha = 1.0
