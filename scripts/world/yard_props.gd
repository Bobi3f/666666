class_name YardProps
extends RefCounted
## Мелочи двора и улицы, без которых село как нарисованное: жёлтая газовая
## труба вдоль заборов с отводом к дому и счётчиком, покрашенные шины-клумбы
## у забора, бочка для дождевой воды, велосипед у забора, вёдра и лейка у
## огорода, скворечник на шесте. Всё — в меш двора (свои координаты двора:
## улица в +Z, забор по z = 12, калитка у entrance), свой генератор чисел —
## остальной двор не сдвигается.

const P := preload("res://scripts/world/person_model.gd")
const GAS := Color(0.9, 0.74, 0.16)


## Всё сразу. ox, oz — наружные полуразмеры дома, entrance — где калитка (x).
static func add(b: MeshBuilder, seed_: int, ox: float, oz: float, entrance: float, poor: bool, rich: bool) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	gas_pipe(b, ox, oz, entrance)
	tyre_planters(b, r, entrance)
	rain_barrel(b, Vector3(ox + 0.45, 0, oz - 0.9))
	if not rich:
		bicycle(b, r, Vector3(6.6, 0, 11.72))
	buckets(b, r, Vector3(2.0, 0, -8.4))
	if not poor:
		birdhouse(b, Vector3(-2.6, 0, -8.2))


## Газовая труба над улицей на высоте 2,75 м (выше камеры за спиной игрока): от соседа к соседу, на
## столбиках (не в калитке), отвод к дому над двором, вниз по стене к
## серому счётчику.
static func gas_pipe(b: MeshBuilder, ox: float, oz: float, entrance: float) -> void:
	var y := 2.75
	var z := 12.35
	VehicleModels.tube(b, Vector3(-12.5, y, z), Vector3(12.5, y, z), 0.035, GAS)
	for x in [-10.0, -5.0, 0.0, 5.0, 10.0]:
		if absf(x - entrance) < 2.2:
			continue
		VehicleModels.tube(b, Vector3(x, 0, z), Vector3(x, y, z), 0.025, GAS.darkened(0.15))
	# Отвод: по двору к правой стене дома и вниз
	var bx := ox + 0.25
	VehicleModels.pipe(b, [Vector3(bx, y, z), Vector3(bx, y, oz - 0.6), Vector3(bx, 1.25, oz - 0.6)], 0.022, GAS)
	b.box(Vector3(bx - 0.14, 0.95, oz - 0.75), Vector3(bx + 0.06, 1.25, oz - 0.45), Color(0.62, 0.64, 0.62))
	b.box(Vector3(bx - 0.145, 1.05, oz - 0.68), Vector3(bx - 0.14, 1.15, oz - 0.52), Color(0.85, 0.88, 0.9))


## Две-три старые шины на улице у забора, покрашены и с цветами внутри.
static func tyre_planters(b: MeshBuilder, r: RandomNumberGenerator, entrance: float) -> void:
	var paints := [Color(0.95, 0.95, 0.93), Color(0.3, 0.5, 0.85), Color(0.9, 0.3, 0.25), Color(0.95, 0.8, 0.2)]
	var flowers := [Color(0.95, 0.3, 0.3), Color(0.98, 0.85, 0.2), Color(0.85, 0.45, 0.9), Color(1, 1, 1)]
	var n := r.randi_range(2, 3)
	var x := entrance - 3.6
	for i in n:
		var c := Vector3(x - i * 0.85, 0, 12.75)
		if c.x < -10.5:
			break
		var col: Color = paints[r.randi() % paints.size()]
		P.limb(b, c, c + Vector3(0, 0.22, 0), Vector2(0.34, 0.34), Vector2(0.32, 0.32), col, true)
		b.box(c + Vector3(-0.22, 0.2, -0.22), c + Vector3(0.22, 0.24, 0.22), Color(0.26, 0.19, 0.13))
		for k in 5:
			var p := c + Vector3(r.randf_range(-0.16, 0.16), 0.24, r.randf_range(-0.16, 0.16))
			b.box(p + Vector3(-0.012, 0, -0.012), p + Vector3(0.012, 0.18, 0.012), Color(0.22, 0.45, 0.17))
			b.box(p + Vector3(-0.05, 0.18, -0.05), p + Vector3(0.05, 0.24, 0.05), flowers[r.randi() % flowers.size()])


## Бочка под водостоком: сбоку дома, с водой и крышкой-доской.
static func rain_barrel(b: MeshBuilder, c: Vector3) -> void:
	var iron := Color(0.28, 0.33, 0.36)
	P.limb(b, c, c + Vector3(0, 0.85, 0), Vector2(0.3, 0.3), Vector2(0.32, 0.32), iron, false)
	for y in [0.15, 0.7]:
		P.limb(b, c + Vector3(0, y, 0), c + Vector3(0, y + 0.04, 0), Vector2(0.32, 0.32), Vector2(0.325, 0.325), iron.darkened(0.25))
	b.box(c + Vector3(-0.27, 0.0, -0.27), c + Vector3(0.27, 0.8, 0.27), Color(0.18, 0.24, 0.27))
	b.box(c + Vector3(-0.38, 0.86, -0.06), c + Vector3(0.38, 0.9, 0.06), Color(0.5, 0.38, 0.25))


