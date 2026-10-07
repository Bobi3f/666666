class_name PrincessModel
## Принцесса во всех подробностях: пышное розовое платье в три яруса с
## оборками и кружевом по подолу, корсет со шнуровкой, атласный пояс с бантом
## сзади, рукава-фонарики, длинные белые перчатки, жемчужное ожерелье с
## кулоном, серьги, золотые волнистые волосы до лопаток, сумочка на цепочке.
## Лицо: голубые глаза с ресницами, брови и губы — по настроению.
##   angry = false — добрая: улыбается, руки вдоль тела, в правой — поводки.
##   angry = true — злая: брови к переносице, губы надуты, руки скрещены.
## Метки частей тела в альфе — как у PersonModel (шейдер ходьбы).

const P := preload("res://scripts/world/person_model.gd")

const DRESS := Color(0.95, 0.5, 0.72)
const DRESS_DARK := Color(0.86, 0.36, 0.6)
const FRILL := Color(0.99, 0.72, 0.86)
const LACE := Color(0.99, 0.97, 0.97)
const SKIN := Color(0.95, 0.79, 0.69)
const HAIR := Color(0.9, 0.72, 0.32)
const GOLD := Color(1.0, 0.8, 0.25)
const GLOVE := Color(0.98, 0.96, 0.95)

const WAIST := 0.95
const CHEST := 1.32
const NECK := 1.37
## Где правая рука держит поводки (координаты модели) — по позе.
const LEASH_HAND := Vector3(0.2, 0.72, -0.03)
const LEASH_HAND_ANGRY := Vector3(0.1, 1.12, -0.19)
## Низ сумочки — сюда вешаются брелочки.
const BAG := Vector3(-0.21, 0.8, 0.09)


static var _shader: Shader


## Материал как у всех людей (шаг, взгляд), но без чужих теней на ней и с
## мягкой подсветкой снизу: тень от чёлки и короны и сумрак под подбородком
## казались щетиной.
static func material() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = P.SHADER.replace("shader_type spatial;", "shader_type spatial;\nrender_mode shadows_disabled;") \
			.replace("ROUGHNESS = 0.9;", "ROUGHNESS = 0.9;\n\tEMISSION = COLOR.rgb * 0.22;")
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	return mat


static func build(b: MeshBuilder, angry: bool) -> void:
	P._mark(b, false)
	_legs(b)
	_skirt(b)
	_bodice(b)
	_arms(b, angry)
	_neck(b)
	var a0 := b.alpha
	b.alpha = 0.5
	_head(b, Vector3(0, NECK + 0.14, 0.0), angry)
	b.alpha = a0
	_bag(b)


## Ноги в светлых колготках и розовые туфельки с бантиками — видны из-под
## подола. Качаются при ходьбе (метки 0.9 / 0.8).
static func _legs(b: MeshBuilder) -> void:
	var tights := Color(0.97, 0.9, 0.88)
	var shoe := Color(0.93, 0.42, 0.62)
	for i in 2:
		var x := -0.075 if i == 0 else 0.075
		b.alpha = 0.9 if i == 0 else 0.8
		P.limb(b, Vector3(x, 0.66, 0.0), Vector3(x, 0.33, 0.0), Vector2(0.056, 0.056), Vector2(0.046, 0.049), tights)
		P.limb(b, Vector3(x, 0.34, 0.0), Vector3(x, 0.09, 0.0), Vector2(0.047, 0.05), Vector2(0.035, 0.038), tights)
		P._shoe(b, Vector3(x, 0.0, 0.0), shoe)
		# Бантик на мыске и тонкий каблучок
		P.ball(b, Vector3(x - 0.018, 0.075, -0.125), Vector3(0.016, 0.01, 0.008), LACE, 2, 6)
		P.ball(b, Vector3(x + 0.018, 0.075, -0.125), Vector3(0.016, 0.01, 0.008), LACE, 2, 6)
		b.box(Vector3(x - 0.015, 0.0, 0.035), Vector3(x + 0.015, 0.04, 0.065), shoe.darkened(0.3))
	b.alpha = 1.0


