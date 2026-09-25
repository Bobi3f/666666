extends Node
## Потребности: сытость и бодрость, от 0 до 100.
## Сытость кончается примерно за сутки, бодрость — за 18 часов.

signal changed

const HUNGER_PER_MIN := 100.0 / (26.0 * 60.0)
const ENERGY_PER_MIN := 100.0 / (18.0 * 60.0)

var food := 80.0
var energy := 90.0
## Еда в запасе (купленная в ларьке). Съесть — клавиша Q.
var snacks := 1

var _warned_food := false
var _warned_energy := false


func _ready() -> void:
	TimeManager.minute_passed.connect(_on_minutes)


func _on_minutes(m: float) -> void:
	food = maxf(food - HUNGER_PER_MIN * m, 0.0)
	# Голодный устаёт вдвое быстрее
	var tire := ENERGY_PER_MIN * (2.0 if food <= 0.0 else 1.0)
	energy = maxf(energy - tire * m, 0.0)
	if food < 20.0 and not _warned_food:
		_warned_food = true
		GameManager.notify("Хочется есть. Купи еду в ларьке и нажми Q")
	if energy < 15.0 and not _warned_energy:
		_warned_energy = true
		GameManager.notify("Слипаются глаза. Пора домой спать")
	changed.emit()


func eat_snack() -> void:
	if snacks <= 0:
		GameManager.notify("Еды нет. Купи в ларьке у дороги")
		return
	snacks -= 1
	eat(35.0)
	GameManager.notify("Поел. Сытость %d%%" % int(food))


func eat(amount: float) -> void:
	food = minf(food + amount, 100.0)
	if food >= 20.0:
		_warned_food = false
	changed.emit()


func rest(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, 100.0)
	if energy >= 15.0:
		_warned_energy = false
	changed.emit()


## Множитель скорости ходьбы: вымотанный персонаж еле плетётся.
func walk_factor() -> float:
	return 0.55 if energy <= 0.0 else 1.0


func save_state() -> Dictionary:
	return {"food": food, "energy": energy, "snacks": snacks}


func load_state(d: Dictionary) -> void:
	food = float(d.get("food", 80.0))
	energy = float(d.get("energy", 90.0))
	snacks = int(d.get("snacks", 1))
	_warned_food = food < 20.0
	_warned_energy = energy < 15.0
	changed.emit()
