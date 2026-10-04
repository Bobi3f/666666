class_name RoadDetails
extends RefCounted
## Мелочь дорог, которой мир богаче: трава между колеями и осыпь по краям
## грунтовок, тропинки, тротуары с бордюром, разметка, бетонные фонари.
## Всё — коробками в общий меш (MeshBuilder), без отдельных узлов: на
## телефоне это не добавляет вызовов отрисовки, мелочь режется по кускам
## и пропадает вдали.


## Грунтовка от a до c шириной 2·half: полоса травы посередине (по ней не
## ездят), тёмные колеи, неровный край — осыпь и кочки травы, камешки.
static func dirt(b: MeshBuilder, a: Vector2, c: Vector2, half: float, dirt_col: Color, rng: RandomNumberGenerator, grass := true) -> void:
	var d := c - a
	var len := d.length()
	if len < 1.0:
		return
	var dir := d / len
	var side := Vector2(dir.y, -dir.x)
	var yaw := atan2(d.x, d.y)
	# Трава примятая, пыльная — под цвет земли, а не газон
	var grass_col := dirt_col.lerp(Color(0.3, 0.4, 0.18), 0.55)
	# Трава посередине — кусками, с разрывами, где проезжали поперёк
	if grass:
		var t := rng.randf_range(0.0, 3.0)
		while t < len - 1.0:
			var l := rng.randf_range(2.5, 6.0)
			var m := a + dir * minf(t + l * 0.5, len - 0.5)
			b.box_rot(Vector3(m.x, 0.037, m.y), Vector3(rng.randf_range(0.2, 0.38), 0.008, l), yaw + rng.randf_range(-0.03, 0.03), grass_col.darkened(rng.randf_range(0.0, 0.15)))
			t += l + rng.randf_range(1.5, 5.0)
	# Край: осыпь (тёмная земля) и трава, наползающая на дорогу
	var t2 := rng.randf_range(0.0, 4.0)
	while t2 < len:
		var s := -1.0 if rng.randf() < 0.5 else 1.0
		var p := a + dir * t2 + side * s * (half - rng.randf_range(0.0, 0.35))
		if rng.randf() < 0.55:
			b.box_rot(Vector3(p.x, 0.038, p.y), Vector3(rng.randf_range(0.25, 0.6), 0.006, rng.randf_range(0.6, 1.6)), yaw + rng.randf_range(-0.3, 0.3), grass_col.lerp(dirt_col, rng.randf_range(0.2, 0.5)))
		else:
			b.box_rot(Vector3(p.x, 0.038, p.y), Vector3(rng.randf_range(0.2, 0.5), 0.006, rng.randf_range(0.5, 1.2)), yaw + rng.randf_range(-0.4, 0.4), dirt_col.darkened(rng.randf_range(0.06, 0.14)))
		# Камешек на обочине
		if rng.randf() < 0.3:
			var q := a + dir * (t2 + 0.7) + side * s * (half + 0.15)
			b.box_rot(Vector3(q.x, 0.0, q.y), Vector3(0.18, 0.1, 0.14), rng.randf() * TAU, Color(0.55, 0.53, 0.5).darkened(rng.randf() * 0.2))
		t2 += rng.randf_range(2.0, 5.0)


## Тропинка по точкам: протоптанная земля, чуть шире — светлая трава по краю.
static func path(b: MeshBuilder, pts: Array, width: float, rng: RandomNumberGenerator) -> void:
	var earth := Color(0.48, 0.41, 0.3)
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var c: Vector2 = pts[i + 1]
		var d := c - a
		var len := d.length()
		var yaw := atan2(d.x, d.y)
		var m := (a + c) * 0.5
		b.box_rot(Vector3(m.x, 0.012, m.y), Vector3(width + 0.5, 0.004, len + 0.3), yaw, Color(0.42, 0.5, 0.26))
		b.box_rot(Vector3(m.x, 0.016, m.y), Vector3(width, 0.004, len + 0.2), yaw, earth.darkened(rng.randf_range(0.0, 0.1)))
		# Утоптанные пятна и камешки
		for k in int(len / 3.0):
			var p := a.lerp(c, rng.randf()) + Vector2(d.y, -d.x).normalized() * rng.randf_range(-width * 0.3, width * 0.3)
			b.box_rot(Vector3(p.x, 0.02, p.y), Vector3(rng.randf_range(0.2, 0.45), 0.004, rng.randf_range(0.3, 0.7)), rng.randf() * TAU, earth.darkened(0.2))


