extends Node
## Цели игрока: из бедной избы — в кирпичный дом. Плюс развоз хлеба на машине.
##
## Уровень дома — это HouseInterior.Wealth: 0 бедный, 1 средний, 2 зажиточный.
## Мир слушает house_changed и перестраивает двор игрока.

signal house_changed(level: int)
signal delivery_changed
signal garden_changed

## Цена перестройки на следующий уровень.
const UPGRADE_COST := [12000, 30000]
const UPGRADE_TEXT := ["штукатуренный дом под шифером", "кирпичный дом под черепицей"]
const DELIVERY_PAY := 500
## Сколько игровых минут даётся на доставку.
const DELIVERY_TIME := 90.0
## Огород: семена, сколько растёт картошка (игровые минуты) и урожай.
const SEED_COST := 100
const GROW_TIME := 3.0 * 1440.0
const HARVEST := 6

var house_level := 0
## Везём ли хлеб в сельмаг и сколько минут осталось.
var delivery_active := false
var delivery_left := 0.0
var deliveries_done := 0
## Посажена ли картошка и когда (минуты от начала игры).
var planted := false
var planted_at := 0.0
var _last_stage := 0


func _ready() -> void:
	TimeManager.minute_passed.connect(_on_minutes)


func _on_minutes(m: float) -> void:
	var st := garden_stage()
	if st != _last_stage:
		_last_stage = st
		if st == 3:
			GameManager.notify("Картошка на огороде поспела — пора копать")
		garden_changed.emit()
	if not delivery_active:
		return
	delivery_left -= m
	if delivery_left <= 0.0:
		delivery_active = false
		GameManager.notify("Не успел: хлеб в сельмаге уже не ждут. Заказ сорван")
		delivery_changed.emit()


## Минуты от начала игры — чтобы считать, сколько растёт огород.
static func now() -> float:
	return (TimeManager.day - 1) * 1440.0 + TimeManager.minutes


## 0 — пусто, 1 — ростки, 2 — ботва, 3 — поспела.
func garden_stage() -> int:
	if not planted:
		return 0
	var k := (now() - planted_at) / GROW_TIME
	if k >= 1.0:
		return 3
	return 1 if k < 0.4 else 2


func garden_prompt() -> String:
	match garden_stage():
		0:
			return "E — посадить картошку (семена %d грн)" % SEED_COST
		3:
			return "E — выкопать картошку (%d в запас еды)" % HARVEST
	var left := int(ceilf((planted_at + GROW_TIME - now()) / 60.0))
	return "Картошка растёт, копать через %d ч" % left


func use_garden() -> void:
	match garden_stage():
		0:
			var h := TimeManager.hour()
			if h < 6.0 or h > 21.0:
				GameManager.notify("В темноте не посадишь. Приходи утром")
				return
			if not GameManager.spend(SEED_COST):
				return
			TimeManager.advance(90.0)
			NeedsManager.rest(-8.0)
			planted = true
			planted_at = now()
			GameManager.notify("Посадил картошку. Через трое суток — копать")
		3:
			TimeManager.advance(90.0)
			NeedsManager.rest(-10.0)
			NeedsManager.snacks += HARVEST
			planted = false
			GameManager.notify("Выкопал картошку: +%d в запас еды (Q)" % HARVEST)
		_:
			GameManager.notify(garden_prompt())
			return
	_last_stage = garden_stage()
	garden_changed.emit()


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
	return {"house": house_level, "delivery": delivery_active, "left": delivery_left, "done": deliveries_done,
		"planted": planted, "planted_at": planted_at}


func load_state(d: Dictionary) -> void:
	var old := house_level
	house_level = int(d.get("house", 0))
	delivery_active = bool(d.get("delivery", false))
	delivery_left = float(d.get("left", 0.0))
	deliveries_done = int(d.get("done", 0))
	planted = bool(d.get("planted", false))
	planted_at = float(d.get("planted_at", 0.0))
	_last_stage = garden_stage()
	garden_changed.emit()
	if old != house_level:
		house_changed.emit(house_level)
	delivery_changed.emit()
