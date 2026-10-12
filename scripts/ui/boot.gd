extends Node
## Запуск игры: экран загрузки, пока строится мир (World.tscn). Мир
## собирается кодом несколько секунд — без этого экрана был бы просто
## чёрный экран. «Новая игра» из меню идёт сюда же.
##
## Грузим в основном потоке, без фоновых: загрузка сцены со скриптами
## в другом потоке на компьютерах — лишний риск вылета.

const WORLD := "res://scenes/World.tscn"
## Порядок сборки скриптов: от зависимостей к тем, кто их использует.
const ORDER := "res://scripts/core/script_order.gd"

## Загрузить сохранение сразу после постройки мира.
static var load_save := false

var screen: LoadingScreen
## Последний процент, что ушёл в консоль браузера.
var _printed := -100


func _ready() -> void:
	screen = LoadingScreen.new()
	add_child(screen)
	screen.set_progress(0.1, "Загрузка…")
	_build.call_deferred()


## Сначала даём экрану загрузки отрисоваться, потом строим мир. В браузере
## и на телефоне — кусками, с кадром между ними (world.gd → breathe):
## одним куском страница минуту не отвечала, и браузер предлагал её закрыть.
func _build() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var staged := in_steps()
	# «FIRST GEAR: …» — этапы для «Сведений для разработчика» на странице игры:
	# если телефон не дотянул, видно, на чём остановился
	var t := Time.get_ticks_msec()
	if staged:
		print("FIRST GEAR: собираю скрипты")
		await compile_scripts(get_tree(), func(p: float) -> void: _progress(0.05 + 0.25 * p))
		print("FIRST GEAR: скрипты собраны за %.1f с" % _since(t))
	var scene := load(WORLD) as PackedScene
	_progress(0.3, "Строим Каменку…")
	await get_tree().process_frame
	await get_tree().process_frame
	var world := scene.instantiate()
	world.staged = staged
	world.build_progress.connect(func(p: float) -> void: _progress(0.3 + 0.55 * p))
	print("FIRST GEAR: строю мир")
	t = Time.get_ticks_msec()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	if not world.is_built:
		await world.built
	print("FIRST GEAR: мир построен за %.1f с" % _since(t))
	if load_save:
		load_save = false
		SaveManager.load_game()
	# Шейдеры — пока закрыто экраном загрузки, иначе игра подвисает в пути
	_progress(0.85, "Готовим картинку…")
	t = Time.get_ticks_msec()
	var mats: int = await ShaderWarmup.run(world, 2, 4 if staged else 0, func(p: float) -> void: _progress(0.85 + 0.15 * p))
	print("FIRST GEAR: картинка готова за %.1f с (%d материалов)" % [_since(t), mats])
	_progress(1.0, "Готово")
	print("FIRST GEAR: игра готова, запуск занял %.1f с" % _since(0))
	await get_tree().process_frame
	queue_free()


## Полоска экрана загрузки. В браузере ещё и «FIRST GEAR: 37%» в консоль:
## страница игры держит свою заставку с процентами, пока игра не готова, —
## даже если телефон почему-то не рисует картинку игры, видно, что идёт.
func _progress(v: float, text := "") -> void:
	screen.set_progress(v, text)
	var pct := int(v * 100.0)
	if OS.has_feature("web") and pct >= _printed + 2:
		_printed = pct
		print("FIRST GEAR: %d%%" % pct)


## Строить мир кусками: в браузере и на телефоне (или с --staged для проверки).
static func in_steps() -> bool:
	return OS.has_feature("web") or OS.has_feature("mobile") or "--staged" in OS.get_cmdline_user_args()


## Собрать скрипты игры по одному, с кадром между ними: сборка всех разом
## (загрузка World.tscn) замораживала страницу в браузере на десятки секунд.
## Порядок — от зависимостей (tools/script_order.py), поэтому каждый скрипт
## собирается сам, а не тянет за собой полмира. on_part(доля) — для полоски.
static func compile_scripts(tree: SceneTree, on_part := Callable()) -> void:
	var paths: Array = (load(ORDER) as Script).get_script_constant_map()["PATHS"]
	var t := Time.get_ticks_msec()
	for i in paths.size():
		if ResourceLoader.exists(paths[i]):
			load(paths[i])
		# Кусок — до 0,15 с: каждый кадр между ними тоже стоит времени
		if Time.get_ticks_msec() - t > 150:
			if on_part.is_valid():
				on_part.call(float(i + 1) / paths.size())
			await tree.process_frame
			t = Time.get_ticks_msec()


## Секунд прошло с отметки Time.get_ticks_msec().
static func _since(t: int) -> float:
	return (Time.get_ticks_msec() - t) / 1000.0
