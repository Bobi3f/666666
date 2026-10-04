extends Node
## Цели игрока: из бедной избы — в кирпичный дом. Плюс развоз хлеба на машине.
##
## Уровень дома — это HouseInterior.Wealth: 0 бедный, 1 средний, 2 зажиточный.
## Мир слушает house_changed и перестраивает двор игрока.

signal house_changed(level: int)
signal delivery_changed
signal garden_changed
signal home_changed

## Цена перестройки на следующий уровень.
const UPGRADE_COST := [12000, 30000]
const UPGRADE_TEXT := ["штукатуренный дом под шифером", "кирпичный дом под черепицей"]
const DELIVERY_PAY := 500
## Сколько игровых минут даётся на доставку.
const DELIVERY_TIME := 90.0
## Премия, если довёз быстрее, чем за половину срока.
const DELIVERY_BONUS := 150
## Огород: семена, сколько растёт картошка (игровые минуты) и урожай.
const SEED_COST := 100
const GROW_TIME := 3.0 * 1440.0
const HARVEST := 6

var house_level := 0
## Везём ли хлеб в сельмаг и сколько минут осталось.
var delivery_active := false
var delivery_left := 0.0
var deliveries_done := 0
## Целость хлеба в процентах: удары и тряска по бездорожью её снижают.
var bread := 100.0
## Обучение первых минут пройдено или пропущено.
var tutorial_done := false
## Права получены на автодроме: развоз хлеба платит больше.
var license := false
const LICENSE_BONUS := 150
## Документы из сельсовета и больницы: passport — паспорт, propiska —
## справка о прописке, work_book — трудовая книжка, med — медсправка водителя.
var docs: Array = []
## Открытые категории прав, кроме B (B — это license): A — мотоцикл,
## C — грузовик, D — автобус.
var categories: Array = []
## Когда открыта категория (день игры) — для карточки прав.
var category_days := {}
## Номер удостоверения (выдаётся с первыми правами).
var license_no := ""
const DOC_NAMES := {"passport": "паспорт", "propiska": "справка о прописке",
	"work_book": "трудовая книжка", "med": "медсправка водителя",
	"school_cert": "аттестат о среднем образовании"}
## Какую категорию прав требует машина: мотоцикл — A, легковые — B,
## грузовик — C, автобус — D; трактору права не спрашивают.
const KIND_CATEGORY := {"moto": "A", "izh": "A", "car": "B", "vaz2107": "B", "niva": "B", "volga": "B", "truck": "C", "bus": "D"}
## В какой день уже был заезд с Колькой (раз в день).
var race_day := 0
## Купленное в «Хозтоварах»: tv — телевизор в комнате, dog — пёс с будкой
## во дворе, greenhouse — теплица над огородом (картошка растёт быстрее).
var home_items: Array = []
## День, когда холодильник последний раз дал еду (раз в сутки, с утра).
var fridge_day := 0
## Купленные в автосалоне машины: niva, volga, truck.
var owned_cars: Array = []
## Во сколько раз больше платят за этот развоз (грузовик — вдвое).
var delivery_mult := 1.0
const GREENHOUSE_SPEED := 1.5
## Посажена ли картошка и когда (минуты от начала игры).
var planted := false
var planted_at := 0.0
## Полив: в какой день полита и сколько дней поливали (дождь тоже поливает).
## Каждый политый день — +1 картошка к урожаю, до трёх.
var watered_day := 0
var watered_days := 0
const WATER_MAX := 3
var _last_stage := 0


func _ready() -> void:
	TimeManager.minute_passed.connect(_on_minutes)


func _on_minutes(m: float) -> void:
	var st := garden_stage()
	# Дождь поливает огород сам
	if (st == 1 or st == 2) and WeatherManager.rain > 0.5 and not WeatherManager.snowing() and watered_day != TimeManager.day:
		watered_day = TimeManager.day
		watered_days += 1
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


func owns(kind: String) -> bool:
	return owned_cars.has(kind)


