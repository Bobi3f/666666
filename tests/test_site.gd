extends SceneTree
## Страница игры на сайте (docs/index.html). На iPhone вместо игры был
## чёрный экран без единого слова: заставка сама уходила через 25 с тишины,
## и что случилось — не узнать. Теперь заставка уходит только по «игра
## готова», замолчавшая игра даёт кнопку перезапуска, журнал хранит проценты
## и память, а картинка на телефоне — не плотнее ×2.
var fails := 0
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1


func _initialize() -> void:
	var html := FileAccess.get_file_as_string("res://docs/index.html")
	ok(html.length() > 10000, "страница прочитана")

	print("== Заставка уходит только когда игра готова")
	ok(html.count("hideCover()") == 2, "hideCover — объявление и один вызов: %d" % html.count("hideCover()"))
	var ready_at := html.find("FG_DIAG.onready = function")
	ok(ready_at > 0 and html.find("hideCover()", ready_at) - ready_at < 120, "этот вызов — в onready")
	ok(not html.contains("if (!heard) hideCover()"), "по тишине заставка больше не прячется")
	ok(html.contains("const SILENCE = 60;") and html.contains("action = \"lite\";"), "минута тишины — «Перезапустить облегчённо»")
	ok(html.contains("if (document.hidden) { heardAt = Date.now(); return; }"), "пока страница свёрнута, тишина не считается")
	ok(not html.contains("play.onclick"), "у кнопки один обработчик (раньше второй запускал игру повторно)")
	ok(html.contains("if (cover.hidden || failed) return;"), "ошибку на заставке не затирают тикающие секунды")

	print("== Журнал для разработчика")
	var pct_at := html.find("const pct = /^FIRST GEAR: (\\d+)%$/.exec(s);")
	ok(pct_at > 0 and html.find("d.progress(+pct[1]);", pct_at) - pct_at < 120, "последний процент — в журнал")
	ok(html.contains("d.engine.rtenv.HEAP8") and html.contains("FG_DIAG.engine = engine;"), "в журнале — память игры")
	ok(html.contains("страницу свернули"), "в журнале — свернули ли страницу во время загрузки")
	ok(html.contains("localStorage.setItem(\"fg_boot\", \"ready\")") and html.contains("if ((crashed || brief) && FG_DIAG.prev) diag.open = true;"),
		"закрыли меньше чем через полминуты после «готова» — в следующий раз журнал открыт")
	ok(not html.contains("lite = crashed || brief"), "но облегчённый запуск — только если загрузка оборвалась")

	print("== Телефон: картинка не плотнее ×2")
	var dpr_at := html.find("d.dpr > 2 && matchMedia(\"(pointer: coarse)\").matches")
	ok(dpr_at > 0 and html.find("get: function () { return 2; }", dpr_at) > dpr_at, "×3 на телефоне становится ×2, компьютер — как был")
	ok(dpr_at < html.find("<script src=\"index.js\">"), "и до того, как движок загрузился")

	print("== iPhone после неудачного запуска")
	ok(html.contains("(IOS ? L(\"На iPhone откройте игру в самом Safari"), "совет открыть в самом Safari вместо APK")

	print("== Архив для itch.io по-прежнему собирается")
	for s in ["<script src=\"pi.js\"></script>", "Версия для Windows — <a ", "const a = document.querySelector(\".note a\").outerHTML;",
			"Windows version — \" + a + \".\";", "const ua = document.querySelector(\".note a\").outerHTML;",
			"Версія для Windows — \" + ua + \".\";", "const apk = \"https://github.com/"]:
		ok(html.contains(s), "tools/build_itch.sh находит: %s" % s.left(40))

	# Синтаксис скриптов страницы — если на машине есть node
	var node := OS.execute("node", ["--version"], []) == 0
	if node:
		var rx := RegEx.create_from_string("(?s)<script>(.*?)</script>")
		var bad := 0
		var n := 0
		for m in rx.search_all(html):
			var path := OS.get_cache_dir().path_join("fg_site_%d.js" % n)
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(m.get_string(1))
			f.close()
			var out := []
			if OS.execute("node", ["--check", path], out, true) != 0:
				bad += 1
				print(out)
			n += 1
		ok(n >= 4 and bad == 0, "скрипты страницы без ошибок синтаксиса: %d" % n)
	else:
		print("  (node нет — синтаксис не проверен)")

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
