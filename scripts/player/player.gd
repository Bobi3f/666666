class_name Player
extends CharacterBody3D

const Villagers := preload("res://scripts/world/villagers.gd")
## Персонаж: ходьба с разгоном, бег, прыжок, приседание, подъём на
## ступеньки, действие по E, еда по Q.
##
## Два вида (V или кнопка «Вид»): от третьего лица — камера за спиной на
## «штанге», которая упирается в стены и не пролезает сквозь них; персонаж
## виден целиком, поворачивается туда, куда идёт, шагает ногами и руками.
## От первого лица — камера в голове с покачиванием при ходьбе.

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
## Камера от третьего лица: насколько сзади и чуть над плечом
const TP_DISTANCE := 3.4
const TP_HEIGHT := 0.25

var camera: SmoothCamera
## Точка глаз: к ней плавно тянется камера (см. SmoothCamera).
var _eye: Node3D
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
## Штанга камеры (третье лицо) и тело персонажа, видимое со стороны
var _arm: SpringArm3D
var _arm_tip: Node3D
var _body: Node3D
var _body_mesh: MeshInstance3D
var _walk_phase := 0.0
## Подсветка того, с чем можно сейчас что-то сделать (E): кольцо на земле
## и стрелка над ним.
var _mark: Node3D
var _mark_ring: MeshInstance3D
var _mark_arrow: MeshInstance3D
var _mark_t := 0.0


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
	# Штанга: камера от третьего лица отъезжает назад, пока не упрётся в стену.
	# Глаза — на её конце (от первого лица длина штанги ноль)
	_arm = SpringArm3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.22
	_arm.shape = ball
	_arm.margin = 0.1
	_arm.add_excluded_object(get_rid())
	_head.add_child(_arm)
	_arm_tip = Node3D.new()
	_arm.add_child(_arm_tip)
	_eye = Node3D.new()
	_arm_tip.add_child(_eye)
	# Тело — видно от третьего лица
	_body = Node3D.new()
	_body.top_level = false
	add_child(_body)
	var bb := MeshBuilder.new()
	bb.ground_shade = false
	Villagers.person_model(bb, Color(0.2, 0.33, 0.25), Color(0.25, 0.22, 0.2), false, false)
	_body_mesh = Villagers.walking_mesh(bb)
	_body.add_child(_body_mesh)
	SettingsManager.changed.connect(_apply_view)
	_apply_view()
	# Камера отдельно от тела: положение сглаживается между шагами физики,
	# поворот головы — сразу, без задержки
	camera = SmoothCamera.new()
	camera.target = _eye
	camera.interpolate_rotation = false
	camera.near = 0.05
	camera.far = 700.0
	camera.fov = FOV
	add_child(camera)
	camera.current = true
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)
	if not GameManager.touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_make_mark()


## Янтарное кольцо и стрелка-указатель: светятся сами, видны и ночью.
func _make_mark() -> void:
	_mark = Node3D.new()
	_mark.top_level = true
	_mark.visible = false
	add_child(_mark)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.75, 0.25, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = false
	var torus := TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 4
	torus.material = mat
	_mark_ring = MeshInstance3D.new()
	_mark_ring.mesh = torus
	_mark_ring.scale = Vector3(1, 0.05, 1)
	_mark_ring.position.y = 0.06
	_mark_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark.add_child(_mark_ring)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.18
	cone.bottom_radius = 0.0
	cone.height = 0.35
	cone.radial_segments = 4
	cone.rings = 1
	cone.material = mat
	_mark_arrow = MeshInstance3D.new()
	_mark_arrow.mesh = cone
	_mark_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark.add_child(_mark_arrow)


func _process(delta: float) -> void:
	var z: InteractZone = null if car != null else _nearest_zone()
	_mark.visible = z != null
	if z == null:
		return
	_mark_t += delta
	# Размер кольца — по зоне: у машины шире, у прилавка меньше
	var r := 0.7
	var cs := z.get_child(0) as CollisionShape3D if z.get_child_count() > 0 else null
	if cs and cs.shape is BoxShape3D:
		var sz := (cs.shape as BoxShape3D).size
		r = clampf(minf(sz.x, sz.z) * 0.45, 0.5, 2.2)
	var pulse := 1.0 + sin(_mark_t * 4.0) * 0.06
	_mark.global_position = Vector3(z.global_position.x, z.global_position.y, z.global_position.z)
	_mark_ring.scale = Vector3(r * pulse, 0.05, r * pulse)
	_mark_arrow.position.y = 2.3 + sin(_mark_t * 3.0) * 0.12
	_mark_arrow.rotation.y = _mark_t * 1.5


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
			KEY_V:
				if car == null:
					toggle_view()
	if car != null:
		return
	# На телефоне касания эмулируют мышь — камеру крутит сенсорное управление
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not GameManager.touch_mode:
		var k := MOUSE_SENS * SettingsManager.mouse_sens
		_look(-motion.relative.x * k, -motion.relative.y * k)


