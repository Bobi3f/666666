extends SceneTree
## Цена каждого эффекта: в одном и том же виде выключаем по одному
## (свечение, сглаживание, тени, рисунок поверхностей, трава, туман,
## виньетка) и смотрим время кадра.
var W
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func frame_ms() -> float:
	for i in 20: await process_frame
	var t := Time.get_ticks_usec()
	for i in 40: await process_frame
	return (Time.get_ticks_usec() - t) / 1000.0 / 40.0
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 12 * 60.0
	var P = W.get_node("Player")
	P.global_position = Vector3(-58, 0.3, -32); P.rotation.y = -1.2
	root.get_node("SettingsManager").set_detail(2)
	var env: Environment = W._env
	var sun: DirectionalLight3D = W._sun
	var vp := root.get_viewport()
	var base := await frame_ms()
	print("основа: %.1f мс  (msaa %d, glow %s, тени %s)" % [base, vp.msaa_3d, env.glow_enabled, sun.shadow_enabled])
	var tests := [
		["свечение", func(on): env.glow_enabled = on],
		["сглаживание MSAA", func(on): vp.msaa_3d = Viewport.MSAA_2X if on else Viewport.MSAA_DISABLED],
		["тени", func(on): sun.shadow_enabled = on],
		["2 каскада теней", func(on): sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if on else DirectionalLight3D.SHADOW_ORTHOGONAL],
		["рисунок поверхностей", func(on): MeshBuilder.set_surface(0.0, 1.0 if on else 0.0)],
		["трава и цветы", func(on): for c in W.get_node("Vegetation").get_children(): if c is MultiMeshInstance3D and not String(c.name).begins_with("Tree"): c.visible = on],
		["деревья", func(on): for c in W.get_node("Vegetation").get_children(): if String(c.name).begins_with("Tree"): c.visible = on],
		["туман", func(on): env.fog_enabled = on],
		["цветокоррекция", func(on): env.adjustment_enabled = on],
		["тени облаков", func(on): MeshBuilder.set_clouds(0.9 if on else 0.0)],
	]
	var orig := [env.glow_enabled, vp.msaa_3d, sun.shadow_enabled, sun.directional_shadow_mode, env.fog_enabled, env.adjustment_enabled]
	for t in tests:
		t[1].call(false)
		var ms := await frame_ms()
		t[1].call(true)
		env.glow_enabled = orig[0]; vp.msaa_3d = orig[1]; sun.shadow_enabled = orig[2]; sun.directional_shadow_mode = orig[3]
		env.fog_enabled = orig[4]; env.adjustment_enabled = orig[5]
		MeshBuilder.set_surface(0.0, 1.0); MeshBuilder.set_clouds(0.9)
		print("без «%s»: %.1f мс  (экономия %+.1f мс, %.0f%%)" % [t[0], ms, base - ms, 100.0 * (base - ms) / base])
	vp.scaling_3d_scale = 0.75
	print("3D в 75%% разрешения: %.1f мс" % await frame_ms())
	quit()