## Юбка колоколом в три яруса, между ярусами — оборки, по подолу кружево;
## по ткани блёстки.
static func _skirt(b: MeshBuilder) -> void:
	var tiers := [
		[WAIST, 0.72, Vector2(0.15, 0.115), Vector2(0.25, 0.21), DRESS],
		[0.72, 0.5, Vector2(0.25, 0.21), Vector2(0.31, 0.27), DRESS.lightened(0.06)],
		[0.5, 0.3, Vector2(0.31, 0.27), Vector2(0.36, 0.31), DRESS.lightened(0.12)],
	]
	for t in tiers:
		P.limb(b, Vector3(0, t[0], 0), Vector3(0, t[1], 0), t[2], t[3], t[4])
	# Оборки: короткий «козырёк» шире яруса, волной
	for f in [[0.745, 0.7, Vector2(0.255, 0.215)], [0.525, 0.48, Vector2(0.315, 0.275)]]:
		var r: Vector2 = f[2]
		P.limb(b, Vector3(0, f[0], 0), Vector3(0, f[1], 0), r, r + Vector2(0.03, 0.03), FRILL)
		for k in 14:
			var a := TAU * k / 14.0
			P.ball(b, Vector3(cos(a) * (r.x + 0.03), f[1] + 0.005, sin(a) * (r.y + 0.03)), Vector3(0.03, 0.012, 0.03), FRILL, 2, 5)
	# Кружево по подолу и нижний край — закрыт снизу
	P.limb(b, Vector3(0, 0.315, 0), Vector3(0, 0.27, 0), Vector2(0.36, 0.31), Vector2(0.375, 0.325), LACE, true)
	for k in 18:
		var a := TAU * k / 18.0
		P.ball(b, Vector3(cos(a) * 0.375, 0.275, sin(a) * 0.325), Vector3(0.025, 0.018, 0.025), LACE, 2, 5)
	# Блёстки
	for k in 22:
		var a := TAU * fmod(k * 0.381, 1.0)
		var y := 0.34 + fmod(k * 0.293, 1.0) * 0.58
		var t := inverse_lerp(WAIST, 0.3, y)
		var rx := lerpf(0.15, 0.36, t) + 0.006
		var rz := lerpf(0.115, 0.31, t) + 0.006
		var p := Vector3(cos(a) * rx, y, sin(a) * rz)
		b.box(p - Vector3(0.008, 0.008, 0.008), p + Vector3(0.008, 0.008, 0.008), Color(1.0, 0.95, 0.75) if k % 3 else LACE)


## Корсет со шнуровкой, кружевной вырез, атласный пояс с большим бантом сзади.
static func _bodice(b: MeshBuilder) -> void:
	P.limb(b, Vector3(0, WAIST - 0.02, 0), Vector3(0, CHEST, 0), Vector2(0.13, 0.095), Vector2(0.155, 0.105), DRESS_DARK)
	# Плечи и верх груди — открытые, кружевной край выреза
	P.limb(b, Vector3(0, CHEST - 0.01, 0), Vector3(0, NECK, 0), Vector2(0.15, 0.1), Vector2(0.085, 0.07), SKIN)
	P.limb(b, Vector3(0, CHEST - 0.035, 0), Vector3(0, CHEST + 0.005, 0), Vector2(0.158, 0.108), Vector2(0.153, 0.104), LACE)
	# Шнуровка крест-накрест
	for k in 4:
		var y := WAIST + 0.06 + k * 0.07
		var z := -0.1 - k * 0.002
		P.limb(b, Vector3(-0.03, y, z - 0.004), Vector3(0.03, y + 0.05, z - 0.004), Vector2(0.004, 0.004), Vector2(0.004, 0.004), LACE)
		P.limb(b, Vector3(0.03, y, z - 0.004), Vector3(-0.03, y + 0.05, z - 0.004), Vector2(0.004, 0.004), Vector2(0.004, 0.004), LACE)
	# Пояс и бант
	P.limb(b, Vector3(0, WAIST - 0.03, 0), Vector3(0, WAIST + 0.03, 0), Vector2(0.14, 0.104), Vector2(0.136, 0.1), FRILL)
	var bow := Vector3(0, WAIST, 0.11)
	for s in [-1.0, 1.0]:
		P.ball(b, bow + Vector3(s * 0.06, 0.015, 0.0), Vector3(0.06, 0.04, 0.022), FRILL, 3, 6)
		P.limb(b, bow + Vector3(s * 0.01, -0.01, 0.0), bow + Vector3(s * 0.05, -0.28, 0.04), Vector2(0.025, 0.006), Vector2(0.03, 0.005), FRILL)
	P.ball(b, bow, Vector3(0.024, 0.024, 0.02), FRILL.darkened(0.1), 2, 6)


