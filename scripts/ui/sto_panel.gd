class_name StoPanel
extends MarketPanel
## Мастер на СТО «Автосервис» в городе: покраска в любой цвет и замена
## изношенных узлов (мотор, сцепление, колодки, амортизаторы, резина) на
## новые — для своей техники, что стоит у СТО. Окно — как у базара
## (MarketPanel): выбор техники сверху, крупные кнопки под палец.

const PAINT_PRICE := [400, 200]
const PAINT_MIN := 30.0
const PART_MIN := 45.0


func open(_m: String, vehicles: Array = []) -> void:
	mode = "sto"
	_vehicles = vehicles
	visible = true
	get_tree().paused = true
	_status.text = ""
	_title.text = "СТО «Автосервис» — покраска и запчасти"
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
		_status.text = "Подгони свою машину или мотоцикл к воротам СТО"
	_refresh()


func _refresh() -> void:
	for c in _goods.get_children():
		c.queue_free()
	if _car == null:
		return
	_goods.add_child(_label("Покраска «%s» — %d грн, полчаса. Сейчас: %s" % [_car.spec.title, paint_price(), _car.paint_name()], 18, Color.WHITE))
	var colors := HFlowContainer.new()
	colors.add_theme_constant_override("h_separation", 8)
	colors.add_theme_constant_override("v_separation", 6)
	_goods.add_child(colors)
	var names: Array = Vehicle.MOTO_PAINT_NAMES if _car.spec.two_wheels else Vehicle.PAINT_NAMES
	var cols: Array = _car.paints()
	for i in cols.size():
		var c: Color = cols[i]
		var b := _button(names[i], c.darkened(0.15))
		b.custom_minimum_size.x = 110
		b.add_theme_color_override("font_color", Color.BLACK if c.get_luminance() > 0.5 else Color.WHITE)
		b.disabled = i == _car.paint
		b.pressed.connect(paint.bind(i))
		colors.add_child(b)
	_goods.add_child(_label("Замена узлов на новые:", 18, Color.WHITE))
	for n in Vehicle.WEAR:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_goods.add_child(row)
		var h: float = _car.part_health(n)
		var fresh := h >= 95.0
		var b := _button("Новый" if fresh else "%d грн" % _car.part_price(n), Color(0.25, 0.25, 0.25) if fresh else Color(0.28, 0.45, 0.25))
		b.custom_minimum_size.x = 120
		b.disabled = fresh
		b.pressed.connect(renew.bind(n))
		row.add_child(b)
		var col := Color(0.95, 0.92, 0.85) if h >= 50.0 else (Color(1.0, 0.8, 0.4) if h >= 25.0 else Color(1.0, 0.5, 0.4))
		var l := _label("%s — ресурс %d%%" % [Vehicle.WEAR[n][0], int(h)], 16, col)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)


func paint_price() -> int:
	return PAINT_PRICE[1 if _car and _car.spec.two_wheels else 0]


## Перекрасить выбранную технику в цвет i. true — получилось.
func paint(i: int) -> bool:
	if _car == null or i == _car.paint:
		return false
	if not GameManager.spend(paint_price()):
		_status.text = "Не хватает денег: покраска — %d грн" % paint_price()
		return false
	SoundLibrary.play("hammer")
	TimeManager.advance(PAINT_MIN)
	_car.set_paint(i)
	QuestManager.event("tuning")
	_status.text = "%s теперь %s" % [_car.spec.title, _car.paint_name()]
	GameManager.notify("СТО: перекрасили — %s теперь %s (−%d грн)" % [_car.spec.title, _car.paint_name(), paint_price()])
	_refresh()
	return true


## Поставить новый узел n. true — получилось.
func renew(n: String) -> bool:
	if _car == null or not Vehicle.WEAR.has(n) or _car.part_health(n) >= 95.0:
		return false
	var price := _car.part_price(n)
	if not GameManager.spend(price):
		_status.text = "Не хватает денег: %s — %d грн" % [String(Vehicle.WEAR[n][0]).to_lower(), price]
		return false
	SoundLibrary.play("hammer")
	TimeManager.advance(PART_MIN)
	_car.renew_part(n)
	QuestManager.event("part_renewed")
	_status.text = "На «%s» поставили новое: %s" % [_car.spec.title, String(Vehicle.WEAR[n][0]).to_lower()]
	GameManager.notify("СТО: %s — новое (−%d грн)" % [String(Vehicle.WEAR[n][0]).to_lower(), price])
	_refresh()
	return true
