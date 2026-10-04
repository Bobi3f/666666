extends Node
## F5 — сохранить, F9 — загрузить.
##
## Клавиши ловятся в _input, раньше интерфейса, по физическому коду клавиши —
## так они работают при любой раскладке и даже если открыто меню.
## Важно: при запуске игры ВНУТРИ редактора Godot (вкладка «Игра») редактор
## может сам перехватывать F-клавиши. В отдельном окне и в собранной игре
## всё работает.
##
## Сохраняется всё, что лежит в группе "persist" и умеет save_state/load_state,
## плюс синглтоны с деньгами, временем, потребностями, погодой и целями.

## Три ячейки: первая — прежний файл, чтобы старые сохранения не пропали.
static func path_for(slot: int) -> String:
	return "user://save.json" if slot <= 1 else "user://save%d.json" % slot


var PATH: String:
	get:
		return path_for(SettingsManager.slot)
## Автосохранение раз в столько секунд настоящей игры (не паузы).
const AUTOSAVE_EVERY := 150.0

var _singletons := ["GameManager", "TimeManager", "NeedsManager", "WeatherManager", "Progress", "QuestManager", "Daily", "Achievements"]
var _since_save := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Каждые пару минут игры — тихое сохранение: на телефоне вкладку легко
## закрыть случайно, и день пропадёт.
func _process(delta: float) -> void:
	if not GameManager.in_game or get_tree().paused:
		return
	_since_save += delta
	if _since_save >= AUTOSAVE_EVERY:
		autosave()


## Свернули игру, ушли на другую вкладку, позвонили — сохраняем сразу.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			autosave()


## Сохранить без сообщения. Пока открыто главное меню при запуске, не
## сохраняем: иначе пустая новая игра затрёт настоящее сохранение.
func autosave() -> bool:
	_since_save = 0.0
	if not GameManager.in_game or not is_instance_valid(GameManager.player):
		return false
	return save_game(true)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F5:
			save_game()
			get_viewport().set_input_as_handled()
		KEY_F9:
			load_game()
			get_viewport().set_input_as_handled()


func save_game(quiet := false) -> bool:
	_since_save = 0.0
	var data := {}
	for n in _singletons:
		data[n] = get_node("/root/" + n).save_state()
	for node in get_tree().get_nodes_in_group("persist"):
		data[str(node.get_path())] = node.save_state()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		GameManager.notify("Не удалось сохранить: " + error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(data, "\t"))
	if not quiet:
		GameManager.notify("Игра сохранена (F9 — загрузить)")
	return true


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


## Что лежит в ячейке — для кнопок меню: «день 5, 3200 грн» или «пусто».
func slot_info(slot: int) -> String:
	var p := path_for(slot)
	if not FileAccess.file_exists(p):
		return "пусто"
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not parsed is Dictionary:
		return "повреждено"
	var d: Dictionary = parsed
	var day := int(d.get("TimeManager", {}).get("day", 1))
	var money := int(d.get("GameManager", {}).get("money", 0))
	return "день %d, %d грн" % [day, money]


func load_game() -> bool:
	if not has_save():
		GameManager.notify("Сохранений пока нет. F5 — сохранить")
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		GameManager.notify("Файл сохранения повреждён")
		return false
	var data: Dictionary = parsed
	for n in _singletons:
		# В старых сохранениях новых разделов нет — начинаем их с нуля
		get_node("/root/" + n).load_state(data.get(n, {}))
	for node in get_tree().get_nodes_in_group("persist"):
		var key := str(node.get_path())
		if data.has(key):
			node.load_state(data[key])
	GameManager.notify("Игра загружена")
	return true


# --- Помощники для сохранения векторов в JSON ----------------------------

static func vec_to_arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func arr_to_vec(a) -> Vector3:
	if a is Array and a.size() == 3:
		return Vector3(a[0], a[1], a[2])
	return Vector3.ZERO
