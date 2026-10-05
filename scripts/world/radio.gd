extends Node
## Радио в машине: B (на телефоне — кнопка «Радио», на геймпаде — вправо
## на крестовине) переключает: выкл → «Ретро FM» → «Эстрада» → выкл.
##
## Песни — готовые файлы sounds/music/radio_<номер>.wav (их синтезирует
## tools/bake_assets.gd); нет файла — синтезируются тут по кусочку за кадр. Пока радио играет, фоновая музыка притихает. Вышел
## из машины — радио молчит, сел обратно — играет та же станция.

const RATE := 16000

## Станции: название, темп, аккорды [корень, ступени], мелодия по тактам
## (ступени от корня, −1 — пауза), инструмент мелодии, есть ли барабаны.
const STATIONS := [
	{"name": "Ретро FM", "bpm": 124.0, "lead": "square", "drums": true,
		"chords": [[48, [0, 4, 7]], [45, [0, 3, 7]], [41, [0, 4, 7]], [43, [0, 4, 7]],
			[48, [0, 4, 7]], [45, [0, 3, 7]], [41, [0, 4, 7]], [43, [0, 4, 7, 10]]],
		"tunes": [[16, -1, 16, 19, 21, 19, 16, -1], [15, 15, 19, -1, 22, -1, 19, 15],
			[19, -1, 21, 19, 16, -1, 12, -1], [14, 17, 19, 23, -1, 19, 17, -1],
			[24, -1, 23, 21, 19, -1, 16, 19], [19, -1, 15, 12, 15, 19, 22, -1],
			[21, 19, 16, -1, 19, 16, 12, -1], [11, 14, 17, 19, 17, 14, 11, -1]]},
	{"name": "Эстрада", "bpm": 108.0, "lead": "accordion", "drums": false,
		"chords": [[50, [0, 3, 7]], [43, [0, 3, 7]], [48, [0, 4, 7]], [41, [0, 4, 7]],
			[46, [0, 4, 7]], [43, [0, 3, 7]], [45, [0, 4, 7]], [50, [0, 3, 7]]],
		"tunes": [[12, 15, 19, 15, 12, -1, 7, -1], [15, -1, 19, 22, 19, 15, 12, -1],
			[16, 19, 24, -1, 19, 16, 12, -1], [12, -1, 16, 19, 21, 19, 16, -1],
			[16, 19, 21, 19, 16, 12, 16, -1], [15, 19, 22, -1, 19, 15, 12, 10],
			[16, -1, 19, 22, 19, 16, 13, -1], [12, 15, 12, 7, 12, -1, -1, -1]]},
]

## Какая станция выбрана: −1 — выключено
var station := -1
## Включено с телефона: играет и пешком
var phone := false
var _player: AudioStreamPlayer
var _streams := {}  # номер станции → AudioStream
## Что собираем сейчас: номер станции, события, буфер, байты
var _build := -1
var _events: Array = []
var _ev_i := 0
var _buf := PackedFloat32Array()
var _bytes := PackedByteArray()
var _enc_i := 0
var _rng := RandomNumberGenerator.new()
## Пока радио играет, раз в полторы минуты — короткая сводка между песнями
var _news_in := 20.0
var _news_i := 0

