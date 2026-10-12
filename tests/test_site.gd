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


## [начало, максимум] памяти движка в МБ — из раздела памяти wasm (id 5).
func memory_mb(b: PackedByteArray) -> Array:
	if b.size() < 8 or b[0] != 0 or b[1] != 0x61:
		return []
	var i := 8
	while i < b.size():
		var sid := b[i]
		var r := leb(b, i + 1)
		if sid == 5:
			var k: int = leb(b, r[1])[1]
			var flags := b[k]
			var mn := leb(b, k + 1)
			var mx: Array = leb(b, mn[1]) if flags & 1 else [0, 0]
			return [mn[0] * 65536 / 1048576, mx[0] * 65536 / 1048576]
		i = r[1] + r[0]
	return []


## Число LEB128 и место после него.
func leb(b: PackedByteArray, i: int) -> Array:
	var v := 0
	var s := 0
	while true:
		var x := b[i]
		i += 1
		v |= (x & 0x7f) << s
		s += 7
		if x < 0x80:
			break
	return [v, i]


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

	print("== iPhone: память игры — одним куском в начале")
	# Ступени роста памяти (46 → 55 → … → 238 МБ) iOS не прощает: закрывает
	# страницу («Повторення проблеми на сайті»)
	ok(html.contains("const go = IOS ? engine.init(\"index\").then(function () {\n        reserveHeap();"), "на iPhone: движок → запас памяти → мир")
	ok(html.contains("for (const mb of [272, 240, 208])") and html.contains("m._free(ptr);"), "запас ~280 МБ (игре нужно ~230) берётся и сразу отдаётся игре, не дали — пробуем меньше")
	ok(html.contains("onProgress: progress,") and not html.contains("engine.startGame({\n        onProgress"), "полоска скачивания — с самого начала и на iPhone")
	ok(html.contains(": engine.startGame();"), "остальные браузеры — как раньше")

	print("== iPhone: свой движок, память с самого запуска")
	ok(html.contains("const pick = ios ? gz(\"engine-ios.gz.wasm\").catch(function () { return gz(\"engine.gz.wasm\"); }) : gz(\"engine.gz.wasm\");"),
		"на iPhone — engine-ios.gz.wasm, нет его — обычный")
	ok(html.contains("if (m.HEAP8.length >= 256 * 1048576)"), "с таким движком запас не берётся — память уже есть")
	var ios_gz := FileAccess.get_file_as_bytes("res://docs/engine-ios.gz.wasm")
	var plain := FileAccess.get_file_as_bytes("res://docs/index.wasm")
	var ios_wasm := ios_gz.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP) if ios_gz.size() > 0 else PackedByteArray()
	ok(ios_wasm.size() == plain.size() and ios_wasm.size() > 1000000, "движок для iPhone того же размера, что обычный: %d" % ios_wasm.size())
	ok(memory_mb(plain) == [32, 2048], "обычный движок: память с 32 МБ, до 2 ГБ: %s" % str(memory_mb(plain)))
	ok(memory_mb(ios_wasm) == [288, 2048], "для iPhone — с 288 МБ сразу (игре нужно ~230): %s" % str(memory_mb(ios_wasm)))
	var diff := 0
	for i in mini(plain.size(), ios_wasm.size()):
		if plain[i] != ios_wasm[i]:
			diff += 1
			if diff > 4: break
	ok(diff > 0 and diff <= 4, "отличается только размер памяти: байт %d" % diff)
	var build := FileAccess.get_file_as_string("res://tools/build_release.sh")
	ok(build.contains("tools/wasm_memory.py\" build/web/index.wasm build/web/engine-ios.wasm 288") and build.contains("docs/engine-ios.gz.wasm"), "сборка делает его заново из каждого движка")
	ok(FileAccess.get_file_as_string("res://tools/build_itch.sh").contains("docs/engine-ios.gz.wasm"), "и кладёт в архив itch.io")

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
