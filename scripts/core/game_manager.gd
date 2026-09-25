extends Node
## Деньги, сообщения на экран и ссылки на игрока и машину.

signal money_changed(value: int)
signal message(text: String)

const START_MONEY := 10000

var money := START_MONEY
var player: Node3D
var car: Node3D


func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)


## Списывает деньги, если хватает. Иначе пишет на экран и возвращает false.
func spend(amount: int) -> bool:
	if money < amount:
		notify("Не хватает денег: нужно %d грн" % amount)
		return false
	add_money(-amount)
	return true


func notify(text: String) -> void:
	message.emit(text)


func save_state() -> Dictionary:
	return {"money": money}


func load_state(d: Dictionary) -> void:
	money = int(d.get("money", START_MONEY))
	money_changed.emit(money)