## Велосипед «Украина» прислонён к забору изнутри двора.
static func bicycle(b: MeshBuilder, r: RandomNumberGenerator, c: Vector3) -> void:
	var frame: Color = [Color(0.15, 0.3, 0.55), Color(0.55, 0.12, 0.12), Color(0.12, 0.35, 0.2)][r.randi() % 3]
	var dark := Color(0.08, 0.08, 0.08)
	var steel := Color(0.65, 0.66, 0.68)
	var wr := 0.33
	var back := c + Vector3(-0.55, wr, 0)
	var front := c + Vector3(0.55, wr, 0)
	for w in [back, front]:
		for k in 8:
			var a0 := TAU * k / 8.0
			var a1 := TAU * (k + 1) / 8.0
			VehicleModels.tube(b, w + Vector3(cos(a0), sin(a0), 0) * wr, w + Vector3(cos(a1), sin(a1), 0) * wr, 0.018, dark)
		VehicleModels.tube(b, w + Vector3(-wr * 0.9, 0, 0), w + Vector3(wr * 0.9, 0, 0), 0.004, steel)
		VehicleModels.tube(b, w + Vector3(0, -wr * 0.9, 0), w + Vector3(0, wr * 0.9, 0), 0.004, steel)
	var pedal := c + Vector3(-0.05, wr, 0)
	var seat := c + Vector3(-0.2, 0.95, 0)
	var head := c + Vector3(0.42, 0.95, 0)
	VehicleModels.pipe(b, [back, pedal, seat, back], 0.017, frame)
	VehicleModels.pipe(b, [pedal, head, seat], 0.017, frame)
	VehicleModels.tube(b, head, front, 0.015, frame)
	b.box(seat + Vector3(-0.12, 0.02, -0.05), seat + Vector3(0.08, 0.07, 0.05), dark)
	VehicleModels.tube(b, head + Vector3(0, 0.05, -0.25), head + Vector3(0, 0.05, 0.25), 0.012, steel)
	VehicleModels.tube(b, head, head + Vector3(0, 0.05, 0), 0.012, steel)


## Вёдра и лейка у калитки в огород.
static func buckets(b: MeshBuilder, r: RandomNumberGenerator, c: Vector3) -> void:
	var zinc := Color(0.62, 0.64, 0.66)
	for i in 2:
		var p := c + Vector3(i * 0.45, 0, r.randf_range(-0.1, 0.1))
		P.limb(b, p, p + Vector3(0, 0.3, 0), Vector2(0.1, 0.1), Vector2(0.14, 0.14), zinc if i == 0 else Color(0.25, 0.4, 0.6), false)
		b.box(p + Vector3(-0.1, 0.02, -0.1), p + Vector3(0.1, 0.25, 0.1), Color(0.2, 0.22, 0.24))
	var w := c + Vector3(1.05, 0, 0)
	var green := Color(0.25, 0.48, 0.3)
	P.limb(b, w, w + Vector3(0, 0.3, 0), Vector2(0.11, 0.11), Vector2(0.1, 0.1), green, true)
	VehicleModels.tube(b, w + Vector3(0.08, 0.08, 0), w + Vector3(0.4, 0.34, 0), 0.015, green)
	VehicleModels.pipe(b, [w + Vector3(-0.08, 0.3, 0), w + Vector3(-0.05, 0.42, 0), w + Vector3(0.05, 0.42, 0), w + Vector3(0.08, 0.3, 0)], 0.01, green.darkened(0.2))


## Скворечник на высоком шесте.
static func birdhouse(b: MeshBuilder, c: Vector3) -> void:
	var wood := Color(0.5, 0.38, 0.24)
	VehicleModels.tube(b, c, c + Vector3(0, 3.4, 0), 0.03, Color(0.45, 0.36, 0.25))
	var h := c + Vector3(0, 3.4, 0)
	b.box(h + Vector3(-0.12, 0, -0.12), h + Vector3(0.12, 0.34, 0.12), wood)
	b.box(h + Vector3(-0.04, 0.18, 0.12), h + Vector3(0.04, 0.26, 0.125), Color(0.06, 0.05, 0.04))
	b.quad(h + Vector3(-0.17, 0.32, 0.17), h + Vector3(0.17, 0.32, 0.17), h + Vector3(0.17, 0.44, -0.17), h + Vector3(-0.17, 0.44, -0.17), wood.darkened(0.3), true)
