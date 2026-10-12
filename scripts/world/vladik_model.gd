class_name VladikModel
extends RefCounted
## Внешность Дяди Владика (по фотографиям): крепкий полноватый мужчина
## лет тридцати, широкие плечи и живот, круглое лицо с полными щеками,
## тёмные прямые брови, короткая щетина на подбородке, стрижка почти под
## ноль — виски «на нет», сверху чуть длиннее. Летом — чёрная футболка
## оверсайз (на спине белая надпись), чёрные шорты ниже колена, часы на
## левой руке, тёмные кроссовки. В холода в гараже — старая рабочая
## куртка, тёмные штаны, ботинки и перчатки.
##
## Всё строится в MeshBuilder (как PersonModel): один меш на позу, метки
## частей тела в альфе — шаг и взгляд делает шейдер PersonModel.SHADER.
## Логика NPC (vladik.gd) знает только имена поз — модель можно заменить
## целиком (хоть на импортированную), не трогая поведение.
##
## Позы: stand — стоит, руки вдоль тела (из неё ходит и бегает);
## talk — руки сцеплены на животе, как на фото; work — у верстака, левая
## рука на столе; crouch — присел у мотора; sit — на табурете; carry —
## несёт ящик. Правое предплечье в work и crouch — отдельный меш
## (tool_arm), им машет логика: ключ, напильник, тряпка.

const SKIN := Color(0.86, 0.68, 0.56)
const HAIR := Color(0.11, 0.09, 0.08)
## Виски «на нет» — кожа сквозь щетину волос.
const FADE := Color(0.3, 0.25, 0.22)
const STUBBLE := Color(0.5, 0.4, 0.34)
const TEE := Color(0.09, 0.09, 0.1)
const SHORTS := Color(0.07, 0.07, 0.08)
const SHOE := Color(0.18, 0.18, 0.2)
const JACKET := Color(0.2, 0.24, 0.3)
const TROUSERS := Color(0.13, 0.13, 0.15)
const BOOT := Color(0.12, 0.1, 0.08)
const GLOVE := Color(0.32, 0.3, 0.24)
const WATCH := Color(0.8, 0.68, 0.38)

## Высота таза стоя и плечи (полуширина) — крупный мужчина.
const HIP := 0.92
const SHOULDER := 0.25
## Плечо и локоть правой руки (от таза) — для отдельного предплечья.
const R_SHOULDER := Vector3(0.25, 0.48, 0.0)

const POSES := ["stand", "talk", "work", "crouch", "sit", "carry"]


## Куда в позе поставить локоть и кисть правой руки (в координатах модели):
## для tool_arm. Пустой словарь — у позы рука своя.
static func tool_arm_points(pose: String) -> Dictionary:
	var xf := _torso_xf(pose)
	match pose:
		"work":
			return {"elbow": xf * Vector3(0.3, 0.2, -0.2), "hand": xf * Vector3(0.12, 0.1, -0.5)}
		"crouch":
			return {"elbow": xf * Vector3(0.3, 0.22, -0.22), "hand": xf * Vector3(0.14, 0.04, -0.5)}
	return {}


## Таз и наклон туловища в позе: туловище, руки и голова строятся от него.
static func _torso_xf(pose: String) -> Transform3D:
	match pose:
		"crouch":
			return Transform3D(Basis(Vector3.RIGHT, -0.45), Vector3(0, 0.52, 0.12))
		"sit":
			return Transform3D(Basis(Vector3.RIGHT, -0.08), Vector3(0, 0.5, 0.05))
		"work":
			return Transform3D(Basis(Vector3.RIGHT, -0.22), Vector3(0, HIP, 0))
	return Transform3D(Basis.IDENTITY, Vector3(0, HIP, 0))


## Весь Владик в позе. outfit: "summer" — футболка и шорты, "work" — куртка.
static func build(b: MeshBuilder, pose: String, outfit := "summer") -> void:
	PersonModel._mark(b, pose in ["work", "crouch", "sit"])
	var warm := outfit == "work"
	_legs(b, pose, warm)
	var saved := b.xf
	b.xf = saved * _torso_xf(pose)
	_torso(b, warm)
	_arms(b, pose, warm)
	# Шея короткая и толстая, голова
	var neck := Vector3(0, 0.55, 0.015)
	PersonModel.limb(b, neck, neck + Vector3(0, 0.08, 0.005), Vector2(0.085, 0.08), Vector2(0.08, 0.076), SKIN)
	head(b, neck + Vector3(0, 0.17, -0.005))
	b.xf = saved
	if pose == "carry":
		# Ящик с запчастями перед животом
		var bx := Vector3(0, HIP + 0.2, -0.42)
		b.box(bx - Vector3(0.22, 0.12, 0.15), bx + Vector3(0.22, 0.12, 0.15), Color(0.45, 0.33, 0.2))
		b.box(bx + Vector3(-0.18, 0.12, -0.1), bx + Vector3(-0.02, 0.17, 0.05), Color(0.55, 0.56, 0.58))
		b.box(bx + Vector3(0.03, 0.12, -0.08), bx + Vector3(0.17, 0.2, 0.08), Color(0.25, 0.25, 0.28))


