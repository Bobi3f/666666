extends Node
## Запуск игры: экран загрузки, пока строится мир (World.tscn). Мир
## собирается кодом несколько секунд — без этого экрана был бы просто
## чёрный экран. «Новая игра» из меню идёт сюда же.
##
## Грузим в основном потоке, без фоновых: загрузка сцены со скриптами
## в другом потоке на компьютерах — лишний риск вылета.

const WORLD := "res://scenes/World.tscn"

## Загрузить сохранение сразу после постройки мира.
static var load_save := false

var screen: LoadingScreen


func _ready() -> void:
	screen = LoadingScreen.new()
	add_child(screen)
	screen.set_progress(0.1, "Загрузка…")
	_build.call_deferred()


## Сначала даём экрану загрузки отрисоваться, потом строим мир одним куском.
func _build() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := load(WORLD) as PackedScene
	screen.set_progress(0.5, "Строим Каменку…")
	await get_tree().process_frame
	await get_tree().process_frame
	var world := scene.instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	if load_save:
		load_save = false
		SaveManager.load_game()
	# Шейдеры — пока закрыто экраном загрузки, иначе игра подвисает в пути
	screen.set_progress(0.9, "Готовим картинку…")
	await ShaderWarmup.run(world)
	screen.set_progress(1.0, "Готово")
	await get_tree().process_frame
	queue_free()
