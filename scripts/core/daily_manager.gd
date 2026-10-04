extends Node
## Повод заходить каждый день: утреннее поручение от кого-нибудь из
## Каменки и доход со своего дела (СТО, ларёк), если его выкупил.
##
## Поручение приходит «звонком» в 7:00 (или сразу, если день начался без
## него) и действует до полуночи. Считается по событиям QuestManager —
## тем же, что двигают задания: поймал рыбу, отработал смену, отвёз пассажира.

signal changed

## [кто просит, что сказать, событие, сколько, награда, нужны ли права]
const ERRANDS := [
	["Баба Галя", "Поймай к ужину три рыбки — на уху", "fish", 3, 250, false],
	["Бригадир Петрович", "Выйди сегодня на смену в колхоз — сено горит", "kolkhoz", 1, 200, false],
	["Кладовщик", "Нужен грузчик на смену на склад в городе", "shift", 1, 200, false],
	["Сельмаг", "Хлеба не хватает — привези со склада", "delivery", 1, 220, false],
	["Диспетчер такси", "Два заказа сегодня — довези пассажиров", "taxi", 2, 260, true],
	["Механик Васёк", "Обкатай машину после ремонта — проедь 3 км", "drive_m", 3000, 150, false],
	["Колька", "Реванш! Обгонишь меня сегодня до моста?", "race_won", 1, 300, false],
	["Дед Михалыч", "Съезди заправься — завтра за удочками поедем", "refuel", 1, 120, false],
	["Бригадир Петрович", "Вспаши поле на тракторе — наряд у сарая", "plough", 1, 300, false],
	["Почтальонка Оля", "Заработай сегодня хоть тысячу — на ярмарке пригодится", "earned", 1000, 200, false],
]

## Своё дело: название, цена, доход в день. Автопарк не покупается —
## открывается, когда своих машин три (cars), и платит, пока они есть.
## kiosk2 — ларёк конкурента в Озерцово, если его перекупить.
## Доход — чтобы дело окупалось за две-три игровые недели (вклад в банке
## за это время даёт меньше 10%): иначе покупать его нет смысла.
const BUSINESSES := {
	"kiosk": {"title": "ларёк у склада", "price": 5000, "income": 250},
	"sto": {"title": "СТО у трассы", "price": 15000, "income": 600},
	"fleet": {"title": "автопарк", "price": 0, "income": 800, "cars": 3},
	"kiosk2": {"title": "ларёк Жоры в Озерцово", "price": 7000, "income": 300},
}
## Работники: кто к какому делу и сколько добавляет в день.
const WORKERS := {"vasya": {"title": "механик Васёк", "biz": "sto", "income": 300}}
## Конкурент: Жора из Озерцово открывает ларёк на другой день после того,
## как выкупишь свой, и половина покупателей уходит к нему. Перекупить его
## ларёк (RIVAL_BUYOUT) или разорить: три дня акции у своего ларька.
const RIVAL_BUYOUT := 7000
const DUMP_COST := 300
const DUMP_DAYS := 3
enum Rival {NONE, ACTIVE, BOUGHT, RUINED}
var rival := Rival.NONE
var dump_days: Array = []

## Поручение на сегодня: индекс в ERRANDS, −1 — нет
var errand := -1
var errand_day := 0
var progress := 0.0
var done := false
var done_total := 0
## Выкупленное дело и в какой день последний раз получен доход
var owned: Array = []
var paid_day := 0
## Нанятые работники (id из WORKERS)
var hired: Array = []
## Вклад в банке: 10% годовых, год — четыре времени года (28 игровых
## дней); проценты капают каждое утро (с копейками — вниз).
var deposit := 0
const INTEREST_YEAR := 0.10
const YEAR_DAYS := 28


func _ready() -> void:
	TimeManager.minute_passed.connect(_on_minutes)
	QuestManager.fired.connect(_on_event)


