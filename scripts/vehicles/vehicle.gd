class_name Vehicle
extends CharacterBody3D
## Транспорт игрока: Жигули и мотоцикл «Ява». Одна механика на всех,
## различия — в SPECS (масса, мотор, передачи, руль, сцепление с дорогой).
##
## Двигатель и колёса связаны через сцепление-трение: пока диски
## проскальзывают, передаётся не больше, чем позволяет прижим; когда обороты
## сравнялись — сцепление «схватилось», и двигатель крутится вместе с колёсами.
##
## Две коробки (T — переключить, по умолчанию автомат):
##   * АВТОМАТ — сцепление не нужно: гидротрансформатор проскальзывает на
##     низких оборотах и схватывает на высоких, передачи переключаются сами,
##     мотор не глохнет. W — газ (заглушенный мотор заведётся сам),
##     S — тормоз, а стоя на месте — задний ход.
##   * МЕХАНИКА — Shift — сцепление, ] [ — передачи, R — зажигание:
##     бросил сцепление — заглох, переключил без сцепления — скрежет.
##
## Машина едет не по рельсам: скорость — вектор, боковое скольжение гасится
## сцеплением шин с дорогой. На асфальте держит, на траве и в грязи — плывёт,
## с ручником (Пробел) на скорости — заносит. На скорости руль ограничен
## сцеплением: слишком резкий поворот — машину сносит наружу.
##
## Бензин тратится по оборотам и газу. Износ — от скрежета, заглохания,
## ударов. Изношенная сама глохнет, разбитая не заводится.

const GRAVITY := 12.0
const STALL_RPM := 380.0
const FUEL_IDLE := 0.004
const FUEL_LOAD := 0.05
## Насколько быстрее шины гасят скольжение вбок, чем в «честной» модели:
## с кнопками руля без этого машину на грунте разворачивает поперёк.
const SIDE_GRIP := 2.2

const SPECS := {
	"car": {
		"title": "Жигули", "ratios": {-1: -3.4, 0: 0.0, 1: 3.6, 2: 2.1, 3: 1.4, 4: 1.0, 5: 0.82},
		"final": 4.1, "wheel_r": 0.29, "mass": 1050.0, "idle": 850.0, "redline": 6200.0,
		"torque": 175.0, "peak_rpm": 3500.0, "inertia": 0.18, "wheelbase": 2.4, "max_steer": 0.6,
		"tank": 40.0, "fuel_k": 1.0, "grip": 9.0, "drag": 0.42, "brake": 9.0,
		"shape": Vector3(1.66, 1.1, 4.15), "shape_y": 0.72,
		"seat": Vector3(-0.36, 1.22, 0.4), "exit": Vector3(-1.6, 0.2, 0.2),
		"chase": Vector3(0, 2.6, 6.5), "roof": true, "two_wheels": false,
	},
	"moto": {
		"title": "Ява", "ratios": {-1: 0.0, 0: 0.0, 1: 2.9, 2: 1.9, 3: 1.4, 4: 1.1},
		"final": 6.0, "wheel_r": 0.31, "mass": 210.0, "idle": 1300.0, "redline": 7800.0,
		"torque": 34.0, "peak_rpm": 5000.0, "inertia": 0.035, "wheelbase": 1.35, "max_steer": 0.55,
		"tank": 14.0, "fuel_k": 0.35, "grip": 11.0, "drag": 0.22, "brake": 8.0,
		"shape": Vector3(0.7, 1.2, 2.0), "shape_y": 0.7,
		"seat": Vector3(0, 1.45, 0.25), "exit": Vector3(-1.0, 0.2, 0.0),
		"chase": Vector3(0, 2.0, 4.2), "roof": false, "two_wheels": true,
	},
	# Машины из автосалона. offroad — насколько лучше держит вне асфальта,
	# mud — во сколько раз легче катится по грунту, траве и грязи.
	"niva": {
		"title": "Нива", "ratios": {-1: -3.5, 0: 0.0, 1: 3.7, 2: 2.2, 3: 1.4, 4: 1.0, 5: 0.82},
		"final": 4.3, "wheel_r": 0.33, "mass": 1150.0, "idle": 850.0, "redline": 5600.0,
		"torque": 215.0, "peak_rpm": 3000.0, "inertia": 0.2, "wheelbase": 2.2, "max_steer": 0.62,
		"tank": 42.0, "fuel_k": 1.2, "grip": 9.5, "drag": 0.45, "brake": 9.0,
		"shape": Vector3(1.72, 1.32, 3.8), "shape_y": 1.02,
		"seat": Vector3(-0.36, 1.32, 0.25), "exit": Vector3(-1.6, 0.2, 0.1),
		"chase": Vector3(0, 2.9, 6.5), "roof": true, "two_wheels": false,
		"offroad": 1.6, "mud": 0.35, "paint": 3,
		"wheels": [Vector3(-0.76, 0.33, -1.1), Vector3(0.76, 0.33, -1.1), Vector3(-0.76, 0.33, 1.1), Vector3(0.76, 0.33, 1.1)],
		"tail": [Vector3(-0.75, 0.87, 1.9), Vector3(0.75, 0.87, 1.9)], "lamps": [Vector3(-0.56, 0.78, -1.92), Vector3(0.56, 0.78, -1.92)],
	},
	"volga": {
		"title": "Волга", "ratios": {-1: -3.5, 0: 0.0, 1: 3.5, 2: 2.26, 3: 1.45, 4: 1.0, 5: 0.8},
		"final": 4.2, "wheel_r": 0.33, "mass": 1400.0, "idle": 800.0, "redline": 5600.0,
		"torque": 295.0, "peak_rpm": 3000.0, "inertia": 0.25, "wheelbase": 2.8, "max_steer": 0.55,
		"tank": 55.0, "fuel_k": 1.4, "grip": 9.8, "drag": 0.36, "brake": 9.5,
		"shape": Vector3(1.84, 1.12, 4.95), "shape_y": 0.9,
		"seat": Vector3(-0.38, 1.16, 0.2), "exit": Vector3(-1.7, 0.2, 0.1),
		"chase": Vector3(0, 2.7, 7.5), "roof": true, "two_wheels": false,
		"offroad": 0.9, "mud": 1.1, "paint": 5,
		"wheels": [Vector3(-0.8, 0.33, -1.42), Vector3(0.8, 0.33, -1.42), Vector3(-0.8, 0.33, 1.42), Vector3(0.8, 0.33, 1.42)],
		"tail": [Vector3(-0.79, 0.68, 2.39), Vector3(0.79, 0.68, 2.39)], "lamps": [Vector3(-0.74, 0.65, -2.4), Vector3(0.74, 0.65, -2.4)],
	},
	"truck": {
		"title": "ГАЗ-53", "ratios": {-1: -6.4, 0: 0.0, 1: 6.5, 2: 3.1, 3: 1.7, 4: 1.0},
		"final": 6.7, "wheel_r": 0.46, "mass": 3200.0, "idle": 700.0, "redline": 3800.0,
		"torque": 430.0, "peak_rpm": 2200.0, "inertia": 0.5, "wheelbase": 3.9, "max_steer": 0.5,
		"tank": 90.0, "fuel_k": 2.2, "grip": 8.5, "drag": 0.8, "brake": 7.0,
		"shape": Vector3(2.3, 2.0, 6.6), "shape_y": 1.3,
		"seat": Vector3(-0.475, 1.84, -1.35), "exit": Vector3(-2.0, 0.2, -1.5),
		"chase": Vector3(0, 4.2, 10.5), "roof": true, "two_wheels": false,
		"offroad": 1.15, "mud": 0.85, "paint": 3,
		"wheels": [Vector3(-0.98, 0.46, -2.45), Vector3(0.98, 0.46, -2.45), Vector3(-0.95, 0.46, 1.55), Vector3(0.95, 0.46, 1.55),
			Vector3(-0.62, 0.46, 1.55), Vector3(0.62, 0.46, 1.55)],
		"tail": [Vector3(-0.97, 0.9, 3.23), Vector3(0.97, 0.9, 3.23)], "lamps": [Vector3(-0.92, 1.22, -3.02), Vector3(0.92, 1.22, -3.02)],
	},
}

