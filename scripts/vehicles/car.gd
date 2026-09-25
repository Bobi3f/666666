class_name Car
extends CharacterBody3D
## Машина на механике.
##
## Двигатель и колёса связаны через сцепление-трение: пока диски
## проскальзывают, передаётся не больше, чем позволяет прижим; когда обороты
## сравнялись — сцепление «схватилось», и двигатель крутится вместе с колёсами.
## Отсюда всё поведение само собой:
##   * на первой без газа машина трогается и ползёт на холостых (~6 км/ч);
##   * бросить сцепление на второй-третьей с места — заглохнет;
##   * тормоз без сцепления до нуля — заглохнет;
##   * переключение без сцепления — скрежет, передача не включится.
## Педаль сцепления на клавиатуре — кнопка, поэтому в зоне схватывания
## она отпускается медленно сама, как это делает нога.

const RATIOS := {-1: -3.4, 0: 0.0, 1: 3.6, 2: 2.1, 3: 1.4, 4: 1.0, 5: 0.82}
const FINAL := 4.1
const WHEEL_R := 0.29
const MASS := 1050.0
const IDLE := 850.0
const REDLINE := 6200.0
const STALL_RPM := 380.0
const ENGINE_INERTIA := 0.18
const WHEELBASE := 2.4
const GRAVITY := 12.0

var driver: Player
var engine_on := false
var gear := 0
var rpm := 0.0
## Скорость вдоль машины, м/с (вперёд — плюс).
var speed := 0.0
## 1 — педаль отпущена (сцепление включено), 0 — выжата.
var clutch := 1.0
var locked := false

var _steer := 0.0
var _camera: Camera3D
var _zone: InteractZone
var _wheels: Array[Node3D] = []


func _ready() -> void:
	add_to_group("persist")
	GameManager.car = self
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.66, 1.1, 4.15)
	cs.shape = shape
	cs.position.y = 0.72
	add_child(cs)
	_build_mesh()
	_camera = Camera3D.new()
	_camera.position = Vector3(-0.36, 1.22, 0.4)
	_camera.rotation.x = -0.06
	_camera.near = 0.05
	_camera.far = 700.0
	_camera.fov = 78.0
	add_child(_camera)
	# Мягкий свет в салоне: без него при солнце сверху салон в глубокой тени
	var cabin := OmniLight3D.new()
	cabin.position = Vector3(0, 1.25, 0.2)
	cabin.omni_range = 2.2
	cabin.light_energy = 0.9
	cabin.distance_fade_enabled = true
	cabin.distance_fade_begin = 20.0
	cabin.distance_fade_length = 5.0
	add_child(cabin)
	_zone = InteractZone.create("E — сесть за руль", Vector3(4.0, 2.0, 5.5))
	_zone.position.y = -0.2
	_zone.activated.connect(_on_enter)
	add_child(_zone)
	floor_snap_length = 0.4


# --- Посадка ----------------------------------------------------------------

func _on_enter() -> void:
	var p := GameManager.player as Player
	if p == null or driver != null:
		return
	driver = p
	p.sit_in(self)
	_camera.current = true
	GameManager.notify("Shift — сцепление, R — зажигание, ] [ — передачи. F1 — помощь")


func exit_car() -> void:
	if driver == null:
		return
	if absf(speed) > 2.0:
		GameManager.notify("Сначала остановись")
		return
	var p := driver
	driver = null
	var out := global_transform * Vector3(-1.6, 0.2, 0.2)
	p.stand_up(out, rotation.y)


# --- Управление -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if driver == null:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_R:
			_toggle_ignition()
		KEY_BRACKETRIGHT:
			_shift(gear + 1)
		KEY_BRACKETLEFT:
			_shift(gear - 1)


func _toggle_ignition() -> void:
	if engine_on:
		engine_on = false
		GameManager.notify("Двигатель заглушен")
		return
	if gear != 0 and clutch > 0.2:
		GameManager.notify("Выжми сцепление (Shift) или поставь нейтраль")
		return
	engine_on = true
	rpm = IDLE
	GameManager.notify("Двигатель заведён")


func _shift(g: int) -> void:
	g = clampi(g, -1, 5)
	if g == gear:
		return
	if clutch > 0.15:
		GameManager.notify("Скрежет! Выжми сцепление (Shift)")
		return
	if g == -1 and speed > 1.0:
		GameManager.notify("Задняя только с места")
		return
	gear = g
	GameManager.notify(gear_name())


func gear_name() -> String:
	match gear:
		-1:
			return "R"
		0:
			return "N"
	return str(gear)


# --- Физика -----------------------------------------------------------------