func buy_car(kind: String) -> void:
	if not owned_cars.has(kind):
		owned_cars.append(kind)
		# Мотоцикл из салона — не машина: в «Автопарк» не считается
		QuestManager.event("moto_bought" if kind == "izh" else "car_bought")


func has_item(id: String) -> bool:
	return home_items.has(id)


func add_item(id: String) -> void:
	if not home_items.has(id):
		home_items.append(id)
		home_changed.emit()


## Сколько растёт картошка: в теплице — быстрее.
func grow_time() -> float:
	return GROW_TIME / (GREENHOUSE_SPEED if has_item("greenhouse") else 1.0)


func delivery_pay() -> int:
	return DELIVERY_PAY + (LICENSE_BONUS if license else 0)


## Хлеб бьётся: удар машины или тряска по кочкам.
func damage_bread(amount: float) -> void:
	if not delivery_active or amount <= 0.0:
		return
	var before := bread
	bread = maxf(bread - amount, 20.0)
	# Сообщаем о заметных потерях, а не о каждой кочке
	if int(before / 10.0) != int(bread / 10.0) and amount >= 3.0:
		GameManager.notify("Хлеб бьётся! Целых буханок: %d%%" % int(ceilf(bread)))


## Минуты от начала игры — чтобы считать, сколько растёт огород.
static func now() -> float:
	return (TimeManager.day - 1) * 1440.0 + TimeManager.minutes


## 0 — пусто, 1 — ростки, 2 — ботва, 3 — поспела.
func garden_stage() -> int:
	if not planted:
		return 0
	var k := (now() - planted_at) / grow_time()
	if k >= 1.0:
		return 3
	return 1 if k < 0.4 else 2


func garden_prompt() -> String:
	match garden_stage():
		0:
			return "E — посадить картошку (семена %d грн)" % SEED_COST
		3:
			return "E — выкопать картошку (%d в запас еды)" % harvest_size()
	var left := int(ceilf((planted_at + grow_time() - now()) / 60.0))
	if watered_day != TimeManager.day:
		return "E — полить картошку из колодца (урожай больше) · копать через %d ч" % left
	return "Картошка полита. Копать через %d ч" % left


func harvest_size() -> int:
	return HARVEST + mini(watered_days, WATER_MAX)


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
			watered_days = 0
			watered_day = 0
			GameManager.notify("Посадил картошку. Через трое суток — копать")
		3:
			TimeManager.advance(90.0)
			NeedsManager.rest(-10.0)
			var got := harvest_size()
			NeedsManager.snacks += got
			planted = false
			GameManager.notify("Выкопал картошку: +%d в запас еды (Q)%s" % [got, " — полив не зря!" if got > HARVEST else ""])
			watered_days = 0
		_:
			if watered_day == TimeManager.day:
				GameManager.notify(garden_prompt())
				return
			var h := TimeManager.hour()
			if h < 5.0 or h > 22.0:
				GameManager.notify("В темноте не полить. Приходи утром")
				return
			TimeManager.advance(20.0)
			NeedsManager.rest(-3.0)
			watered_day = TimeManager.day
			watered_days += 1
			SoundLibrary.play("splash", -6.0)
			GameManager.notify("Полил картошку. Урожай будет: %d" % harvest_size())
			garden_changed.emit()
			return
	_last_stage = garden_stage()
	garden_changed.emit()


func max_level() -> bool:
	return house_level >= UPGRADE_COST.size()


func next_cost() -> int:
	return 0 if max_level() else UPGRADE_COST[house_level]


func goal_text() -> String:
	if delivery_active:
		return "Доставка: хлеб в сельмаг «Каменка» — осталось %d мин, хлеб целый на %d%%" % [int(delivery_left), int(ceilf(bread))]
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
	QuestManager.event("house_%d" % house_level)
	return true


func start_delivery() -> void:
	if delivery_active:
		GameManager.notify("Хлеб уже в машине — вези в сельмаг")
		return
	delivery_active = true
	delivery_left = DELIVERY_TIME
	bread = 100.0
	GameManager.notify("Погрузили хлеб. Вези аккуратно, быстрее чем за %d мин — премия" % int(DELIVERY_TIME / 2.0))
	delivery_changed.emit()