func _on_minutes(_m: float) -> void:
	if not GameManager.in_game:
		return
	var day := TimeManager.day
	# Новый день — доход со своего дела за вчера
	if paid_day < day:
		if paid_day > 0 and deposit > 0:
			var add := int(deposit * INTEREST_YEAR / YEAR_DAYS)
			if add > 0:
				deposit += add
				GameManager.notify("Банк: на вклад начислено +%d грн (10%% годовых), на счету %d грн" % [add, deposit])
		if paid_day > 0 and not owned.is_empty():
			var sum := 0
			for id in owned:
				sum += income(id)
			if sum > 0:
				GameManager.add_money(sum)
				SoundLibrary.play("cash", -6.0)
				GameManager.notify("Доход с твоего дела за день: +%d грн%s" % [sum, " (Жора переманивает покупателей)" if rival == Rival.ACTIVE else ""])
			if owned.has("fleet") and own_cars() < int(BUSINESSES.fleet.cars):
				GameManager.notify("Автопарк простаивает: нужно три своих машины, сейчас %d" % own_cars())
		# Ларёк куплен вчера или раньше — в Озерцово объявляется конкурент
		if paid_day > 0 and rival == Rival.NONE and owned.has("kiosk"):
			rival = Rival.ACTIVE
			GameManager.notify("В Озерцово Жора открыл свой ларёк — половина покупателей теперь у него. Перекупи его ларёк или устрой у себя три дня акции")
		paid_day = day
	# В первый день и так много нового — поручения со второго
	if errand_day != day and day >= 2 and TimeManager.hour() >= 7.0:
		_new_errand(day)


