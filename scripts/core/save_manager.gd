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
## плюс синглтоны с деньгами, временем и потребностями.

const PATH := "user://save.json"

var _singletons := ["GameManager", "TimeManager", "NeedsManager"]


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


func save_game() -> bool:
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
	GameManager.notify("Игра сохранена (F9 — загрузить)")
	return true


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


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
		if data.has(n):
			get_node("/root/" + n).load_state(data[n])
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
