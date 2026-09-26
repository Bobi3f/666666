extends Node
## Настройки игрока: чувствительность мыши и громкость.
## Хранятся отдельно от сохранения игры, в user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"

## Множитель к базовой чувствительности мыши, 0.2–3.
var mouse_sens := 1.0
## Громкость 0–1.
var volume := 0.8
## Автоматическая коробка передач (T в машине переключает).
var auto_gearbox := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		mouse_sens = clampf(float(cfg.get_value("input", "mouse_sens", 1.0)), 0.2, 3.0)
		volume = clampf(float(cfg.get_value("audio", "volume", 0.8)), 0.0, 1.0)
		auto_gearbox = bool(cfg.get_value("driving", "auto_gearbox", true))
	_apply()


func set_mouse_sens(v: float) -> void:
	mouse_sens = clampf(v, 0.2, 3.0)
	_save()


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_apply()
	_save()


func set_auto_gearbox(v: bool) -> void:
	auto_gearbox = v
	_save()
	changed.emit()


func _apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)
	changed.emit()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sens", mouse_sens)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("driving", "auto_gearbox", auto_gearbox)
	cfg.save(PATH)
