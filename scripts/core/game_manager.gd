extends Node
## Деньги, сообщения на экран и ссылки на игрока и машину.

signal money_changed(value: int)
signal message(text: String)

## Денег в обрез: на жизнь хватит, на новый дом — надо заработать.
const START_MONEY := 1500

var money := START_MONEY
var player: Node3D
## Жигули игрока и мотоцикл; vehicle — то, на чём игрок едет сейчас.
var car: Node3D
var moto: Node3D
var vehicle: Node3D
## Телефон: Android или браузер на телефоне — показываем сенсорное управление,
## мышь не захватываем.
const TOUCH_NAMES := [
	[", журнал — J, управление — F1", ", журнал — кнопка «Журнал»"],
	[" (Q)", " (кнопка «Еда»)"],
	[" — J)", " — «Журнал»)"],
]

var touch_mode := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)
	if amount > 0:
		QuestManager.event("earned", amount)


## Списывает деньги, если хватает. Иначе пишет на экран и возвращает false.
func spend(amount: int) -> bool:
	if money < amount:
		notify("Не хватает денег: нужно %d грн" % amount)
		return false
	add_money(-amount)
	SoundLibrary.play("cash", -6.0)
	return true


func notify(text: String) -> void:
	message.emit(touch_text(text))


## На телефоне клавиш нет: упоминания клавиш заменяем названиями экранных кнопок.
func touch_text(text: String) -> String:
	if not touch_mode:
		return text
	for pair in TOUCH_NAMES:
		text = text.replace(pair[0], pair[1])
	return text


func save_state() -> Dictionary:
	return {"money": money}


func load_state(d: Dictionary) -> void:
	money = int(d.get("money", START_MONEY))
	money_changed.emit(money)
