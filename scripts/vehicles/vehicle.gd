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
## С какого удара (м/с потерянной скорости, ~16 км/ч) машина получает
## повреждения; слабее — только звук.
const DAMAGE_HIT := 4.5

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
		"title": "Ява", "ratios": {-1: -2.9, 0: 0.0, 1: 2.9, 2: 1.9, 3: 1.4, 4: 1.1},
		"final": 6.0, "wheel_r": 0.31, "mass": 210.0, "idle": 1300.0, "redline": 7800.0,
		"torque": 34.0, "peak_rpm": 5000.0, "inertia": 0.035, "wheelbase": 1.35, "max_steer": 0.55,
		"tank": 14.0, "fuel_k": 0.35, "grip": 11.0, "drag": 0.22, "brake": 8.0,
		"shape": Vector3(0.7, 1.2, 2.0), "shape_y": 0.7,
		"seat": Vector3(0, 1.45, 0.25), "exit": Vector3(-1.0, 0.2, 0.0),
		"chase": Vector3(0, 2.0, 4.2), "roof": false, "two_wheels": true,
	},
	# «ИЖ Юпитер-5» из автосалона: двухцилиндровый, тяжелее и мощнее «Явы»,
	# бак больше, разгоняется до 130.
	"izh": {
		"title": "ИЖ Юпитер-5", "ratios": {-1: -2.8, 0: 0.0, 1: 2.8, 2: 1.85, 3: 1.35, 4: 1.05},
		"final": 5.6, "wheel_r": 0.32, "mass": 235.0, "idle": 1200.0, "redline": 7000.0,
		"torque": 42.0, "peak_rpm": 5200.0, "inertia": 0.04, "wheelbase": 1.4, "max_steer": 0.52,
		"tank": 18.0, "fuel_k": 0.42, "grip": 11.0, "drag": 0.23, "brake": 8.0,
		"shape": Vector3(0.75, 1.25, 2.1), "shape_y": 0.72,
		"seat": Vector3(0, 1.52, 0.3), "exit": Vector3(-1.0, 0.2, 0.0),
		"chase": Vector3(0, 2.1, 4.4), "roof": false, "two_wheels": true,
		"wheels": [Vector3(0, 0.32, -0.76), Vector3(0, 0.32, 0.64)], "tail": [Vector3(0, 0.86, 0.985)],
	},
	# Мопед «Карпаты» — первый транспорт: прав не нужно, медленный (до 50),
	# бака на 6 литров хватает надолго, зато в горку тянет еле-еле.
	"moped": {
		"title": "Карпаты", "ratios": {-1: -3.0, 0: 0.0, 1: 3.0, 2: 1.8, 3: 1.25},
		"final": 11.0, "wheel_r": 0.28, "mass": 95.0, "idle": 1400.0, "redline": 6500.0,
		"torque": 6.0, "peak_rpm": 4500.0, "inertia": 0.02, "wheelbase": 1.2, "max_steer": 0.6,
		"tank": 6.0, "fuel_k": 0.12, "grip": 10.0, "drag": 0.3, "brake": 6.0,
		"shape": Vector3(0.6, 1.1, 1.75), "shape_y": 0.6,
		"seat": Vector3(0, 1.3, 0.2), "exit": Vector3(-0.9, 0.2, 0.0),
		"chase": Vector3(0, 1.8, 3.8), "roof": false, "two_wheels": true,
		"wheels": [Vector3(0, 0.28, -0.62), Vector3(0, 0.28, 0.55)], "tail": [Vector3(0, 0.62, 0.81)],
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
	# Учебный ПАЗ автошколы: длинный и тяжёлый, поворачивает широко.
	"bus": {
		"title": "ПАЗ-672", "ratios": {-1: -6.2, 0: 0.0, 1: 6.4, 2: 3.4, 3: 1.8, 4: 1.0},
		"final": 6.8, "wheel_r": 0.5, "mass": 5200.0, "idle": 650.0, "redline": 3600.0,
		"torque": 520.0, "peak_rpm": 2200.0, "inertia": 0.55, "wheelbase": 5.3, "max_steer": 0.52,
		"tank": 110.0, "fuel_k": 2.6, "grip": 8.0, "drag": 1.0, "brake": 6.5,
		"shape": Vector3(2.5, 2.8, 9.0), "shape_y": 1.75,
		"seat": Vector3(-0.75, 2.0, -3.7), "exit": Vector3(-2.2, 0.2, -3.6),
		"chase": Vector3(0, 5.0, 13.0), "roof": true, "two_wheels": false,
		"offroad": 1.0, "mud": 1.0, "paint": 3,
		"wheels": [Vector3(-1.12, 0.5, -2.8), Vector3(1.12, 0.5, -2.8), Vector3(-1.12, 0.5, 2.5), Vector3(1.12, 0.5, 2.5)],
		"tail": [Vector3(-1.0, 0.8, 4.55), Vector3(1.0, 0.8, 4.55)], "lamps": [Vector3(-0.95, 0.8, -4.55), Vector3(0.85, 0.8, -4.55)],
	},
	# Колхозный трактор: медленный, тянет по пашне как по асфальту.
	# Колёса — [где, радиус, ширина]: задние огромные, передние маленькие.
	"tractor": {
		"title": "МТЗ-80", "ratios": {-1: -9.0, 0: 0.0, 1: 9.0, 2: 5.5, 3: 3.4, 4: 2.2},
		"final": 8.0, "wheel_r": 0.72, "mass": 3400.0, "idle": 700.0, "redline": 2300.0,
		"torque": 560.0, "peak_rpm": 1500.0, "inertia": 0.6, "wheelbase": 2.4, "max_steer": 0.62,
		"tank": 130.0, "fuel_k": 1.8, "grip": 10.0, "drag": 1.2, "brake": 6.0,
		"shape": Vector3(1.9, 2.4, 4.4), "shape_y": 1.35,
		"seat": Vector3(0, 2.3, 0.62), "exit": Vector3(-1.9, 0.2, 0.6),
		"chase": Vector3(0, 4.6, 8.5), "roof": true, "two_wheels": false,
		"offroad": 1.6, "mud": 0.25, "paint": 2,
		"wheels": [[Vector3(-0.92, 0.72, 0.9), 0.72, 0.42], [Vector3(0.92, 0.72, 0.9), 0.72, 0.42],
			[Vector3(-0.78, 0.42, -1.4), 0.42, 0.22], [Vector3(0.78, 0.42, -1.4), 0.42, 0.22]],
		"tail": [Vector3(-0.7, 1.4, 1.67), Vector3(0.7, 1.4, 1.67)], "lamps": [Vector3(-0.29, 1.31, -2.13), Vector3(0.29, 1.31, -2.13)],
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
## Категория, на которую сейчас идёт экзамен в автошколе: на своей «Яве»
## без категории A сесть можно только на экзамене.
static var exam_category := ""
var _sale: Label3D

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
## Учебная машина автошколы: сесть можно, только пока allowed() — на экзамене.
var school := false
var allowed: Callable
var blurb := ""
var engine_tuned := false
var paint := 0
var _paint_mesh: MeshInstance3D
## Номер из ГАИ ("" — заводской, см. plate()) и места табличек модели.
var plate_text := ""
var _plate_spots: Array = []
## Запчасти с базара: "speedo" (спидометр с подсветкой), "exhaust" (прямоточный
## глушитель: громче и +6% тяги), "tank" (бак в полтора раза больше),
## "wheels" (большие колёса: выше и держат на грунте), "rims" — цвет дисков
## (номер в RIMS, нет ключа — заводские).
var parts := {}
const RIMS := [Color(0.86, 0.88, 0.92), Color(0.1, 0.1, 0.11), Color(0.75, 0.12, 0.1), Color(0.85, 0.66, 0.2)]
const RIM_NAMES := ["хромированные", "чёрные", "красные", "золотые"]
const BIG_WHEEL := 1.18
## Сколько ещё секунд машину «трясёт» после ямы (камера при этом не дёргается)
var _shake := 0.0
var braking := false

var _steer := 0.0
var _yaw_rate := 0.0
var _lean := 0.0
var _camera: SmoothCamera
## Метки, за которыми плавно тянутся камеры: место водителя и точка сзади.
var _seat_mark: Node3D
var _chase_mark: Node3D
var _chase: SmoothCamera
var _chase_yaw := 0.0
var _chase_y := 0.0
var _chase_ready := false
var _body: Node3D  # всё, что наклоняется (мотоцикл в повороте)
var _rider: Node3D
var _zone: InteractZone
var _wheels: Array[Node3D] = []
var _engine_snd: AudioStreamPlayer3D
var _skid_snd: AudioStreamPlayer3D
var _rain_snd: AudioStreamPlayer
## Шины по гравию или траве — слышно, по чему едешь
var _road_snd: AudioStreamPlayer
## Пыль из-под колёс по грунту (зимой — снежная), только у своей машины
var _dust: CPUParticles3D
var _dust_mat: StandardMaterial3D
var _smoke: CPUParticles3D
var _rng := RandomNumberGenerator.new()
var _warned_fuel := false
var _headlights: Array[SpotLight3D] = []
## Свет в салоне и слой (бит слоя 3), на который он светит.
const CABIN_LAYER := 4
var _cabin_light: OmniLight3D
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
	_build_gauges()
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
		# Мягкий свет в салоне: без него при солнце сверху салон в глубокой
		# тени. Горит, только пока в машине водитель, и светит только на саму
		# машину — иначе каждая стоящая машина заново рисует кусок мира вокруг
		_cabin_light = OmniLight3D.new()
		_cabin_light.position = Vector3(0, 1.25, 0.2)
		_cabin_light.omni_range = 2.2
		_cabin_light.light_energy = 0.9
		_cabin_light.light_cull_mask = CABIN_LAYER
		_cabin_light.visible = false
		add_child(_cabin_light)
		for g in find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).layers |= CABIN_LAYER
	var zone_size := Vector3(4.0, 2.0, 5.5) if not spec.two_wheels else Vector3(2.6, 2.0, 3.0)
	_zone = InteractZone.create("E — %s: %s" % ["сесть за руль" if spec.roof else "сесть на мотоцикл", spec.title], zone_size)
	_zone.position.y = -0.2
	# Машина из салона: пока не куплена — подсказка с ценой, E — купить
	_zone.prompt_fn = func() -> String:
		if school and not (allowed.is_valid() and allowed.call()):
			return "Учебный «%s» автошколы — только на экзамене" % spec.title
		if not owned():
			return "E — купить «%s» за %d грн: %s" % [spec.title, price, blurb]
		return "E — %s: %s" % ["сесть за руль" if spec.roof else "сесть на мотоцикл", spec.title]
	_zone.activated.connect(func() -> void:
		if school and not (allowed.is_valid() and allowed.call()):
			return
		if owned():
			if school or may_drive():
				_on_enter()
			else:
				SoundLibrary.play("click", -4.0, 0.6)
				GameManager.notify(license_warning())
		elif GameManager.spend(price):
			Progress.buy_car(kind)
			SoundLibrary.play("quest")
			GameManager.notify("«%s» теперь твоя! %s" % [spec.title, "Садись и езжай" if may_drive() else license_warning()]))
	add_child(_zone)
	# Продаётся — табличка с ценой над крышей, пока не купили
	if price > 0 and not school:
		_sale = Label3D.new()
		_sale.text = "ПРОДАЁТСЯ\n%d грн" % price
		_sale.font_size = 64
		_sale.pixel_size = 0.006
		_sale.outline_size = 12
		_sale.modulate = Color(1.0, 0.9, 0.4)
		_sale.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_sale.position.y = float(spec.shape_y) + float((spec.shape as Vector3).y) * 0.5 + 0.7
		_sale.visibility_range_end = 60.0
		add_child(_sale)
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
	_road_snd = AudioStreamPlayer.new()
	add_child(_road_snd)
	_dust = _make_dust()
	add_child(_dust)
	# Дым из-под капота у побитой машины
	if not spec.two_wheels:
		_smoke = _make_dust()
		_smoke.emission_box_extents = Vector3(0.3, 0.05, 0.3)
		var half2: Vector3 = (spec.shape as Vector3) * 0.5
		_smoke.position = Vector3(0, float(spec.shape_y) + half2.y * 0.6, -half2.z + 0.7)
		_smoke.direction = Vector3(0, 1, 0)
		_smoke.gravity = Vector3(0, 1.2, 0)
		_smoke.amount = 20
		_smoke.lifetime = 2.5
		var sm := (_smoke.mesh as QuadMesh).duplicate() as QuadMesh
		var smat := _dust_mat.duplicate() as StandardMaterial3D
		smat.albedo_color = Color(0.3, 0.3, 0.32)
		sm.material = smat
		_smoke.mesh = sm
		add_child(_smoke)
		# _make_dust заменил материал пыли — возвращаем материал настоящей пыли
		_dust_mat = (_dust.mesh as QuadMesh).material as StandardMaterial3D
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
	if _cabin_light:
		_cabin_light.visible = true
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
	if _cabin_light:
		_cabin_light.visible = false
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
		if absf(GameManager.steer_axis) > 0.01:
			steer_in = GameManager.steer_axis
	if SettingsManager.auto_gearbox:
		var io := _pedal_inputs(dt, w, s) if drv and GameManager.pedal_mode else _auto_inputs(dt, w, s)
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
		# Назад автомат не разгоняет больше ~20 км/ч (мотоцикл — шагом)
		var gas := 1.0 if s and speed > -rev_max() else 0.0
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


## Педали телефона: газ — в сторону, выбранную рычагом D/R, тормоз —
## всегда тормоз. Катимся не туда — газ тормозит, пока не встанем.
func _pedal_inputs(dt: float, gas: bool, brake: bool) -> Vector2:
	_auto_start_cool = maxf(_auto_start_cool - dt, 0.0)
	if not engine_on:
		if gas and _auto_start_cool <= 0.0:
			_auto_start_cool = 2.0
			if _try_start() and gear == 0:
				gear = 1
		return Vector2(0.0, 1.0 if brake else 0.0)
	var want := -1 if GameManager.pedal_reverse and (spec.ratios[-1] as float) != 0.0 else 1
	if (want == -1) != (gear == -1) or gear == 0:
		if absf(speed) < 0.5:
			gear = want
		else:
			return Vector2(0.0, 1.0 if gas or brake else 0.0)
	# Назад больше ~20 км/ч не разгоняемся (мотоцикл — шагом)
	var g := gas and (want == 1 or speed > -rev_max())
	return Vector2(1.0 if g else 0.0, 1.0 if brake else 0.0)


## Предел скорости назад, м/с. Заднего хода у мотоцикла и мопеда нет —
## назад откатываются, отталкиваясь ногами, шагом (около 5 км/ч).
func rev_max() -> float:
	return 1.4 if spec.two_wheels else 5.5


## Один шаг симуляции. Вынесено отдельно, чтобы гонять в тестах без клавиатуры.
func _update(dt: float, throttle: float, brake: bool, handbrake: bool, pedal: bool, steer_in: float) -> void:
	if gear == -1 and speed < -rev_max():
		throttle = 0.0
		# Ногами быстрее не оттолкнёшься
		if spec.two_wheels:
			speed = -rev_max()
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
		roll = 1.0 + (roll - 1.0) * float(spec.get("mud", 1.0)) * (0.7 if has_part("wheels") else 1.0)
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
		wn.rotation.x -= speed / wheel_r * dt * float(wn.get_meta("k", 1.0))
		# Передние колёса поворачивают вместе с рулём
		if wn.position.z < 0.0 and not spec.two_wheels:
			wn.rotation.y = _steer
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
	# Большие колёса с базара — тоже лучше вне асфальта
	if has_part("wheels") and not on_asphalt():
		grip *= 1.25
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
		if driver:
			GameManager.vibrate(int(clampf(hit * 25.0, 60.0, 300.0)))
		if self == GameManager.delivery_vehicle:
			Progress.damage_bread(hit * 2.5)
		# Лёгкий толчок (до ~16 км/ч потерянной скорости) — только звук;
		# ломается машина от сильных ударов
		if hit > DAMAGE_HIT:
			_wear((hit - DAMAGE_HIT * 0.5) * (2.0 if spec.roof else 3.0))
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
				GameManager.notify("Упал! %s: %d%%" % [spec.title, int(condition)])
			elif hit > DAMAGE_HIT:
				GameManager.notify("Бах! %s: %d%%" % [spec.title, int(condition)])


## Покрытие под колёсами: сопротивление качению и сцепление шин.
func surface() -> Dictionary:
	var s := _surface()
	# Зимой снег и лёд — держит хуже везде
	s.grip = float(s.grip) * WeatherManager.ice_factor()
	return s


func _surface() -> Dictionary:
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
		# Прямоток — ниже и громче
		var loud := has_part("exhaust")
		_engine_snd.pitch_scale = clampf(rpm / 60.0 * per_rev / 55.0 * (0.88 if loud else 1.0), 0.3, 4.0)
		var gas := 1.0 if driver and Input.is_physical_key_pressed(KEY_W) else 0.0
		_engine_snd.volume_db = lerpf(-8.0, 0.0, gas) + (0.0 if engine_on else -10.0) + (4.0 if loud else 0.0)
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
	_update_road_sound()
	_update_dust()
	_update_smoke()
	var want_rain: bool = driver != null and spec.roof and WeatherManager.rain > 0.3 and not WeatherManager.snowing()
	if want_rain != _rain_snd.playing:
		if want_rain:
			_rain_snd.play()
		else:
			_rain_snd.stop()


func _make_dust() -> CPUParticles3D:
	var d := CPUParticles3D.new()
	d.amount = 48
	d.lifetime = 1.8
	d.local_coords = false
	d.emitting = false
	d.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var half: Vector3 = (spec.shape as Vector3) * 0.5
	d.emission_box_extents = Vector3(half.x * 0.8, 0.1, 0.2)
	d.position = Vector3(0, 0.25, half.z)
	d.direction = Vector3(0, 0.6, 1)
	d.spread = 25.0
	d.gravity = Vector3(0, 0.4, 0)
	d.initial_velocity_min = 0.8
	d.initial_velocity_max = 2.0
	d.damping_min = 1.0
	d.damping_max = 2.0
	d.scale_amount_min = 1.0
	d.scale_amount_max = 2.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.6))
	d.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.75))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	d.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2(1.3, 1.3)
	_dust_mat = StandardMaterial3D.new()
	_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_dust_mat.vertex_color_use_as_albedo = true
	_dust_mat.albedo_texture = _puff_texture()
	q.material = _dust_mat
	d.mesh = q
	return d


