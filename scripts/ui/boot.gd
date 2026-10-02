extends Node
## Запуск игры: экран загрузки, пока грузится и строится мир (World.tscn).
## Мир собирается кодом несколько секунд — без этого экрана на телефоне
## был бы просто чёрный экран. «Новая игра» из меню идёт сюда же.

const WORLD := "res://scenes/World.tscn"

## Загрузить сохранение сразу после постройки мира.
static var load_save := false

var screen: LoadingScreen
var _building := false


func _ready() -> void:
	screen = LoadingScreen.new()
	add_child(screen)
	screen.set_progress(0.05, "Загрузка…")
	if ResourceLoader.load_threaded_request(WORLD) != OK:
		_build(load(WORLD) as PackedScene)


func _process(_delta: float) -> void:
	if _building:
		return
	var prog := []
	var st := ResourceLoader.load_threaded_get_status(WORLD, prog)
	match st:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			screen.set_progress(0.05 + float(prog[0]) * 0.5)
		ResourceLoader.THREAD_LOAD_LOADED:
			_build(ResourceLoader.load_threaded_get(WORLD) as PackedScene)
		_:
			_build(load(WORLD) as PackedScene)


## Мир строится одним куском: сначала даём экрану отрисоваться.
func _build(scene: PackedScene) -> void:
	_building = true
	screen.set_progress(0.6, "Строим Каменку…")
	await get_tree().process_frame
	await get_tree().process_frame
	var world := scene.instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	if load_save:
		load_save = false
		SaveManager.load_game()
	screen.set_progress(1.0, "Готово")
	await get_tree().process_frame
	queue_free()
