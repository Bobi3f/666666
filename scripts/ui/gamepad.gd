extends Node
## Геймпад (Xbox, PlayStation и похожие) — поверх клавиатуры.
##
## Как и сенсорные кнопки, геймпад «нажимает» те же клавиши
## (Input.parse_input_event), поэтому остальная игра о нём не знает.
## Пешком левый стик двигает плавно (GameManager.move_axis), правый
## крутит камеру. В машине RT — газ, LT — тормоз, левый стик — руль.
## В меню кнопки выбираются крестовиной и A — это Godot умеет сам.

const DEAD := 0.2
const LOOK_SPEED := 2.6  # радиан в секунду при стике до упора

var _down := {}  # клавиша → зажата геймпадом
## Для автотестов: номер «геймпада», которого физически нет.
var test_pad := -1
var _axis_on := false  # стик сейчас двигает персонажа — чтобы не мешать джойстику на экране


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _pad() -> int:
	if test_pad >= 0:
		return test_pad
	var pads := Input.get_connected_joypads()
	return pads[0] if not pads.is_empty() else -1


func _process(delta: float) -> void:
	var pad := _pad()
	if pad < 0:
		return
	var paused := get_tree().paused
	var driving := GameManager.vehicle != null
	# Кнопки — в клавиши. Start и Back работают и на паузе
	_press(KEY_ESCAPE, Input.is_joy_button_pressed(pad, JOY_BUTTON_START))
	if paused:
		_release_game_keys()
		return
	_press(KEY_M, Input.is_joy_button_pressed(pad, JOY_BUTTON_BACK))
	_press(KEY_J, Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_UP))
	_press(KEY_E, Input.is_joy_button_pressed(pad, JOY_BUTTON_X))
	_press(KEY_SPACE, Input.is_joy_button_pressed(pad, JOY_BUTTON_A))
	_press(KEY_V if driving else KEY_C, Input.is_joy_button_pressed(pad, JOY_BUTTON_B))
	_press(KEY_H if driving else KEY_Q, Input.is_joy_button_pressed(pad, JOY_BUTTON_Y))
	# Сменили режим — отпускаем клавишу другого режима
	_press(KEY_C if driving else KEY_V, false)
	_press(KEY_Q if driving else KEY_H, false)
	var stick := Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
	if driving:
		if _axis_on:
			GameManager.move_axis = Vector2.ZERO
			_axis_on = false
		_press(KEY_W, Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) > 0.3)
		_press(KEY_S, Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT) > 0.3)
		_press(KEY_A, stick.x < -0.35)
		_press(KEY_D, stick.x > 0.35)
		_press(KEY_SHIFT, false)
	else:
		for k in [KEY_W, KEY_S, KEY_A, KEY_D]:
			_press(k, false)
		var mag := stick.length()
		if mag >= DEAD:
			GameManager.move_axis = stick / mag * minf((mag - DEAD) / (0.9 - DEAD), 1.0)
			_axis_on = true
		elif _axis_on:
			GameManager.move_axis = Vector2.ZERO
			_axis_on = false
		# Бег — нажать левый стик или отклонить до упора
		_press(KEY_SHIFT, Input.is_joy_button_pressed(pad, JOY_BUTTON_LEFT_STICK) or mag > 0.97)
		var look := Vector2(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y))
		if look.length() > DEAD:
			var p := GameManager.player as Player
			if p:
				var k := LOOK_SPEED * delta * SettingsManager.mouse_sens
				p._look(-look.x * k, -look.y * k * 0.7)


func _release_game_keys() -> void:
	for k in _down.keys():
		if k != KEY_ESCAPE:
			_press(k, false)
	if _axis_on:
		GameManager.move_axis = Vector2.ZERO
		_axis_on = false


func _press(key: int, down: bool) -> void:
	if bool(_down.get(key, false)) == down:
		return
	_down[key] = down
	var e := InputEventKey.new()
	e.physical_keycode = key
	e.keycode = key
	e.pressed = down
	Input.parse_input_event(e)