func _new_errand(day: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 7919 + 13
	var pool: Array[int] = []
	for i in ERRANDS.size():
		if bool(ERRANDS[i][5]) and not Progress.license:
			continue
		# Вчерашнее не повторяем
		if i == errand:
			continue
		pool.append(i)
	errand = pool[rng.randi() % pool.size()]
	errand_day = day
	progress = 0.0
	done = false
	var e: Array = ERRANDS[errand]
	SoundLibrary.play("quest", -8.0)
	GameManager.notify("Звонок — %s: «%s». Награда %d грн" % [e[0], e[1], e[4]])
	changed.emit()


func _on_event(name: String, amount: float) -> void:
	if errand < 0 or done or errand_day != TimeManager.day:
		return
	var e: Array = ERRANDS[errand]
	if e[2] != name:
		return
	progress += amount
	if progress >= float(e[3]):
		done = true
		done_total += 1
		GameManager.add_money(int(e[4]))
		SoundLibrary.play("quest")
		GameManager.notify("Поручение выполнено — %s благодарит: +%d грн" % [e[0], e[4]])
		QuestManager.event("errand")
	changed.emit()


## Строка для трекера на экране, "" — нечего показывать.
func tracker_line() -> String:
	if errand < 0 or errand_day != TimeManager.day or done:
		return ""
	var e: Array = ERRANDS[errand]
	var count := int(e[3])
	var n := "" if count == 1 else " — %d / %d" % [mini(int(progress), count), count]
	if e[2] == "drive_m":
		n = " — %d / %d м" % [int(progress), count]
	return "» Поручение (%s): %s%s" % [e[0], e[1], n]


func owns(id: String) -> bool:
	return owned.has(id)


## Сколько дело приносит в день сейчас: ларёк при конкуренте — вдвое
## меньше, автопарк — только при трёх своих машинах.
func income(id: String) -> int:
	var b: Dictionary = BUSINESSES[id]
	if id == "kiosk" and rival == Rival.ACTIVE:
		return int(b.income) / 2
	if id == "fleet" and own_cars() < int(b.cars):
		return 0
	var sum := int(b.income)
	for w in hired:
		if WORKERS[w].biz == id:
			sum += int(WORKERS[w].income)
	return sum


## Нанять работника к своему делу (Васёк — на СТО).
func hire(id: String) -> void:
	if hired.has(id) or not WORKERS.has(id):
		return
	hired.append(id)
	GameManager.notify("%s теперь работает у тебя: +%d грн в день к доходу" % [String(WORKERS[id].title).capitalize(), int(WORKERS[id].income)])
	changed.emit()


## Своих машин (не мотоциклов, не учебных и не колхозного трактора).
func own_cars() -> int:
	var n := 0
	if not is_inside_tree():
		return 0
	for v in get_tree().get_nodes_in_group("vehicles"):
		var car := v as Vehicle
		if car and car.owned() and car.price > 0 and not car.spec.two_wheels and not car.school and car.kind != "tractor":
			n += 1
	return n


## Перекупить ларёк Жоры: конкурента нет, его ларёк — твой.
func buy_rival() -> bool:
	if rival != Rival.ACTIVE or not GameManager.spend(RIVAL_BUYOUT):
		return false
	rival = Rival.BOUGHT
	owned.append("kiosk2")
	SoundLibrary.play("cash")
	GameManager.notify("Жора продал свой ларёк! Теперь в Озерцово тоже твоя торговля: +%d грн в день" % int(BUSINESSES.kiosk2.income))
	QuestManager.event("business")
	QuestManager.event("rival_done")
	changed.emit()
	return true


## Акция у своего ларька — день разорения конкурента (раз в день).
func dump() -> bool:
	if rival != Rival.ACTIVE or dump_days.has(TimeManager.day) or not GameManager.spend(DUMP_COST):
		return false
	dump_days.append(TimeManager.day)
	SoundLibrary.play("cash", -4.0)
	if dump_days.size() >= DUMP_DAYS:
		rival = Rival.RUINED
		GameManager.notify("Жора не выдержал акций и закрыл ларёк — покупатели снова у тебя!")
		QuestManager.event("rival_ruined")
		QuestManager.event("rival_done")
	else:
		GameManager.notify("Акция «дешевле, чем у Жоры»: день %d из %d" % [dump_days.size(), DUMP_DAYS])
	changed.emit()
	return true


func buy(id: String) -> bool:
	var b: Dictionary = BUSINESSES[id]
	if owned.has(id):
		return false
	if b.has("cars") and own_cars() < int(b.cars):
		GameManager.notify("Для автопарка нужно %d своих машины — сейчас %d" % [int(b.cars), own_cars()])
		return false
	if not GameManager.spend(int(b.price)):
		return false
	owned.append(id)
	SoundLibrary.play("cash")
	GameManager.notify("Теперь %s — твоё! Каждое утро +%d грн дохода" % [b.title, income(id)])
	QuestManager.event("business")
	QuestManager.event("business_" + id)
	changed.emit()
	return true


## Положить все деньги, кроме мелочи на расходы.
func put_money(keep := 300) -> int:
	var sum := GameManager.money - keep
	if sum <= 0:
		return 0
	GameManager.money -= sum
	GameManager.money_changed.emit(GameManager.money)
	deposit += sum
	changed.emit()
	return sum


func take_money() -> int:
	var sum := deposit
	deposit = 0
	GameManager.money += sum
	GameManager.money_changed.emit(GameManager.money)
	changed.emit()
	return sum


func save_state() -> Dictionary:
	return {"deposit": deposit, "errand": errand, "day": errand_day, "n": progress, "done": done, "total": done_total, "owned": owned, "paid": paid_day,
		"rival": rival, "dump": dump_days, "hired": hired}


func load_state(d: Dictionary) -> void:
	errand = int(d.get("errand", -1))
	errand_day = int(d.get("day", 0))
	progress = float(d.get("n", 0.0))
	done = bool(d.get("done", false))
	done_total = int(d.get("total", 0))
	owned = (d.get("owned", []) as Array).duplicate()
	paid_day = int(d.get("paid", 0))
	deposit = int(d.get("deposit", 0))
	rival = int(d.get("rival", Rival.NONE))
	dump_days = (d.get("dump", []) as Array).duplicate()
	hired = (d.get("hired", []) as Array).duplicate()
	changed.emit()
