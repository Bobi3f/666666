class_name Police
extends Node3D
## Отделение милиции в городе, за площадью: здание с вывеской, флаг,
## дежурные «Жигули» с мигалкой, дежурный у входа.
##
## Здесь гасят долг по штрафам (если на посту ГАИ платить было нечем или
## уехал от инспектора) и подрабатывают дружинником: вечером обойти город
## по пяти точкам — жёлтая стрелка покажет, куда идти.

const Villagers := preload("res://scripts/world/villagers.gd")
## Отделение: центр, вход смотрит на дорогу (к -X)
const STATION := Vector3(114.0, 0, 92.0)
const PATROL_PAY := 300
## Точки обхода: двор у пятиэтажек, площадь, склад, автосалон, назад
const PATROL := [Vector3(97.0, 0, 64.0), Vector3(150.0, 0, 58.0), Vector3(122.0, 0, 21.0),
	Vector3(40.0, 0, 50.0), Vector3(104.0, 0, 92.0)]

## Долг по штрафам, грн
var debt := 0
var patrol_active := false
var patrol_idx := 0
var _patrol_day := -1
var _arrow: MeshInstance3D
var _t := 0.0
var _blink: Array = []
var _lit: MeshInstance3D


func _ready() -> void:
	add_to_group("persist")
	_build()


## Милицейские «Жигули»: белые с синей полосой, «МИЛИЦИЯ» на дверях, мигалка.
## Возвращает материалы красного и синего огня — пусть мигают.
static func car(parent: Node3D, pos: Vector3, yaw: float) -> Array:
	var b := MeshBuilder.new()
	b.ground_shade = false
	VehicleModels.zhiguli(b, Color(0.93, 0.93, 0.92), false)
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.86 - 0.02, 0.5, -2.0), Vector3(sx * 0.86 + 0.02, 0.64, 2.0), Color(0.15, 0.3, 0.7))
	b.box(Vector3(-0.45, 1.38, -0.12), Vector3(0.45, 1.46, 0.12), Color(0.2, 0.2, 0.22))
	for p in [Vector3(-0.78, 0.29, -1.3), Vector3(0.78, 0.29, -1.3), Vector3(-0.78, 0.29, 1.3), Vector3(0.78, 0.29, 1.3)]:
		var saved := b.xf
		b.xf = Transform3D(Basis.IDENTITY, p)
		VehicleModels.car_wheel(b, 0.29, 0.2)
		b.xf = saved
	var root := Node3D.new()
	root.add_child(b.build_mesh())
	var mats := []
	for i in 2:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.9, 0.1, 0.1) if i == 0 else Color(0.1, 0.3, 1.0)
		var box := BoxMesh.new()
		box.size = Vector3(0.36, 0.14, 0.2)
		box.material = m
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.position = Vector3(-0.22 if i == 0 else 0.22, 1.53, 0)
		root.add_child(mi)
		mats.append(m)
	for sx in [-1.0, 1.0]:
		var l := Label3D.new()
		l.text = "МИЛИЦИЯ"
		l.font_size = 48
		l.pixel_size = 0.004
		l.outline_size = 0
		l.modulate = Color(0.15, 0.3, 0.7)
		l.position = Vector3(sx * 0.9, 0.78, 0.1)
		l.rotation.y = sx * PI / 2.0
		root.add_child(l)
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	# Дальше чем на 60 м мигалки и надписи не нужны
	for c in root.get_children():
		(c as GeometryInstance3D).visibility_range_end = 120.0
	return mats


## Мигалка: красный и синий по очереди.
static func blink(mats: Array, t: float) -> void:
	var on := fmod(t, 0.8) < 0.4
	(mats[0] as StandardMaterial3D).albedo_color = Color(1.0, 0.1, 0.1) if on else Color(0.3, 0.05, 0.05)
	(mats[1] as StandardMaterial3D).albedo_color = Color(0.05, 0.1, 0.3) if on else Color(0.15, 0.4, 1.0)