## Ноги: шорты ниже колена или штаны, икры, кроссовки или ботинки.
## Стоя — с метками шага (левая 0.9, правая 0.8).
static func _legs(b: MeshBuilder, pose: String, warm: bool) -> void:
	var cloth := TROUSERS if warm else SHORTS
	var foot := BOOT if warm else SHOE
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var hip := Vector3(s * 0.12, HIP, 0.0)
		var knee: Vector3
		var ankle: Vector3
		match pose:
			"crouch":
				hip = Vector3(s * 0.13, 0.52, 0.12)
				knee = Vector3(s * 0.2, 0.55, -0.3)
				ankle = Vector3(s * 0.17, 0.1, -0.12)
			"sit":
				hip = Vector3(s * 0.13, 0.5, 0.05)
				knee = Vector3(s * 0.16, 0.52, -0.4)
				ankle = Vector3(s * 0.16, 0.1, -0.45)
			_:
				knee = Vector3(s * 0.125, 0.5, -0.01)
				ankle = Vector3(s * 0.12, 0.1, 0.0)
		var walking := pose in ["stand", "carry", "talk"]
		if walking:
			b.alpha = 0.9 if i == 0 else 0.8
		# Бедро в шортах (штанах) — широкое, шорты заканчиваются ниже колена
		PersonModel.limb(b, hip, knee, Vector2(0.11, 0.115), Vector2(0.085, 0.09), cloth)
		PersonModel.ball(b, knee, Vector3(0.085, 0.085, 0.09), cloth, 3, 8)
		var cuff := knee.lerp(ankle, 0.0 if warm else 0.16)
		if warm:
			PersonModel.limb(b, knee, ankle + Vector3(0, 0.02, 0), Vector2(0.08, 0.085), Vector2(0.07, 0.072), cloth)
		else:
			PersonModel.limb(b, knee, cuff, Vector2(0.088, 0.092), Vector2(0.088, 0.092), cloth)
			PersonModel.limb(b, cuff, ankle, Vector2(0.06, 0.065), Vector2(0.045, 0.048), SKIN)
		_shoe(b, Vector3(ankle.x, 0.0, ankle.z), foot, warm)
		b.alpha = 1.0


## Обувь: кроссовок с подошвой или высокий рабочий ботинок.
static func _shoe(b: MeshBuilder, at: Vector3, col: Color, boot: bool) -> void:
	b.box(at + Vector3(-0.055, 0.0, -0.17), at + Vector3(0.055, 0.03, 0.07), Color(0.08, 0.08, 0.08) if boot else Color(0.75, 0.74, 0.7))
	PersonModel.ball(b, at + Vector3(0, 0.055, -0.09), Vector3(0.056, 0.05, 0.085), col, 3, 8)
	PersonModel.limb(b, at + Vector3(0, 0.03, 0.03), at + Vector3(0, 0.16 if boot else 0.12, 0.02), Vector2(0.056, 0.06), Vector2(0.052, 0.056), col, true)


