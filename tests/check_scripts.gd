extends SceneTree
## Проверка всех скриптов проекта: каждый загружается и компилируется
## вместе с глобальными менеджерами (GameManager, TimeManager…), поэтому
## ложных «Identifier not found» нет. Ошибки — в журнал Godot (SCRIPT ERROR),
## итог — строка «ИТОГО». Запуск: godot --headless --path . --script tests/check_scripts.gd

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _walk(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_walk(dir.path_join(sub), out)


func _run() -> void:
	var files: Array[String] = []
	_walk("res://scripts", files)
	for f in files:
		var s := load(f) as GDScript
		if s == null or not s.can_instantiate():
			fails += 1
			print("  FAIL " + f)
	print("Проверено скриптов: %d" % files.size())
	print("ИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit(1 if fails > 0 else 0)