## Краски в СТО: первая — заводская.
const PAINTS := [Color(0.78, 0.72, 0.52), Color(0.55, 0.09, 0.09), Color(0.13, 0.3, 0.55),
	Color(0.2, 0.4, 0.22), Color(0.88, 0.88, 0.85), Color(0.11, 0.11, 0.12)]
const PAINT_NAMES := ["бежевый", "вишнёвый", "синий", "зелёный", "белый", "чёрный"]
const MOTO_PAINTS := [Color(0.7, 0.12, 0.1), Color(0.13, 0.3, 0.55), Color(0.1, 0.1, 0.11)]
const MOTO_PAINT_NAMES := ["красный", "синий", "чёрный"]

## Вид сзади (V) — общий для всего транспорта.
static var chase_view := false

@export var kind := "car"

var spec: Dictionary
var driver: Player
var engine_on := false
var gear := 0
var rpm := 0.0
## Скорость вдоль машины, м/с (вперёд — плюс), и поперёк (занос).
var speed := 0.0
var lateral := 0.0
## 1 — педаль отпущена (сцепление включено), 0 — выжата.
var clutch := 1.0
var locked := false
var fuel := 25.0
var condition := 100.0
## Тюнинг в СТО: всесезонная резина (держит на грунте и в грязи),
## форсированный мотор (+20% тяги), цвет кузова.
var tires := false
## Цена в автосалоне и короткое описание; 0 — своя с начала игры.
var price := 0
var blurb := ""
var engine_tuned := false
var paint := 0
var _paint_mesh: MeshInstance3D
var _shake := 0.0
var _shake_k := 0.0
var braking := false

var _steer := 0.0
var _yaw_rate := 0.0
var _lean := 0.0
var _camera: SmoothCamera
## Метки, за которыми плавно тянутся камеры: место водителя и точка сзади.
var _seat_mark: Node3D
var _chase_mark: Node3D
var _chase: SmoothCamera
var _body: Node3D  # всё, что наклоняется (мотоцикл в повороте)
var _rider: Node3D
var _zone: InteractZone
var _wheels: Array[Node3D] = []
var _engine_snd: AudioStreamPlayer3D
var _skid_snd: AudioStreamPlayer3D
var _rain_snd: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _warned_fuel := false
var _headlights: Array[SpotLight3D] = []
var _lights_forced := false
var _brake_mat: StandardMaterial3D
var _shift_timer := 0.0
var _rev_timer := 0.0
var _auto_start_cool := 0.0