## Тротуар в плане r (X, Z) с бордюром со стороны дороги (road_side: "x0",
## "x1", "z0", "z1" — какая грань прямоугольника выходит к проезжей части).
static func sidewalk(b: MeshBuilder, r: Rect2, road_side: String) -> void:
	var tile := Color(0.56, 0.56, 0.54)
	var curb := Color(0.7, 0.7, 0.68)
	b.box(Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0.1, r.end.y), tile)
	# Швы плитки поперёк
	var along_x := r.size.x > r.size.y
	var t := 1.0
	var total := r.size.x if along_x else r.size.y
	while t < total:
		if along_x:
			b.box(Vector3(r.position.x + t, 0.1, r.position.y), Vector3(r.position.x + t + 0.04, 0.104, r.end.y), tile.darkened(0.18))
		else:
			b.box(Vector3(r.position.x, 0.1, r.position.y + t), Vector3(r.end.x, 0.104, r.position.y + t + 0.04), tile.darkened(0.18))
		t += 1.0
	match road_side:
		"x0":
			b.box(Vector3(r.position.x - 0.05, 0, r.position.y), Vector3(r.position.x + 0.15, 0.17, r.end.y), curb)
		"x1":
			b.box(Vector3(r.end.x - 0.15, 0, r.position.y), Vector3(r.end.x + 0.05, 0.17, r.end.y), curb)
		"z0":
			b.box(Vector3(r.position.x, 0, r.position.y - 0.05), Vector3(r.end.x, 0.17, r.position.y + 0.15), curb)
		"z1":
			b.box(Vector3(r.position.x, 0, r.end.y - 0.15), Vector3(r.end.x, 0.17, r.end.y + 0.05), curb)


## Прерывистая осевая на асфальте от a до c (по X или по Z).
static func center_line(b: MeshBuilder, a: Vector2, c: Vector2, y := 0.051) -> void:
	var d := c - a
	var len := d.length()
	var dir := d / len
	var t := 1.0
	while t < len - 1.0:
		var p := a + dir * t
		var q := a + dir * minf(t + 2.5, len)
		var mn := Vector3(minf(p.x, q.x) - (0.06 if absf(dir.x) < 0.5 else 0.0), y, minf(p.y, q.y) - (0.06 if absf(dir.y) < 0.5 else 0.0))
		var mx := Vector3(maxf(p.x, q.x) + (0.06 if absf(dir.x) < 0.5 else 0.0), y + 0.004, maxf(p.y, q.y) + (0.06 if absf(dir.y) < 0.5 else 0.0))
		b.box(mn, mx, Color(0.9, 0.9, 0.86))
		t += 6.0


## Бетонный фонарь, как вдоль советских трасс и улиц: опора, изогнутый
## кронштейн над дорогой, плафон «кобра» — ночью светится (glow).
## yaw — куда смотрит кронштейн (0 — к −Z).
static func lamp(b: MeshBuilder, glow: MeshBuilder, p: Vector3, yaw: float, height := 7.5) -> void:
	var saved := b.xf
	var g_saved := glow.xf
	var xf := saved * Transform3D(Basis(Vector3.UP, yaw), p)
	b.xf = xf
	glow.xf = g_saved * Transform3D(Basis(Vector3.UP, yaw), p)
	var concrete := Color(0.66, 0.66, 0.63)
	b.box(Vector3(-0.15, 0, -0.15), Vector3(0.15, 1.0, 0.15), concrete.darkened(0.1), true)
	b.box(Vector3(-0.11, 1.0, -0.11), Vector3(0.11, height, 0.11), concrete)
	# Кронштейн: подъём и вылет над дорогой
	b.box(Vector3(-0.04, height - 0.4, -0.04), Vector3(0.04, height + 0.25, 0.04), Color(0.35, 0.36, 0.37))
	b.box(Vector3(-0.035, height + 0.2, -1.9), Vector3(0.035, height + 0.27, 0.0), Color(0.35, 0.36, 0.37))
	b.box(Vector3(-0.03, height - 0.25, -0.05), Vector3(0.03, height + 0.2, -0.0), Color(0.35, 0.36, 0.37))
	# Плафон
	b.box(Vector3(-0.2, height + 0.08, -2.4), Vector3(0.2, height + 0.3, -1.75), Color(0.42, 0.44, 0.46))
	glow.box(Vector3(-0.15, height + 0.02, -2.32), Vector3(0.15, height + 0.08, -1.83), Color(1.0, 0.86, 0.6))
	b.xf = saved
	glow.xf = g_saved
