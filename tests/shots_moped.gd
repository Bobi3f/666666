extends SceneTree
## Снимки начала игры: мопед у калитки, соседские «Жигули» с табличкой,
## мопед вблизи, учебные «Жигули» у автодрома.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func view(name: String, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c is CanvasLayer: c.visible = false
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 10 * 60.0
	var P = W.get_node("Player"); P.set_physics_process(false)
	cam = Camera3D.new(); W.add_child(cam)
	var M = W.get_node("Moped")
	var mp: Vector3 = M.global_position
	await view("start_gate", P.global_position + Vector3(0, 1.7, 0), mp + Vector3(1.5, 0.5, 0))
	await view("moped_close", mp + Vector3(1.6, 1.0, 1.8), mp + Vector3(0, 0.6, 0))
	await view("moped_side", mp + Vector3(0.2, 0.8, 2.6), mp + Vector3(0, 0.6, 0))
	var C = W.get_node("Car")
	await view("car_for_sale", C.global_position + Vector3(-6, 2.5, 5), C.global_position + Vector3(0, 1, 0))
	var SC = W.get_node("AutoSchool").car
	await view("school_car", SC.global_position + Vector3(-6, 3, 6), SC.global_position + Vector3(0, 0.8, 0))
	quit()