func _ready() -> void:
	spec = SPECS[kind]
	if spec.has("paint") and paint == 0:
		paint = int(spec.paint)
	add_to_group("persist")
	add_to_group("vehicles")
	fuel = minf(fuel, spec.tank)
	# Кузов — коробка, но приподнятая: снизу её заменяет закруглённая «лыжа»
	# вдоль машины. Плоское дно цеплялось бы за любой порожек (край асфальта
	# на выезде к трассе — 5 см), а круглое перекатывается, как колесо.
	var size: Vector3 = spec.shape
	var r := 0.3 if not spec.two_wheels else 0.25
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y - r, size.z)
	cs.shape = shape
	cs.position.y = spec.shape_y + r * 0.5
	add_child(cs)
	var skid := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = size.z - 0.1
	skid.shape = cap
	skid.rotation.x = PI / 2.0
	# Низ «лыжи» — на уровне колёс (y = 0), иначе машина проседает в землю
	skid.position.y = r
	add_child(skid)
	_body = Node3D.new()
	add_child(_body)
	if spec.two_wheels:
		_build_moto()
	else:
		_build_car()
	# Камеры отдельно от машины: сглаживаются между шагами физики, иначе
	# на телефоне и в браузере картинка при езде подёргивается
	_seat_mark = Node3D.new()
	_seat_mark.position = spec.seat
	_seat_mark.rotation.x = -0.06
	_body.add_child(_seat_mark)
	_camera = SmoothCamera.new()
	_camera.target = _seat_mark
	_camera.near = 0.05
	_camera.far = 700.0
	_camera.fov = 78.0
	add_child(_camera)
	_chase_mark = Node3D.new()
	_chase_mark.top_level = true
	add_child(_chase_mark)
	_chase = SmoothCamera.new()
	_chase.target = _chase_mark
	_chase.far = 700.0
	_chase.fov = 70.0
	add_child(_chase)
	if spec.roof:
		# Мягкий свет в салоне: без него при солнце сверху салон в глубокой тени
		var cabin := OmniLight3D.new()
		cabin.position = Vector3(0, 1.25, 0.2)
		cabin.omni_range = 2.2
		cabin.light_energy = 0.9
		cabin.distance_fade_enabled = true
		cabin.distance_fade_begin = 20.0
		cabin.distance_fade_length = 5.0
		add_child(cabin)
	var zone_size := Vector3(4.0, 2.0, 5.5) if not spec.two_wheels else Vector3(2.6, 2.0, 3.0)
	_zone = InteractZone.create("E — %s: %s" % ["сесть за руль" if spec.roof else "сесть на мотоцикл", spec.title], zone_size)
	_zone.position.y = -0.2
	# Машина из салона: пока не куплена — подсказка с ценой, E — купить
	_zone.prompt_fn = func() -> String:
		if not owned():
			return "E — купить «%s» за %d грн: %s" % [spec.title, price, blurb]
		return "E — %s: %s" % ["сесть за руль" if spec.roof else "сесть на мотоцикл", spec.title]
	_zone.activated.connect(func() -> void:
		if owned():
			_on_enter()
		elif GameManager.spend(price):
			Progress.buy_car(kind)
			SoundLibrary.play("quest")
			GameManager.notify("«%s» теперь твоя! Садись и езжай" % spec.title))
	add_child(_zone)
	floor_snap_length = 0.4
	_rng.randomize()
	_engine_snd = AudioStreamPlayer3D.new()
	_engine_snd.stream = SoundLibrary.stream("engine")
	_engine_snd.unit_size = 6.0
	_engine_snd.max_distance = 80.0
	_engine_snd.position = Vector3(0, 0.7, -1.5 if spec.roof else 0.0)
	add_child(_engine_snd)
	_skid_snd = AudioStreamPlayer3D.new()
	_skid_snd.stream = SoundLibrary.stream("skid")
	_skid_snd.unit_size = 6.0
	_skid_snd.volume_db = -80.0
	add_child(_skid_snd)
	# Дождь по крыше — только сидя в машине с крышей
	_rain_snd = AudioStreamPlayer.new()
	_rain_snd.stream = SoundLibrary.stream("rain")
	_rain_snd.volume_db = -6.0
	add_child(_rain_snd)
	var lamps: Array = spec.get("lamps", [Vector3(-0.55, 0.68, -2.1), Vector3(0.55, 0.68, -2.1)] if spec.roof else [Vector3(0, 1.0, -0.95)])
	for p in lamps:
		var l := SpotLight3D.new()
		l.position = p
		l.rotation.x = -0.06
		l.spot_range = 40.0
		l.spot_angle = 28.0
		l.light_energy = 3.0 if spec.roof else 2.4
		l.light_color = Color(1.0, 0.95, 0.82)
		l.visible = false
		_body.add_child(l)
		_headlights.append(l)


# --- Посадка ----------------------------------------------------------------

func _on_enter() -> void:
	var p := GameManager.player as Player
	if p == null or driver != null or p.car != null:
		return
	driver = p
	GameManager.vehicle = self
	p.sit_in(self)
	_update_camera(1.0)
	_active_camera().current = true
	if SettingsManager.auto_gearbox:
		GameManager.notify("%s. Автомат: W — газ, S — тормоз и назад. T — механика, V — вид" % spec.title)
	else:
		GameManager.notify("%s. Механика: Shift — сцепление, R — зажигание, ] [ — передачи. T — автомат" % spec.title)


func exit_car() -> void:
	if driver == null:
		return
	if absf(speed) > 2.0:
		GameManager.notify("Сначала остановись")
		return
	_drop_driver()


