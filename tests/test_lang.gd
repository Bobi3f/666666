extends SceneTree
## Два языка: по умолчанию русский, в меню — «English». Перевод «на лету»:
## надписи, подсказки, сообщения со вставками (имена, числа), многострочные
## тексты журнала. Переключение — сразу, обратно — снова русский.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await process_frame
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	current_scene = W
	_run.call_deferred()
func _run() -> void:
	await frames(5)
	var SM = root.get_node("SettingsManager"); var GM = root.get_node("GameManager")
	var TS = TranslationServer
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var lang0: String = SM.lang

	print("== По умолчанию — русский")
	ok(SM.lang == "ru" and TS.get_locale().begins_with("ru"), "язык: " + SM.lang)
	ok(TS.translate("Новая игра") == "Новая игра", "русский не трогаем")

	print("== English")
	SM.set_lang("en")
	ok(TS.get_locale() == "en", "локаль en")
	var t := func(s: String) -> String: return String(TS.translate(s))
	ok(t.call("Новая игра") == "New game", "точная строка: " + t.call("Новая игра"))
	ok(t.call("Купил %s — привезут домой, будет %s" % ["телевизор «Рубин»", "в комнате"]) == "Bought a \"Rubin\" TV — it'll be delivered home, it'll be in the room",
		"шаблон со вставками: " + t.call("Купил %s — привезут домой, будет %s" % ["телевизор «Рубин»", "в комнате"]))
	ok(t.call("Оля: «%s»" % "Пойдём! Куда сегодня?") == "Olya: \"Let's go! Where to today?\"", "реплика Оли: " + t.call("Оля: «%s»" % "Пойдём! Куда сегодня?"))
	ok(t.call("E — поговорить: %s%s" % ["Баба Галя", "  (!)"]) == "E — talk: Baba Galya  (!)", "подсказка жителя: " + t.call("E — поговорить: %s%s" % ["Баба Галя", "  (!)"]))
	ok(t.call("День %d (%s), %02d:%02d" % [3, "ср", 9, 5]) == "Day 3 (Wed), 09:05", "часы: " + t.call("День %d (%s), %02d:%02d" % [3, "ср", 9, 5]))
	var multi: String = t.call("  Путь: мопед «Карпаты» → работы → паспорт и медсправка → права → первая машина\n  Пить — колонка на деревенской улице (бесплатно) или вода в сельмаге\n")
	ok(multi.begins_with("  Path:") and multi.contains("\n  Drink") and multi.ends_with("\n"), "многострочный текст по строкам, отступы на месте")
	var tip: String = t.call("Жду: %s" % "Отдай деду Михалычу 3 еды из запаса".to_lower())
	ok(tip == "Waiting: give Grandpa Mikhalych 3 food from your supplies", "кусок после to_lower: " + tip)
	ok(t.call("1: день 3, 1500 грн") == "1: day 3, 1500 UAH", "склеенное из кусков: " + t.call("1: день 3, 1500 грн"))
	ok(t.call("Hello") == "Hello", "английское не трогаем")
	var line: String = t.call("» Первое утро: Позавтракай — съешь что-нибудь из запаса (Q)")
	ok(line == "» First Morning: Have breakfast — eat something from your supplies (Q)", "строка задания: " + line)
	var jl: String = t.call("[b]» Первое утро[/b]\n[color=#9a9a9a]· Старый мопед[/color]")
	ok(jl == "[b]» First Morning[/b]\n[color=#9a9a9a]· The Old Moped[/color]", "журнал в тегах: " + jl)
	var cnt: String = t.call("• Ударник труда: Отработай 2 смены в колхозе — 1 / 2")
	ok(cnt == "• Shock Worker: Work 2 shifts at the kolkhoz — 1 / 2", "задание со счётчиком: " + cnt)

	print("== На экране")
	var hud = child("hud.gd")
	GM.notify("Звонок — %s: «%s». Награда %d грн" % ["Баба Галя", "Поймай к ужину три рыбки — на уху", 250])
	await frames(3)
	var shown := ""
	var msg: Label = hud._msg
	for m in [msg.text] + hud._queue:
		if String(m).begins_with("Звонок"):
			shown = msg.tr(m)
	ok(shown == "Phone call — Baba Galya: \"Catch three little fish for dinner — for fish soup\". Reward 250 UAH", "сообщение на экране: " + shown)
	ok(SM.t("Каменка") == "Kamenka", "надпись на карте: " + SM.t("Каменка"))

	print("== Весь словарь переводится")
	var D = load("res://scripts/core/lang_en.gd")
	var miss := 0
	for ru in D.EN:
		if not String(ru).contains("%") and t.call(ru) == ru and D.EN[ru] != ru:
			miss += 1
			print("    не переведено: ", ru)
	ok(miss == 0, "непереведённых точных строк: %d" % miss)
	var t0 := Time.get_ticks_usec()
	for i in 200:
		t.call("Задание выполнено: «%s» %s" % ["Уха для бабы Гали", "+%d грн" % i])
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	ok(ms < 400.0, "200 новых сообщений переводятся за %.0f мс" % ms)

	print("== Сохраняется и переключается обратно")
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	ok(cfg.get_value("ui", "lang", "") == "en", "язык записан в настройки")
	SM.set_lang("ru")
	ok(t.call("Новая игра") == "Новая игра" and SM.t("Каменка") == "Каменка", "обратно на русский")
	SM.set_lang(lang0)

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
