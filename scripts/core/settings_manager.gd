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
## Частота кадров на экране — понять, где игра тормозит.
var show_fps := false
## Ограничение кадров: индекс в FPS_LIMITS. 0 — как экран (вертикальная
## синхронизация: 60 кадров на обычном мониторе), дальше — без синхронизации
## до 60, 120, 144 кадров или без ограничения. На компьютере — 120: на
## мониторе 120–144 Гц игра идёт плавнее, а видеокарта не греется зря.
const FPS_LIMITS := [0, 60, 120, 144, 1000]
const FPS_NAMES := ["Как экран", "60", "120", "144", "Без огранич."]
var fps_limit := 0 if (OS.has_feature("mobile") or OS.has_feature("web")) else 2
## Сглаживание краёв на компьютере: 0 — выкл, 1 — 2x, 2 — 4x (на высокой детализации).
const AA_NAMES := ["Выкл", "2x", "4x"]
var aa := 1
## Чёткость 3D на компьютере: доля разрешения экрана (интерфейс всегда чёткий).
const RENDER_SCALES := [1.0, 0.85, 0.75]
var scale_i := 0
## Держать FPS: не хватает кадров — сама по шагам выключает сглаживание и
## снижает чёткость 3D (мир, свет, тени и трава остаются). Только на этот
## запуск — в настройки не пишется.
var auto_perf := true
var _perf_step := 0
var _perf_slow := 0.0
## Пешком — вид от третьего лица (персонаж виден со спины).
var third_person := true
## Профиль игрока: имя и фамилия — в меню, на правах, в окне GEARCOIN.
var first_name := ""
var last_name := ""
## Ход времени: сутки за 24, 48 или 96 минут — медленнее, ближе к жизни.
const TIME_RATES := [1.0, 0.5, 0.25]
const TIME_NAMES := ["Обычный", "Медленный", "Очень медл."]
var time_speed := 0
## Машины на трассе (попутки и рейсовые автобусы): выключил — дороги пустые.
var traffic := true
## Ячейка сохранения 1–3.
var slot := 1
## Язык: "ru" или "en". В браузере и на телефоне при первом запуске — по
## языку системы (русский, украинский, белорусский — русский), на компьютере
## и в тестах — русский.
var lang := _system_lang()
## Переводчик текущего языка (null — русский) и все созданные, по языкам
var _english: LangTranslation
var _tr := {}
## Свои клавиши: клавиша действия в игре → какой её жмёт игрок (только
## изменённые). См. KeyRemap.
var key_map := {}
## Свои места кнопок на телефоне: "подпись|режим" или "wheel" →
## [x и y центра долей экрана, размер]. См. touch_controls.gd.
var touch_layout := {}
var remap: KeyRemap
var detail := 0 if (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")) else 2


static func _phone() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


## Слабый телефон: если игра долго идёт медленно, детализация снижается
## сама (раз в полминуты, не ниже низкой); на низкой — ещё и 3D в половину
## разрешения. В тестах (--no-menu) не трогаем.
var _slow := 0.0
## Слабый телефон на низкой детализации: 3D ещё на четверть грубее.
## На iPhone в Safari графика медленнее, чем в Chrome на Android: сразу чуть
## меньше строк 3D-картинки (дальше игра сама упростит, если тормозит)
var _lines_k := 0.85 if OS.has_feature("web_ios") else 1.0
var _auto := not ("--no-menu" in OS.get_cmdline_user_args())


func _process(delta: float) -> void:
	if not _auto or not GameManager.in_game or get_tree().paused:
		_slow = 0.0
		_perf_slow = 0.0
		return
	var fps := Engine.get_frames_per_second()
	_keep_fps(fps, delta)
	_try_better(fps, delta)
	# Ниже 28 кадров дольше 8 секунд — проще картинку (раньше ждали 15 с при 24)
	_slow = _slow + delta if fps > 0 and fps < 28 else maxf(_slow - delta * 2.0, 0.0)
	if _slow < 8.0:
		return
	_slow = -15.0
	if detail > 0:
		set_detail(detail - 1)
		GameManager.notify("Игра шла медленно — детализация снижена до «%s». Вернуть — в «Настройках»" % ["низкая", "средняя"][detail])
	elif _lines_k > 0.75:
		_lines_k = 0.75
		changed.emit()
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
		# Раньше на компьютере в браузере по умолчанию была средняя — один
		# раз поднимаем до высокой (дальше игра сама снизит, если тормозит)
		if not cfg.has_section_key("graphics", "v") and detail == 1 and not _phone():
			detail = 2
		text_scale = clampf(float(cfg.get_value("ui", "text_scale", 1.0)), 1.0, 1.4)
		left_hand = bool(cfg.get_value("ui", "left_hand", false))
		vibration = bool(cfg.get_value("ui", "vibration", true))
		minimap = bool(cfg.get_value("ui", "minimap", true))
		show_fps = bool(cfg.get_value("ui", "show_fps", false))
		fps_limit = clampi(int(cfg.get_value("graphics", "fps_limit", fps_limit)), 0, FPS_LIMITS.size() - 1)
		aa = clampi(int(cfg.get_value("graphics", "aa", aa)), 0, AA_NAMES.size() - 1)
		scale_i = clampi(int(cfg.get_value("graphics", "scale", scale_i)), 0, RENDER_SCALES.size() - 1)
		auto_perf = bool(cfg.get_value("graphics", "auto_perf", auto_perf))
		_perf_step = clampi(int(cfg.get_value("graphics", "perf_step", 0)), 0, PERF_LADDER.size())
		_hw_checked = cfg.has_section_key("graphics", "hw")
		gpu_name = str(cfg.get_value("graphics", "hw", ""))
		third_person = bool(cfg.get_value("ui", "third_person", true))
		first_name = str(cfg.get_value("profile", "first", ""))
		last_name = str(cfg.get_value("profile", "last", ""))
		time_speed = clampi(int(cfg.get_value("game", "time_speed", 0)), 0, TIME_RATES.size() - 1)
		traffic = bool(cfg.get_value("game", "traffic", true))
		slot = clampi(int(cfg.get_value("save", "slot", 1)), 1, 3)
		lang = _known_lang(str(cfg.get_value("ui", "lang", lang)))
		var km: Variant = cfg.get_value("controls", "keys", {})
		key_map = (km as Dictionary).duplicate() if km is Dictionary else {}
		var tl: Variant = cfg.get_value("controls", "touch", {})
		touch_layout = (tl as Dictionary).duplicate(true) if tl is Dictionary else {}
	remap = KeyRemap.new()
	remap.name = "KeyRemap"
	get_tree().root.add_child.call_deferred(remap)
	_apply_lang()
	_apply()
	_first_run_hw.call_deferred()


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
	_perf_step = 0
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


func set_show_fps(v: bool) -> void:
	show_fps = v
	_save()
	changed.emit()


func set_minimap(v: bool) -> void:
	minimap = v
	_save()
	changed.emit()


func set_lang(v: String) -> void:
	lang = _known_lang(v)
	_apply_lang()
	_save()
	changed.emit()


## Языки игры: русский (как в коде), украинский, английский.
const LANGS := ["ru", "uk", "en"]


static func _known_lang(v: String) -> String:
	return v if v in LANGS else "ru"


static func _system_lang() -> String:
	if not (OS.has_feature("web") or OS.has_feature("mobile")):
		return "ru"
	match OS.get_locale_language():
		"uk":
			return "uk"
		"ru", "be":
			return "ru"
	return "en"


## Английский и украинский — свой перевод «на лету» (LangTranslation),
## русский — как в коде.
func _apply_lang() -> void:
	if lang != "ru" and not _tr.has(lang):
		_tr[lang] = LangTranslation.new(lang)
		TranslationServer.add_translation(_tr[lang])
	_english = _tr.get(lang)
	TranslationServer.set_locale(lang)


## Переводчик — скрипт: убрать его из TranslationServer, пока скрипты живы,
## иначе игра падает при выходе.
func _exit_tree() -> void:
	for k in _tr:
		TranslationServer.remove_translation(_tr[k])
	_tr.clear()
	_english = null


## Перевести строку для рисования (draw_string) — надписи и кнопки
## переводятся сами.
func t(s: String) -> String:
	return _english.text(s) if lang != "ru" and _english else s


func set_vibration(v: bool) -> void:
	vibration = v
	_save()
	changed.emit()


## Назначить клавишу user действию game_key. Если она уже у другого
## действия — меняются местами.
func bind_key(game_key: int, user: int) -> void:
	var old := KeyRemap.key_for(game_key)
	for a in KeyRemap.ACTIONS:
		var other: int = a[0]
		if other != game_key and KeyRemap.key_for(other) == user:
			_set_bind(other, old)
	_set_bind(game_key, user)
	_save()
	changed.emit()


func _set_bind(game_key: int, user: int) -> void:
	if user == game_key:
		key_map.erase(game_key)
	else:
		key_map[game_key] = user


func reset_keys() -> void:
	key_map = {}
	_save()
	changed.emit()


func set_touch_layout(d: Dictionary) -> void:
	touch_layout = d.duplicate(true)
	_save()
	changed.emit()


func set_slot(v: int) -> void:
	slot = clampi(v, 1, 3)
	_save()
	changed.emit()


## Дальность травы по детализации, метры (0 — травы нет).
func grass_range() -> float:
	return [22.0, 45.0, 85.0][eff_detail()]


## Дальность обзора, метры: до этого расстояния видно землю и лес
## (дальше — туман и холмы на горизонте).
func view_range() -> float:
	return [900.0, 1300.0, 1800.0][eff_detail()]


## Дальность деревьев целиком (дальше — простые силуэты леса), метры.
func tree_range() -> float:
	return [260.0, 380.0, 520.0][eff_detail()]


## Дальность подробных деревьев, метры: дальше — упрощённые (до tree_range).
func tree_lod_range() -> float:
	return [110.0, 150.0, 200.0][eff_detail()]


## Дальность мелких деталей мира (штакетник, рамы, ящики), метры.
func small_range() -> float:
	return [100.0, 140.0, 200.0][eff_detail()]


## Телефон: сколько строк по высоте у 3D-картинки (дальше растягивается).
func render_lines() -> float:
	return [560.0, 680.0, 820.0][detail] * _lines_k


## Дальность теней от солнца (0 — без теней).
func shadow_range() -> float:
	return [0.0, 45.0, 85.0][eff_detail()]


## Сколько кадров хотим: потолок из настроек, но не больше частоты экрана
## при синхронизации.
func fps_target() -> float:
	var hz := DisplayServer.screen_get_refresh_rate()
	if hz <= 0.0:
		hz = 60.0
	var lim: int = FPS_LIMITS[fps_limit]
	if lim == 0 or _vsync_on():
		return hz
	return float(mini(lim, 240))


## Частота экрана, Гц (неизвестна — 60).
func screen_hz() -> float:
	var hz := DisplayServer.screen_get_refresh_rate()
	return hz if hz > 0.0 else 60.0


## Синхронизация с экраном: «Как экран» или потолок не ниже частоты экрана —
## больше кадров экран всё равно не покажет, а без синхронизации картинка
## рвётся и дёргается. Ниже частоты (120 на 144 Гц) — без неё, с потолком.
func _vsync_on() -> bool:
	var lim: int = FPS_LIMITS[fps_limit]
	return lim == 0 or (lim < 1000 and float(lim) >= screen_hz() - 1.0)


## «Держать FPS»: шаги вниз по очереди — сглаживание, чёткость, детализация
## (тени, блеск, трава, дальность), снова чёткость — пока не наберётся цель.
## [что, значение]: aa — выключить; scale — доля разрешения; detail — на
## сколько ступеней ниже выбранной детализации.
const PERF_LADDER := [["aa", 0], ["scale", 0.85], ["detail", 1], ["scale", 0.75], ["detail", 2],
	["scale", 0.62], ["scale", 0.5]]
const PERF_TEXT := ["сглаживание краёв выключено", "чёткость 3D — 85 %", "тени и блеск попроще, трава ближе",
	"чёткость 3D — 75 %", "детализация низкая", "чёткость 3D — 62 %", "чёткость 3D — 50 %"]


## Держать FPS на компьютере: меньше 85 % от цели — шаг вниз. Совсем мало
## (меньше половины) — через 2 секунды, иначе через 5; после шага ждём 4 с,
## пока картинка перестроится. Шаг запоминается до следующего запуска.
func _keep_fps(fps: float, delta: float) -> void:
	if not auto_perf or GameManager.touch_mode or _perf_step >= PERF_LADDER.size() or fps <= 0.0:
		return
	var target := fps_target()
	_perf_slow = _perf_slow + delta if fps < target * 0.85 else maxf(_perf_slow - delta, minf(_perf_slow, 0.0))
	if _perf_slow < (2.0 if fps < target * 0.5 else 5.0):
		return
	_perf_slow = -4.0
	# Только что поднимались и снова не хватает — выше этого шага не пробуем
	if _tried_up:
		_ceiling = _perf_step + 1
		_tried_up = false
	_perf_step += 1
	_save()
	changed.emit()
	GameManager.notify("Чтобы держать %d FPS: %s. Вернуть — в «Настройках»" % [int(target), PERF_TEXT[_perf_step - 1]])


## Запас кадров держится 20 секунд — шаг обратно вверх (картинка лучше).
## Если на этом шаге снова не хватило — выше него в этом запуске не лезем.
var _good := 0.0
var _ceiling := 0


func _try_better(fps: float, delta: float) -> void:
	if not auto_perf or GameManager.touch_mode or _perf_step <= _ceiling or fps <= 0.0:
		_good = 0.0
		return
	# Потолок кадров срезает FPS ровно на цели — «хватает» уже с 97 %
	_good = _good + delta if fps >= fps_target() * 0.97 else 0.0
	if _good < 20.0:
		return
	_good = 0.0
	_perf_slow = -6.0
	_perf_step -= 1
	_tried_up = true
	_save()
	changed.emit()


var _tried_up := false


## Видеокарта компьютера — при первом запуске: встроенная (Intel, AMD
## Radeon Graphics) или программная — сразу несколько шагов вниз, чтобы
## не начинать с самой тяжёлой картинки. Дальше «Держать FPS» подстроит.
func hardware_preset(adapter: String, cores: int) -> int:
	var a := adapter.to_lower()
	var step := 0
	if a.contains("llvmpipe") or a.contains("swiftshader") or a.contains("basic render") or a.contains("software"):
		step = 5
	elif (a.contains("intel") and not a.contains("arc")) or a.contains("radeon(tm) graphics") or a.contains("radeon graphics") \
			or a.contains("vega") or a.contains("uhd") or a.contains("iris") or a.contains("mali") or a.contains("adreno"):
		step = 3
	if cores > 0 and cores <= 4:
		step += 1
	return mini(step, PERF_LADDER.size())


func _first_run_hw() -> void:
	if not _auto or _phone() or OS.has_feature("web"):
		return
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	if cfg.has_section_key("graphics", "hw"):
		return
	gpu_name = RenderingServer.get_video_adapter_name()
	_perf_step = hardware_preset(gpu_name, OS.get_processor_count())
	_hw_checked = true
	_save()
	changed.emit()


## Видеокарта — для строки в настройках.
var gpu_name := ""
var _hw_checked := false


## Сколько ступеней детализации снял «Держать FPS».
func _perf_detail_drop() -> int:
	var drop := 0
	for i in mini(_perf_step, PERF_LADDER.size()):
		if PERF_LADDER[i][0] == "detail":
			drop = int(PERF_LADDER[i][1])
	return drop


## Детализация сейчас (с учётом «Держать FPS»): от неё дальности, тени, блеск.
func eff_detail() -> int:
	return maxi(detail - _perf_detail_drop(), 0)


## Сглаживание сейчас (с учётом «Держать FPS»).
func effective_aa() -> int:
	return 0 if _perf_step >= 1 else aa


## Доля разрешения 3D сейчас (с учётом «Держать FPS»).
func effective_scale() -> float:
	var s: float = RENDER_SCALES[scale_i]
	for i in mini(_perf_step, PERF_LADDER.size()):
		if PERF_LADDER[i][0] == "scale":
			s = minf(s, float(PERF_LADDER[i][1]))
	return s


func set_aa(i: int) -> void:
	aa = clampi(i, 0, AA_NAMES.size() - 1)
	_perf_step = 0
	_save()
	changed.emit()


func set_scale(i: int) -> void:
	scale_i = clampi(i, 0, RENDER_SCALES.size() - 1)
	_perf_step = 0
	_save()
	changed.emit()


func set_auto_perf(v: bool) -> void:
	auto_perf = v
	_perf_step = 0
	_save()
	changed.emit()


## Записать имя и фамилию: лишние пробелы убираем, длину ограничиваем.
func set_player_name(first: String, last: String) -> void:
	first_name = first.strip_edges().left(20)
	last_name = last.strip_edges().left(24)
	_save()
	changed.emit()


## «Имя Фамилия» или пусто, если профиль не заполнен.
func full_name() -> String:
	return ("%s %s" % [first_name, last_name]).strip_edges()


## Во сколько раз медленнее обычного идут игровые часы.
func time_rate() -> float:
	return TIME_RATES[time_speed]


func set_traffic(v: bool) -> void:
	traffic = v
	_save()
	changed.emit()


func set_time_speed(i: int) -> void:
	time_speed = clampi(i, 0, TIME_RATES.size() - 1)
	_save()
	changed.emit()


func set_fps_limit(i: int) -> void:
	fps_limit = clampi(i, 0, FPS_LIMITS.size() - 1)
	_perf_step = 0
	_apply_fps()
	_save()


## Синхронизация с экраном и потолок кадров. В браузере частоту задаёт
## сам браузер (по экрану) — там только потолок.
func _apply_fps() -> void:
	var lim: int = FPS_LIMITS[fps_limit]
	var sync := _vsync_on()
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		# Адаптивная: не успевает кадр — показывает сразу, без провала до
		# половины частоты (где не поддерживается — обычная синхронизация)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE if sync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0 if sync or lim >= 1000 else lim


func _apply() -> void:
	_apply_fps()
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
	cfg.set_value("graphics", "v", 2)
	cfg.set_value("graphics", "fps_limit", fps_limit)
	cfg.set_value("graphics", "aa", aa)
	cfg.set_value("graphics", "scale", scale_i)
	cfg.set_value("graphics", "auto_perf", auto_perf)
	cfg.set_value("graphics", "perf_step", _perf_step)
	if _hw_checked:
		cfg.set_value("graphics", "hw", gpu_name)
	cfg.set_value("ui", "text_scale", text_scale)
	cfg.set_value("ui", "left_hand", left_hand)
	cfg.set_value("ui", "vibration", vibration)
	cfg.set_value("ui", "minimap", minimap)
	cfg.set_value("ui", "show_fps", show_fps)
	cfg.set_value("ui", "lang", lang)
	cfg.set_value("ui", "third_person", third_person)
	cfg.set_value("profile", "first", first_name)
	cfg.set_value("profile", "last", last_name)
	cfg.set_value("game", "time_speed", time_speed)
	cfg.set_value("game", "traffic", traffic)
	cfg.set_value("save", "slot", slot)
	cfg.set_value("controls", "keys", key_map)
	cfg.set_value("controls", "touch", touch_layout)
	cfg.save(PATH)
