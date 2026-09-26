extends Node
## Цели игрока: из бедной избы — в кирпичный дом. Плюс развоз хлеба на машине.
##
## Уровень дома — это HouseInterior.Wealth: 0 бедный, 1 средний, 2 зажиточный.
## Мир слушает house_changed и перестраивает двор игрока.

signal house_changed(level: int)
signal delivery_changed

## Цена перестройки на следующий уровень.
const UPGRADE_COST := [12000, 30000]
const UPGRADE_TEXT := ["штукатуренный дом под шифером", "кирпичный дом под черепицей"]
const DELIVERY_PAY := 500
## Сколько игровых минут даётся на доставку.
const DELIVERY_TIME := 90.0

var house_level := 0
## Везём ли хлеб в сельмаг и сколько минут осталось.
var delivery_active := false
var delivery_left := 0.0
var deliveries_done := 0


func _ready() -> void:
	TimeManager.minute_passed.connect(_on_minutes)


func _on_minutes(m: float) -> void:
	if not delivery_active:
		return
	delivery_left -= m
	if delivery_left <= 0.0:
		delivery_active = false
		GameManager.notify("Не успел: хлеб в сельмаге уже не ждут. Заказ сорван")
		delivery_changed.emit()


func max_level() -> bool:
	return house_level >= UPGRADE_COST.size()


func next_cost() -> int:
	return 0 if max_level() else UPGRADE_COST[house_level]


func goal_text() -> String:
	if delivery_active:
		return "Доставка: отвези хлеб на машине в сельмаг «Каменка» — осталось %d мин" % int(delivery_left)
	if max_level():
		return "Цель выполнена: у тебя лучший дом в Каменке!"
	return "Цель: накопить %d грн — прораб у калитки построит %s" % [next_cost(), UPGRADE_TEXT[house_level]]


## Перестройка дома: списать деньги и поднять уровень.
func upgrade_house() -> bool:
	if max_level():
		GameManager.notify("Дом и так лучший в селе")
		return false
	if not GameManager.spend(next_cost()):
		return false
	house_level += 1
	SoundLibrary.play("hammer")
	# Бригада работает весь день
	TimeManager.advance(8.0 * 60.0)
	GameManager.notify("Бригада отработала день — теперь у тебя %s!" % UPGRADE_TEXT[house_level - 1])
	house_changed.emit(house_level)
	return true


func start_delivery() -> void:
	if delivery_active:
		GameManager.notify("Хлеб уже в машине — вези в сельмаг")
		return
	delivery_active = true
	delivery_left = DELIVERY_TIME
	GameManager.notify("Погрузили хлеб. Отвези на машине в сельмаг за %d мин" % int(DELIVERY_TIME))
	delivery_changed.emit()


func finish_delivery() -> void:
	if not delivery_active:
		return
	delivery_active = false
	deliveries_done += 1
	GameManager.add_money(DELIVERY_PAY)
	SoundLibrary.play("cash")
	GameManager.notify("Хлеб доставлен: +%d грн" % DELIVERY_PAY)
	delivery_changed.emit()


func save_state() -> Dictionary:
	return {"house": house_level, "delivery": delivery_active, "left": delivery_left, "done": deliveries_done}


func load_state(d: Dictionary) -> void:
	var old := house_level
	house_level = int(d.get("house", 0))
	delivery_active = bool(d.get("delivery", false))
	delivery_left = float(d.get("left", 0.0))
	deliveries_done = int(d.get("done", 0))
	if old != house_level:
		house_changed.emit(house_level)
	delivery_changed.emit()
