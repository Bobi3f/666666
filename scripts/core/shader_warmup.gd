class_name ShaderWarmup
extends RefCounted
## Прогрев шейдеров за экраном загрузки. В браузере (WebGL) шейдер
## собирается, когда его впервые рисуют, — игра на это время замирает:
## первая машина навстречу, вход в город, люди, вода. Здесь каждый
## материал мира один раз рисуется маленьким квадратиком перед камерой,
## пока экран загрузки ещё закрывает картинку, — потом подвисаний нет.

## Слой квадратиков прогрева: при прогреве по частям камера видит только его.
const LAYER := 1 << 19


## Собрать материалы мира и нарисовать каждый пару кадров.
## per_frame > 0 — по частям (браузер, телефон): за кадр сначала столько
## материалов, кадр прошёл быстро — пачка вдвое больше. Мир камера пока не
## рисует, картинка — в четверть размера (шейдер собирается тот же, а кадр
## дешевле). Разом все шейдеры собирались одним кадром на десятки секунд —
## страница не отвечала. on_part(доля) — для полоски загрузки.
static func run(world: Node, frames := 2, per_frame := 0, on_part := Callable()) -> int:
	var cam := world.get_viewport().get_camera_3d()
	if cam == null:
		return 0
	var mats := collect(world)
	var holder := Node3D.new()
	holder.name = "ShaderWarmup"
	world.add_child(holder)
	var mask := cam.cull_mask
	var vp := world.get_viewport()
	var scale := vp.scaling_3d_scale
	if per_frame > 0:
		cam.cull_mask = LAYER
		vp.scaling_3d_scale = 0.25
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	# Каждый материал — дважды: одиночным квадратиком и «пачкой» (MultiMesh):
	# трава и деревья рисуются пачками, а это для видеокарты другой вариант
	# шейдера — без прогрева он собирался при первом взгляде на лес
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D.IDENTITY)
	# Фонарь и фары: при точечном и направленном свете — свои варианты
	# шейдеров (ночью у фонаря, первые фары). Светят прямо на квадратики
	var omni := OmniLight3D.new()
	omni.omni_range = 4.0
	omni.position = Vector3(0, 0, -1.5)
	holder.add_child(omni)
	var spot := SpotLight3D.new()
	spot.spot_range = 5.0
	spot.position = Vector3(0, 0, -0.5)
	holder.add_child(spot)
	holder.global_transform = cam.global_transform
	var i := 0
	var batch_size := per_frame
	var in_batch := 0
	var t := Time.get_ticks_msec()
	for k in mats.size():
		var m := mats[k]
		if per_frame > 0 and in_batch >= batch_size:
			if on_part.is_valid():
				on_part.call(float(k) / mats.size())
			await world.get_tree().process_frame
			var dt := Time.get_ticks_msec() - t
			t = Time.get_ticks_msec()
			if dt < 150:
				batch_size = mini(batch_size * 2, 64)
			in_batch = 0
			# Камера могла сдвинуться (игрок упал на землю) — квадратики за ней
			holder.global_transform = cam.global_transform
		in_batch += 1
		for batch in [false, true]:
			var at := Vector3((i % 20) * 0.06 - 0.6, (i / 20) * 0.06 - 0.3, -2.0)
			# Сеткой перед камерой: все видны в кадре, тень тоже считается
			if batch:
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.material_override = m
				mmi.position = at
				if per_frame > 0:
					mmi.layers = LAYER
				holder.add_child(mmi)
			else:
				var mi := MeshInstance3D.new()
				mi.mesh = quad
				mi.material_override = m
				mi.position = at
				if per_frame > 0:
					mi.layers = LAYER
				holder.add_child(mi)
			i += 1
	if per_frame > 0:
		await world.get_tree().process_frame
		cam.cull_mask = mask
		# Окно за это время меняло размер (полный экран) — мир сам выставил чёткость
		if is_equal_approx(vp.scaling_3d_scale, 0.25):
			vp.scaling_3d_scale = scale
	for f in frames:
		await world.get_tree().process_frame
	holder.queue_free()
	return mats.size()


## Сколько квадратиков рисует прогрев: каждый материал одиночным и пачкой.
static func quads(world: Node) -> int:
	return collect(world).size() * 2


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
		# Пачки (трава, деревья): материалы их меша
		var mmi := g as MultiMeshInstance3D
		if mmi and mmi.multimesh and mmi.multimesh.mesh:
			for s in mmi.multimesh.mesh.get_surface_count():
				var mm_mat := mmi.multimesh.mesh.surface_get_material(s)
				if mm_mat:
					list.append(mm_mat)
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
