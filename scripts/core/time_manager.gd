extends Node
## Игровое время. Одна реальная секунда — одна игровая минута,
## сутки проходят за 24 минуты (медленнее — настройка «Ход времени»).
##
## Работа не перематывает часы: work() занимает игрока, и время идёт
## своим ходом, пока работа не кончится (на экране — сколько осталось).

signal minute_passed(minutes: float)
## Работа началась или кончилась.
signal work_changed

const START_HOUR := 8.0

var day := 1
## Минуты с полуночи текущего дня.
var minutes := START_HOUR * 60.0
var speed := 1.0
## Идущая работа: сколько игровых минут осталось, сколько всего и что делаем.
var work_left := 0.0
var work_total := 0.0
var work_what := ""


func _process(delta: float) -> void:
	var m := delta * speed * SettingsManager.time_rate()
	advance(m)
	if work_left > 0.0:
		work_left = maxf(work_left - m, 0.0)
		if work_left <= 0.0:
			_work_done()


## Занять игрока работой на m игровых минут: часы не прыгают, а идут.
## Награда уже выдана — игрок просто стоит за делом, пока время не выйдет.
func work(m: float, what: String) -> void:
	if m <= 0.0:
		return
	work_left += m
	work_total = work_left
	work_what = what
	work_changed.emit()


func busy() -> bool:
	return work_left > 0.0


## Строка для экрана: «Дою коров — ещё 12 мин».
func work_text() -> String:
	return "%s — ещё %d мин" % [work_what, ceili(work_left)]


## Доработать сразу (тесты, обморок, сон): оставшееся время проходит разом.
func finish_work() -> void:
	if work_left > 0.0:
		advance(work_left)
		_work_done()


func _work_done() -> void:
	work_left = 0.0
	work_total = 0.0
	work_changed.emit()
	GameManager.notify("%s — готово. %s" % [work_what, clock_text()])


## Двигает время вперёд на m игровых минут.
func advance(m: float) -> void:
	minutes += m
	while minutes >= 1440.0:
		minutes -= 1440.0
		day += 1
	minute_passed.emit(m)


func hour() -> float:
	return minutes / 60.0


## Перематывает до указанного часа (завтра, если он уже прошёл).
## Возвращает, сколько минут прошло.
func skip_to(target_hour: float) -> float:
	var target := target_hour * 60.0
	var passed := target - minutes
	if passed <= 0.0:
		passed += 1440.0
	advance(passed)
	return passed


const WEEKDAYS := ["вс", "пн", "вт", "ср", "чт", "пт", "сб"]


## Первый день — понедельник, каждый седьмой — воскресенье (ярмарка).
func weekday() -> String:
	return WEEKDAYS[day % 7]


## Поставить время суток сразу (выбор в меню): тот же день, без голода
## и усталости за пропущенные часы.
func set_hour(h: float) -> void:
	minutes = clampf(h, 0.0, 23.99) * 60.0
	minute_passed.emit(0.0)


func clock_text() -> String:
	var m := int(minutes)
	return "День %d (%s), %02d:%02d" % [day, weekday(), m / 60, m % 60]


func save_state() -> Dictionary:
	return {"day": day, "minutes": minutes, "work": work_left, "work_what": work_what}


func load_state(d: Dictionary) -> void:
	day = int(d.get("day", 1))
	minutes = float(d.get("minutes", START_HOUR * 60.0))
	work_left = maxf(float(d.get("work", 0.0)), 0.0)
	work_total = work_left
	work_what = str(d.get("work_what", "Работаю"))
	work_changed.emit()
