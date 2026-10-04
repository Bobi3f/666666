extends Node3D
## Огород игрока за задним забором: пустые грядки → ростки → ботва → поспела.
## Стоит в начале координат двора игрока; грядки — те же, что у соседей
## в world.gd (_vegetable_plot), но растения рисуются здесь по стадии.

var _plants: MeshInstance3D
var _stage := -1


func _ready() -> void:
	var zone := InteractZone.create("", Vector3(21.0, 2.0, 5.0))
	zone.position = Vector3(0, 0, -11.8)
	zone.prompt_fn = Progress.garden_prompt
	zone.activated.connect(Progress.use_garden)
	add_child(zone)
	Progress.garden_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	var stage := Progress.garden_stage()
	if stage == _stage:
		return
	_stage = stage
	if _plants:
		_plants.queue_free()
		_plants = null
	if stage == 0:
		return
	var b := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var leaf := Color(0.26, 0.45, 0.18) if stage < 3 else Color(0.45, 0.45, 0.2)
	var size: float = [0.0, 0.18, 0.45, 0.5][stage]
	var z := -13.6
	while z < -9.8:
		var x := -10.0
		while x < 10.0:
			b.box_rot(Vector3(x, 0.16 + size * 0.5, z + 0.22), Vector3(size, size * 0.5, size * 0.9), rng.randf() * TAU,
				leaf.lightened(rng.randf() * 0.12))
			# Поспевшая: цветы на ботве
			if stage == 3 and rng.randf() < 0.3:
				b.box(Vector3(x - 0.05, 0.16 + size * 0.75, z + 0.17), Vector3(x + 0.05, 0.16 + size * 0.75 + 0.08, z + 0.27), Color(0.95, 0.95, 0.9))
			x += rng.randf_range(0.8, 1.1)
		z += 0.9
	_plants = b.build_mesh()
	add_child(_plants)
