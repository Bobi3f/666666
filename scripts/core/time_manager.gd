extends Node
## Игровое время. Одна реальная секунда — одна игровая минута,
## сутки проходят за 24 минуты.

signal minute_passed(minutes: float)

const START_HOUR := 8.0

var day := 1
## Минуты с полуночи текущего дня.
var minutes := START_HOUR * 60.0
var speed := 1.0


func _process(delta: float) -> void:
	advance(delta * speed)


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


func clock_text() -> String:
	var m := int(minutes)
	return "День %d, %02d:%02d" % [day, m / 60, m % 60]


func save_state() -> Dictionary:
	return {"day": day, "minutes": minutes}


func load_state(d: Dictionary) -> void:
	day = int(d.get("day", 1))
	minutes = float(d.get("minutes", START_HOUR * 60.0))
