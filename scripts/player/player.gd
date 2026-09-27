class_name Player
extends CharacterBody3D
## Персонаж от первого лица: ходьба с разгоном, бег, прыжок, приседание,
## подъём на ступеньки, покачивание камеры, действие по E, еда по Q.

const WALK := 4.0
const RUN := 7.0
const CROUCH := 1.8
## Разгон и торможение на земле и в воздухе, м/с²
const ACCEL := 30.0
const AIR_ACCEL := 6.0
const JUMP := 4.8
const GRAVITY := 12.0
## Прыжок ещё засчитывается чуть после края и чуть до приземления
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.15
const MOUSE_SENS := 0.0025
## Поворот камеры стрелками, рад/с
const KEY_TURN := 2.4
const STAND_HEIGHT := 1.75
const CROUCH_HEIGHT := 1.1
const STAND_EYES := 1.62
const CROUCH_EYES := 0.98
## Ступенька, на которую персонаж заходит сам, без прыжка
const STEP_HEIGHT := 0.45
const FOV := 75.0
const RUN_FOV := 82.0

var camera: Camera3D
var car: Node3D  # машина, в которой сидим; null — пешком
var crouching := false
var _head: Node3D
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _zones: Array[InteractZone] = []
var _crouch_toggled := false
var _coyote := 0.0
var _jump_buffer := 0.0
var _bob_time := 0.0
var _land_dip := 0.0
var _fall_speed := 0.0
## Пройдено с последнего шага — для звука шагов
var _stride := 0.0


func _ready() -> void:
	add_to_group("persist")
	GameManager.player = self
	_shape = CollisionShape3D.new()
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.3
	_capsule.height = STAND_HEIGHT
	_shape.shape = _capsule
	_shape.position.y = STAND_HEIGHT * 0.5
	add_child(_shape)
	_head = Node3D.new()
	_head.position.y = STAND_EYES
	add_child(_head)
	camera = Camera3D.new()
	camera.near = 0.05
	camera.far = 700.0
	camera.fov = FOV
	_head.add_child(camera)
	camera.current = true
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)
	if not GameManager.touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not GameManager.touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		match key.physical_keycode:
			KEY_E:
				_use()
			KEY_Q:
				if car == null:
					NeedsManager.eat_snack()
			KEY_SPACE:
				if car == null:
					_jump_buffer = JUMP_BUFFER
			KEY_C:
				if car == null:
					_crouch_toggled = not _crouch_toggled
	if car != null:
		return
	# На телефоне касания эмулируют мышь — камеру крутит сенсорное управление
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not GameManager.touch_mode:
		var k := MOUSE_SENS * SettingsManager.mouse_sens
		_look(-motion.relative.x * k, -motion.relative.y * k)


func _look(yaw: float, pitch: float) -> void:
	rotate_y(yaw)
	_head.rotation.x = clampf(_head.rotation.x + pitch, -1.45, 1.45)


func _physics_process(delta: float) -> void:
	if car != null:
		return
	_turn_with_keys(delta)
	_update_crouch(delta)

	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		input.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		input.y += 1
	if Input.is_physical_key_pressed(KEY_A):
		input.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		input.x += 1
	# Джойстик и стик — плавно: чуть отклонил — идёшь медленно
	var amount := 1.0
	if input == Vector2.ZERO and GameManager.move_axis != Vector2.ZERO:
		input = GameManager.move_axis
		amount = clampf(input.length(), 0.0, 1.0)
	var running := Input.is_physical_key_pressed(KEY_SHIFT) and not crouching and input.y < 0.0
	var speed := CROUCH if crouching else (RUN if running else WALK)
	speed *= NeedsManager.walk_factor()
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized() * amount

	# Плавный разгон и торможение; в воздухе направление меняется слабо
	var on_floor := is_on_floor()
	var accel := ACCEL if on_floor else AIR_ACCEL
	var flat := Vector2(velocity.x, velocity.z).move_toward(Vector2(dir.x, dir.z) * speed, accel * delta)
	velocity.x = flat.x
	velocity.z = flat.y

	_coyote = COYOTE_TIME if on_floor else maxf(_coyote - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if _jump_buffer > 0.0 and _coyote > 0.0 and _can_stand():
		velocity.y = JUMP
		_jump_buffer = 0.0
		_coyote = 0.0
		_crouch_toggled = false
		SoundLibrary.play("jump", -8.0, randf_range(0.9, 1.1))
	elif not on_floor:
		velocity.y -= GRAVITY * delta
		_fall_speed = maxf(_fall_speed, -velocity.y)

	if not (on_floor and _try_step(delta)):
		move_and_slide()

	# Приземление: камера чуть проседает, тем сильнее, чем выше падали
	if is_on_floor() and _fall_speed > 0.0:
		if _fall_speed > 3.0:
			_land_dip = minf(_fall_speed * 0.025, 0.25)
			SoundLibrary.play("land", -6.0 + minf(_fall_speed, 8.0), randf_range(0.9, 1.1))
		_fall_speed = 0.0
	_update_camera(delta, running and flat.length() > WALK)
	_footsteps(delta)

	# Упал за край мира — вернуть на дорогу
	if global_position.y < -20.0:
		global_position = Vector3(global_position.x, 2.0, global_position.z)
		velocity = Vector3.ZERO


## Стрелки поворачивают камеру — если мышь неудобна или не захвачена.
func _turn_with_keys(delta: float) -> void:
	var yaw := 0.0
	var pitch := 0.0
	if Input.is_physical_key_pressed(KEY_LEFT):
		yaw += 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT):
		yaw -= 1.0
	if Input.is_physical_key_pressed(KEY_UP):
		pitch += 1.0
	if Input.is_physical_key_pressed(KEY_DOWN):
		pitch -= 1.0
	if yaw != 0.0 or pitch != 0.0:
		_look(yaw * KEY_TURN * delta, pitch * KEY_TURN * 0.6 * delta)