func _build() -> void:
	var c := STATION
	var b := MeshBuilder.new()
	var wall := Color(0.86, 0.84, 0.76)
	var blue := Color(0.2, 0.35, 0.65)
	# Двухэтажное здание, вход к дороге (к -X)
	b.box(c + Vector3(-7, 0, -4.5), c + Vector3(7, 6.6, 4.5), wall, true)
	b.box(c + Vector3(-7.01, 3.2, -4.51), c + Vector3(7.01, 3.45, 4.51), blue)
	b.box(c + Vector3(-7.3, 6.6, -4.8), c + Vector3(7.3, 6.85, 4.8), Color(0.4, 0.4, 0.42))
	for fl in [0.9, 4.1]:
		for z in [-3.0, -1.5, 1.5, 3.0]:
			b.box(c + Vector3(-7.04, fl, z - 0.5), c + Vector3(-7.0, fl + 1.5, z + 0.5), Color(0.3, 0.38, 0.45))
			# Решётки на окнах первого этажа
			if fl < 1.0:
				for k in 4:
					b.box(c + Vector3(-7.07, fl, z - 0.45 + k * 0.3), c + Vector3(-7.04, fl + 1.5, z - 0.41 + k * 0.3), Color(0.2, 0.2, 0.22))
	# Крыльцо, дверь, козырёк
	b.box(c + Vector3(-8.6, 0, -1.4), c + Vector3(-7, 0.3, 1.4), Color(0.6, 0.6, 0.58), true)
	b.box(c + Vector3(-7.04, 0.3, -0.7), c + Vector3(-7.0, 2.5, 0.7), Color(0.3, 0.25, 0.2))
	b.box(c + Vector3(-8.4, 2.7, -1.5), c + Vector3(-7, 2.85, 1.5), Color(0.35, 0.35, 0.37))
	# Флагшток
	var fp := c + Vector3(-9.5, 0, 3.5)
	b.box(fp + Vector3(-0.05, 0, -0.05), fp + Vector3(0.05, 7.0, 0.05), Color(0.7, 0.7, 0.72), true)
	# Милицейский флаг: синее полотнище с белой полосой
	b.box(fp + Vector3(0, 6.1, 0.05), fp + Vector3(0.02, 6.9, 1.3), Color(0.15, 0.3, 0.65))
	b.box(fp + Vector3(0, 6.42, 0.05), fp + Vector3(0.025, 6.58, 1.3), Color(0.95, 0.95, 0.95))
	# Площадка перед входом
	b.box(c + Vector3(-13, 0, -6), c + Vector3(-7, 0.04, 6), Color(0.45, 0.45, 0.46))
	add_child(b.build_mesh())
	# Ночью горят окна дежурной части и фонарь над входом
	var lit := MeshBuilder.new()
	lit.ground_shade = false
	for z in [-3.0, -1.5, 1.5]:
		lit.box(c + Vector3(-7.06, 0.9, z - 0.5), c + Vector3(-7.04, 2.4, z + 0.5), Color(1.0, 0.88, 0.6))
	lit.box(c + Vector3(-7.07, 4.1, -3.5), c + Vector3(-7.05, 5.6, -2.5), Color(1.0, 0.88, 0.6))
	lit.box(c + Vector3(-8.3, 2.55, -0.2), c + Vector3(-8.0, 2.7, 0.2), Color(1.0, 0.95, 0.8))
	_lit = lit.build_mesh(true)
	add_child(_lit)
	var body := b.build_body()
	add_child(body)
	for side in [[Vector3(-7.05, 5.2, 0), -PI / 2.0, "МИЛИЦИЯ"], [Vector3(0, 5.2, 4.55), 0.0, "ОТДЕЛЕНИЕ МИЛИЦИИ"]]:
		var l := Label3D.new()
		l.text = side[2]
		l.font_size = 96
		l.pixel_size = 0.009
		l.outline_size = 12
		l.modulate = Color(0.95, 0.95, 1.0)
		l.outline_modulate = Color(0.1, 0.2, 0.5)
		l.position = c + side[0]
		l.rotation.y = side[1]
		add_child(l)
	_blink = car(self, c + Vector3(-9.5, 0.05, -4.2), PI / 2.0)
	# Дежурный у входа
	var pb := MeshBuilder.new()
	pb.ground_shade = false
	Villagers.person_model(pb, Color(0.3, 0.36, 0.3), Color(0.2, 0.25, 0.4), false, false)
	var duty := pb.build_mesh()
	duty.position = c + Vector3(-8.2, 0.3, 1.9)
	duty.rotation.y = -PI / 2.0
	add_child(duty)
	var desk := InteractZone.create("", Vector3(2.4, 2.2, 3.0))
	desk.position = c + Vector3(-8.6, 0, 0)
	desk.prompt_fn = _desk_prompt
	desk.activated.connect(_desk)
	add_child(desk)
	var arrow := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.4
	cone.bottom_radius = 0.0
	cone.height = 0.8
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(1.0, 0.8, 0.15)
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone.material = am
	arrow.mesh = cone
	arrow.visible = false
	add_child(arrow)
	_arrow = arrow