const NEWS := [
	"В Каменке рекордный урожай картошки — не забывайте поливать огороды!",
	"Автосалон у въезда в город: «Нива», «Волга» и ГАЗ-53 ждут хозяев.",
	"Бригадир колхоза «Заря» ищет трактористов на пахоту.",
	"ГАИ напоминает: у Каменки — не быстрее шестидесяти!",
	"Рыбаки говорят: на пруду снова видели щуку.",
	"Грибники, осенью в лесу грибов вдвое больше. Мухоморы не брать!",
	"Склад в городе набирает грузчиков — платят сразу.",
	"Такси у площади Мира: водители с правами, подходите!",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("radio")
	_rng.seed = 91
	_player = AudioStreamPlayer.new()
	add_child(_player)
	for i in STATIONS.size():
		if Assets.has_sound("music/radio_%d" % i):
			_streams[i] = Assets.sound("music/radio_%d" % i, Callable())
	SettingsManager.changed.connect(_apply_volume)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_B:
		toggle()


## Следующая станция по кругу. Работает только в машине.
func toggle() -> void:
	if GameManager.vehicle == null:
		return
	station += 1
	if station >= STATIONS.size():
		station = -1
	SoundLibrary.play("click", -4.0)
	if station < 0:
		GameManager.notify("Радио выключено")
	elif _streams.has(station):
		GameManager.notify("Радио: «%s»" % STATIONS[station].name)
	else:
		GameManager.notify("Радио: «%s» — настраивается…" % STATIONS[station].name)
		_start_build(station)
	_sync()


## Музыка с телефона: станция i играет и пешком.
func play_on_phone(i: int) -> void:
	station = i
	phone = true
	if not _streams.has(i):
		_start_build(i)
	_sync()


func stop_phone() -> void:
	phone = false
	station = -1
	_sync()


## Сводка: погода, ярмарка, сезон или местная новость.
func _news() -> String:
	_news_i += 1
	match _news_i % 4:
		0:
			return "Синоптики: сейчас %s. %s" % [WeatherManager.name_text(),
				"Возможна гроза — берегитесь молний!" if WeatherManager.season() == 0 else "Одевайтесь по погоде!"]
		1:
			if TimeManager.day % 7 == 6:
				return "Завтра воскресенье — ярмарка на площади Мира с восьми до четырёх!"
			if TimeManager.day % 7 == 0:
				return "Сегодня ярмарка на площади Мира: рыба дороже, лотерея, пирожки!"
			var left := WeatherManager.SEASON_DAYS - (TimeManager.day - 1) % WeatherManager.SEASON_DAYS
			var next: String = WeatherManager.SEASONS[(WeatherManager.season() + 1) % 4]
			return "До смены сезона — %d дн. Скоро %s!" % [left, next]
	return NEWS[_rng.randi() % NEWS.size()]


func playing() -> bool:
	return _player.playing


func _process(_delta: float) -> void:
	if _build >= 0:
		_step_build()
	_player.stream_paused = get_tree().paused
	if not get_tree().paused:
		_sync()
		if _player.playing:
			_news_in -= _delta
			if _news_in <= 0.0:
				_news_in = 90.0
				GameManager.notify("%s: «%s»" % [STATIONS[station].name, _news()])


## Играть нужную станцию, если сидим в машине, иначе молчать.
func _sync() -> void:
	var want := station >= 0 and (GameManager.vehicle != null or phone) and _streams.has(station)
	if want:
		if _player.stream != _streams[station] or not _player.playing:
			var restart: bool = _player.stream != _streams[station]
			_player.stream = _streams[station]
			_apply_volume()
			_player.play(0.0 if restart else _player.get_playback_position())
	elif _player.playing:
		_player.stop()
	SoundLibrary.duck_music(_player.playing)


func _apply_volume() -> void:
	_player.volume_db = linear_to_db(maxf(SettingsManager.music, 0.05) * 0.6)


func _midi(n: int) -> float:
	return 440.0 * pow(2.0, (n - 69) / 12.0)


func _start_build(i: int) -> void:
	if _build == i:
		return
	_build = i
	_events.clear()
	_ev_i = 0
	_enc_i = 0
	var st: Dictionary = STATIONS[i]
	var beat: float = 60.0 / float(st.bpm)
	var bar := beat * 4.0
	var chords: Array = st.chords
	_buf.resize(int(bar * chords.size() * 2.0 * RATE))
	_buf.fill(0.0)
	# Два прохода: второй раз мелодия на октаву выше — чтобы не надоедало
	for rep in 2:
		for c in chords.size():
			var root: int = chords[c][0]
			var steps: Array = chords[c][1]
			var t0 := (rep * chords.size() + c) * bar
			for s in steps:
				_events.append([t0, bar, _midi(root + 12 + int(s)), "pad", 0.035])
			if st.drums:
				# Бас восьмыми, бочка на раз и три, малый на два и четыре, хэт восьмыми
				for k in 8:
					_events.append([t0 + k * beat * 0.5, beat * 0.45, _midi(root - 12 + (7 if k % 4 == 3 else 0)), "bass", 0.16])
					_events.append([t0 + k * beat * 0.5, 0.05, 0.0, "hat", 0.05])
				for k in 4:
					_events.append([t0 + k * beat, 0.25, 0.0, "kick" if k % 2 == 0 else "snare", 0.35 if k % 2 == 0 else 0.18])
			else:
				# «Умпа»: бас на раз и три, аккорд на два и четыре
				for k in 4:
					if k % 2 == 0:
						_events.append([t0 + k * beat, beat * 0.9, _midi(root - 12 + (0 if k == 0 else 7)), "bass", 0.2])
					else:
						for s in steps:
							_events.append([t0 + k * beat, beat * 0.5, _midi(root + int(s)), "accordion", 0.04])
			var tune: Array = st.tunes[c]
			for k in 8:
				if int(tune[k]) >= 0:
					var n := root + 12 + int(tune[k]) + (12 if rep == 1 and st.drums else 0)
					_events.append([t0 + k * beat * 0.5, beat * 0.48, _midi(n), st.lead, 0.1])


## Собрать станцию целиком сразу — для tools/bake_assets.gd.
func render_now(i: int) -> AudioStreamWAV:
	_start_build(i)
	while _build >= 0:
		_step_build()
	return _streams[i]


func _step_build() -> void:
	var t0 := Time.get_ticks_usec()
	while _ev_i < _events.size() and Time.get_ticks_usec() - t0 < 3000:
		_render(_events[_ev_i])
		_ev_i += 1
	if _ev_i < _events.size():
		return
	if _bytes.size() != _buf.size() * 2:
		_bytes.resize(_buf.size() * 2)
	while _enc_i < _buf.size() and Time.get_ticks_usec() - t0 < 3000:
		var end := mini(_enc_i + 4000, _buf.size())
		for i in range(_enc_i, end):
			_bytes.encode_s16(i * 2, int(clampf(_buf[i], -1.0, 1.0) * 32000.0))
		_enc_i = end
	if _enc_i < _buf.size():
		return
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = _bytes.duplicate()
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = _buf.size()
	_streams[_build] = s
	_build = -1
	# Пока собиралась, переключили на другую станцию — собираем её
	if station >= 0 and not _streams.has(station):
		_start_build(station)


func _render(e: Array) -> void:
	var start := int(float(e[0]) * RATE)
	var len := float(e[1])
	var n := int(len * RATE)
	var f: float = e[2]
	var kind: String = e[3]
	var vol: float = e[4]
	var size := _buf.size()
	var w := TAU * f / RATE
	for j in n:
		var t := float(j) / RATE
		var v := 0.0
		match kind:
			"pad":
				v = sin(w * j) * minf(t / 0.2, 1.0) * minf((len - t) / 0.3, 1.0)
			"bass":
				v = (sin(w * j) + 0.3 * sin(2.0 * w * j)) * exp(-t * 4.0) * minf(t * 80.0, 1.0)
			"square":
				# Мягкий «квадрат» из нечётных гармоник
				v = (sin(w * j) + sin(3.0 * w * j) / 3.0 + sin(5.0 * w * j) / 5.0) * exp(-t * 3.0) * minf(t * 150.0, 1.0)
			"accordion":
				# Баян: два чуть расстроенных голоса и гармоники, ровная громкость
				var vib := sin(t * 34.0) * 0.004
				v = (sin(w * j * (1.0 + vib)) + 0.5 * sin(2.0 * w * j * 1.003) + 0.3 * sin(3.0 * w * j)) * minf(t / 0.03, 1.0) * minf((len - t) / 0.05, 1.0)
			"kick":
				v = sin(TAU * (50.0 + 90.0 * exp(-t * 30.0)) * t) * exp(-t * 12.0)
			"snare":
				v = (_rng.randf() * 2.0 - 1.0) * exp(-t * 20.0) + 0.3 * sin(TAU * 190.0 * t) * exp(-t * 25.0)
			"hat":
				v = (_rng.randf() * 2.0 - 1.0) * exp(-t * 90.0)
		_buf[(start + j) % size] += v * vol