## Ctrl — держать, C — переключить. Встать можно, только если над головой пусто.
func _update_crouch(delta: float) -> void:
	var want := Input.is_physical_key_pressed(KEY_CTRL) or _crouch_toggled
	if want != crouching:
		if want:
			crouching = true
		elif _can_stand():
			crouching = false
	var h := CROUCH_HEIGHT if crouching else STAND_HEIGHT
	if not is_equal_approx(_capsule.height, h):
		_capsule.height = move_toward(_capsule.height, h, 6.0 * delta)
		_shape.position.y = _capsule.height * 0.5
	var eyes := CROUCH_EYES if crouching else STAND_EYES
	_head.position.y = move_toward(_head.position.y, eyes, 4.0 * delta)


func _can_stand() -> bool:
	if not crouching and is_equal_approx(_capsule.height, STAND_HEIGHT):
		return true
	return not test_move(global_transform, Vector3(0, STAND_HEIGHT - _capsule.height + 0.05, 0))


## Заходим на крыльцо и бордюр без прыжка: если впереди невысокое препятствие,
## а над ним свободно — поднимаемся и опускаемся на него.
func _try_step(delta: float) -> bool:
	var motion := Vector3(velocity.x, 0, velocity.z) * delta
	if motion.length() < 0.001 or not test_move(global_transform, motion):
		return false
	var up := Vector3(0, STEP_HEIGHT, 0)
	if test_move(global_transform, up):
		return false
	# Низ капсулы круглый: чтобы встать на ступеньку, а не зацепиться
	# за её ребро, шагаем сразу на четверть метра
	var ahead := motion.normalized() * maxf(motion.length(), 0.25)
	var raised := global_transform.translated(up)
	if test_move(raised, ahead):
		return false
	var start := global_transform
	global_position += up + ahead
	var col := move_and_collide(-up)
	if col == null or col.get_normal().y < 0.7:
		# Под ногами не ступенька — откатываемся
		global_transform = start
		return false
	velocity.y = 0.0
	return true


## Шаг — каждые ~0.7 м пути по земле; в присяде тише.
func _footsteps(delta: float) -> void:
	var v := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or v < 0.5:
		_stride = 0.0
		return
	_stride += v * delta
	var step_len := 0.9 if v > WALK + 0.5 else 0.7
	if _stride >= step_len:
		_stride = 0.0
		SoundLibrary.play("step", -14.0 if crouching else -8.0, randf_range(0.8, 1.2))


## Покачивание при ходьбе, просадка при приземлении, шире обзор на бегу.
func _update_camera(delta: float, sprinting: bool) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var bob := Vector3.ZERO
	if is_on_floor() and speed > 0.5:
		_bob_time += delta * speed * 1.9
		var amp := 0.035 if speed <= WALK + 0.1 else 0.06
		if crouching:
			amp *= 0.5
		bob = Vector3(cos(_bob_time * 0.5) * amp * 0.6, absf(sin(_bob_time)) * amp, 0)
	else:
		_bob_time = 0.0
	_land_dip = move_toward(_land_dip, 0.0, 0.8 * delta)
	camera.position = camera.position.lerp(bob - Vector3(0, _land_dip, 0), minf(delta * 12.0, 1.0))
	camera.fov = lerpf(camera.fov, RUN_FOV if sprinting else FOV, minf(delta * 6.0, 1.0))


# --- Действия -------------------------------------------------------------

func enter_zone(z: InteractZone) -> void:
	if not _zones.has(z):
		_zones.append(z)


func exit_zone(z: InteractZone) -> void:
	_zones.erase(z)


## Подсказка для HUD: ближайшее действие.
func current_prompt() -> String:
	var z := _nearest_zone()
	return z.text() if z else ""


func _nearest_zone() -> InteractZone:
	var best: InteractZone = null
	var best_d := INF
	for z in _zones:
		# Зоны без подсказки сейчас неактивны (письма уже разнесены и т. п.)
		if not is_instance_valid(z) or z.text() == "":
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
	crouching = false
	_crouch_toggled = false
	_capsule.height = STAND_HEIGHT
	_shape.position.y = STAND_HEIGHT * 0.5
	_head.position.y = STAND_EYES
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
