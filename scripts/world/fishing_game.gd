class_name FishingGame
extends Node3D
## Рыбалка с мостков: закинул — смотришь на поплавок — клюнуло — подсекай.
##
## Подсекать той же кнопкой E (на телефоне — та же кнопка «E»): мир передаёт
## сюда нажатие через pull(). Рано дёрнул — рыба ушла, опоздал — сорвалась.
## Сам улов, время и деньги считает мир по сигналу finished.

signal finished(result: String)  # "fish", "early", "miss", "nobite", "cancel"

## Сколько секунд даётся на подсечку: на телефоне палец медленнее мыши.
const BITE_WINDOW := 1.1

enum State {IDLE, WAIT, BITE}

var state := State.IDLE
var _t := 0.0
var _wait := 0.0
var _will_bite := false
var _float: Node3D
var _anchor := Vector3.ZERO
## Где стоит рыбак: ушёл с мостков — рыбалка кончилась.
var spot := Vector3.ZERO


func _ready() -> void:
	_float = Node3D.new()
	var body := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.1
	m.height = 0.2
	body.mesh = m
	body.material_override = _mat(Color(0.95, 0.95, 0.9))
	_float.add_child(body)
	var tip := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.03
	c.bottom_radius = 0.065
	c.height = 0.24
	tip.mesh = c
	tip.position.y = 0.15
	tip.material_override = _mat(Color(0.9, 0.15, 0.1))
	_float.add_child(tip)
	_float.visible = false
	add_child(_float)


func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.6
	return m


func active() -> bool:
	return state != State.IDLE


## Закинуть удочку: поплавок падает в точку water, клюнет ли — решает luck.
func cast(water: Vector3, luck: float) -> void:
	_anchor = water
	_float.global_position = water
	_float.visible = true
	_t = 0.0
	_wait = randf_range(1.5, 4.5)
	_will_bite = randf() < luck
	state = State.WAIT
	SoundLibrary.play_at("splash", water, -8.0, 1.4)


## Нажали E, пока поплавок на воде.
func pull() -> void:
	match state:
		State.WAIT:
			_end("early")
		State.BITE:
			_end("fish")


func cancel() -> void:
	if active():
		_end("cancel")


func _end(result: String) -> void:
	state = State.IDLE
	_float.visible = false
	finished.emit(result)


func _process(delta: float) -> void:
	if state == State.IDLE:
		return
	var p := GameManager.player as Node3D
	if p == null or p.global_position.distance_to(spot) > 4.0 or GameManager.vehicle != null:
		cancel()
		return
	_t += delta
	var y := sin(_t * 2.2) * 0.012
	if state == State.WAIT:
		# Изредка поплавок «вздрагивает» — это ещё не поклёвка, не спеши
		if fmod(_t, 1.7) < 0.12:
			y -= 0.02
		if _t >= _wait:
			if _will_bite:
				state = State.BITE
				_t = 0.0
				SoundLibrary.play_at("splash", _anchor, -6.0, 1.8)
				Input.vibrate_handheld(120)
			elif _t >= _wait + 2.5:
				_end("nobite")
	elif state == State.BITE:
		# Клюёт: поплавок резко уходит под воду и дёргается
		y = -0.09 + sin(_t * 30.0) * 0.03
		if _t >= BITE_WINDOW:
			_end("miss")
	_float.global_position = _anchor + Vector3(0, y, 0)
