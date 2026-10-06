class_name ShaderWarmup
extends RefCounted
## Прогрев шейдеров за экраном загрузки. В браузере (WebGL) шейдер
## собирается, когда его впервые рисуют, — игра на это время замирает:
## первая машина навстречу, вход в город, люди, вода. Здесь каждый
## материал мира один раз рисуется маленьким квадратиком перед камерой,
## пока экран загрузки ещё закрывает картинку, — потом подвисаний нет.


## Собрать материалы мира и нарисовать каждый пару кадров.
static func run(world: Node, frames := 2) -> int:
	var cam := world.get_viewport().get_camera_3d()
	if cam == null:
		return 0
	var mats := collect(world)
	var holder := Node3D.new()
	holder.name = "ShaderWarmup"
	world.add_child(holder)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var i := 0
	for m in mats:
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = m
		# Сеткой перед камерой: все видны в кадре, тень тоже считается
		mi.position = Vector3((i % 20) * 0.06 - 0.6, (i / 20) * 0.06 - 0.3, -2.0)
		holder.add_child(mi)
		i += 1
	holder.global_transform = cam.global_transform
	for f in frames:
		await world.get_tree().process_frame
	holder.queue_free()
	return mats.size()


## Разные материалы мира: у ShaderMaterial важен сам шейдер (один на всех
## людей), у остальных — сам материал.
static func collect(root: Node) -> Array[Material]:
	var out: Array[Material] = []
	var seen := {}
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		var list: Array[Material] = []
		if g.material_override:
			list.append(g.material_override)
		var mi := g as MeshInstance3D
		if mi and mi.mesh:
			for s in mi.mesh.get_surface_count():
				var sm := mi.mesh.surface_get_material(s)
				if sm:
					list.append(sm)
		var cp := g as CPUParticles3D
		if cp and cp.mesh:
			for s in cp.mesh.get_surface_count():
				var pm := cp.mesh.surface_get_material(s)
				if pm:
					list.append(pm)
		for m in list:
			var key: Variant = (m as ShaderMaterial).shader if m is ShaderMaterial else m
			if key == null or seen.has(key):
				continue
			seen[key] = true
			out.append(m)
	return out