func _drop_driver() -> void:
	var p := driver
	driver = null
	if GameManager.vehicle == self:
		GameManager.vehicle = null
	if SettingsManager.auto_gearbox:
		gear = 0
	var out := global_transform * (spec.exit as Vector3)
	p.stand_up(out, rotation.y)


func _active_camera() -> Camera3D:
	return _chase if chase_view else _camera


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
			if not SettingsManager.auto_gearbox:
				_shift(gear + 1)
		KEY_BRACKETLEFT:
			if not SettingsManager.auto_gearbox:
				_shift(gear - 1)
		KEY_H:
			SoundLibrary.play_at("horn", global_position, 2.0, 1.0 if spec.roof else 1.35)
		KEY_L:
			_lights_forced = not _lights_forced
			SoundLibrary.play("click", -8.0)
		KEY_T:
			SettingsManager.set_auto_gearbox(not SettingsManager.auto_gearbox)
			if SettingsManager.auto_gearbox:
				clutch = 1.0
				if gear == 0 and engine_on:
					gear = 1
			GameManager.notify("Коробка: %s" % ("АВТОМАТ — W газ, S тормоз и назад" if SettingsManager.auto_gearbox else "МЕХАНИКА — Shift сцепление, ] [ передачи"))
		KEY_V:
			chase_view = not chase_view
			_update_camera(1.0)
			_active_camera().current = true


func _toggle_ignition() -> void:
	if engine_on:
		engine_on = false
		GameManager.notify("Двигатель заглушен")
		return
	if not SettingsManager.auto_gearbox and gear != 0 and clutch > 0.2:
		GameManager.notify("Выжми сцепление (Shift) или поставь нейтраль")
		return
	_try_start()


func _try_start() -> bool:
	SoundLibrary.play_at("starter", global_position, 0.0, 1.0 if spec.roof else 1.5)
	if fuel <= 0.0:
		GameManager.notify("Стартер крутит, а мотор не схватывает — бак пустой. Заправка у трассы")
		return false
	if condition < 10.0:
		GameManager.notify("Мотор не заводится — техника разбита. Нужна СТО у трассы")
		return false
	engine_on = true
	rpm = spec.idle
	GameManager.notify("Двигатель заведён")
	return true


func _shift(g: int) -> void:
	var top: int = _top_gear()
	var low := -1 if (spec.ratios[-1] as float) != 0.0 else 0
	g = clampi(g, low, top)
	if g == gear:
		return
	if clutch > 0.15:
		GameManager.notify("Скрежет! Выжми сцепление (Shift)")
		SoundLibrary.play_at("grind", global_position)
		_wear(1.5)
		return
	if g == -1 and speed > 1.0:
		GameManager.notify("Задняя только с места")
		return
	gear = g
	GameManager.notify(gear_name())


func _top_gear() -> int:
	var top := 0
	for k in spec.ratios:
		top = maxi(top, k)
	return top


func gear_name() -> String:
	if SettingsManager.auto_gearbox:
		match gear:
			-1:
				return "R"
			0:
				return "N"
		return "D%d" % gear
	match gear:
		-1:
			return "R"
		0:
			return "N"
	return str(gear)


# --- Физика -----------------------------------------------------------------

func _physics_process(dt: float) -> void:
	var drv := driver != null
	var w := drv and Input.is_physical_key_pressed(KEY_W)
	var s := drv and Input.is_physical_key_pressed(KEY_S)
	var handbrake := (not drv) or Input.is_physical_key_pressed(KEY_SPACE)
	var steer_in := 0.0
	if drv:
		steer_in = float(Input.is_physical_key_pressed(KEY_A)) - float(Input.is_physical_key_pressed(KEY_D))
	if SettingsManager.auto_gearbox:
		var io := _auto_inputs(dt, w, s)
		_update(dt, io.x, io.y > 0.5, handbrake, false, steer_in)
	else:
		var pedal := drv and Input.is_physical_key_pressed(KEY_SHIFT)
		_update(dt, 1.0 if w else 0.0, s, handbrake, pedal, steer_in)
	if drv:
		_update_camera(dt)


## Автомат: педали → газ и тормоз, задний ход и запуск мотора сами.
## Возвращает (газ, тормоз).
func _auto_inputs(dt: float, w: bool, s: bool) -> Vector2:
	_auto_start_cool = maxf(_auto_start_cool - dt, 0.0)
	if not engine_on:
		if (w or s) and _auto_start_cool <= 0.0:
			_auto_start_cool = 2.0
			if _try_start() and gear == 0:
				gear = 1
		return Vector2(0.0, 1.0 if s else 0.0)
	var has_reverse := (spec.ratios[-1] as float) != 0.0
	if gear == 0 and (w or s):
		gear = 1
	if gear == -1:
		# Задний ход: S — газ назад, W — тормоз, а стоя — снова вперёд
		if w and absf(speed) < 0.3:
			gear = 1
			return Vector2(1.0, 0.0)
		# Назад больше ~20 км/ч автомат не разгоняет
		var gas := 1.0 if s and speed > -5.5 else 0.0
		return Vector2(gas, 1.0 if w else 0.0)
	# Стоим и держим тормоз — через полсекунды включится задний
	if s and speed < 0.3 and has_reverse:
		_rev_timer += dt
		if _rev_timer > 0.5:
			gear = -1
			_rev_timer = 0.0
	else:
		_rev_timer = 0.0
	return Vector2(1.0 if w else 0.0, 1.0 if s else 0.0)


