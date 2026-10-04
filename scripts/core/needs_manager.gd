extends Node
## Потребности: сытость, бодрость и вода, от 0 до 100.
## Тают медленно, чтобы успевать ездить и работать: сытость кончается
## примерно за двое суток, бодрость — за 30 часов, вода — за 54 часа.
## Жажда ненавязчивая: в обморок от неё не падают, только устают быстрее,
## пока не попьёшь (колонка на улице — бесплатно).

signal changed
## Обморок: от усталости (бодрость 0) или голода (сытость 0 три часа).
signal fainted(reason: String)

const HUNGER_PER_MIN := 100.0 / (48.0 * 60.0)
const ENERGY_PER_MIN := 100.0 / (30.0 * 60.0)
const THIRST_PER_MIN := 100.0 / (54.0 * 60.0)

var food := 80.0
var energy := 90.0
var water := 90.0
## Еда в запасе (купленная в ларьке). Съесть — клавиша Q.
var snacks := 1
## Пойманная рыба — сдаётся в сельмаг.
var fish := 0

var _starving := 0.0
var _warned_food := false
var _warned_energy := false
var _warned_water := false


func _ready() -> void:
	TimeManager.minute_passed.connect(_on_minutes)


func _on_minutes(m: float) -> void:
	food = maxf(food - HUNGER_PER_MIN * m, 0.0)
	water = maxf(water - THIRST_PER_MIN * m, 0.0)
	_starving = _starving + m if food <= 0.0 else 0.0
	# Голодный устаёт вдвое быстрее, без воды — в полтора раза
	var tire := ENERGY_PER_MIN * (2.0 if food <= 0.0 else 1.0) * (1.5 if water <= 0.0 else 1.0)
	if water < 20.0 and not _warned_water:
		_warned_water = true
		GameManager.notify("Хочется пить. Колонка на деревенской улице — бесплатно, вода есть в магазинах")
	energy = maxf(energy - tire * m, 0.0)
	if food < 20.0 and not _warned_food:
		_warned_food = true
		GameManager.notify("Хочется есть. Купи еду в ларьке и нажми Q")
	if energy < 15.0 and not _warned_energy:
		_warned_energy = true
		GameManager.notify("Слипаются глаза. Пора домой спать — иначе упадёшь где стоишь")
	if food <= 0.0 and _starving > 0.0 and _starving < m + 0.01:
		GameManager.notify("Живот сводит от голода. Не поешь за три часа — упадёшь в обморок")
	# Обморок — только в обычном ходе времени, не во время перемотки (сон, смена)
	if m < 30.0:
		if energy <= 0.0:
			_starving = 0.0
			fainted.emit("Свалился от усталости.")
		elif _starving > 180.0:
			_starving = 0.0
			fainted.emit("Потерял сознание от голода.")
	changed.emit()


func eat_snack() -> void:
	if snacks <= 0:
		GameManager.notify("Еды нет. Купи в ларьке у дороги")
		return
	snacks -= 1
	eat(35.0)
	QuestManager.event("ate")
	GameManager.notify("Поел. Сытость %d%%" % int(food))


func eat(amount: float) -> void:
	food = minf(food + amount, 100.0)
	if food >= 20.0:
		_warned_food = false
	changed.emit()


func drink(amount: float) -> void:
	water = minf(water + amount, 100.0)
	if water >= 20.0:
		_warned_water = false
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
	return {"food": food, "energy": energy, "water": water, "snacks": snacks, "fish": fish}


func load_state(d: Dictionary) -> void:
	food = float(d.get("food", 80.0))
	energy = float(d.get("energy", 90.0))
	water = float(d.get("water", 90.0))
	_warned_water = water < 20.0
	snacks = int(d.get("snacks", 1))
	fish = int(d.get("fish", 0))
	_warned_food = food < 20.0
	_warned_energy = energy < 15.0
	changed.emit()