func _physics_process(dt: float) -> void:
	var drv := driver != null
	var throttle := 1.0 if drv and Input.is_physical_key_pressed(KEY_W) else 0.0
	var brake := drv and Input.is_physical_key_pressed(KEY_S)
	var handbrake := (not drv) or Input.is_physical_key_pressed(KEY_SPACE)
	var pedal := drv and Input.is_physical_key_pressed(KEY_SHIFT)
	var steer_in := 0.0
	if drv:
		steer_in = float(Input.is_physical_key_pressed(KEY_A)) - float(Input.is_physical_key_pressed(KEY_D))
	_update(dt, throttle, brake, handbrake, pedal, steer_in)


## Один шаг симуляции. Вынесено отдельно, чтобы гонять в тестах без клавиатуры.
func _update(dt: float, throttle: float, brake: bool, handbrake: bool, pedal: bool, steer_in: float) -> void:
	# Педаль: выжимается быстро, в зоне схватывания отпускается медленно
	if pedal:
		clutch = move_toward(clutch, 0.0, dt * 6.0)
	else:
		var rate := 0.45 if clutch > 0.2 and clutch < 0.8 else 3.0
		clutch = move_toward(clutch, 1.0, dt * rate)

	var ratio: float = RATIOS[gear] * FINAL
	var wheel_rpm := speed / WHEEL_R * 60.0 / TAU * ratio
	var eff := smoothstep(0.2, 0.8, clutch) if gear != 0 else 0.0
	var force := 0.0
	locked = false
	if engine_on:
		var t_eng := _engine_torque(rpm, throttle)
		var t_fric := 12.0 + rpm * 0.004
		var cap := eff * eff * 300.0
		var slip := rpm - wheel_rpm
		if eff > 0.0 and absf(slip) < 80.0 and absf(t_eng - t_fric) < cap:
			locked = true
			force = (t_eng - t_fric) * ratio / WHEEL_R
		else:
			var t_c := cap * signf(slip)
			force = t_c * ratio / WHEEL_R
			rpm += (t_eng - t_fric - t_c) / ENGINE_INERTIA * dt * 60.0 / TAU

	var rolling := 0.012 * MASS * 9.8
	var resist := rolling * signf(speed) + 0.42 * speed * absf(speed)
	speed += (force - resist) / MASS * dt
	# Стоим и толкать нечем — не ползём от погрешностей
	if absf(speed) < 0.05 and absf(force) < rolling:
		speed = 0.0
	if brake:
		speed = move_toward(speed, 0.0, 9.0 * dt)
	if handbrake:
		speed = move_toward(speed, 0.0, 6.0 * dt)

	if locked:
		rpm = speed / WHEEL_R * 60.0 / TAU * ratio
	rpm = clampf(rpm, 0.0, REDLINE)
	if engine_on and rpm < STALL_RPM:
		engine_on = false
		rpm = 0.0
		if driver:
			GameManager.notify("Заглох! Выжми сцепление и заведи снова (R)")
	if not engine_on:
		rpm = move_toward(rpm, 0.0, 3000.0 * dt)

	# Руль: на скорости поворачивает меньше
	var max_steer := 0.6 / (1.0 + absf(speed) * 0.08)
	_steer = move_toward(_steer, steer_in * max_steer, dt * 2.5)
	rotate_y(speed * tan(_steer) / WHEELBASE * dt)

	var fwd := -global_transform.basis.z
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * dt
	move_and_slide()
	# Упёрлись в стену — скорость теряется
	speed = fwd.dot(Vector3(velocity.x, 0, velocity.z))
	for w in _wheels:
		w.rotation.x -= speed / WHEEL_R * dt


func _engine_torque(r: float, throttle: float) -> float:
	# Регулятор холостого хода держит ~850 об/мин
	var idle := clampf((IDLE - r) * 0.35, 0.0, 110.0)
	var peak := 175.0 * throttle * clampf(1.2 - absf(r - 3500.0) / 5000.0, 0.4, 1.0)
	if r >= REDLINE:
		peak = 0.0
	return idle + peak


func speed_kmh() -> float:
	return absf(speed) * 3.6


# --- Внешний вид ------------------------------------------------------------