## Один шаг симуляции. Вынесено отдельно, чтобы гонять в тестах без клавиатуры.
func _update(dt: float, throttle: float, brake: bool, handbrake: bool, pedal: bool, steer_in: float) -> void:
	var auto: bool = SettingsManager.auto_gearbox
	var idle: float = spec.idle
	var redline: float = spec.redline
	var mass: float = spec.mass
	var wheel_r: float = spec.wheel_r
	braking = brake
	_shift_timer = maxf(_shift_timer - dt, 0.0)

	if auto:
		_auto_shift(throttle)
		clutch = 0.0 if _shift_timer > 0.0 else 1.0
	elif pedal:
		clutch = move_toward(clutch, 0.0, dt * 6.0)
	else:
		# Педаль в зоне схватывания отпускается медленно, как ногой
		var rate := 0.45 if clutch > 0.2 and clutch < 0.8 else 3.0
		clutch = move_toward(clutch, 1.0, dt * rate)

	var ratio: float = (spec.ratios[gear] as float) * (spec.final as float)
	var wheel_rpm := speed / wheel_r * 60.0 / TAU * ratio
	var cap := 0.0
	if gear != 0 and ratio != 0.0:
		if auto:
			# Гидротрансформатор: на холостых почти не держит, на оборотах — как сцепление
			var k := clampf((rpm - idle) / 1600.0, 0.0, 1.0)
			cap = 0.0 if _shift_timer > 0.0 else (0.09 + 1.7 * k * k) * _torque()
		else:
			var eff := smoothstep(0.2, 0.8, clutch)
			cap = eff * eff * _torque() * 1.7
	var force := 0.0
	locked = false
	if engine_on:
		var t_eng := _engine_torque(rpm, throttle)
		var t_fric := _torque() * (0.07 + rpm * 0.000023)
		var slip := rpm - wheel_rpm
		if cap > 0.0 and absf(slip) < 80.0 and absf(t_eng - t_fric) < cap:
			locked = true
			force = (t_eng - t_fric) * ratio / wheel_r
		else:
			var t_c := cap * signf(slip)
			force = t_c * ratio / wheel_r
			rpm += (t_eng - t_fric - t_c) / (spec.inertia as float) * dt * 60.0 / TAU

	# Покрытие: асфальт, грунт, трава; в дождь грунт раскисает
	var surf := surface()
	var roll: float = surf.roll
	if roll > 1.01:
		roll = 1.0 + (roll - 1.0) * float(spec.get("mud", 1.0))
	var rolling: float = 0.012 * mass * 9.8 * roll
	var resist: float = rolling * signf(speed) + (spec.drag as float) * speed * absf(speed)
	speed += (force - resist) / mass * dt
	if absf(speed) < 0.05 and absf(force) < rolling:
		speed = 0.0
	if brake:
		speed = move_toward(speed, 0.0, (spec.brake as float) * surf.grip * dt)
	if handbrake:
		speed = move_toward(speed, 0.0, 6.0 * dt)

	if locked:
		rpm = speed / wheel_r * 60.0 / TAU * ratio
	rpm = clampf(rpm, 0.0, redline)
	if engine_on and auto and rpm < idle * 0.8:
		# Автомат не глохнет: трансформатор отпускает, регулятор держит холостые
		rpm = idle * 0.8
	if engine_on and not auto and rpm < STALL_RPM:
		_stall("Заглох! Выжми сцепление и заведи снова (R)")
	if engine_on:
		fuel = maxf(fuel - (FUEL_IDLE + FUEL_LOAD * throttle * rpm / redline) * (spec.fuel_k as float) * dt, 0.0)
		if fuel <= 0.0:
			_stall("Мотор чихнул и заглох — кончился бензин. Заправка у трассы")
		elif fuel < (spec.tank as float) * 0.12 and not _warned_fuel and driver:
			_warned_fuel = true
			GameManager.notify("Бензин на исходе — %d л" % int(ceilf(fuel)))
		elif condition < 30.0 and _rng.randf() < dt * (30.0 - condition) * 0.004:
			_stall("Мотор заглох сам — техника изношена. Почини на СТО")
	if not engine_on:
		rpm = move_toward(rpm, 0.0, 3000.0 * dt)

	_steering(dt, steer_in, handbrake, surf.grip)
	_move(dt, handbrake)
	# Пройденный путь — для заданий и статистики
	if driver:
		var d := absf(speed) * dt
		if d > 0.0:
			QuestManager.event("drive_m", d)
			if not auto:
				QuestManager.event("manual_m", d)
	for wn in _wheels:
		wn.rotation.x -= speed / wheel_r * dt
	_update_sound()
	_update_lights()


## Автомат переключает передачи сам: вверх — тем позже, чем сильнее газ,
## вниз — когда обороты провалились или вдавили газ в пол (кикдаун).
func _auto_shift(throttle: float) -> void:
	if not engine_on or gear < 1 or _shift_timer > 0.0:
		return
	var top := _top_gear()
	var redline: float = spec.redline
	var idle: float = spec.idle
	var up := lerpf(idle + (redline - idle) * 0.3, redline * 0.88, throttle)
	var down := idle + (redline - idle) * 0.12
	if rpm > up and gear < top and locked:
		gear += 1
		_shift_timer = 0.35
	elif gear > 1 and (rpm < down or (throttle > 0.9 and rpm < redline * 0.4 and absf(speed) > 3.0)):
		# Вниз — только если на меньшей передаче не будет перекрута
		var lower: float = (spec.ratios[gear - 1] as float) * (spec.final as float)
		if speed / (spec.wheel_r as float) * 60.0 / TAU * lower < redline * 0.85:
			gear -= 1
			_shift_timer = 0.3


