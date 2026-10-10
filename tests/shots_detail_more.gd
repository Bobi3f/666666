extends SceneTree
## Детальнее: двор с газовой трубой, шинами, велосипедом; машины с
## зеркалами и поворотниками; округлые собака и куры; люди в очках.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 560)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func shot(n: String, at: Vector3, look: Vector3) -> void:
	W.get_node("Player").global_position = Vector3(at.x, 0.2, at.z) + Vector3(0, 0, 30)
	for i in 3: await physics_frame
	cam.make_current(); cam.global_position = at; cam.look_at(look)
	await save(n)
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 11 * 60.0
	cam = Camera3D.new(); cam.fov = 60; W.add_child(cam)
	# Двор у соседей (-100, -24), смотрит на улицу в -Z: двор в своих координатах
	await shot("d_street", Vector3(-112, 2.2, -36.5), Vector3(-95, 1.4, -27))
	await shot("d_yard", Vector3(-108, 1.8, -32), Vector3(-100, 1.0, -26))
	# Машины на улице и в салоне
	var car: Node3D = null
	for v in W.find_children("*", "Vehicle", true, false):
		if v.kind == "niva": car = v
	if car:
		var p: Vector3 = car.global_position
		await shot("d_niva", p + car.global_transform.basis * Vector3(2.6, 1.3, -3.2), p + Vector3(0, 0.8, 0))
	var vil = null
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("villagers.gd"): vil = c
	var dog: Node3D = vil._dogs[0].node
	await shot("d_dog", dog.global_position + Vector3(1.4, 0.8, 1.4), dog.global_position + Vector3(0, 0.35, 0))
	var ch: Node3D = vil._chickens[0].node
	vil.set_process(false)
	await shot("d_chicken", ch.global_position + Vector3(0.8, 0.5, 0.8), ch.global_position + Vector3(0, 0.25, 0))
	quit()