static var _puff: Texture2D


## Клуб пыли — textures/vehicles/dust.png (см. Assets).
static func _puff_texture() -> Texture2D:
	if _puff == null:
		_puff = Assets.texture("vehicles/dust", puff_image)
	return _puff


static func puff_image() -> Image:
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var r := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
			var a := clampf(1.0 - r, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return img


func _update_dust() -> void:
	var v := absf(speed)
	var want := driver != null and v > 4.0 and not on_asphalt() and WeatherManager.wetness < 0.4 and WeatherManager.rain < 0.3
	if want != _dust.emitting:
		_dust.emitting = want
	if want:
		var snowy := WeatherManager.snow > 0.5
		_dust_mat.albedo_color = Color(0.92, 0.94, 0.98) if snowy else Color(0.62, 0.53, 0.4)
		_dust.speed_scale = clampf(v / 12.0, 0.6, 1.6)


func _update_smoke() -> void:
	if _smoke == null:
		return
	var want := engine_on and condition < 35.0
	if want != _smoke.emitting:
		_smoke.emitting = want
		if want and driver:
			GameManager.notify("Из-под капота дымит! Машину пора на СТО")


func _update_road_sound() -> void:
	var v := absf(speed)
	var kind := ""
	if driver != null and v > 1.0 and not on_asphalt():
		var p := global_position
		var dirt: bool = Roads.on_gravel(p.x, p.z) or Roads.on_forest_road(p.x, p.z) or float(_surface().roll) < 3.0
		kind = "gravel" if dirt else "grass"
		# Зимой под колёсами снег — скрипит, как гравий, только тише
		if WeatherManager.snow > 0.5:
			kind = "gravel"
	if kind == "":
		if _road_snd.playing:
			_road_snd.stop()
		return
	var s := SoundLibrary.stream(kind)
	if _road_snd.stream != s:
		_road_snd.stream = s
	if not _road_snd.playing:
		_road_snd.play()
	_road_snd.pitch_scale = clampf(0.75 + v / 25.0, 0.75, 1.6)
	_road_snd.volume_db = linear_to_db(clampf(v / 14.0, 0.05, 1.0)) - (4.0 if spec.roof else 0.0)


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


## Камера закреплена за машиной, как в Car Parking: стоит всегда на одном
## расстоянии сзади и не отстаёт на скорости. Плавно, без рывков, она только
## поворачивается следом за машиной и сглаживает мелкие ступеньки по высоте
## (бордюр, край асфальта). На ямах не трясётся — яму чувствует вибрация.
func _update_camera(dt: float) -> void:
	_shake = maxf(_shake - dt, 0.0)
	if not chase_view or _chase == null:
		return
	var back: Vector3 = spec.chase
	var yaw := rotation.y
	var y := global_position.y
	if dt >= 0.5 or not _chase_ready:
		_chase_yaw = yaw
		_chase_y = y
		_chase_ready = true
	else:
		# Поворот — чуть мягче машины: на повороте видно, куда едешь
		_chase_yaw = lerp_angle(_chase_yaw, yaw, minf(dt * 8.0, 1.0))
		_chase_y = lerpf(_chase_y, y, minf(dt * 6.0, 1.0))
	var origin := Vector3(global_position.x, _chase_y, global_position.z)
	var turn := Basis(Vector3.UP, _chase_yaw)
	_chase_mark.global_position = origin + turn * back
	_chase_mark.look_at(origin + Vector3(0, 1.0, 0))
	if dt >= 0.5:
		_chase.snap()


## Асфальт — трасса, город, площадки АЗС и СТО.
func on_asphalt() -> bool:
	return Roads.on_asphalt(global_position.x, global_position.z)


func headlights_on() -> bool:
	return _headlights[0].visible


func tank() -> float:
	return float(spec.tank) * (1.5 if has_part("tank") else 1.0)


func refuel(liters: float) -> void:
	fuel = minf(fuel + liters, tank())
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


## Какие права нужны: "" — никаких (мопед, трактор колхоза).
func category() -> String:
	return String(Progress.KIND_CATEGORY.get(kind, ""))


## Можно ли за руль: права нужной категории или идёт экзамен на неё.
func may_drive() -> bool:
	var c := category()
	return c == "" or Progress.has_category(c) or exam_category == c


func license_warning() -> String:
	if category() == "B":
		return "Без прав за руль нельзя: сначала автошкола у трассы — паспорт, медсправка и экзамен"
	return "Нужна категория %s — экзамен в автошколе у трассы" % category()


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
		"izh":
			VehicleModels.izh(b, col)
		"moped":
			VehicleModels.moped(b, col)
		"niva":
			VehicleModels.niva(b, col, glass)
		"volga":
			VehicleModels.volga(b, col, glass)
		"truck":
			VehicleModels.gaz53(b, col, glass)
		"bus":
			VehicleModels.bus(b, col, Vector3(2.5, 3.0, 9.0))
		"tractor":
			VehicleModels.tractor(b, col, glass)
		_:
			VehicleModels.zhiguli(b, col, true, glass)
	_paint_mesh = b.build_mesh()
	_body.add_child(_paint_mesh)
	# Надписи модели (эмблемы на баке и т. п.) — живут вместе с кузовом
	for l in b.get_meta("labels", []):
		var lb := Label3D.new()
		lb.text = l[0]
		lb.position = l[1]
		lb.rotation.y = l[2]
		lb.pixel_size = l[3]
		lb.modulate = l[4]
		lb.font_size = 64
		lb.outline_size = 0
		lb.double_sided = false
		_paint_mesh.add_child(lb)
	if school and not _body.has_node("SchoolMarks"):
		_school_marks()
	# Номерные знаки — один раз, перекраска их не трогает
	_plate_spots = b.get_meta("plates", [])
	if not _body.has_node("Plates"):
		_attach_plates()
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
	SoundLibrary.play_at("land", global_position, -4.0 + strength * 3.0, 0.8)
	if driver:
		GameManager.vibrate(int(30.0 + strength * 30.0))
	if self == GameManager.delivery_vehicle:
		Progress.damage_bread(strength * 2.5)


## Номер машины: зарегистрированный в ГАИ или выданный с завода.
func plate() -> String:
	return plate_text if plate_text != "" else Plates.number(String(name).hash())


## Новый номер (окошко ГАИ в милиции) — таблички перевешиваются сразу.
func set_plate(t: String) -> void:
	plate_text = t
	var old := _body.get_node_or_null("Plates")
	if old:
		_body.remove_child(old)
		old.queue_free()
	_attach_plates()


func _attach_plates() -> void:
	Plates.attach(_body, _paint_mesh.get_aabb(), plate(), spec.two_wheels, _plate_spots)


func repaint() -> void:
	paint = (paint + 1) % paints().size()
	_paint_body()


## Учебная машина: треугольник «У» на крыше, у легковой — жёлтая полоса
## со штриховкой по бокам и надпись «УЧЕБНАЯ».
func _school_marks() -> void:
	var box := _paint_mesh.get_aabb()
	var b := MeshBuilder.new()
	b.ground_shade = false
	var top := box.end.y
	# Треугольник на крыше: стойка, красная кайма, белое поле, смотрит вперёд
	var zc := box.position.z + box.size.z * (0.42 if kind == "car" else 0.15)
	b.box(Vector3(-0.03, top, zc - 0.03), Vector3(0.03, top + 0.12, zc + 0.03), Color(0.2, 0.2, 0.2))
	for side in [-1.0, 1.0]:
		var z: float = zc + side * 0.01
		b.tri(Vector3(-0.3, top + 0.1, z), Vector3(0.3, top + 0.1, z), Vector3(0, top + 0.62, z), Color(0.85, 0.12, 0.1), true)
		var z2: float = zc + side * 0.02
		b.tri(Vector3(-0.2, top + 0.15, z2), Vector3(0.2, top + 0.15, z2), Vector3(0, top + 0.5, z2), Color(0.97, 0.97, 0.97), true)
	if kind == "car":
		var yellow := Color(0.98, 0.75, 0.1)
		for sx in [-1.0, 1.0]:
			var x: float = (box.end.x + 0.006) * sx
			var x2: float = x + 0.004 * sx
			# Полоса понизу дверей и заднего крыла
			b.box(Vector3(minf(x, x2), 0.38, -0.55), Vector3(maxf(x, x2), 0.56, 1.95), yellow)
			# Чёрная штриховка в конце полосы
			var z := 1.0
			while z < 1.9:
				var x3: float = x + 0.008 * sx
				b.tri(Vector3(x3, 0.38, z), Vector3(x3, 0.56, z + 0.12), Vector3(x3, 0.38, z + 0.08), Color(0.08, 0.08, 0.08), true)
				b.tri(Vector3(x3, 0.38, z + 0.08), Vector3(x3, 0.56, z + 0.12), Vector3(x3, 0.56, z + 0.2), Color(0.08, 0.08, 0.08), true)
				z += 0.2
	var m := b.build_mesh()
	m.name = "SchoolMarks"
	_body.add_child(m)
	var u := Label3D.new()
	u.text = "У"
	u.font_size = 96
	u.pixel_size = 0.0035
	u.outline_size = 0
	u.modulate = Color(0.05, 0.05, 0.05)
	u.double_sided = false
	u.position = Vector3(0, top + 0.27, zc - 0.03)
	u.rotation.y = PI
	m.add_child(u)
	var u2 := u.duplicate() as Label3D
	u2.position.z = zc + 0.03
	u2.rotation.y = 0.0
	m.add_child(u2)
	if kind == "car":
		for sx in [-1.0, 1.0]:
			var l := Label3D.new()
			l.text = "УЧЕБНАЯ\nавтошкола «Каменка»"
			l.font_size = 64
			l.pixel_size = 0.0028
			l.outline_size = 0
			l.modulate = Color(0.97, 0.97, 0.97)
			# Только снаружи — иначе просвечивает сквозь стёкла с другого борта
			l.double_sided = false
			l.position = Vector3((box.end.x + 0.012) * sx, 0.82, 0.05)
			l.rotation.y = PI / 2.0 * sx
			m.add_child(l)


## Тяга мотора с учётом форсировки.
func _torque() -> float:
	return (spec.torque as float) * (1.2 if engine_tuned else 1.0) * (1.06 if has_part("exhaust") else 1.0)


func has_part(n: String) -> bool:
	return parts.has(n) and n != "rims"


## Поставить запчасть с базара. Диски при каждой покупке — следующего цвета.
func fit_part(n: String) -> void:
	if n == "rims":
		parts["rims"] = (int(parts.get("rims", -1)) + 1) % RIMS.size()
	else:
		parts[n] = true
	_apply_parts()


## Внешний вид запчастей: колёса (размер, цвет дисков) и труба глушителя.
func _apply_parts() -> void:
	if not _body:
		return
	var big := has_part("wheels")
	var disc: Variant = RIMS[int(parts["rims"])] if parts.has("rims") else null
	for n in _wheels:
		var cur: Variant = n.get_meta("disc") if n.has_meta("disc") else null
		if cur != disc:
			n.set_meta("disc", disc)
			for c in n.get_children():
				c.queue_free()
			n.add_child(_wheel_mesh(n.get_meta("moto"), n.get_meta("r"), n.get_meta("w"), disc))
		n.scale = Vector3.ONE * (BIG_WHEEL if big else 1.0)
	# Колёса растут от оси — кузов поднимаем, чтобы они стояли на земле
	_body.position.y = float(spec.wheel_r) * (BIG_WHEEL - 1.0) if big else 0.0
	var old := _body.get_node_or_null("Exhaust")
	if old:
		old.free()
	if has_part("exhaust") and _paint_mesh:
		var box := _paint_mesh.get_aabb()
		var b := MeshBuilder.new()
		b.ground_shade = false
		var chrome := Color(0.8, 0.82, 0.86)
		if spec.two_wheels:
			# Труба вдоль правого бока, срез назад
			b.box(Vector3(0.14, 0.3, -0.2), Vector3(0.22, 0.38, box.end.z - 0.05), chrome)
			b.box(Vector3(0.13, 0.29, box.end.z - 0.08), Vector3(0.23, 0.39, box.end.z + 0.02), Color(0.08, 0.08, 0.08))
		else:
			var x := box.position.x * 0.5
			var y := box.position.y + 0.18
			b.box(Vector3(x - 0.07, y - 0.07, box.end.z - 0.5), Vector3(x + 0.07, y + 0.07, box.end.z + 0.12), chrome)
			b.box(Vector3(x - 0.05, y - 0.05, box.end.z + 0.1), Vector3(x + 0.05, y + 0.05, box.end.z + 0.13), Color(0.08, 0.08, 0.08))
		var m := b.build_mesh()
		m.name = "Exhaust"
		_body.add_child(m)


func _build_car() -> void:
	_paint_body()
	_brake_lights(spec.get("tail", [Vector3(-0.62, 0.62, 2.06), Vector3(0.48, 0.62, 2.06)]), Vector3(0.16, 0.12, 0.03))
	for p in spec.get("wheels", [Vector3(-0.78, 0.29, -1.3), Vector3(0.78, 0.29, -1.3), Vector3(-0.78, 0.29, 1.3), Vector3(0.78, 0.29, 1.3)]):
		if p is Array:
			_wheel(p[0], false, p[1], p[2])
		else:
			_wheel(p, false)


func _build_moto() -> void:
	_paint_body()
	_brake_lights(spec.get("tail", [Vector3(0, 0.66, 0.965)]), Vector3(0.12, 0.07, 0.03))
	for p in spec.get("wheels", [Vector3(0, 0.31, -0.8), Vector3(0, 0.31, 0.62)]):
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
	# Модель седока — под сиденье «Явы»; на мопеде сиденье ниже
	_rider.position.y = float((spec.seat as Vector3).y) - 1.45
	_rider.visible = false
	_body.add_child(_rider)


func _wheel(p: Vector3, moto: bool, r := 0.0, w := 0.2) -> void:
	if r <= 0.0:
		r = spec.wheel_r
	var n := Node3D.new()
	# Маленькие колёса крутятся быстрее
	n.set_meta("k", float(spec.wheel_r) / r)
	n.set_meta("moto", moto)
	n.set_meta("r", r)
	n.set_meta("w", w)
	n.position = p
	n.add_child(_wheel_mesh(moto, r, w, null))
	_body.add_child(n)
	_wheels.append(n)


func _wheel_mesh(moto: bool, r: float, w: float, disc: Variant) -> MeshInstance3D:
	var wb := MeshBuilder.new()
	wb.ground_shade = false
	if moto:
		VehicleModels.moto_wheel(wb, r, disc)
	else:
		VehicleModels.car_wheel(wb, r, w, disc)
	return wb.build_mesh()


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
	if _sale:
		_sale.visible = not owned()
	# От первого лица мотоциклиста не рисуем — камера у него в голове
	if _rider:
		_rider.visible = driver != null and chase_view
	var inside := driver != null and not chase_view
	for g in _gauge_holders:
		g.visible = inside
	if driver != null and not _needles.is_empty():
		var top: float = {"moto": 140.0, "izh": 140.0, "moped": 60.0, "truck": 120.0, "tractor": 40.0}.get(kind, 160.0)
		var k_speed := clampf(speed_kmh() / top, 0.0, 1.0)
		var k_rpm := clampf(rpm / float(spec.redline) * 0.85, 0.0, 1.0)
		for i in _needles.size():
			var k := k_speed if i == 0 else k_rpm
			var target := deg_to_rad(135.0 - 270.0 * k)
			(_needles[i] as Node3D).rotation.z = lerp_angle((_needles[i] as Node3D).rotation.z, target, minf(_delta * 12.0, 1.0))


# --- Приборы на торпедо -------------------------------------------------------

## Где стоят круглые приборы в салоне: [центр, радиус, наклон назад]. Первый —
## спидометр, второй — тахометр. У мотоцикла один спидометр на фаре.
func _gauge_spots() -> Array:
	match kind:
		"car":
			return [[Vector3(-0.41, 1.04, -0.327), 0.03, 0.0], [Vector3(-0.28, 1.04, -0.327), 0.03, 0.0]]
		"moto":
			return [[Vector3(0.0, 1.122, -0.89), 0.042, -1.1]]
		"izh":
			return [[Vector3(0.0, 1.173, -0.62), 0.045, -1.3]]
		"moped":
			return [[Vector3(0.0, 1.0, -0.63), 0.035, -1.1]]
		"tractor":
			return [[Vector3(-0.15, 1.72, -0.148), 0.045, 0.0], [Vector3(0.15, 1.72, -0.148), 0.045, 0.0]]
	# Машины из салона: торпедо по _cabin(dz, y, hx)
	var cab: Array = {"niva": [-0.66, 0.62, 0.72], "volga": [-0.8, 0.5, 0.76], "truck": [-2.05, 1.12, 0.95]}.get(kind, [])
	if cab.is_empty():
		return []
	var dz: float = cab[0]
	var y: float = cab[1]
	var hx: float = cab[2]
	var r := hx * 0.075
	return [[Vector3(-hx * 0.6, y + 0.44, dz + 0.262), r, 0.0], [Vector3(-hx * 0.4, y + 0.44, dz + 0.262), r, 0.0]]


var _needles: Array[Node3D] = []
## Циферблаты рисуем, только когда сидишь в салоне — снаружи их не видно
var _gauge_holders: Array[Node3D] = []
static var _dial_tex: Texture2D


func _build_gauges() -> void:
	var spots := _gauge_spots()
	if spots.is_empty():
		return
	var face_mat := StandardMaterial3D.new()
	face_mat.albedo_texture = _dial_texture()
	face_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	# Подсветка приборов: видно и ночью
	face_mat.emission_enabled = true
	face_mat.emission_texture = face_mat.albedo_texture
	face_mat.emission_energy_multiplier = 0.35
	var needle_mat := StandardMaterial3D.new()
	needle_mat.albedo_color = Color(1.0, 0.45, 0.15)
	needle_mat.emission_enabled = true
	needle_mat.emission = Color(1.0, 0.45, 0.15)
	needle_mat.emission_energy_multiplier = 0.6
	for s in spots:
		var r: float = s[1]
		var holder := Node3D.new()
		holder.position = s[0]
		holder.rotation.x = s[2]
		holder.visible = false
		_body.add_child(holder)
		_gauge_holders.append(holder)
		var face := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(r, r) * 2.0
		face.mesh = q
		face.material_override = face_mat
		face.position.z = 0.001
		face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(face)
		var pivot := Node3D.new()
		pivot.position.z = 0.003
		holder.add_child(pivot)
		var needle := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(r * 0.08, r * 0.85, 0.001)
		needle.mesh = bm
		needle.position.y = r * 0.36
		needle.material_override = needle_mat
		needle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(needle)
		pivot.rotation.z = deg_to_rad(135.0)
		_needles.append(pivot)


## Циферблат: тёмный круг, белые риски через 30°, красная зона в конце.
static func _dial_texture() -> Texture2D:
	if _dial_tex == null:
		_dial_tex = Assets.texture("vehicles/dial", dial_image, true)
	return _dial_tex


static func dial_image() -> Image:
	var n := 64
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5) - c
			var r := d.length() / (n * 0.5)
			if r > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var col := Color(0.08, 0.08, 0.09)
			if r > 0.92:
				col = Color(0.6, 0.6, 0.62)
			elif r > 0.72:
				# Угол от «12 часов» по часовой: шкала от −135° до +135°
				var ang := rad_to_deg(atan2(d.x, -d.y))
				if absf(ang) <= 136.0:
					var tick := fposmod(ang + 135.0, 30.0)
					if tick < 3.0 or tick > 27.0:
						col = Color(0.95, 0.95, 0.9)
					elif ang > 95.0 and r > 0.8:
						col = Color(0.75, 0.15, 0.1)
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	return img


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
		"plate": plate_text,
		"parts": parts.duplicate(),
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
	var pa: Variant = d.get("parts", {})
	parts = (pa as Dictionary).duplicate() if pa is Dictionary else {}
	if parts.has("rims"):
		parts["rims"] = int(parts["rims"]) % RIMS.size()
	_apply_parts()
	var pt := str(d.get("plate", ""))
	if pt != plate_text and _paint_mesh:
		set_plate(pt)
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
