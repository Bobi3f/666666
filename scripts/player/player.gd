class_name Player
extends CharacterBody3D
## Персонаж от первого лица: ходьба, бег, прыжок, действие по E, еда по Q.

const WALK := 4.0
const RUN := 7.0
const JUMP := 4.6
const GRAVITY := 12.0
const MOUSE_SENS := 0.0025

var camera: Camera3D
var car: Node3D  # машина, в которой сидим; null — пешком
var _head: Node3D
var _zones: Array[InteractZone] = []


func _ready() -> void:
	add_to_group("persist")
	GameManager.player = self
	var cs := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	cs.shape = capsule
	cs.position.y = 0.875
	add_child(cs)
	_head = Node3D.new()
	_head.position.y = 1.62
	add_child(_head)
	camera = Camera3D.new()
	camera.near = 0.05
	camera.far = 700.0
	camera.fov = 75.0
	_head.add_child(camera)
	camera.current = true
	floor_snap_length = 0.3
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		match key.physical_keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_E:
				_use()
			KEY_Q:
				if car == null:
					NeedsManager.eat_snack()
	if car != null:
		return
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-motion.relative.x * MOUSE_SENS)
		_head.rotation.x = clampf(_head.rotation.x - motion.relative.y * MOUSE_SENS, -1.45, 1.45)


func _physics_process(delta: float) -> void:
	if car != null:
		return
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		input.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		input.y += 1
	if Input.is_physical_key_pressed(KEY_A):
		input.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		input.x += 1
	var speed := RUN if Input.is_physical_key_pressed(KEY_SHIFT) else WALK
	speed *= NeedsManager.walk_factor()
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_on_floor():
		if Input.is_physical_key_pressed(KEY_SPACE):
			velocity.y = JUMP
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	# Упал за край мира — вернуть на дорогу
	if global_position.y < -20.0:
		global_position = Vector3(global_position.x, 2.0, global_position.z)
		velocity = Vector3.ZERO


# --- Действия -------------------------------------------------------------

func enter_zone(z: InteractZone) -> void:
	if not _zones.has(z):
		_zones.append(z)


func exit_zone(z: InteractZone) -> void:
	_zones.erase(z)


## Подсказка для HUD: ближайшее действие.
func current_prompt() -> String:
	var z := _nearest_zone()
	return z.prompt if z else ""


func _nearest_zone() -> InteractZone:
	var best: InteractZone = null
	var best_d := INF
	for z in _zones:
		if not is_instance_valid(z):
			continue
		var d := z.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = z
	return best


func _use() -> void:
	if car != null:
		car.exit_car()
		return
	var z := _nearest_zone()
	if z:
		z.activate()


## Садимся в машину: прячем тело, выключаем коллизию.
func sit_in(c: Node3D) -> void:
	car = c
	visible = false
	for ch in get_children():
		if ch is CollisionShape3D:
			ch.disabled = true
	_zones.clear()
	velocity = Vector3.ZERO


func stand_up(at: Vector3, yaw: float) -> void:
	car = null
	visible = true
	for ch in get_children():
		if ch is CollisionShape3D:
			ch.disabled = false
	global_position = at
	rotation.y = yaw
	camera.current = true


func save_state() -> Dictionary:
	return {
		"pos": SaveManager.vec_to_arr(global_position),
		"yaw": rotation.y,
		"pitch": _head.rotation.x,
	}


func load_state(d: Dictionary) -> void:
	if car != null:
		car.exit_car()
	global_position = SaveManager.arr_to_vec(d.get("pos"))
	rotation.y = float(d.get("yaw", 0.0))
	_head.rotation.x = float(d.get("pitch", 0.0))
	velocity = Vector3.ZERO