func _desk_prompt() -> String:
	if debt > 0:
		if GameManager.money >= debt:
			return "E — оплатить штрафы: %d грн" % debt
		return "Долг по штрафам %d грн — не хватает денег" % debt
	if patrol_active:
		return "Дежурный: «Обход не закончен — иди по стрелке»"
	var h := TimeManager.hour()
	if _patrol_day == TimeManager.day:
		return "Дежурный: «Сегодня ты уже отдежурил. Спасибо, дружинник!»"
	if h < 18.0 or h >= 23.0:
		return "Дежурный: «Дружинники нужны вечером, с 18:00 до 23:00»"
	return "E — дружинник: вечерний обход города, 5 точек, +%d грн" % PATROL_PAY


func _desk() -> void:
	if debt > 0:
		if GameManager.spend(debt):
			SoundLibrary.play("cash")
			GameManager.notify("Штрафы оплачены: %d грн. Долгов нет" % debt)
			debt = 0
			QuestManager.event("fines_paid")
		return
	var h := TimeManager.hour()
	if patrol_active or _patrol_day == TimeManager.day or h < 18.0 or h >= 23.0:
		return
	patrol_active = true
	patrol_idx = 0
	_patrol_day = TimeManager.day
	SoundLibrary.play("click", -4.0)
	GameManager.notify("Дежурный: «Надевай повязку — обойди город, жёлтая стрелка покажет куда»")
	_update_patrol_line()


func _update_patrol_line() -> void:
	GameManager.challenge_line = "Обход дружинника: точка %d из %d — иди к стрелке" % [patrol_idx + 1, PATROL.size()] if patrol_active else ""


## Штраф, который нечем заплатить, — в долг (гасится в отделении).
func add_debt(sum: int) -> void:
	debt += sum


func _process(delta: float) -> void:
	_t += delta
	blink(_blink, _t)
	var h := TimeManager.hour()
	var dark := h < 6.5 or h > 19.5
	_lit.visible = dark
	_arrow.visible = patrol_active
	if not patrol_active:
		return
	var target: Vector3 = PATROL[patrol_idx]
	_arrow.global_position = target + Vector3(0, 2.6 + sin(_t * 4.0) * 0.2, 0)
	_arrow.rotation.y = _t * 2.0
	var p := GameManager.player as Node3D
	if p == null or GameManager.vehicle != null:
		return
	# Обход — пешком; к 23:00 не успел — обход засчитан не весь
	if TimeManager.hour() >= 23.5:
		patrol_active = false
		GameManager.challenge_line = ""
		GameManager.notify("Обход не закончен к полуночи — без оплаты")
		return
	if Vector2(p.global_position.x - target.x, p.global_position.z - target.z).length() < 4.0:
		patrol_idx += 1
		SoundLibrary.play("click", -6.0, 1.3)
		if patrol_idx >= PATROL.size():
			patrol_active = false
			GameManager.challenge_line = ""
			GameManager.add_money(PATROL_PAY)
			SoundLibrary.play("cash")
			QuestManager.event("patrol")
			GameManager.notify("Обход закончен, в городе тихо. +%d грн" % PATROL_PAY)
			return
		_update_patrol_line()


func save_state() -> Dictionary:
	return {"debt": debt, "patrol_day": _patrol_day}


func load_state(d: Dictionary) -> void:
	debt = int(d.get("debt", 0))
	_patrol_day = int(d.get("patrol_day", -1))
	patrol_active = false
