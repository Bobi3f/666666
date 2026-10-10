class_name JunkPanel
extends MarketPanel
## Дядя Гриша на свалке: скупает машины и мотоциклы на лом и продаёт б/у
## запчасти, снятые со старых машин. Б/у узел вдвое с лишним дешевле нового
## на СТО, но не новый — ресурс 70%. Проданная техника возвращается туда,
## где её продавали, — можно купить снова. Окно — как у СТО (StoPanel).

## Б/у узел: доля цены нового и ресурс после замены, %.
const USED_K := 0.4
const USED_HEALTH := 70.0
## За технику — половина цены, за износ — меньше (до четверти цены).
const SELL_K := 0.5
const WORK_MIN := 30.0


func open(_m: String, vehicles: Array = []) -> void:
	mode = "junk"
	_vehicles = vehicles
	visible = true
	get_tree().paused = true
	_status.text = ""
	_title.text = "Свалка — приём лома и запчасти б/у"
	_cars_label.visible = true
	_cars_box.visible = true
	for c in _cars_box.get_children():
		c.queue_free()
	for car in vehicles:
		var b := _button(car.spec.title, Color(0.3, 0.26, 0.2))
		b.pressed.connect(select.bind(car))
		_cars_box.add_child(b)
	select(vehicles[0] if not vehicles.is_empty() else null)


func select(car: Vehicle) -> void:
	_car = car
	if car == null:
		_status.text = "Загони свою машину или мотоцикл за ворота свалки"
	_refresh()


func _refresh() -> void:
	for c in _goods.get_children():
		c.queue_free()
	if _car == null:
		return
	# Продать на лом
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_goods.add_child(row)
	var sb := _button("Продать за %d грн" % sell_price(_car), Color(0.6, 0.2, 0.15))
	sb.custom_minimum_size.x = 220
	sb.disabled = not can_sell(_car)
	sb.pressed.connect(sell)
	row.add_child(sb)
	var why := "Гриша: «%s? Возьму, в каком есть»" % _car.spec.title if can_sell(_car) else "Гриша: «Мопед себе оставь — на нём полсела ездит»"
	var wl := _label(why, 16, Color(0.95, 0.92, 0.85))
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(wl)
	# Б/у узлы
	_goods.add_child(_label("Запчасти б/у — со старых машин, ресурс %d%%:" % int(USED_HEALTH), 18, Color.WHITE))
	for n in Vehicle.WEAR:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		_goods.add_child(r)
		var h: float = _car.part_health(n)
		var ok := h < USED_HEALTH
		var b := _button("%d грн" % used_price(_car, n) if ok else "Не нужно", Color(0.28, 0.45, 0.25) if ok else Color(0.25, 0.25, 0.25))
		b.custom_minimum_size.x = 120
		b.disabled = not ok
		b.pressed.connect(fit_used.bind(n))
		r.add_child(b)
		var col := Color(0.95, 0.92, 0.85) if h >= 50.0 else (Color(1.0, 0.8, 0.4) if h >= 25.0 else Color(1.0, 0.5, 0.4))
		var l := _label("%s — сейчас %d%%" % [Vehicle.WEAR[n][0], int(h)], 16, col)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)


## Мопед не берут: он у игрока с самого начала и нужен в пути.
static func can_sell(car: Vehicle) -> bool:
	return car != null and car.price > 0 and Progress.owns(car.kind)


## Цена за технику: половина цены, за износ узлов и кузова — меньше.
static func sell_price(car: Vehicle) -> int:
	var wear := car.condition / 100.0
	for n in Vehicle.WEAR:
		wear += car.part_health(n) / 100.0
	wear /= float(Vehicle.WEAR.size() + 1)
	return int(round(car.price * SELL_K * lerpf(0.5, 1.0, wear) / 10.0)) * 10


static func used_price(car: Vehicle, n: String) -> int:
	return maxi(int(round(car.part_price(n) * USED_K / 10.0)) * 10, 10)


## Продать выбранную технику. true — получилось.
func sell() -> bool:
	if not can_sell(_car):
		return false
	var car := _car
	var money := sell_price(car)
	car.sell_back()
	GameManager.add_money(money)
	SoundLibrary.play("cash")
	QuestManager.event("vehicle_sold")
	GameManager.notify("Свалка: «%s» продана за %d грн" % [car.spec.title, money])
	_vehicles.erase(car)
	_status.text = "«%s» больше не твоя: +%d грн" % [car.spec.title, money]
	for c in _cars_box.get_children():
		if (c as Button).text == car.spec.title:
			c.queue_free()
	_car = null
	_refresh()
	return true


## Поставить б/у узел n. true — получилось.
func fit_used(n: String) -> bool:
	if _car == null or not Vehicle.WEAR.has(n) or _car.part_health(n) >= USED_HEALTH:
		return false
	var price := used_price(_car, n)
	if not GameManager.spend(price):
		_status.text = "Не хватает денег: %s б/у — %d грн" % [String(Vehicle.WEAR[n][0]).to_lower(), price]
		return false
	SoundLibrary.play("hammer")
	TimeManager.advance(WORK_MIN)
	_car.health[n] = USED_HEALTH
	_car._warned_parts.erase(n)
	QuestManager.event("used_part")
	_status.text = "На «%s» поставили б/у: %s" % [_car.spec.title, String(Vehicle.WEAR[n][0]).to_lower()]
	GameManager.notify("Свалка: %s б/у (−%d грн)" % [String(Vehicle.WEAR[n][0]).to_lower(), price])
	_refresh()
	return true
