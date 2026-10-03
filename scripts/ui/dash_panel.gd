extends "res://scripts/ui/speedometer.gd"
## Щиток на руле: те же приборы, что на экране, но нарисованные в маленький
## экранчик (SubViewport) — он висит на руле мотоцикла и показывает живые
## стрелку и лампочки. Сейчас — у «ИЖ Юпитер-5».

## Размер приборов в экранчике (точки)
const R := 60.0

var vehicle: Vehicle


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func _vehicle() -> Vehicle:
	return vehicle


func _jawa_r() -> float:
	return R


func _process(delta: float) -> void:
	if vehicle == null or vehicle.driver == null:
		return
	position = Vector2.ZERO
	size = Vector2(R * 4.5 + 16.0, R * 2.0 + 10.0)
	_shown = lerpf(_shown, vehicle.speed_kmh(), minf(delta * 8.0, 1.0))
	queue_redraw()


func _draw() -> void:
	if vehicle and vehicle.kind == "izh":
		_draw_izh(vehicle)
