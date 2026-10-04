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
	["Колька", "Реванш! Обгонишь меня сегодня до города?", "race_won", 1, 300, false],
	["Дед Михалыч", "Съезди заправься — завтра за удочками поедем", "refuel", 1, 120, false],
	["Бригадир Петрович", "Вспаши поле на тракторе — наряд у сарая", "plough", 1, 300, false],
	["Почтальонка Оля", "Заработай сегодня хоть тысячу — на ярмарке пригодится", "earned", 1000, 200, false],
]

## Своё дело: [id, название, цена, доход в день, где выкупить]
const BUSINESSES := {
	"kiosk": {"title": "ларёк у склада", "price": 15000, "income": 350},
	"sto": {"title": "СТО у трассы", "price": 40000, "income": 900},
}

## Поручение на сегодня: индекс в ERRANDS, −1 — нет
var errand := -1
var errand_day := 0
var progress := 0.0
var done := false
var done_total := 0
## Выкупленное дело и в какой день последний раз получен доход
var owned: Array = []
var paid_day := 0
## Вклад в сберкассе: каждое утро +1% (с копейками — вниз), до 100 грн в день.
var deposit := 0
const INTEREST := 0.01
const INTEREST_MAX := 100


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
			var add := mini(int(deposit * INTEREST), INTEREST_MAX)
			if add > 0:
				deposit += add
				GameManager.notify("Сберкасса: на вклад начислено +%d грн, на счету %d грн" % [add, deposit])
		if paid_day > 0 and not owned.is_empty():
			var sum := 0
			for id in owned:
				sum += int(BUSINESSES[id].income)
			GameManager.add_money(sum)
			SoundLibrary.play("cash", -6.0)
			GameManager.notify("Доход с твоего дела за день: +%d грн" % sum)
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


func buy(id: String) -> bool:
	var b: Dictionary = BUSINESSES[id]
	if owned.has(id) or not GameManager.spend(int(b.price)):
		return false
	owned.append(id)
	SoundLibrary.play("cash")
	GameManager.notify("Теперь %s — твоё! Каждое утро +%d грн дохода" % [b.title, b.income])
	QuestManager.event("business")
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
	return {"deposit": deposit, "errand": errand, "day": errand_day, "n": progress, "done": done, "total": done_total, "owned": owned, "paid": paid_day}


func load_state(d: Dictionary) -> void:
	errand = int(d.get("errand", -1))
	errand_day = int(d.get("day", 0))
	progress = float(d.get("n", 0.0))
	done = bool(d.get("done", false))
	done_total = int(d.get("total", 0))
	owned = (d.get("owned", []) as Array).duplicate()
	paid_day = int(d.get("paid", 0))
	deposit = int(d.get("deposit", 0))
	changed.emit()
