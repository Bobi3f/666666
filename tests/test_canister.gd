extends SceneTree
## Канистра бензина: купить на АЗС (в Каменке и на трассе), залить в свою
## машину или мотоцикл из инвентаря где угодно, сохраняется.
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
func _run() -> void:
	await frames(10)
	var GM = root.get_node("GameManager"); var PR = root.get_node("Progress")
	var zones: Array = W.find_children("CanZone", "InteractZone", true, false)
	ok(zones.size() >= 2, "канистры продают на обеих АЗС: %d" % zones.size())
	ok(zones[0].text().contains("канистра бензина 10 л"), "у кассы: " + zones[0].text())
	GM.money = 2000
	PR.canister_l = 0.0
	var price: int = W.CAN_PRICE
	ok(W.buy_canister() and PR.canister_l == 10.0 and GM.money == 2000 - price, "купил канистру за %d грн: 10 л" % price)
	W.buy_canister(); W.buy_canister(); W.buy_canister()
	ok(PR.canister_l == 40.0 and not W.buy_canister(), "больше 40 л не увезти")
	var moped: Vehicle = W.get_node("Moped")
	moped.fuel = 1.0
	W.get_node("Player").global_position = moped.global_position + Vector3(1.5, 0, 0)
	await frames(2)
	var inv: InventoryPanel = W.get_node("Inventory")
	inv.open()
	await frames(2)
	var pour: Button
	for b in inv.find_children("*", "Button", true, false):
		if b.text == "Залить": pour = b
	ok(pour != null, "в инвентаре — «Залить»")
	if pour: pour.pressed.emit()
	await frames(2)
	ok(is_equal_approx(moped.fuel, moped.tank()) and is_equal_approx(PR.canister_l, 40.0 - (moped.tank() - 1.0)), "в мопед — сколько влезло: бак %d л, в канистрах %d л" % [int(moped.fuel), int(PR.canister_l)])
	ok(not PR.use_canister(moped), "полный бак — канистру не тратит")
	var st: Dictionary = PR.save_state()
	PR.load_state({})
	ok(PR.canister_l == 0.0, "старое сохранение — канистр нет")
	PR.load_state(st)
	ok(PR.canister_l > 30.0, "бензин в канистрах сохраняется")
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
