extends Node
## Настройки игрока: чувствительность мыши и громкость.
## Хранятся отдельно от сохранения игры, в user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"

## Множитель к базовой чувствительности мыши, 0.2–3.
var mouse_sens := 1.0
## Инверсия камеры по вертикали: мышь/палец вверх — смотреть вниз.
var invert_y := false
## Громкость 0–1.
var volume := 0.8
## Громкость фоновой музыки отдельно от звуков.
var music := 0.5
## Автоматическая коробка передач (T в машине переключает).
var auto_gearbox := true
## Детализация: 0 — низкая (без травы и теней), 1 — средняя, 2 — высокая.
## В браузере по умолчанию средняя: WebGL медленнее настольной графики.
## На телефоне — низкая: трава и тени для мобильной графики слишком тяжелы.
## Размер текста и кнопок: 1 — обычный, 1.2 — крупнее, 1.4 — крупный.
var text_scale := 1.0
## Телефон под левую руку: джойстик и руль справа, кнопки слева.
var left_hand := false
## Вибрация на телефоне при ударах и поклёвке.
var vibration := true
## Мини-карта в углу экрана.
var minimap := true
## Пешком — вид от третьего лица (персонаж виден со спины).
var third_person := true
## Ячейка сохранения 1–3.
var slot := 1
var detail := 0 if (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")) \
	else (1 if OS.has_feature("web") else 2)


## Слабый телефон: если игра долго идёт медленно, детализация снижается
## сама (раз в полминуты, не ниже низкой); на низкой — ещё и 3D в половину
## разрешения. В тестах (--no-menu) не трогаем.
var _slow := 0.0
var _auto := not ("--no-menu" in OS.get_cmdline_user_args())


func _process(delta: float) -> void:
	if not _auto or not GameManager.in_game or get_tree().paused:
		_slow = 0.0
		return
	var fps := Engine.get_frames_per_second()
	_slow = _slow + delta if fps > 0 and fps < 24 else maxf(_slow - delta * 2.0, 0.0)
	if _slow < 15.0:
		return
	_slow = -15.0
	if detail > 0:
		set_detail(detail - 1)
		GameManager.notify("Игра шла медленно — детализация снижена до «%s». Вернуть — в «Настройках»" % ["низкая", "средняя"][detail])
	elif get_viewport().scaling_3d_scale > 0.5:
		get_viewport().scaling_3d_scale = 0.5
		GameManager.notify("Игра шла медленно — картинка чуть проще, зато плавнее")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		mouse_sens = clampf(float(cfg.get_value("input", "mouse_sens", 1.0)), 0.2, 3.0)
		invert_y = bool(cfg.get_value("input", "invert_y", false))
		volume = clampf(float(cfg.get_value("audio", "volume", 0.8)), 0.0, 1.0)
		music = clampf(float(cfg.get_value("audio", "music", 0.5)), 0.0, 1.0)
		auto_gearbox = bool(cfg.get_value("driving", "auto_gearbox", true))
		detail = clampi(int(cfg.get_value("graphics", "detail", detail)), 0, 2)
		text_scale = clampf(float(cfg.get_value("ui", "text_scale", 1.0)), 1.0, 1.4)
		left_hand = bool(cfg.get_value("ui", "left_hand", false))
		vibration = bool(cfg.get_value("ui", "vibration", true))
		minimap = bool(cfg.get_value("ui", "minimap", true))
		third_person = bool(cfg.get_value("ui", "third_person", true))
		slot = clampi(int(cfg.get_value("save", "slot", 1)), 1, 3)
	_apply()


func set_mouse_sens(v: float) -> void:
	mouse_sens = clampf(v, 0.2, 3.0)
	_save()


func set_invert_y(v: bool) -> void:
	invert_y = v
	_save()
	changed.emit()


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


func set_text_scale(v: float) -> void:
	text_scale = clampf(v, 1.0, 1.4)
	_save()
	changed.emit()


func set_left_hand(v: bool) -> void:
	left_hand = v
	_save()
	changed.emit()


func set_third_person(v: bool) -> void:
	third_person = v
	_save()
	changed.emit()


func set_minimap(v: bool) -> void:
	minimap = v
	_save()
	changed.emit()


func set_vibration(v: bool) -> void:
	vibration = v
	_save()
	changed.emit()


func set_slot(v: int) -> void:
	slot = clampi(v, 1, 3)
	_save()
	changed.emit()


## Дальность травы по детализации, метры (0 — травы нет).
func grass_range() -> float:
	return [22.0, 45.0, 85.0][detail]


## Дальность обзора, метры: до этого расстояния видно землю и лес
## (дальше — туман и холмы на горизонте).
func view_range() -> float:
	return [900.0, 1300.0, 1800.0][detail]


## Дальность деревьев целиком (дальше — простые силуэты леса), метры.
func tree_range() -> float:
	return [260.0, 380.0, 520.0][detail]


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
	cfg.set_value("input", "invert_y", invert_y)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "music", music)
	cfg.set_value("driving", "auto_gearbox", auto_gearbox)
	cfg.set_value("graphics", "detail", detail)
	cfg.set_value("ui", "text_scale", text_scale)
	cfg.set_value("ui", "left_hand", left_hand)
	cfg.set_value("ui", "vibration", vibration)
	cfg.set_value("ui", "minimap", minimap)
	cfg.set_value("ui", "third_person", third_person)
	cfg.set_value("save", "slot", slot)
	cfg.save(PATH)