## Рукава-фонарики с кружевом, длинные перчатки до локтя.
static func _arms(b: MeshBuilder, angry: bool) -> void:
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var sh := Vector3(s * 0.165, CHEST - 0.03, 0.0)
		P.ball(b, sh + Vector3(s * 0.01, 0.0, 0.0), Vector3(0.075, 0.065, 0.068), FRILL, 4, 8)
		var el: Vector3
		var wr: Vector3
		if angry:
			# Руки скрещены на груди: локти вперёд, кисти — у другого локтя
			el = Vector3(s * 0.2, CHEST - 0.22, -0.08)
			wr = Vector3(-s * 0.1, CHEST - 0.17 + (0.03 if s > 0.0 else 0.0), -0.17 - (0.025 if s > 0.0 else 0.0))
		else:
			b.alpha = 0.7 if i == 0 else 0.6
			el = sh + Vector3(s * 0.025, -0.27, 0.01)
			wr = el + Vector3(s * 0.005, -0.23, -0.02)
		P.limb(b, sh + Vector3(0, -0.04, 0), sh + (el - sh) * 0.35, Vector2(0.06, 0.06), Vector2(0.045, 0.045), LACE)
		P.limb(b, sh, el, Vector2(0.04, 0.04), Vector2(0.035, 0.035), SKIN)
		P.limb(b, el + (el - wr).normalized() * 0.03, wr, Vector2(0.038, 0.038), Vector2(0.03, 0.029), GLOVE)
		var hand := wr + (wr - el).normalized() * 0.045
		P.ball(b, hand, Vector3(0.03, 0.05, 0.04) if not angry else Vector3(0.035, 0.03, 0.045), GLOVE, 3, 6)
		if not angry and s > 0.0:
			# Поводки собраны в кулаке — петли
			P.ball(b, hand + Vector3(0.0, -0.035, -0.01), Vector3(0.022, 0.02, 0.022), Color(0.85, 0.15, 0.25), 2, 6)
		b.alpha = 1.0


## Шея, жемчужное ожерелье с розовым кулоном.
static func _neck(b: MeshBuilder) -> void:
	P.limb(b, Vector3(0, NECK - 0.03, 0.005), Vector3(0, NECK + 0.06, 0.008), Vector2(0.042, 0.04), Vector2(0.038, 0.037), SKIN)
	for k in 16:
		var a := TAU * k / 16.0
		var front := maxf(-sin(a), 0.0)
		var p := Vector3(cos(a) * 0.058, NECK - 0.005 - front * 0.04, sin(a) * 0.052 - front * 0.025)
		P.ball(b, p, Vector3(0.008, 0.008, 0.008), Color(0.97, 0.95, 0.9), 2, 5)
	P.ball(b, Vector3(0, NECK - 0.07, -0.085), Vector3(0.014, 0.018, 0.008), Color(0.95, 0.25, 0.55), 2, 6)


