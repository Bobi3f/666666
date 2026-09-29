extends Node
## Достижения: повод играть дальше и после кирпичного дома. Считаются по
## событиям игры (QuestManager.fired), видны в журнале (J).

signal unlocked(id: String)

## id → [название, как получить, событие, сколько]
const LIST := {
	"fish1": ["Первая поклёвка", "Поймай первую рыбу", "fish", 1],
	"fish25": ["Рыбак", "Поймай 25 рыб", "fish", 25],
	"trophy": ["Трофей", "Поймай щуку или сома", "trophy", 1],
	"mushroom30": ["Грибник", "Собери 30 грибов в лесу", "mushroom", 30],
	"km10": ["Водитель", "Проедь 10 км", "drive_m", 10000],
	"km100": ["Дальнобойщик", "Проедь 100 км", "drive_m", 100000],
	"license": ["С правами", "Сдай экзамен в автошколе", "license", 1],
	"race": ["Гонщик", "Обгони Кольку", "race_won", 1],
	"taxi10": ["Таксист", "Отвези 10 пассажиров", "taxi", 10],
	"bread10": ["Хлебовоз", "Развези хлеб 10 раз", "delivery", 10],
	"plough5": ["Пахарь", "Вспаши поле 5 раз", "plough", 5],
	"work20": ["Трудяга", "Отработай 20 смен в колхозе и на складе", "work", 20],
	"errand10": ["Свой человек", "Выполни 10 поручений", "errand", 10],
	"lucky": ["Везунчик", "Выиграй в лотерею 500 грн и больше", "lottery_win", 1],
	"cars3": ["Автопарк", "Купи все три машины в салоне", "car_bought", 3],
	"biz": ["Бизнесмен", "Выкупи своё дело", "business", 1],
	"house2": ["Хозяин Каменки", "Построй кирпичный дом", "house_2", 1],
	"year": ["Четыре сезона", "Проживи в Каменке 28 дней", "day", 28],
	"region": ["Весь район", "Побывай во всех четырёх соседних сёлах", "village_visit", 4],
}

var counts := {}
var got: Array = []


func _ready() -> void:
	QuestManager.fired.connect(_on_event)
	TimeManager.minute_passed.connect(func(_m: float) -> void: _set_count("day", TimeManager.day - 1))


func _on_event(name: String, amount: float) -> void:
	# Смены в колхозе и на складе — одна копилка
	if name == "kolkhoz" or name == "shift":
		name = "work"
	if name == "lottery_win" and amount < 500.0:
		return
	var add := amount if name == "drive_m" else 1.0
	counts[name] = float(counts.get(name, 0.0)) + add
	_check(name)


func _set_count(name: String, v: float) -> void:
	if float(counts.get(name, 0.0)) >= v:
		return
	counts[name] = v
	_check(name)


func _check(name: String) -> void:
	for id in LIST:
		var a: Array = LIST[id]
		if a[2] != name or got.has(id):
			continue
		if float(counts.get(name, 0.0)) >= float(a[3]):
			got.append(id)
			if GameManager.in_game:
				SoundLibrary.play("quest", -2.0, 1.2)
				GameManager.notify("Достижение: «%s» — %s (%d из %d, журнал J)" % [a[0], a[1], got.size(), LIST.size()])
			unlocked.emit(id)


## Для журнала: сколько набрано у достижения, 0..1.
func progress(id: String) -> float:
	var a: Array = LIST[id]
	return clampf(float(counts.get(a[2], 0.0)) / float(a[3]), 0.0, 1.0)


func save_state() -> Dictionary:
	return {"counts": counts, "got": got}


func load_state(d: Dictionary) -> void:
	counts = (d.get("counts", {}) as Dictionary).duplicate()
	got = (d.get("got", []) as Array).duplicate()