func _build_mesh() -> void:
	var b := MeshBuilder.new()
	b.ground_shade = false
	var paint := Color(0.78, 0.72, 0.52)
	var dark := Color(0.08, 0.08, 0.09)
	var chrome := Color(0.75, 0.75, 0.78)
	var seat := Color(0.3, 0.2, 0.15)
	# Кузов: низ, капот и багажник (вперёд — к -Z)
	b.box(Vector3(-0.82, 0.32, -2.05), Vector3(0.82, 0.9, 2.05), paint)
	# Стойки и крыша салона
	for x in [-0.72, 0.66]:
		b.box(Vector3(x, 0.9, -0.55), Vector3(x + 0.06, 1.42, -0.45), paint)
		b.box(Vector3(x, 0.9, 0.95), Vector3(x + 0.06, 1.42, 1.05), paint)
		b.box(Vector3(x, 0.9, 0.2), Vector3(x + 0.06, 1.42, 0.26), paint)
	b.box(Vector3(-0.74, 1.42, -0.6), Vector3(0.74, 1.47, 1.08), paint)
	# Потолок салона — светлая обивка
	b.box(Vector3(-0.7, 1.4, -0.55), Vector3(0.7, 1.42, 1.03), Color(0.85, 0.82, 0.75))
	# Салон: торпедо, приборы, руль-обод, сиденья
	var panel := Color(0.28, 0.24, 0.2)
	b.box(Vector3(-0.72, 0.9, -0.55), Vector3(0.72, 1.02, -0.32), panel)
	b.box(Vector3(-0.5, 1.0, -0.4), Vector3(-0.22, 1.08, -0.33), Color(0.1, 0.1, 0.1))
	b.box(Vector3(-0.48, 1.01, -0.331), Vector3(-0.24, 1.07, -0.329), Color(0.9, 0.85, 0.6))
	var rim := Color(0.12, 0.12, 0.12)
	b.box(Vector3(-0.52, 0.96, -0.2), Vector3(-0.2, 0.99, -0.18), rim)
	b.box(Vector3(-0.52, 1.17, -0.2), Vector3(-0.2, 1.2, -0.18), rim)
	b.box(Vector3(-0.52, 0.96, -0.2), Vector3(-0.49, 1.2, -0.18), rim)
	b.box(Vector3(-0.23, 0.96, -0.2), Vector3(-0.2, 1.2, -0.18), rim)
	b.box(Vector3(-0.37, 0.96, -0.32), Vector3(-0.35, 1.05, -0.19), rim)
	for x in [-0.36, 0.36]:
		b.box(Vector3(x - 0.25, 0.9, 0.1), Vector3(x + 0.25, 1.0, 0.55), seat)
		b.box(Vector3(x - 0.25, 1.0, 0.5), Vector3(x + 0.25, 1.45, 0.6), seat)
	b.box(Vector3(-0.7, 0.9, 0.7), Vector3(0.7, 1.0, 1.0), seat)
	# Бамперы, фары, фонари, решётка
	b.box(Vector3(-0.85, 0.32, -2.12), Vector3(0.85, 0.45, -2.02), chrome)
	b.box(Vector3(-0.85, 0.32, 2.02), Vector3(0.85, 0.45, 2.12), chrome)
	b.box(Vector3(-0.35, 0.6, -2.07), Vector3(0.35, 0.78, -2.04), dark)
	for x in [-0.62, 0.48]:
		b.box(Vector3(x, 0.6, -2.08), Vector3(x + 0.14, 0.76, -2.04), Color(1.0, 0.97, 0.85))
		b.box(Vector3(x, 0.62, 2.04), Vector3(x + 0.14, 0.74, 2.08), Color(0.8, 0.1, 0.08))
	add_child(b.build_mesh())
	# Колёса — отдельные узлы, чтобы крутились
	for p in [Vector3(-0.78, WHEEL_R, -1.3), Vector3(0.78, WHEEL_R, -1.3), Vector3(-0.78, WHEEL_R, 1.3), Vector3(0.78, WHEEL_R, 1.3)]:
		var wb := MeshBuilder.new()
		wb.ground_shade = false
		wb.box(Vector3(-0.1, -WHEEL_R, -WHEEL_R), Vector3(0.1, WHEEL_R, WHEEL_R), dark)
		wb.box(Vector3(-0.11, -0.12, -0.12), Vector3(0.11, 0.12, 0.12), chrome)
		var w := Node3D.new()
		w.position = p
		w.add_child(wb.build_mesh())
		add_child(w)
		_wheels.append(w)


# --- Сохранение -------------------------------------------------------------

func save_state() -> Dictionary:
	return {
		"pos": SaveManager.vec_to_arr(global_position),
		"yaw": rotation.y,
		"engine": engine_on,
		"gear": gear,
		"driver": driver != null,
	}


func load_state(d: Dictionary) -> void:
	global_position = SaveManager.arr_to_vec(d.get("pos"))
	rotation.y = float(d.get("yaw", 0.0))
	speed = 0.0
	engine_on = bool(d.get("engine", false))
	rpm = IDLE if engine_on else 0.0
	# После загрузки — на нейтрали, иначе машина сразу поедет или заглохнет
	gear = 0
	clutch = 1.0
	# Игрок загружается отдельно — сажаем его после всех загрузок
	if bool(d.get("driver", false)):
		_on_enter.call_deferred()
