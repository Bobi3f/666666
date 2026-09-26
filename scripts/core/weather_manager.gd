extends Node
## Погода: ясно, пасмурно, туман, дождь. Меняется раз в несколько игровых
## часов. Мир читает отсюда силу солнца, туман и дождь; машина — грязь.

signal changed(kind: int)

enum Kind { CLEAR, CLOUDY, FOG, RAIN }

const NAMES := ["ясно", "пасмурно", "туман", "дождь"]

var kind := Kind.CLEAR
## Плавный переход 0..1 к силе текущей погоды — чтобы не щёлкало.
var rain := 0.0
var cloud := 0.0
var fog := 0.0
## Грунт раскисает после дождя и подсыхает часами.
var wetness := 0.0

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
	rain = lerpf(rain, 1.0 if kind == Kind.RAIN else 0.0, k)
	cloud = lerpf(cloud, 1.0 if kind != Kind.CLEAR else 0.0, k)
	fog = lerpf(fog, 1.0 if kind == Kind.FOG else 0.0, k)
	if kind == Kind.RAIN:
		wetness = minf(wetness + m / 40.0, 1.0)
	else:
		wetness = maxf(wetness - m / 300.0, 0.0)


func _pick_next() -> void:
	# Чаще ясно, дождь — примерно раз в сутки
	var r := _rng.randf()
	var next := Kind.CLEAR
	if r > 0.5:
		next = Kind.CLOUDY
	if r > 0.72:
		next = Kind.RAIN
	if r > 0.9:
		next = Kind.FOG
	set_kind(next, _rng.randf_range(120.0, 360.0))


func set_kind(k: int, minutes := 240.0) -> void:
	var was := kind
	kind = k
	_minutes_left = minutes
	if was != k:
		changed.emit(k)
		if k == Kind.RAIN:
			GameManager.notify("Пошёл дождь. Грунтовки раскиснут — на машине осторожнее")


func name_text() -> String:
	return NAMES[kind]


## Раскисшая грунтовка: во сколько раз растёт сопротивление качению.
func mud_factor() -> float:
	return 1.0 + wetness * 5.0


func save_state() -> Dictionary:
	return {"kind": kind, "left": _minutes_left, "wet": wetness}


func load_state(d: Dictionary) -> void:
	kind = int(d.get("kind", Kind.CLEAR))
	_minutes_left = float(d.get("left", 240.0))
	wetness = float(d.get("wet", 0.0))
	rain = 1.0 if kind == Kind.RAIN else 0.0
	cloud = 1.0 if kind != Kind.CLEAR else 0.0
	fog = 1.0 if kind == Kind.FOG else 0.0
	changed.emit(kind)