## Туловище от таза (0) вверх: широкий таз, живот вперёд, грудь, плечи.
## Футболка оверсайз — ниже пояса, или куртка с воротником и молнией.
static func _torso(b: MeshBuilder, warm: bool) -> void:
	var top := JACKET if warm else TEE
	# Пояс шорт и низ футболки навыпуск
	PersonModel.limb(b, Vector3(0, -0.04, 0.0), Vector3(0, 0.08, 0.0), Vector2(0.2, 0.15), Vector2(0.22, 0.16), TROUSERS if warm else SHORTS)
	PersonModel.limb(b, Vector3(0, 0.0, 0.0), Vector3(0, 0.18, -0.01), Vector2(0.25, 0.19), Vector2(0.26, 0.2), top, true)
	# Живот — главное в силуэте сбоку
	PersonModel.ball(b, Vector3(0, 0.2, -0.07), Vector3(0.235, 0.22, 0.2), top, 6, 14)
	PersonModel.limb(b, Vector3(0, 0.18, -0.01), Vector3(0, 0.44, 0.0), Vector2(0.26, 0.2), Vector2(0.27, 0.17), top)
	PersonModel.limb(b, Vector3(0, 0.44, 0.0), Vector3(0, 0.57, 0.01), Vector2(0.27, 0.17), Vector2(0.15, 0.11), top)
	PersonModel.ball(b, Vector3(0, 0.45, 0.0), Vector3(0.265, 0.09, 0.168), top, 4, 14)
	if warm:
		# Молния, воротник-стойка, нагрудные карманы
		b.box(Vector3(-0.008, 0.02, -0.29), Vector3(0.008, 0.5, -0.27), Color(0.6, 0.6, 0.6))
		PersonModel.limb(b, Vector3(0, 0.52, 0.01), Vector3(0, 0.6, 0.015), Vector2(0.11, 0.1), Vector2(0.105, 0.095), top.darkened(0.15))
		for s in [-1.0, 1.0]:
			b.box(Vector3(s * 0.06, 0.32, -0.215), Vector3(s * 0.17, 0.42, -0.2), top.darkened(0.12))
	else:
		# Ворот футболки с тёмной лентой, как на фото
		PersonModel.limb(b, Vector3(0, 0.545, 0.01), Vector3(0, 0.575, 0.012), Vector2(0.095, 0.085), Vector2(0.09, 0.082), Color(0.04, 0.04, 0.04))


## Руки по позе. Футболка — короткий широкий рукав до локтя, дальше кожа;
## куртка — рукав до кисти, перчатки. Часы — на левой руке.
static func _arms(b: MeshBuilder, pose: String, warm: bool) -> void:
	var sleeve := JACKET if warm else TEE
	var hand_col := GLOVE if warm else SKIN
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var sh := Vector3(s * SHOULDER, 0.48, 0.0)
		var el: Vector3
		var wr: Vector3
		match pose:
			"talk":
				el = Vector3(s * 0.31, 0.2, -0.08)
				wr = Vector3(s * 0.05, 0.12, -0.3)
			"work":
				if i == 1:
					el = Vector3(0.3, 0.2, -0.2)
					wr = el
				else:
					el = Vector3(-0.32, 0.2, -0.15)
					wr = Vector3(-0.18, 0.06, -0.48)
			"crouch":
				if i == 1:
					el = Vector3(0.3, 0.22, -0.22)
					wr = el
				else:
					el = Vector3(-0.3, 0.2, -0.22)
					wr = Vector3(-0.16, 0.0, -0.46)
			"sit":
				el = Vector3(s * 0.31, 0.18, -0.1)
				wr = Vector3(s * 0.2, 0.06, -0.38)
			"carry":
				el = Vector3(s * 0.32, 0.18, -0.16)
				wr = Vector3(s * 0.2, 0.2, -0.38)
			_:
				el = sh + Vector3(s * 0.05, -0.29, 0.02)
				wr = el + Vector3(s * 0.01, -0.26, -0.02)
		var walking := pose == "stand"
		if walking:
			b.alpha = 0.7 if i == 0 else 0.6
		# Плечо и рукав
		PersonModel.ball(b, sh + Vector3(-s * 0.03, -0.01, 0), Vector3(0.08, 0.07, 0.085), sleeve, 4, 10)
		var cut := sh.lerp(el, 0.9) if not warm else el
		PersonModel.limb(b, sh, cut, Vector2(0.092, 0.092), Vector2(0.088, 0.088), sleeve, not warm)
		if not warm:
			PersonModel.limb(b, cut, el, Vector2(0.066, 0.066), Vector2(0.06, 0.06), SKIN)
		PersonModel.ball(b, el, Vector3(0.06, 0.06, 0.06), sleeve if warm else SKIN, 3, 8)
		if wr != el:
			PersonModel.limb(b, el, wr, Vector2(0.058, 0.058) if not warm else Vector2(0.064, 0.064), Vector2(0.045, 0.045), sleeve if warm else SKIN)
			PersonModel.ball(b, wr + (wr - el).normalized() * 0.045, Vector3(0.045, 0.05, 0.05), hand_col, 3, 8)
			if i == 0 and not warm:
				# Часы на левом запястье: браслет и квадратный циферблат
				PersonModel.limb(b, wr - (wr - el).normalized() * 0.01, wr - (wr - el).normalized() * 0.035, Vector2(0.05, 0.05), Vector2(0.05, 0.05), WATCH, true)
				var face := wr - (wr - el).normalized() * 0.022 + Vector3(0, 0.045, 0)
				b.box(face - Vector3(0.018, 0.006, 0.018), face + Vector3(0.018, 0.006, 0.018), Color(0.25, 0.22, 0.15))
		b.alpha = 1.0


