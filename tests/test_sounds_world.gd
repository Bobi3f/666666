extends SceneTree
## Разные звуки: у каждого мотоцикла и у грузовика, трактора, «Волги» свой
## мотор, у попуток тоже; голоса людей — смех, крики, гомон — в сёлах и
## в городе, где люди бывают, и в своё время.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await process_frame
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
## Насколько звук «звонкий»: доля быстрых перепадов в сигнале.
func bright(a: PackedFloat32Array) -> float:
	var d := 0.0
	var s := 0.0
	for i in range(1, a.size()):
		d += absf(a[i] - a[i - 1])
		s += absf(a[i])
	return d / maxf(s, 0.001)
func _run() -> void:
	await frames(10)
	var SL = root.get_node("SoundLibrary"); var TM = root.get_node("TimeManager"); var GM = root.get_node("GameManager")
	var WM = root.get_node("WeatherManager")

	print("== Мотоциклы")
	var bikes := {}
	for v in W.find_children("*", "Vehicle", true, false):
		if v.kind in ["moped", "moto", "izh"] and not bikes.has(v.kind): bikes[v.kind] = v
	var car: Vehicle = W.get_node("Car")
	ok(bikes.size() == 3, "в мире «Карпаты», «Ява» и ИЖ: %s" % [bikes.keys()])
	var seen := {}
	for k in bikes:
		var st: AudioStream = bikes[k]._engine_snd.stream
		ok(st != null and st == SL.stream("engine_" + k), "%s — свой мотор engine_%s" % [bikes[k].spec.title, k])
		seen[st] = true
	ok(seen.size() == 3, "у всех трёх звуки разные")
	ok(car._engine_snd.stream == SL.stream("engine"), "у «Жигулей» прежний мотор")
	var bm: float = bright(SL._engine_moped())
	var bj: float = bright(SL._engine_moto())
	var bi: float = bright(SL._engine_izh())
	ok(bm > bj and bj > bi, "звонкость: «Карпаты» %.3f > «Ява» %.3f > ИЖ %.3f" % [bm, bj, bi])
	var pitch := {}
	for k in bikes:
		var v: Vehicle = bikes[k]
		v.engine_on = true
		v.rpm = 3000.0
		v._update_sound()
		pitch[k] = v._engine_snd.pitch_scale
		v.engine_on = false
		v.rpm = 0.0
		v._update_sound()
	ok(pitch.moped > pitch.moto and pitch.moto > pitch.izh, "на 3000 об/мин: «Карпаты» %.2f выше «Явы» %.2f, ИЖ %.2f ниже" % [pitch.moped, pitch.moto, pitch.izh])

	print("== Машины")
	for v in W.find_children("*", "Vehicle", true, false):
		if v.kind in ["truck", "volga", "tractor", "bus"] and v._engine_snd:
			ok(v._engine_snd.stream == SL.stream(Vehicle.ENGINE_SOUND[v.kind]), "%s — %s" % [v.spec.title, Vehicle.ENGINE_SOUND[v.kind]])
	var tr = null
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("traffic.gd"): tr = c
	if tr:
		var kinds := {}
		for v in tr._vehicles:
			kinds[v.kind] = (v.snd as AudioStreamPlayer3D).stream
		for k in ["truck", "kamaz", "bus"]:
			if kinds.has(k):
				ok(kinds[k] == SL.stream("engine_diesel"), "попутка %s — дизель" % k)
		if kinds.has("zaz"):
			ok(kinds.zaz == SL.stream("engine_zaz"), "«Запорожец» тарахтит по-своему")
	for n in ["engine_moped", "engine_moto", "engine_izh", "engine_diesel", "engine_tractor", "engine_volga", "engine_zaz", "chatter"]:
		var w := SL.stream(n) as AudioStreamWAV
		ok(Assets.has_sound("effects/" + n) and (w == null or w.loop_mode != AudioStreamWAV.LOOP_DISABLED), "%s — файл, петлёй" % n)

	print("== Голоса")
	for n in ["laugh_man", "laugh_woman", "laugh_kid", "shout_hey", "shout_yahoo", "kids_play", "cheer", "auu"]:
		ok(Assets.has_sound("effects/" + n) and SL.stream(n) != null, "голос %s — запечён в файл" % n)
	# Женский смех выше мужского, детский — ещё выше и звонче
	ok(bright(SL._laugh(3, 300.0, 250.0, "а", 1.17, 0.09, 0.05, 0.05)) > bright(SL._laugh(3, 165.0, 120.0, "а", 1.0, 0.11, 0.06, 0.06)), "женский смех звонче мужского")
	var VO = W.get_node("Voices")
	var VS = VO.get_script()
	GM.in_game = true
	WM.set_kind(0, 9999.0)
	TM.minutes = 12 * 60.0
	var spots := {}
	for i in VS.SPOTS.size(): spots[VS.SPOTS[i].name] = i
	var here: Array = VO.audible(Vector3(-100, 0, -40))
	ok(here.has(spots["лавочки"]), "днём в Каменке у лавочек слышно людей")
	ok(not here.has(spots["рынок"]), "а городской рынок оттуда не слышно")
	VO.speak(spots["лавочки"])
	ok(VO.last.spot == "лавочки" and VO.last.sound.begins_with("laugh") and VO.last.pos.distance_to(Vector3(-95, 1.6, -36.5)) < 10.0, "засмеялись у лавочек: %s" % VO.last.sound)
	here = VO.audible(Town.w(Vector3(64, 0, 144)))
	ok(here.has(spots["рынок"]), "в городе на рынке — гомон и окрики")
	VO.speak(spots["рынок"])
	ok(VO.last.pos.x > 700.0, "голос с рынка — в городе")
	ok(VO.audible(Town.w(Vector3(160, 0, 160))).has(spots["стадион"]), "на стадионе болеют")
	ok(VO.audible(Vector3(124, 0, 112)).has(spots["роща"]), "в роще аукаются")
	TM.minutes = 3 * 60.0
	ok(not VO.audible(Vector3(-100, 0, -40)).has(spots["лавочки"]), "в 3 ночи у лавочек тихо")
	TM.minutes = 23 * 60.0
	ok(VO.audible(Vector3(-24, 0, -25)).has(spots["клуб «Каменка»"]), "в 11 вечера у клуба шумят")
	TM.minutes = 12 * 60.0
	WM.set_kind(3, 9999.0)
	WM.rain = 1.0
	ok(not VO.audible(Vector3(-100, 0, -40)).has(spots["лавочки"]), "в ливень на лавочках никого")
	WM.set_kind(0, 9999.0)
	WM.rain = 0.0
	# Гомон переезжает к ближнему месту с толпой
	var cam := Camera3D.new()
	W.add_child(cam)
	cam.make_current()
	cam.global_position = Vector3(-96, 1.7, -40)
	await create_timer(3.5).timeout
	ok(VO._crowd.playing and VO._crowd.volume_db > -20.0 and VO._crowd.global_position.distance_to(Vector3(-95, 1.6, -36.5)) < 1.0, "у лавочек гомон: %.0f дБ" % VO._crowd.volume_db)
	cam.global_position = Vector3(-600, 50, 300)
	await create_timer(3.5).timeout
	ok(VO._crowd.volume_db < -70.0, "вдали от людей гомона нет")

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
