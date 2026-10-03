class_name KeyRemap
extends Node
## Свои клавиши на компьютере: игрок назначает, какой клавишей делать
## действие (меню → «Управление»). Вся игра по-прежнему читает «свои»
## клавиши (W, E, Z…), а этот узел подменяет нажатия: нажал назначенную —
## игра получает клавишу действия. Клавиша, у которой действие забрали,
## ничего не делает. Стоит последним в дереве — получает нажатия первым.

## Действия, которые можно переназначить: [клавиша в игре, что делает]
const ACTIONS := [
	[KEY_W, "Вперёд / газ"], [KEY_S, "Назад / тормоз"], [KEY_A, "Влево / руль влево"], [KEY_D, "Вправо / руль вправо"],
	[KEY_SPACE, "Прыжок / ручник"], [KEY_SHIFT, "Бег / сцепление"], [KEY_C, "Присесть"], [KEY_E, "Действие, сесть, выйти"],
	[KEY_Q, "Съесть из запаса"], [KEY_H, "Сигнал"], [KEY_L, "Фары"], [KEY_Z, "Поворотник налево"],
	[KEY_X, "Поворотник направо"], [KEY_V, "Вид"], [KEY_R, "Зажигание"], [KEY_T, "Автомат / механика"],
	[KEY_B, "Радио"], [KEY_M, "Карта"], [KEY_J, "Журнал"],
]

## Ждём клавишу для назначения — нажатия не подменяем.
var capturing := false


func _process(_delta: float) -> void:
	# Новые узлы добавляются в конец — остаёмся последними
	var p := get_parent()
	if p and get_index() != p.get_child_count() - 1:
		p.move_child.call_deferred(self, -1)


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or capturing or k.has_meta("remapped"):
		return
	var map: Dictionary = SettingsManager.key_map
	if map.is_empty():
		return
	var p := k.physical_keycode
	var g := -1
	for game_key in map:
		if int(map[game_key]) == p:
			g = int(game_key)
	if g >= 0 and g != p:
		get_viewport().set_input_as_handled()
		_send(g, k.pressed, k.echo)
		# Эта клавиша сама была действием, которое переехало: её нажатие не считается
		if map.has(p):
			_send(p, false, false)
		return
	if map.has(p) and int(map[p]) != p:
		get_viewport().set_input_as_handled()
		_send(p, false, false)


func _send(code: int, pressed: bool, echo: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	e.echo = echo
	e.set_meta("remapped", true)
	Input.parse_input_event(e)


## Какая клавиша сейчас делает действие game_key.
static func key_for(game_key: int) -> int:
	return int(SettingsManager.key_map.get(game_key, game_key))


static func key_name(code: int) -> String:
	match code:
		KEY_SPACE:
			return "Пробел"
		KEY_SHIFT:
			return "Shift"
	return OS.get_keycode_string(code)