## Руль и занос. Поворот ограничен сцеплением шин: max боковое ускорение
## ≈ grip · g. Ручник отпускает зад — машину разворачивает сильнее и заносит.
func _steering(dt: float, steer_in: float, handbrake: bool, grip: float) -> void:
	var v := absf(speed)
	var max_steer: float = (spec.max_steer as float) / (1.0 + v * 0.05)
	_steer = move_toward(_steer, steer_in * max_steer, dt * 2.5)
	var target := speed * tan(_steer) / (spec.wheelbase as float)
	var mu := 1.15 * grip
	if v > 1.0:
		var limit := mu * 9.8 / v
		if handbrake and v > 5.0 and not spec.two_wheels:
			limit *= 1.8
			target *= 1.5
		target = clampf(target, -limit, limit)
	_yaw_rate = target
	rotate_y(_yaw_rate * dt)
	# Мотоцикл в повороте ложится: tan(крен) = v · ω / g
	if spec.two_wheels:
		var want := clampf(atan(speed * _yaw_rate / 9.8), -0.75, 0.75)
		_lean = lerpf(_lean, want, minf(dt * 6.0, 1.0))
		_body.rotation.z = _lean


## Движение вектором: часть скорости по курсу, часть — вбок (занос).
## Боковую гасит сцепление шин; поворот курса сам рождает занос, если шины
## не успевают.
func _move(dt: float, handbrake: bool) -> void:
	var fwd := -global_transform.basis.z
	var right := global_transform.basis.x
	var grip: float = (spec.grip as float) * surface().grip
	# Всесезонка: на грунте, траве и в грязи держит заметно лучше
	if tires:
		grip *= 1.08 if on_asphalt() else 1.35
	# Вездеход держит вне асфальта лучше, «Волга» — хуже
	if not on_asphalt():
		grip *= float(spec.get("offroad", 1.0))
	if handbrake and driver and absf(speed) > 3.0 and not spec.two_wheels:
		grip *= 0.18
	# Прошлая скорость в мире, разложенная по новому курсу: если машина
	# повернулась быстрее, чем её несёт, появляется скорость вбок — занос.
	# Продольную задаёт трансмиссия, боковую гасят шины.
	lateral = Vector3(velocity.x, 0, velocity.z).dot(right)
	# Шины гасят боковое скольжение: машина едет туда, куда смотрит.
	# С ручником — сцепление уже ослаблено выше, машина уходит в занос.
	lateral *= exp(-grip * SIDE_GRIP * dt)
	# Юз тормозит машину
	speed = move_toward(speed, 0.0, absf(lateral) * 0.6 * dt)
	var v := fwd * speed + right * lateral
	velocity.x = v.x
	velocity.z = v.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * dt
	var before := speed
	move_and_slide()
	# Упёрлись — скорость теряется, сильный удар бьёт технику
	var after_v := Vector3(velocity.x, 0, velocity.z)
	speed = fwd.dot(after_v)
	lateral = right.dot(after_v)
	var hit := absf(before) - absf(speed)
	if hit > 3.0 and get_slide_collision_count() > 0:
		SoundLibrary.play_at("crash", global_position, minf(hit, 8.0) - 4.0)
		if self == GameManager.delivery_vehicle:
			Progress.damage_bread(hit * 2.5)
		_wear(hit * (2.0 if spec.roof else 3.0))
		if driver:
			if spec.two_wheels and hit > 6.0:
				# С мотоцикла на такой скорости вылетаешь
				speed = 0.0
				lateral = 0.0
				velocity = Vector3.ZERO
				engine_on = false
				var p := driver
				_drop_driver()
				p.velocity = Vector3.ZERO
				NeedsManager.rest(-10.0)
				GameManager.notify("Упал с мотоцикла! Ява: %d%%" % int(condition))
			else:
				GameManager.notify("Бах! %s: %d%%" % [spec.title, int(condition)])


## Покрытие под колёсами: сопротивление качению и сцепление шин.
func surface() -> Dictionary:
	if on_asphalt():
		return {"roll": 1.0, "grip": 1.0 - WeatherManager.rain * 0.15}
	var mud := WeatherManager.mud_factor()
	var p := global_position
	# Деревенская улица, съезд и тропинки — грунт; остальное — трава
	var dirt := (p.x > -166.0 and p.x < -56.0 and p.z > -43.0 and p.z < -37.0) or (p.x > -63.0 and p.x < -56.0 and p.z > -43.0 and p.z < -4.0)
	# Качение по грунту — вдвое тяжелее асфальта, по траве — в пять раз
	# Гравийка полевого кольца — плотнее грунта, но не асфальт
	if Roads.on_gravel(p.x, p.z):
		return {"roll": 1.4 * sqrt(mud), "grip": 0.88 / sqrt(sqrt(mud))}
	if dirt or Roads.on_forest_road(p.x, p.z):
		return {"roll": 2.0 * mud, "grip": 0.8 / sqrt(mud)}
	return {"roll": 5.0 * mud, "grip": 0.6 / sqrt(mud)}


func _stall(text: String) -> void:
	engine_on = false
	rpm = 0.0
	SoundLibrary.play_at("stall", global_position)
	_wear(0.5)
	if driver:
		GameManager.notify(text)


