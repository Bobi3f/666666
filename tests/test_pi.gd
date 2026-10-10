extends SceneTree
## Оплата Pi Network: монеты начисляются по номеру пакета, один платёж — один
## раз, отмена и чужие пакеты не начисляют; цены в π одинаковы в игре, в
## docs/pi.js и на сервере; вне Pi Browser окно — как раньше.
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
## Пакеты [цена, монет] из JS-файла: строка «PI_PACKS = [[0.5, 100], …];»
func packs_in(path: String) -> Array:
	var f := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	if f == null: return []
	var t := f.get_as_text()
	var re := RegEx.new()
	re.compile("PI_PACKS = (\\[\\[.*?\\]\\]);")
	var m := re.search(t)
	return JSON.parse_string(m.get_string(1)) if m else []
func _run() -> void:
	await frames(10)
	var PR = root.get_node("Progress")
	var shop: GearShop = W.get_node("GearShop")
	print("== Цены везде одинаковые")
	for path in ["res://docs/pi.js", "res://server/cloudflare/functions/api/pi/[[route]].js"]:
		var p: Array = packs_in(path)
		var same := p.size() == GearShop.PACKS.size()
		for i in p.size():
			same = same and is_equal_approx(float(p[i][0]), GearShop.PI_PRICES[i]) and int(p[i][1]) == int(GearShop.PACKS[i][0])
		ok(same, "%s: %s" % [path.get_file(), p])
	ok(GearShop.pi_price_text(0) == "0.5 π" and GearShop.pi_price_text(5) == "35 π", "цена текстом: %s, %s" % [GearShop.pi_price_text(0), GearShop.pi_price_text(5)])

	print("== Начисление")
	PR.gearcoins = 0
	PR.pi_paid = []
	shop.open()
	await frames(2)
	var got := shop.apply_pi([{"id": "pay_abc123", "pack": 2, "coins": 1200, "ok": true}])
	ok(got == 1200 and PR.gearcoins == 1200 and PR.pi_paid.has("pay_abc123"), "оплатил пакет 3: +1 200 GEARCOIN")
	ok(shop.apply_pi([{"id": "pay_abc123", "pack": 2, "ok": true}]) == 0 and PR.gearcoins == 1200, "тот же платёж второй раз — не начисляется")
	ok(shop.apply_pi([{"id": "pay_x", "pack": 9, "ok": true}, {"id": "pay_y", "pack": 1}]) == 0, "чужой пакет и незавершённый — не начисляются")
	shop.apply_pi([{"cancel": true}])
	ok(shop._status.text == "Оплата отменена" and PR.gearcoins == 1200, "отмена — без монет")
	var st: Dictionary = PR.save_state()
	PR.pi_paid = []
	PR.load_state(st)
	ok(PR.pi_paid.has("pay_abc123"), "засчитанные платежи сохраняются")

	print("== Вне Pi Browser")
	ok(GearShop.pi_status().is_empty(), "не браузер — оплаты Pi нет")
	ok(not shop.buy_pi(0), "кнопка Pi не срабатывает")
	shop.close_panel()
	PR.gearcoins = 0
	PR.pi_paid = []

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit(1 if fails else 0)
