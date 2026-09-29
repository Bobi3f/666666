class_name TaxiJob
extends Node3D
## Подработка таксистом на Жигулях.
##
## Пассажир ждёт у янтарного кольца: на стоянке «ТАКСИ» в городе или в
## одном из мест по округе. Подъехал на Жигулях и остановился рядом —
## садится сам (без прав не сядет). Называет, куда ехать; там загорается
## кольцо. Остановился в кольце — плата за расстояние, сверху чаевые, если
## довёз быстро и не побил машину. Следующий пассажир ждёт уже в другом месте.
## Работают таксисты с 7:00 до 22:00.

const Villagers := preload("res://scripts/world/villagers.gd")
const BASE_PAY := 100
const PAY_PER_M := 0.6
const TIP := 80
## Насколько близко остановиться к пассажиру или месту высадки.
const REACH := 7.5

## [куда везти — как скажет пассажир, где стоит пассажир / где высадить]
const PLACES := [
	["на стоянку такси в городе", Vector3(102.3, 0, 15.0)],
	["к сельмагу «Каменка»", Vector3(-53.0, 0, -24.0)],
	["к остановке у Каменки", Vector3(-63.2, 0, -11.0)],
	["на АЗС у трассы", Vector3(-103.0, 0, 8.0)],
	["в колхоз «Заря»", Vector3(-30.0, 0, -33.8)],
	["к пруду", Vector3(-168.3, 0, -46.0)],
	["к автошколе", Vector3(13.5, 0, -12.0)],
	["на площадь Мира", Vector3(122.0, 0, 8.6)],
	# Сёла района — у магазинов (Region.shop_pos): дорога дальняя, плата больше
	["в Озерцово, к магазину", Vector3(-418.0, 0, -302.0)],
	["в Первомай, к магазину", Vector3(433.0, 0, -352.0)],
	["в Тошики, к магазину", Vector3(-388.0, 0, 378.0)],
	["в Заречье, к магазину", Vector3(448.0, 0, 298.0)],
]

enum State {WAITING, RIDING}

var state := State.WAITING
var at := 0  # где ждёт пассажир (индекс в PLACES)
var dest := 0  # куда везём
var _t := 0.0
var _dist := 0.0
var _cond0 := 100.0
var _away := 0.0
var _nag := 0.0
## После высадки новый пассажир садится не сразу — сперва выходит прежний
var _rest := 0.0
var _passenger: Node3D
var _ring: MeshInstance3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_passenger = Node3D.new()
	var b := MeshBuilder.new()
	b.ground_shade = false
	Villagers.person_model(b, Color(0.55, 0.35, 0.6), Color(0.25, 0.2, 0.18), false, true)
	_passenger.add_child(b.build_mesh())
	add_child(_passenger)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.1
	torus.outer_radius = 3.4
	torus.rings = 32
	_ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.75, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.75, 0.2)
	mat.emission_energy_multiplier = 1.4
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = mat
	add_child(_ring)
	_wait_at(0)


func place_name(i: int) -> String:
	return PLACES[i][0]


func place_pos(i: int) -> Vector3:
	return PLACES[i][1]


func _open() -> bool:
	var h := TimeManager.hour()
	return h >= 7.0 and h < 22.0


func _wait_at(i: int) -> void:
	state = State.WAITING
	at = i
	_passenger.visible = true
	_passenger.global_position = place_pos(i)
	_ring.global_position = place_pos(i) + Vector3(0, 0.25, 0)


func _car() -> Vehicle:
	var v := GameManager.vehicle as Vehicle
	# На мотоцикле и тракторе пассажиров не возят
	return v if v and not v.spec.two_wheels and v.kind != "tractor" else null


func _process(delta: float) -> void:
	_ring.rotate_y(delta)
	_nag -= delta
	var open := _open()
	match state:
		State.WAITING:
			_passenger.visible = open
			_ring.visible = open
			if not open:
				return
			var car := _car()
			if car == null:
				return
			if _rest > 0.0:
				_rest -= delta
				return
			# Пассажир поворачивается к подъезжающей машине
			var to := car.global_position - _passenger.global_position
			_passenger.rotation.y = lerp_angle(_passenger.rotation.y, atan2(to.x, to.z), delta * 4.0)
			if to.length() < REACH and car.speed_kmh() < 3.0:
				if not Progress.license:
					if _nag <= 0.0:
						_nag = 20.0
						GameManager.notify("Пассажир: «А права-то у тебя есть?» — сдай на права в автошколе у трассы")
					return
				_board(car)
		State.RIDING:
			_t += delta
			var car := _car()
			var mins := int(_t) / 60
			GameManager.challenge_line = "Такси: пассажира — %s, %d:%02d" % [place_name(dest), mins, int(_t) % 60]
			if car == null:
				# Вышел из машины надолго — пассажир уходит
				_away += delta
				if _away > 60.0:
					GameManager.notify("Пассажир не дождался и ушёл пешком")
					_finish_ride(false)
				return
			_away = 0.0
			if car.global_position.distance_to(place_pos(dest)) < REACH and car.speed_kmh() < 3.0:
				_pay(car)


func _board(car: Vehicle) -> void:
	state = State.RIDING
	var choices: Array[int] = []
	for i in PLACES.size():
		if i != at and place_pos(i).distance_to(place_pos(at)) > 40.0:
			choices.append(i)
	dest = choices[_rng.randi() % choices.size()]
	_t = 0.0
	_away = 0.0
	_dist = place_pos(at).distance_to(place_pos(dest))
	_cond0 = car.condition
	_passenger.visible = false
	_ring.global_position = place_pos(dest) + Vector3(0, 0.25, 0)
	SoundLibrary.play("click", -4.0)
	GameManager.notify("Пассажир: «Мне %s. Быстро довезёшь — не обижу!»" % place_name(dest))


## Сколько секунд — «быстро»: как если бы ехал в среднем 30 км/ч.
func fast_time() -> float:
	return _dist / 8.3 + 10.0


func _pay(car: Vehicle) -> void:
	var pay := BASE_PAY + int(_dist * PAY_PER_M)
	var bits: Array[String] = []
	# На «Волге» ехать приятно — платят больше
	if car.kind == "volga":
		pay = int(pay * 1.4)
		bits.append("на «Волге» — с шиком")
	var smooth := _cond0 - car.condition < 1.5
	if _t < fast_time() and smooth:
		pay += TIP
		bits.append("чаевые за быстрый и мягкий ход")
	elif not smooth:
		bits.append("без чаевых — растряс пассажира")
	GameManager.add_money(pay)
	SoundLibrary.play("cash")
	QuestManager.event("taxi")
	var tail := (": " + ", ".join(bits)) if not bits.is_empty() else ""
	GameManager.notify("Приехали! +%d грн%s" % [pay, tail])
	_finish_ride(true)


func _finish_ride(delivered: bool) -> void:
	GameManager.challenge_line = ""
	_rest = 6.0
	# Следующий ждёт там, куда довёз, на стоянке в городе или где-то ещё
	var next := 0
	if delivered and _rng.randf() < 0.6:
		next = dest
	elif _rng.randf() < 0.5:
		next = _rng.randi() % PLACES.size()
	_wait_at(next)
