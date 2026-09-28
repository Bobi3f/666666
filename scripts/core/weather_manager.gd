extends Node
## Погода: ясно, пасмурно, туман, дождь (зимой — снег). Меняется раз
## в несколько игровых часов. Мир читает отсюда силу солнца, туман и дождь;
## машина — грязь и лёд.
##
## Времена года: неделя — сезон. Первая неделя — лето, потом осень
## (зелень желтеет), зима (снег лежит, скользко, грязь замёрзла), весна.

signal changed(kind: int)

enum Kind { CLEAR, CLOUDY, FOG, RAIN, STORM }

const NAMES := ["ясно", "пасмурно", "туман", "дождь", "гроза"]
const SEASONS := ["лето", "осень", "зима", "весна"]
const SEASON_DAYS := 7

var kind := Kind.CLEAR
## Плавный переход 0..1 к силе текущей погоды — чтобы не щёлкало.
var rain := 0.0
var cloud := 0.0
var fog := 0.0
## Грунт раскисает после дождя и подсыхает часами.
var wetness := 0.0
## Сезон на экране плавно: снег ложится и тает, листва желтеет понемногу.
var snow := 0.0
var autumn := 0.0
var spring := 0.0

var _minutes_left := 240.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	TimeManager.minute_passed.connect(_on_minutes)


func _on_minutes(m: float) -> void:
	_minutes_left -= m
	if _minutes_left <= 0.0:
		_pick_next()
	var k := clampf(m / 20.0, 0.0, 1.0)
	rain = lerpf(rain, 1.0 if wet() else 0.0, k)
	cloud = lerpf(cloud, 1.0 if kind != Kind.CLEAR else 0.0, k)
	fog = lerpf(fog, 1.0 if kind == Kind.FOG else 0.0, k)
	var winter := season() == 2
	if wet() and not winter:
		wetness = minf(wetness + m / 40.0, 1.0)
	else:
		# Зимой грязь замерзает
		wetness = maxf(wetness - m / (60.0 if winter else 300.0), 0.0)
	# Снег ложится за полдня (в снегопад — быстрее), тает за сутки
	if winter:
		snow = minf(snow + m / (120.0 if wet() else 600.0), 1.0)
	else:
		snow = maxf(snow - m / 1440.0, 0.0)
	var s := season()
	autumn = move_toward(autumn, 1.0 if s == 1 else (0.5 if s == 2 else 0.0), m / 1440.0)
	spring = move_toward(spring, 1.0 if s == 3 else 0.0, m / 1440.0)
	_apply_season()


## 0 лето, 1 осень, 2 зима, 3 весна.
func season() -> int:
	return int((TimeManager.day - 1) / SEASON_DAYS) % 4


func season_text() -> String:
	return SEASONS[season()]


func _apply_season() -> void:
	MeshBuilder.set_season(snow, autumn, spring)
	var gm := Vegetation.grass_material
	if gm:
		gm.set_shader_parameter("snow", snow)
		gm.set_shader_parameter("autumn", autumn)


## Сейчас метёт снег, а не льёт дождь.
func snowing() -> bool:
	return season() == 2


## Лёд и снег: во сколько раз хуже сцепление шин.
func ice_factor() -> float:
	return 1.0 - snow * 0.3


func _pick_next() -> void:
	# Чаще ясно, дождь — примерно раз в сутки
	var r := _rng.randf()
	var next := Kind.CLEAR
	if r > 0.5:
		next = Kind.CLOUDY
	if r > 0.72:
		next = Kind.RAIN
	# Летом и весной дождь иногда с грозой
	if r > 0.72 and r < 0.78 and (season() == 0 or season() == 3):
		next = Kind.STORM
	if r > 0.9:
		next = Kind.FOG
	set_kind(next, _rng.randf_range(120.0, 360.0))


## Идёт дождь (или гроза) — мокро, грязь, в колхозе не работают.
func wet() -> bool:
	return kind == Kind.RAIN or kind == Kind.STORM


## Вспышка молнии: 1 — сверкнуло, гаснет за доли секунды.
var flash := 0.0


## Название для экрана: зимой вместо дождя — снег.
func weather_word() -> String:
	if wet() and snowing():
		return "метель" if kind == Kind.STORM else "снег"
	return NAMES[kind]


func set_kind(k: int, minutes := 240.0) -> void:
	var was := kind
	kind = k
	_minutes_left = minutes
	if was != k:
		changed.emit(k)
		if k == Kind.STORM and not snowing():
			GameManager.notify("Гроза! Лучше переждать под крышей — и на машине осторожнее")
		elif k == Kind.RAIN or k == Kind.STORM:
			if snowing():
				GameManager.notify("Пошёл снег. Дороги скользкие — на машине тормози заранее")
			else:
				GameManager.notify("Пошёл дождь. Грунтовки раскиснут — на машине осторожнее")


func name_text() -> String:
	return "%s, %s" % [weather_word(), season_text()]


## Раскисшая грунтовка: во сколько раз растёт сопротивление качению.
func mud_factor() -> float:
	return 1.0 + wetness * 5.0


func save_state() -> Dictionary:
	return {"kind": kind, "left": _minutes_left, "wet": wetness, "snow": snow, "autumn": autumn, "spring": spring}


func load_state(d: Dictionary) -> void:
	kind = int(d.get("kind", Kind.CLEAR))
	_minutes_left = float(d.get("left", 240.0))
	wetness = float(d.get("wet", 0.0))
	rain = 1.0 if wet() else 0.0
	cloud = 1.0 if kind != Kind.CLEAR else 0.0
	fog = 1.0 if kind == Kind.FOG else 0.0
	snow = float(d.get("snow", 0.0))
	autumn = float(d.get("autumn", 0.0))
	spring = float(d.get("spring", 0.0))
	_apply_season()
	changed.emit(kind)