func finish_delivery() -> void:
	if not delivery_active:
		return
	delivery_active = false
	deliveries_done += 1
	# Платят за целый хлеб; мятые буханки идут со скидкой
	var pay := int(round(delivery_pay() * delivery_mult * bread / 100.0))
	var fast := delivery_left >= DELIVERY_TIME / 2.0
	if fast:
		pay += DELIVERY_BONUS
	GameManager.add_money(pay)
	SoundLibrary.play("cash")
	var t := "Хлеб доставлен: +%d грн" % pay
	if fast:
		t += ", с премией за скорость"
	if bread < 99.5:
		t += ". Помято %d%% хлеба — вычли" % int(round(100.0 - bread))
	GameManager.notify(t)
	QuestManager.event("delivery")
	delivery_changed.emit()


func has_doc(id: String) -> bool:
	return docs.has(id)


func add_doc(id: String) -> void:
	if not docs.has(id):
		docs.append(id)


func has_category(c: String) -> bool:
	return license if c == "B" else categories.has(c)


func add_category(c: String) -> void:
	if not category_days.has(c):
		category_days[c] = TimeManager.day
	if license_no == "":
		license_no = "ВХХ № %06d" % (100000 + (TimeManager.day * 7919 + int(TimeManager.minutes)) % 900000)
	if c == "B":
		license = true
	elif not categories.has(c):
		categories.append(c)


## Категории строкой для журнала и инспектора: «A, B, C».
func categories_text() -> String:
	var out: Array = []
	for c in ["A", "B", "C", "D"]:
		if has_category(c):
			out.append(c)
	return ", ".join(out) if not out.is_empty() else "нет"


func save_state() -> Dictionary:
	return {"docs": docs, "cats": categories, "house": house_level, "delivery": delivery_active, "left": delivery_left, "done": deliveries_done, "bread": bread, "tutorial": tutorial_done, "license": license, "race_day": race_day, "home": home_items, "cars": owned_cars, "path2": true,
		"planted": planted, "planted_at": planted_at, "w_day": watered_day, "w_days": watered_days, "fridge": fridge_day, "cat_days": category_days, "license_no": license_no}


func load_state(d: Dictionary) -> void:
	var old := house_level
	house_level = int(d.get("house", 0))
	delivery_active = bool(d.get("delivery", false))
	delivery_left = float(d.get("left", 0.0))
	deliveries_done = int(d.get("done", 0))
	bread = float(d.get("bread", 100.0))
	# В старых сохранениях ключа нет — там игрок уже освоился
	tutorial_done = bool(d.get("tutorial", true))
	license = bool(d.get("license", false))
	docs = (d.get("docs", []) as Array).duplicate()
	categories = (d.get("cats", []) as Array).duplicate()
	race_day = int(d.get("race_day", 0))
	home_items = (d.get("home", []) as Array).duplicate()
	fridge_day = int(d.get("fridge", 0))
	var cd: Variant = d.get("cat_days", {})
	category_days = (cd as Dictionary).duplicate() if cd is Dictionary else {}
	license_no = str(d.get("license_no", ""))
	owned_cars = (d.get("cars", []) as Array).duplicate()
	# Сохранения до мопеда: «Жигули» и «Ява» были у игрока с начала и ездил
	# он на них без прав — так и остаётся, ничего не отбираем
	if not d.is_empty() and not d.has("path2"):
		for k in ["car", "moto"]:
			if not owned_cars.has(k):
				owned_cars.append(k)
		license = true
		if not categories.has("A"):
			categories.append("A")
	home_changed.emit()
	planted = bool(d.get("planted", false))
	planted_at = float(d.get("planted_at", 0.0))
	watered_day = int(d.get("w_day", 0))
	watered_days = int(d.get("w_days", 0))
	_last_stage = garden_stage()
	garden_changed.emit()
	if old != house_level:
		house_changed.emit(house_level)
	delivery_changed.emit()