## Голова: лицо, глаза с ресницами, брови и губы по настроению, румянец,
## серьги, волосы с чёлкой набок, локонами у лица и волной по спине.
static func _head(b: MeshBuilder, c: Vector3, angry: bool) -> void:
	# Низ лица светлее верха: свет сверху его затеняет, и без этого
	# подбородок выглядит как щетина
	P.ball(b, c, Vector3(0.084, 0.108, 0.095), SKIN, 8, 12, true)
	_lower_half(b, c, Vector3(0.084, 0.108, 0.095), SKIN.lightened(0.12), 8, 12)
	P.ball(b, c + Vector3(0, -0.064, -0.032), Vector3(0.038, 0.035, 0.054), SKIN.lightened(0.14), 3, 8)
	var front := c.z - 0.091
	var brow := HAIR.darkened(0.35)
	for s in [-1.0, 1.0]:
		var e := Vector3(c.x + s * 0.031, c.y + 0.012, front + 0.008)
		b.box(e + Vector3(-0.018, -0.01, -0.004), e + Vector3(0.018, 0.01, 0.0), Color(0.98, 0.98, 0.98))
		b.box(e + Vector3(-0.009, -0.009, -0.006), e + Vector3(0.009, 0.009, -0.003), Color(0.25, 0.52, 0.88))
		b.box(e + Vector3(-0.004, -0.004, -0.007), e + Vector3(0.004, 0.004, -0.0055), Color(0.05, 0.06, 0.1))
		b.box(e + Vector3(s * 0.002, 0.002, -0.0075), e + Vector3(s * 0.002 + 0.003, 0.005, -0.0065), Color.WHITE)
		# Ресницы: линия над глазом и стрелка к виску
		b.box(e + Vector3(-0.02, 0.009, -0.006), e + Vector3(0.02, 0.014, 0.0), Color(0.06, 0.04, 0.05))
		P.limb(b, e + Vector3(s * 0.018, 0.012, -0.004), e + Vector3(s * 0.03, 0.02, 0.0), Vector2(0.003, 0.002), Vector2(0.001, 0.001), Color(0.06, 0.04, 0.05))
		# Брови: добрая — плавной дугой, злая — сведены к переносице
		if angry:
			P.limb(b, e + Vector3(-s * 0.014, 0.017, -0.004), e + Vector3(s * 0.02, 0.034, 0.0), Vector2(0.004, 0.004), Vector2(0.003, 0.003), brow)
		else:
			P.limb(b, e + Vector3(-s * 0.016, 0.026, -0.004), e + Vector3(s * 0.004, 0.032, -0.002), Vector2(0.0035, 0.0035), Vector2(0.004, 0.004), brow)
			P.limb(b, e + Vector3(s * 0.004, 0.032, -0.002), e + Vector3(s * 0.021, 0.026, 0.0), Vector2(0.004, 0.004), Vector2(0.0025, 0.0025), brow)
		# Румянец: добрая — нежный, злая — от обиды ярче
		b.box(Vector3(c.x + s * 0.05 - 0.017, c.y - 0.03, front + 0.016), Vector3(c.x + s * 0.05 + 0.017, c.y - 0.013, front + 0.02),
			Color(0.98, 0.55, 0.55) if angry else Color(0.98, 0.66, 0.66))
		# Серьги: золотой гвоздик и розовая капелька
		var ear := c + Vector3(s * 0.084, -0.01, 0.006)
		P.ball(b, ear, Vector3(0.014, 0.027, 0.02), SKIN.darkened(0.05), 2, 6)
		P.ball(b, ear + Vector3(s * 0.006, -0.03, 0.0), Vector3(0.006, 0.006, 0.006), GOLD, 2, 5)
		P.ball(b, ear + Vector3(s * 0.006, -0.045, 0.0), Vector3(0.007, 0.011, 0.007), Color(0.95, 0.3, 0.6), 2, 5)
	P.limb(b, Vector3(c.x, c.y + 0.006, front + 0.006), Vector3(c.x, c.y - 0.022, front - 0.005), Vector2(0.007, 0.006), Vector2(0.012, 0.009), SKIN.darkened(0.04), true)
	# Губы
	var lip := Color(0.9, 0.32, 0.45)
	var m := Vector3(c.x, c.y - 0.048, front + 0.002)
	if angry:
		# Надула губки, уголки вниз
		P.ball(b, m + Vector3(0, 0.002, 0), Vector3(0.016, 0.008, 0.006), lip, 2, 6)
		P.ball(b, m + Vector3(0, -0.006, 0.0), Vector3(0.014, 0.007, 0.006), lip.darkened(0.08), 2, 6)
		for s in [-1.0, 1.0]:
			b.box(m + Vector3(s * 0.016 - 0.004, -0.008, 0.0), m + Vector3(s * 0.016 + 0.004, -0.004, 0.004), lip.darkened(0.25))
	else:
		# Улыбка: уголки вверх
		b.box(m + Vector3(-0.02, -0.002, 0.0), m + Vector3(0.02, 0.005, 0.004), lip)
		b.box(m + Vector3(-0.015, -0.009, 0.0), m + Vector3(0.015, -0.002, 0.004), lip.darkened(0.06))
		for s in [-1.0, 1.0]:
			b.box(m + Vector3(s * 0.022 - 0.004, 0.003, 0.0), m + Vector3(s * 0.022 + 0.004, 0.009, 0.004), lip.darkened(0.1))
	# Волосы: шапка, затылок, чёлка набок
	P.ball(b, c + Vector3(0, 0.022, 0.012), Vector3(0.094, 0.11, 0.104), HAIR, 4, 12, true)
	P.ball(b, c + Vector3(0, -0.005, 0.032), Vector3(0.093, 0.1, 0.09), HAIR, 4, 12)
	# Чёлка набок: пряди прилегают ко лбу, слева длиннее
	for k in 5:
		var fx := -0.06 + k * 0.028
		P.ball(b, c + Vector3(fx, 0.078 - k * 0.006, -0.078 + absf(fx) * 0.25), Vector3(0.03, 0.02 + (4 - k) * 0.003, 0.018), HAIR.lightened(0.03 * (k % 2)), 2, 6)
	# Локоны у лица — волной до груди
	for s in [-1.0, 1.0]:
		var pts := [c + Vector3(s * 0.082, 0.04, -0.03), c + Vector3(s * 0.095, -0.08, -0.03), c + Vector3(s * 0.085, -0.18, -0.045),
			c + Vector3(s * 0.105, -0.27, -0.05), c + Vector3(s * 0.095, -0.34, -0.06)]
		for k in pts.size() - 1:
			var w := 0.022 - k * 0.003
			P.limb(b, pts[k], pts[k + 1], Vector2(w, w * 1.6), Vector2(w - 0.003, (w - 0.003) * 1.6), HAIR if k % 2 == 0 else HAIR.lightened(0.06))
		P.ball(b, pts[pts.size() - 1], Vector3(0.018, 0.022, 0.018), HAIR, 2, 6)
	# Волна по спине до лопаток: широкая прядь и три волнистых пряди поверх
	P.limb(b, c + Vector3(0, -0.02, 0.07), c + Vector3(0, -0.42, 0.13), Vector2(0.085, 0.04), Vector2(0.1, 0.025), HAIR)
	for k in 3:
		var x := (k - 1) * 0.05
		var p0 := c + Vector3(x, -0.02, 0.095)
		var p1 := c + Vector3(x * 1.2 + 0.015, -0.18, 0.12)
		var p2 := c + Vector3(x * 1.3 - 0.015, -0.32, 0.14)
		var p3 := c + Vector3(x * 1.35 + 0.01, -0.46, 0.145)
		var col := HAIR.lightened(0.04 * k)
		P.limb(b, p0, p1, Vector2(0.03, 0.02), Vector2(0.028, 0.018), col)
		P.limb(b, p1, p2, Vector2(0.028, 0.018), Vector2(0.025, 0.016), col)
		P.limb(b, p2, p3, Vector2(0.025, 0.016), Vector2(0.012, 0.01), col, true)


