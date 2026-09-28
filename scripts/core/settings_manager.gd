extends Node
## Настройки игрока: чувствительность мыши и громкость.
## Хранятся отдельно от сохранения игры, в user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"

## Множитель к базовой чувствительности мыши, 0.2–3.
var mouse_sens := 1.0
## Громкость 0–1.
var volume := 0.8
## Громкость фоновой музыки отдельно от звуков.
var music := 0.5
## Автоматическая коробка передач (T в машине переключает).
var auto_gearbox := true
## Детализация: 0 — низкая (без травы и теней), 1 — средняя, 2 — высокая.
## В браузере по умолчанию средняя: WebGL медленнее настольной графики.
## На телефоне — низкая: трава и тени для мобильной графики слишком тяжелы.
var detail := 0 if (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")) \
	else (1 if OS.has_feature("web") else 2)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		mouse_sens = clampf(float(cfg.get_value("input", "mouse_sens", 1.0)), 0.2, 3.0)
		volume = clampf(float(cfg.get_value("audio", "volume", 0.8)), 0.0, 1.0)
		music = clampf(float(cfg.get_value("audio", "music", 0.5)), 0.0, 1.0)
		auto_gearbox = bool(cfg.get_value("driving", "auto_gearbox", true))
		detail = clampi(int(cfg.get_value("graphics", "detail", detail)), 0, 2)
	_apply()


func set_mouse_sens(v: float) -> void:
	mouse_sens = clampf(v, 0.2, 3.0)
	_save()


func set_music(v: float) -> void:
	music = clampf(v, 0.0, 1.0)
	_save()
	changed.emit()


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_apply()
	_save()


func set_auto_gearbox(v: bool) -> void:
	auto_gearbox = v
	_save()
	changed.emit()


func set_detail(v: int) -> void:
	detail = clampi(v, 0, 2)
	_save()
	changed.emit()


## Дальность травы по детализации, метры (0 — травы нет).
func grass_range() -> float:
	return [0.0, 40.0, 75.0][detail]


## Дальность теней от солнца (0 — без теней).
func shadow_range() -> float:
	return [0.0, 45.0, 70.0][detail]


func _apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)
	changed.emit()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sens", mouse_sens)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "music", music)
	cfg.set_value("driving", "auto_gearbox", auto_gearbox)
	cfg.set_value("graphics", "detail", detail)
	cfg.save(PATH)
