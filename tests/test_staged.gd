extends SceneTree
## Стройка мира кусками (браузер, телефон): между кусками — кадр, страница
## отвечает. Одним куском мир на среднем телефоне строился больше минуты —
## браузер считал страницу зависшей. Мир кусками — тот же, что целиком.
var fails := 0
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1


## Что должно совпасть у мира, построенного целиком и кусками.
func fingerprint(w: Node) -> Dictionary:
	var d := {}
	d["узлов"] = w.find_children("*", "", true, false).size()
	d["зон действия"] = w.find_children("*", "InteractZone", true, false).size()
	d["кусков округи"] = w.get_node("Region/RegionMesh").get_child_count()
	d["кусков Каменки"] = w.get_node("WorldMesh").get_child_count()
	d["растительность"] = str(w.get_node("Vegetation").counts)
	return d


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Запуск: собираются только нужные скрипты, мир — потом по одному")
	var startup := 0
	for f in all_scripts("res://scripts"):
		if ResourceLoader.has_cached(f): startup += 1
	ok(startup < 25, "при запуске собрано скриптов: %d (было 65 — вся округа, машины, переводы)" % startup)
	var later := ["res://scripts/vehicles/vehicle.gd", "res://scripts/world/region.gd", "res://scripts/player/player.gd"]
	# Словарь перевода грузится только для выбранного языка
	for code in ["en", "uk"]:
		if root.get_node("SettingsManager").lang != code:
			later.append("res://scripts/core/lang_%s.gd" % code)
	for f in later:
		ok(not ResourceLoader.has_cached(f), "%s — не при запуске" % f.get_file())
	var order: Array = load("res://scripts/core/script_order.gd").PATHS
	var missing := []
	for f in all_scripts("res://scripts"):
		if f != "res://scripts/core/script_order.gd" and not order.has(f): missing.append(f.get_file())
	ok(missing.is_empty(), "порядок сборки знает все скрипты (иначе: python3 tools/script_order.py) %s" % str(missing))
	var pieces := [0]
	var longest := 0
	var t := Time.get_ticks_msec()
	var t_all := t
	var BootScript = load("res://scripts/ui/boot.gd")
	var done := [false]
	(func() -> void:
		await BootScript.compile_scripts(self, func(_p: float) -> void: pieces[0] += 1)
		done[0] = true).call()
	while not done[0]:
		await process_frame
		longest = maxi(longest, Time.get_ticks_msec() - t)
		t = Time.get_ticks_msec()
	var total := Time.get_ticks_msec() - t_all
	print("  скрипты собраны за %d кадров (%d мс), самый долгий: %d мс" % [pieces[0], total, longest])
	# Кусок — около 0,15 с (boot.gd). Число кусков зависит от скорости машины,
	# поэтому мерим средний кусок: не дольше 0,4 с — значит, не одним махом
	ok(pieces[0] >= maxi(5, total / 400), "по кусочку за кадр: %d кусков, в среднем %d мс" % [pieces[0], total / maxi(pieces[0], 1)])
	# Доля, а не миллисекунды: машина то быстрее, то медленнее
	ok(longest < total * 0.3, "ни один кусок не дольше 30%% всей сборки скриптов")
	ok(ResourceLoader.has_cached("res://scripts/world/world.gd"), "к концу собран и мир")

	print("== Кусками, как в браузере")
	var W = load("res://scenes/World.tscn").instantiate()
	W.staged = true
	var parts: Array[float] = []
	W.build_progress.connect(func(p: float) -> void: parts.append(p))
	t = Time.get_ticks_msec()
	t_all = t
	root.add_child(W)
	ok(not W.is_built, "после add_child ещё строится")
	ok(paused, "пока строится — пауза: часы, машины и автосохранение стоят")
	ok(root.disable_3d, "и 3D не рисуется")
	var frames := 0
	longest = Time.get_ticks_msec() - t
	t = Time.get_ticks_msec()
	while not W.is_built and frames < 2000:
		await process_frame
		longest = maxi(longest, Time.get_ticks_msec() - t)
		t = Time.get_ticks_msec()
		frames += 1
	ok(W.is_built, "достроился за %d кадров" % frames)
	ok(frames >= 15, "кусками, не разом")
	total = Time.get_ticks_msec() - t_all
	print("  мир построен за %d мс, самый долгий кусок: %d мс" % [total, longest])
	ok(longest < total * 0.15, "ни один кусок не дольше 15%% всей стройки (одним куском было 100%%)")
	ok(parts.size() >= 15 and parts[-1] > 0.9, "полоска загрузки двигалась: %d шагов" % parts.size())
	var sorted := parts.duplicate()
	sorted.sort()
	ok(sorted == parts, "и только вперёд")
	ok(paused, "меню при запуске само поставило паузу")
	ok(not root.disable_3d, "3D снова рисуется")
	# Отложенные вызовы (интерьеры) — к следующему кадру, в обоих случаях
	await process_frame
	var staged := fingerprint(W)

	print("== Прогрев шейдеров по частям")
	var cam: Camera3D = W.get_viewport().get_camera_3d()
	var mask := cam.cull_mask
	var scale3d: float = W.get_viewport().scaling_3d_scale
	var steps: Array[float] = []
	var n: int = await ShaderWarmup.run(W, 2, 4, func(p: float) -> void: steps.append(p))
	ok(n > 10, "прогрето материалов: %d" % n)
	ok(steps.size() >= 3, "по частям: %d кадров" % steps.size())
	ok(steps.size() < (n - 1) / 4, "кадры быстрые — пачки растут (по 4 было бы %d кадров)" % ((n - 1) / 4))
	ok(cam.cull_mask == mask, "камера снова видит весь мир")
	ok(is_equal_approx(W.get_viewport().scaling_3d_scale, scale3d), "и в прежней чёткости")
	await process_frame
	ok(W.find_child("ShaderWarmup", true, false) == null, "квадратики убраны")
	ok(boot_in_steps() == false, "в тестах на компьютере — целиком")
	W.free()
	for i in 3: await process_frame

	print("== Целиком, как в тестах и на компьютере — тот же мир")
	paused = false
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	ok(W.is_built, "достроен сразу после add_child")
	await process_frame
	var whole := fingerprint(W)
	for k in whole:
		ok(whole[k] == staged[k], "%s совпадает: %s" % [k, str(staged[k])])

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()


func boot_in_steps() -> bool:
	return load("res://scripts/ui/boot.gd").in_steps()


func all_scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for sub in DirAccess.get_directories_at(dir): out.append_array(all_scripts(dir + "/" + sub))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"): out.append(dir + "/" + f)
	return out