## Нижняя половина эллипсоида (как PersonModel.ball, только низ).
static func _lower_half(b: MeshBuilder, c: Vector3, r: Vector3, col: Color, lat: int, lon: int) -> void:
	for j in lat / 2:
		var t0 := -PI * 0.5 + PI * j / lat
		var t1 := -PI * 0.5 + PI * (j + 1) / lat
		for i in lon:
			var p0 := P._sph(t0, TAU * i / lon)
			var p1 := P._sph(t0, TAU * (i + 1) / lon)
			var p2 := P._sph(t1, TAU * (i + 1) / lon)
			var p3 := P._sph(t1, TAU * i / lon)
			b.smooth_quad([c + p1 * r, c + p0 * r, c + p3 * r, c + p2 * r], [P._en(p1, r), P._en(p0, r), P._en(p3, r), P._en(p2, r)], col)


## Сумочка на тонкой золотой цепочке через плечо — сзади на левом боку.
static func _bag(b: MeshBuilder) -> void:
	var bag := Color(0.85, 0.3, 0.55)
	P.limb(b, Vector3(0.14, CHEST + 0.01, 0.06), Vector3(-0.2, BAG.y + 0.14, BAG.z), Vector2(0.004, 0.004), Vector2(0.004, 0.004), GOLD)
	P.limb(b, Vector3(0.14, CHEST + 0.01, 0.06), Vector3(0.155, CHEST + 0.03, -0.02), Vector2(0.004, 0.004), Vector2(0.004, 0.004), GOLD)
	b.box(Vector3(BAG.x - 0.03, BAG.y, BAG.z - 0.08), Vector3(BAG.x + 0.03, BAG.y + 0.13, BAG.z + 0.08), bag)
	b.box(Vector3(BAG.x - 0.035, BAG.y + 0.07, BAG.z - 0.085), Vector3(BAG.x + 0.035, BAG.y + 0.135, BAG.z + 0.085), bag.darkened(0.15))
	P.ball(b, Vector3(BAG.x - 0.036, BAG.y + 0.075, BAG.z), Vector3(0.006, 0.01, 0.01), GOLD, 2, 5)