func _wear(amount: float) -> void:
	condition = maxf(condition - amount, 0.0)


func _update_sound() -> void:
	if engine_on or rpm > 50.0:
		if not _engine_snd.playing:
			_engine_snd.play()
		# 4 цилиндра — 2 вспышки на оборот, одноцилиндровая Ява — одна, но звонче;
		# звук записан на 55 вспышек в секунду
		var per_rev := 2.0 if spec.roof else 1.2
		_engine_snd.pitch_scale = clampf(rpm / 60.0 * per_rev / 55.0, 0.3, 4.0)
		var gas := 1.0 if driver and Input.is_physical_key_pressed(KEY_W) else 0.0
		_engine_snd.volume_db = lerpf(-8.0, 0.0, gas) + (0.0 if engine_on else -10.0)
	elif _engine_snd.playing:
		_engine_snd.stop()
	# Визг шин в заносе
	var skid := absf(lateral)
	if skid > 2.5 and on_asphalt():
		if not _skid_snd.playing:
			_skid_snd.play()
		_skid_snd.volume_db = linear_to_db(clampf((skid - 2.5) / 5.0, 0.05, 1.0)) - 2.0
	elif _skid_snd.playing:
		_skid_snd.stop()
	var want_rain: bool = driver != null and spec.roof and WeatherManager.rain > 0.3
	if want_rain != _rain_snd.playing:
		if want_rain:
			_rain_snd.play()
		else:
			_rain_snd.stop()


## Фары: сами — в темноте, тумане и дождь; L — в любое время.
## Стоп-сигналы горят, пока жмут тормоз.
func _update_lights() -> void:
	var h := TimeManager.hour()
	var dark := h < 6.3 or h > 19.7 or WeatherManager.fog > 0.5 or WeatherManager.rain > 0.5
	var lit := engine_on and (dark or _lights_forced)
	for l in _headlights:
		l.visible = lit
	if _brake_mat:
		var on := braking and driver != null
		_brake_mat.albedo_color = Color(1.0, 0.1, 0.05) if on else (Color(0.55, 0.05, 0.03) if lit else Color(0.3, 0.04, 0.03))


func _update_camera(dt: float) -> void:
	# Тряска на яме — камера подпрыгивает и быстро успокаивается
	if _shake > 0.0:
		_shake = maxf(_shake - dt, 0.0)
		var off := sin(_shake * 70.0) * 0.06 * _shake_k * (_shake / 0.4)
		_camera.v_offset = off
		if _chase:
			_chase.v_offset = off
	if not chase_view or _chase == null:
		return
	var back: Vector3 = spec.chase
	var target := global_transform.origin + global_transform.basis * back
	var look := global_transform.origin + Vector3(0, 1.0, 0)
	var k := minf(dt * 5.0, 1.0)
	_chase_mark.global_position = _chase_mark.global_position.lerp(target, k) if dt < 0.5 else target
	_chase_mark.look_at(look)
	if dt >= 0.5:
		_chase.snap()


## Асфальт — трасса, город, площадки АЗС и СТО.
func on_asphalt() -> bool:
	var p := global_position
	if absf(p.z) < 4.2:
		return true
	if p.x > -120.0 and p.x < -78.0 and p.z > 0.0 and p.z < 21.0:
		return true
	# Автодром и въезд к нему
	if p.x > -2.0 and p.x < 20.0 and p.z > -75.0 and p.z < -18.0:
		return true
	if p.x > 6.0 and p.x < 12.0 and p.z > -18.0 and p.z < 0.0:
		return true
	return p.x > 38.0 and p.z > 0.0


func headlights_on() -> bool:
	return _headlights[0].visible


func tank() -> float:
	return spec.tank


func refuel(liters: float) -> void:
	fuel = minf(fuel + liters, spec.tank)
	_warned_fuel = false


func repair() -> void:
	condition = 100.0


func _engine_torque(r: float, throttle: float) -> float:
	var idle: float = spec.idle
	var torque: float = _torque()
	# Регулятор холостого хода держит обороты
	var idle_t := clampf((idle - r) * torque * 0.002, 0.0, torque * 0.63)
	var peak := torque * throttle * clampf(1.2 - absf(r - (spec.peak_rpm as float)) / (spec.redline as float * 0.8), 0.4, 1.0)
	if r >= (spec.redline as float):
		peak = 0.0
	return idle_t + peak


func speed_kmh() -> float:
	return absf(speed) * 3.6


# --- Внешний вид ------------------------------------------------------------

func owned() -> bool:
	return price == 0 or Progress.owns(kind)


func paints() -> Array:
	return MOTO_PAINTS if spec.two_wheels else PAINTS


func paint_name() -> String:
	return (MOTO_PAINT_NAMES if spec.two_wheels else PAINT_NAMES)[paint]


## Кузов строится заново в нужном цвете — при покраске и после загрузки.
func _paint_body() -> void:
	if _paint_mesh:
		_paint_mesh.queue_free()
	var b := MeshBuilder.new()
	b.ground_shade = false
	var col: Color = paints()[paint % paints().size()]
	var glass := MeshBuilder.new()
	glass.ground_shade = false
	match kind:
		"moto":
			VehicleModels.java(b, col)
		"niva":
			VehicleModels.niva(b, col, glass)
		"volga":
			VehicleModels.volga(b, col, glass)
		"truck":
			VehicleModels.gaz53(b, col, glass)
		_:
			VehicleModels.zhiguli(b, col, true, glass)
	_paint_mesh = b.build_mesh()
	_body.add_child(_paint_mesh)
	# Стёкла — прозрачные, чтобы из салона было видно дорогу
	if not spec.two_wheels:
		var gm := glass.build_mesh()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.6, 0.72, 0.78, 0.22)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 0.1
		mat.metallic = 0.4
		gm.material_override = mat
		gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_paint_mesh.add_child(gm)


