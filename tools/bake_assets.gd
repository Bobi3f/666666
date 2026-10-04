extends SceneTree
## Готовит файлы текстур (textures/) и звуков (sounds/) тем же кодом, что
## раньше рисовал и синтезировал их прямо в игре. Запуск из корня проекта:
##   godot --headless --path . --script tools/bake_assets.gd
## потом tools/import_assets.sh — настройки импорта (мипмапы, петли, сжатие).
## Свои картинки и звуки можно положить в те же папки под теми же именами.

var made := 0


func _initialize() -> void:
	_run.call_deferred()


func _dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _png(name: String, img: Image) -> void:
	var path := "res://textures/" + name + ".png"
	_dir(path.get_base_dir())
	img.clear_mipmaps()
	img.save_png(path)
	made += 1
	print("  ", path)


func _wav(name: String, s: AudioStreamWAV) -> void:
	var path := "res://sounds/" + name + ".wav"
	_dir(path.get_base_dir())
	s.save_to_wav(path)
	made += 1
	print("  ", path, "  петля" if s.loop_mode != AudioStreamWAV.LOOP_DISABLED else "")


func _run() -> void:
	print("== Текстуры")
	var HI := load("res://scripts/world/house_interior.gd")
	var done := {}
	for w in 3:
		var h: Node3D = HI.new()
		for t in h.texture_makers(w):
			if not done.has(t[0]):
				done[t[0]] = true
				_png("interior/" + t[0], t[1].call())
		h.free()
	# Классы — через load(): при разборе этого файла автозагрузок ещё нет
	_png("world/grain", load("res://scripts/core/mesh_builder.gd").grain_image())
	var NS := load("res://scripts/world/night_sky.gd")
	_png("sky/clouds", NS.cloud_image())
	_png("sky/moon", NS.moon_image())
	var VH := load("res://scripts/vehicles/vehicle.gd")
	_png("vehicles/dust", VH.puff_image())
	_png("vehicles/dial", VH.dial_image())

	print("== Звуки")
	var SL = root.get_node("SoundLibrary")
	for n in SL._makers:
		_wav("effects/" + n, SL._makers[n].call())
	_wav("music/music", SL.render_music_now())
	_wav("music/disco", load("res://scripts/world/club.gd").make_disco_loop())
	var radio: Node = load("res://scripts/world/radio.gd").new()
	root.add_child(radio)
	for i in radio.STATIONS.size():
		_wav("music/radio_%d" % i, radio.render_now(i))
	radio.queue_free()
	print("Готово: %d файлов" % made)
	quit()