## Правое предплечье с ключом — отдельный меш для работы: от локтя (0)
## до кисти hand. Ключ — гаечный, рожок вперёд.
static func tool_arm(b: MeshBuilder, hand: Vector3, outfit := "summer") -> void:
	var warm := outfit == "work"
	var col := JACKET if warm else SKIN
	PersonModel.limb(b, Vector3.ZERO, hand, Vector2(0.06, 0.06), Vector2(0.046, 0.046), col)
	PersonModel.ball(b, hand + hand.normalized() * 0.04, Vector3(0.046, 0.05, 0.05), GLOVE if warm else SKIN, 3, 8)
	var k := hand + hand.normalized() * 0.06
	var steel := Color(0.72, 0.72, 0.74)
	PersonModel.limb(b, k + Vector3(-0.07, 0, 0), k + Vector3(0.12, 0, -0.02), Vector2(0.01, 0.006), Vector2(0.01, 0.006), steel, true)
	b.box(k + Vector3(0.11, -0.012, -0.05), k + Vector3(0.15, 0.012, 0.0), steel)


## Голова: круглое полное лицо, щёки, подбородок со щетиной, широкий нос,
## тёмные прямые брови, уши; волосы — короткая тёмная «площадка» сверху,
## виски и затылок почти под ноль. Метка 0.5 — поворот головы шейдером.
static func head(b: MeshBuilder, c: Vector3) -> void:
	var a0 := b.alpha
	b.alpha = 0.5
	PersonModel.ball(b, c, Vector3(0.108, 0.126, 0.112), SKIN, 8, 14)
	# Полные щёки — лицо круглое книзу, второй подбородок, щетина на
	# подбородке и чуть над губой
	PersonModel.ball(b, c + Vector3(0, -0.045, -0.012), Vector3(0.106, 0.075, 0.1), SKIN, 5, 14)
	PersonModel.ball(b, c + Vector3(0, -0.098, -0.035), Vector3(0.05, 0.03, 0.058), STUBBLE.lerp(SKIN, 0.35), 3, 10)
	PersonModel.ball(b, c + Vector3(0, -0.108, 0.01), Vector3(0.07, 0.035, 0.065), SKIN.darkened(0.04), 3, 10)
	# Уши
	for s in [-1.0, 1.0]:
		PersonModel.ball(b, c + Vector3(s * 0.108, -0.005, 0.01), Vector3(0.018, 0.034, 0.024), SKIN.darkened(0.07), 2, 6)
	# Глаза, тёмные прямые брови
	var front := c.z - 0.108
	for s in [-1.0, 1.0]:
		var e := Vector3(c.x + s * 0.038, c.y + 0.016, front + 0.008)
		b.box(e + Vector3(-0.017, -0.007, -0.004), e + Vector3(0.017, 0.007, 0.0), Color(0.95, 0.94, 0.92))
		b.box(e + Vector3(-0.008, -0.007, -0.006), e + Vector3(0.008, 0.007, -0.003), Color(0.18, 0.12, 0.08))
		b.box(e + Vector3(-0.026, 0.02, -0.006), e + Vector3(0.024, 0.031, 0.002), HAIR)
	# Нос широкий, губы
	PersonModel.limb(b, Vector3(c.x, c.y + 0.008, front + 0.004), Vector3(c.x, c.y - 0.032, front - 0.014), Vector2(0.011, 0.01), Vector2(0.022, 0.016), SKIN.darkened(0.05), true)
	b.box(Vector3(c.x - 0.03, c.y - 0.062, front + 0.012), Vector3(c.x + 0.03, c.y - 0.05, front + 0.018), Color(0.68, 0.42, 0.38))
	# Волосы: виски и затылок под ноль (тёмная щетина по коже), сверху —
	# короткая площадка, линия надо лбом прямая
	PersonModel.ball(b, c + Vector3(0, 0.014, 0.026), Vector3(0.111, 0.126, 0.104), FADE, 6, 14, true)
	PersonModel.ball(b, c + Vector3(0, -0.015, 0.035), Vector3(0.106, 0.098, 0.094), FADE, 4, 12)
	PersonModel.ball(b, c + Vector3(0, 0.068, 0.01), Vector3(0.108, 0.078, 0.116), HAIR, 4, 14, true)
	b.alpha = a0