## Брелочки на сумочке — из коллекции игрока (ids из Princess.KEYCHAINS).
static func charms(ids: Array) -> MeshBuilder:
	var b := MeshBuilder.new()
	b.ground_shade = false
	var n := 0
	for id in ids:
		var at := Vector3(BAG.x - 0.035, BAG.y - 0.01, BAG.z - 0.06 + n * 0.024)
		P.limb(b, at + Vector3(0, 0.03, 0), at, Vector2(0.002, 0.002), Vector2(0.002, 0.002), Color(0.8, 0.8, 0.82))
		var c := at + Vector3(0, -0.015, 0)
		match id:
			"crown":
				b.box(c + Vector3(-0.004, -0.008, -0.01), c + Vector3(0.004, 0.006, 0.01), GOLD)
				for k in 3:
					b.box(c + Vector3(-0.004, 0.006, -0.009 + k * 0.008), c + Vector3(0.004, 0.012, -0.007 + k * 0.008), GOLD)
			"snezhka":
				P.ball(b, c, Vector3(0.008, 0.012, 0.012), Color(0.97, 0.96, 0.94), 2, 5)
			"barsik":
				P.ball(b, c, Vector3(0.008, 0.012, 0.011), Color(0.55, 0.52, 0.48), 2, 5)
			"heart":
				P.ball(b, c + Vector3(0, 0.002, -0.005), Vector3(0.005, 0.008, 0.007), Color(0.9, 0.1, 0.2), 2, 5)
				P.ball(b, c + Vector3(0, 0.002, 0.005), Vector3(0.005, 0.008, 0.007), Color(0.9, 0.1, 0.2), 2, 5)
				b.box(c + Vector3(-0.004, -0.01, -0.004), c + Vector3(0.004, 0.0, 0.004), Color(0.9, 0.1, 0.2))
			"star":
				b.box(c + Vector3(-0.003, -0.01, -0.003), c + Vector3(0.003, 0.01, 0.003), Color(1.0, 0.85, 0.2))
				b.box(c + Vector3(-0.003, -0.003, -0.01), c + Vector3(0.003, 0.003, 0.01), Color(1.0, 0.85, 0.2))
			_:
				b.box(c + Vector3(-0.005, -0.006, -0.014), c + Vector3(0.005, 0.004, 0.014), Color(0.98, 0.55, 0.75))
				b.box(c + Vector3(-0.004, 0.004, -0.007), c + Vector3(0.004, 0.009, 0.007), Color(0.6, 0.75, 0.85))
		n += 1
	return b


## Ошейник с медальоном на собаку (модель AnimalModel.dog) или кота.
static func collar(b: MeshBuilder, color: Color, cat := false) -> void:
	if cat:
		P.limb(b, Vector3(0, 0.29, -0.17), Vector3(0, 0.31, -0.19), Vector2(0.06, 0.06), Vector2(0.058, 0.058), color, true)
		P.ball(b, Vector3(0, 0.27, -0.235), Vector3(0.014, 0.014, 0.014), GOLD, 2, 6)
		return
	P.limb(b, Vector3(0, 0.515, -0.35), Vector3(0, 0.545, -0.375), Vector2(0.082, 0.082), Vector2(0.08, 0.08), color, true)
	P.ball(b, Vector3(0, 0.49, -0.425), Vector3(0.016, 0.02, 0.006), GOLD, 2, 6)