## Яма на дороге: машину подбрасывает, скорость теряется, подвеска
## изнашивается, в развозе бьётся хлеб.
func bump(strength: float) -> void:
	speed *= 1.0 - 0.05 * strength
	_wear(strength * 0.6)
	_shake = 0.25 + strength * 0.15
	_shake_k = strength
	SoundLibrary.play_at("land", global_position, -4.0 + strength * 3.0, 0.8)
	if self == GameManager.delivery_vehicle:
		Progress.damage_bread(strength * 2.5)


func repaint() -> void:
	paint = (paint + 1) % paints().size()
	_paint_body()


## Тяга мотора с учётом форсировки.
func _torque() -> float:
	return (spec.torque as float) * (1.2 if engine_tuned else 1.0)


func _build_car() -> void:
	_paint_body()
	_brake_lights(spec.get("tail", [Vector3(-0.62, 0.62, 2.06), Vector3(0.48, 0.62, 2.06)]), Vector3(0.16, 0.12, 0.03))
	for p in spec.get("wheels", [Vector3(-0.78, 0.29, -1.3), Vector3(0.78, 0.29, -1.3), Vector3(-0.78, 0.29, 1.3), Vector3(0.78, 0.29, 1.3)]):
		_wheel(p, false)


func _build_moto() -> void:
	_paint_body()
	_brake_lights([Vector3(0, 0.66, 0.965)], Vector3(0.12, 0.07, 0.03))
	for p in [Vector3(0, 0.31, -0.8), Vector3(0, 0.31, 0.62)]:
		_wheel(p, true)
	# Мотоциклист — виден с вида сзади, пока кто-то едет
	_rider = Node3D.new()
	var r := MeshBuilder.new()
	r.ground_shade = false
	var jacket := Color(0.2, 0.25, 0.35)
	r.box(Vector3(-0.2, 0.9, -0.05), Vector3(0.2, 1.45, 0.3), jacket)
	r.box(Vector3(-0.25, 0.55, -0.35), Vector3(-0.12, 0.95, 0.2), Color(0.2, 0.2, 0.24))
	r.box(Vector3(0.12, 0.55, -0.35), Vector3(0.25, 0.95, 0.2), Color(0.2, 0.2, 0.24))
	r.box(Vector3(-0.32, 1.1, -0.75), Vector3(-0.2, 1.35, 0.1), jacket)
	r.box(Vector3(0.2, 1.1, -0.75), Vector3(0.32, 1.35, 0.1), jacket)
	r.box(Vector3(-0.14, 1.45, -0.05), Vector3(0.14, 1.75, 0.22), Color(0.9, 0.9, 0.2))
	_rider.add_child(r.build_mesh())
	_rider.visible = false
	_body.add_child(_rider)


func _wheel(p: Vector3, moto: bool) -> void:
	var wb := MeshBuilder.new()
	wb.ground_shade = false
	if moto:
		VehicleModels.moto_wheel(wb, spec.wheel_r)
	else:
		VehicleModels.car_wheel(wb, spec.wheel_r, 0.2)
	var n := Node3D.new()
	n.position = p
	n.add_child(wb.build_mesh())
	_body.add_child(n)
	_wheels.append(n)


## Стоп-сигналы — отдельный меш со своим материалом: его яркость меняется.
func _brake_lights(points: Array, size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	_brake_mat = StandardMaterial3D.new()
	_brake_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_brake_mat.albedo_color = Color(0.3, 0.04, 0.03)
	for p in points:
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = _brake_mat
		mi.position = p
		_body.add_child(mi)


func _process(_delta: float) -> void:
	# От первого лица мотоциклиста не рисуем — камера у него в голове
	if _rider:
		_rider.visible = driver != null and chase_view


# --- Сохранение -------------------------------------------------------------

func save_state() -> Dictionary:
	return {
		"pos": SaveManager.vec_to_arr(global_position),
		"yaw": rotation.y,
		"engine": engine_on,
		"gear": gear,
		"driver": driver != null,
		"fuel": fuel,
		"condition": condition,
		"tires": tires,
		"engine_tuned": engine_tuned,
		"paint": paint,
	}


func load_state(d: Dictionary) -> void:
	global_position = SaveManager.arr_to_vec(d.get("pos"))
	rotation.y = float(d.get("yaw", 0.0))
	speed = 0.0
	lateral = 0.0
	velocity = Vector3.ZERO
	fuel = float(d.get("fuel", 25.0))
	condition = float(d.get("condition", 100.0))
	tires = bool(d.get("tires", false))
	engine_tuned = bool(d.get("engine_tuned", false))
	var p := int(d.get("paint", 0)) % paints().size()
	if p != paint:
		paint = p
		_paint_body()
	engine_on = bool(d.get("engine", false))
	rpm = spec.idle if engine_on else 0.0
	# После загрузки — на нейтрали, иначе техника сразу поедет или заглохнет
	gear = 0
	clutch = 1.0
	if driver:
		_drop_driver()
	# Игрок загружается отдельно — сажаем его после всех загрузок
	if bool(d.get("driver", false)):
		_on_enter.call_deferred()
