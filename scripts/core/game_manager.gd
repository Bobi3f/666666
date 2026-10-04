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
## Старый мопед «Карпаты» — с него начинается игра.
var moped: Node3D
var vehicle: Node3D
## Телефон: Android или браузер на телефоне — показываем сенсорное управление,
## мышь не захватываем.
const TOUCH_NAMES := [
	[", журнал — J, управление — F1", ", журнал — кнопка «Журнал»"],
	[" (Q)", " (кнопка «Еда»)"],
	[" — J)", " — «Журнал»)"],
	[". Автомат: W — газ, S — тормоз и назад. T — механика, V — вид", ": крути руль пальцем, педали справа, рычаг D/R — вперёд или назад"],
	["(W — завести)", "(«Газ» — завести)"],
	["T — коробка, V — вид", "«Вид» — камера"],
]

## Плавное движение пешком от джойстика телефона или стика геймпада:
## x — вбок, y — вперёд(−)/назад(+), длина до 1 — насколько отклонён.
var move_axis := Vector2.ZERO
## Руль на экране телефона: −1 (до упора вправо) … 1 (влево), 0 — не держат.
var steer_axis := 0.0
## Педали телефона (как в Car Parking): W — всегда газ, S — всегда тормоз,
## а направление выбирает рычаг D/R. Выключено — клавиатурная схема.
var pedal_mode := false
var pedal_reverse := false

## Игра идёт (главное меню при запуске закрыто) — можно автосохраняться.
var in_game := false
## Строка идущего заезда (экзамен, спор) — показывается первой в задании.
var challenge_line := ""
## Куда вести стрелку-навигатор (работа, заезд); Vector3.INF — работы нет,
## тогда стрелка ведёт по сюжетному заданию (nav_arrow.gd).
var nav_target := Vector3.INF
var nav_label := ""
## В какой машине сейчас хлеб на развоз (удары и ямы бьют хлеб только в ней).
var delivery_vehicle: Node = null

var touch_mode := "--touch" in OS.get_cmdline_user_args() or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


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
## Вибрация телефона: удар, яма, поклёвка. На компьютере ничего не делает,
## на телефоне — если не выключена в настройках.
func vibrate(ms: int) -> void:
	if touch_mode and SettingsManager.vibration:
		Input.vibrate_handheld(ms)


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