func _look(yaw: float, pitch: float) -> void:
	if SettingsManager.invert_y:
		pitch = -pitch
	rotate_y(yaw)
	# Со спины камера не лезет под землю и не смотрит строго вниз
	var lo := -1.1 if SettingsManager.third_person else -1.45
	var hi := 0.9 if SettingsManager.third_person else 1.45
	_head.rotation.x = clampf(_head.rotation.x + pitch, lo, hi)
	# Тело стоит на месте, пока не пошли: при повороте камеры его не крутим
	if SettingsManager.third_person:
		_body.rotate_y(-yaw)


## Вид от первого или третьего лица — из настроек.
func _apply_view() -> void:
	var tp := SettingsManager.third_person
	_arm.spring_length = TP_DISTANCE if tp else 0.0
	_arm.position = Vector3(0, TP_HEIGHT, 0) if tp else Vector3.ZERO
	_body.visible = tp
	_head.rotation.x = clampf(_head.rotation.x, -1.1 if tp else -1.45, 0.9 if tp else 1.45)
	if camera:
		camera.snap()


func toggle_view() -> void:
	SettingsManager.set_third_person(not SettingsManager.third_person)
	GameManager.notify("Вид: %s" % ("от третьего лица" if SettingsManager.third_person else "от первого лица"))


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
	_update_body(delta, flat)
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
	# Персонажа перенесло на ступеньку разом — камера догонит плавно
	camera.kick(global_position - start.origin - motion)
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
		# По асфальту — чётко, по траве — мягко, зимой — снег скрипит
		var snd := "step"
		if WeatherManager.snow > 0.5 and global_position.y < 0.3:
			snd = "step_snow"
		elif not Roads.on_asphalt(global_position.x, global_position.z) and global_position.y < 0.1:
			snd = "step_grass"
		SoundLibrary.play(snd, -14.0 if crouching else -8.0, randf_range(0.8, 1.2))


## Тело от третьего лица: поворачивается туда, куда идём, шагает, приседает.
func _update_body(delta: float, flat: Vector2) -> void:
	if not _body.visible:
		return
	# В тесноте (изба, у стены) камере некуда отъехать — тело прячем,
	# чтобы голова не закрывала обзор: получается вид из глаз
	_body_mesh.visible = _arm.get_hit_length() > 1.1
	var speed := flat.length()
	if speed > 0.3:
		var want := atan2(-flat.x, -flat.y)
		_body.global_rotation.y = lerp_angle(_body.global_rotation.y, want, minf(delta * 12.0, 1.0))
		_walk_phase += speed * delta * 3.3
	var on_floor := is_on_floor()
	var amount := clampf(speed / WALK, 0.0, 1.3) if on_floor else 0.35
	Villagers.set_walk(_body_mesh, _walk_phase, amount)
	# Подпрыгивает на шаге, присев — ниже
	_body_mesh.position.y = absf(sin(_walk_phase)) * 0.04 * minf(amount, 1.0) if on_floor else 0.0
	var sy := 0.68 if crouching else 1.0
	_body.scale = _body.scale.lerp(Vector3(1.0, sy, 1.0), minf(delta * 10.0, 1.0))


## Покачивание при ходьбе, просадка при приземлении, шире обзор на бегу.
func _update_camera(delta: float, sprinting: bool) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var bob := Vector3.ZERO
	if is_on_floor() and speed > 0.5 and not SettingsManager.third_person:
		_bob_time += delta * speed * 1.9
		var amp := 0.035 if speed <= WALK + 0.1 else 0.06
		if crouching:
			amp *= 0.5
		# Мягкая волна вверх-вниз (без «отскока» внизу шага) и лёгкое покачивание вбок
		bob = Vector3(sin(_bob_time * 0.5) * amp * 0.5, (1.0 - cos(_bob_time * 2.0)) * 0.5 * amp, 0)
	else:
		_bob_time = 0.0
	_land_dip = move_toward(_land_dip, 0.0, 0.8 * delta)
	_eye.position = _eye.position.lerp(bob - Vector3(0, _land_dip, 0), minf(delta * 10.0, 1.0))
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
