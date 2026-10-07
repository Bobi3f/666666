extends Node
## Все звуки игры — готовые файлы в sounds/ (effects/, music/), их заранее
## синтезирует tools/bake_assets.gd этим же кодом. Нет файла — звук
## синтезируется при запуске, как раньше (см. Assets).
##
## play(name) — звук интерфейса или «в голове» игрока (шаги, касса);
## play_at(name, pos) — звук в мире, тише с расстоянием;
## stream(name) — сам звук, для постоянных источников (мотор, дождь).

const RATE := 22050

var _streams := {}
## Как синтезировать каждый звук: имя → () -> AudioStreamWAV.
var _makers := {}
var _rng := RandomNumberGenerator.new()

# --- Фоновая музыка ---------------------------------------------------------
## Мелодия собирается понемногу в фоне (несколько миллисекунд за кадр),
## чтобы игра не подвисала на старте, особенно в браузере и на телефоне.
const MUSIC_RATE := 16000
const MUSIC_BPM := 96.0
var music_player: AudioStreamPlayer
var _music_events: Array = []  # [начало, длина, частота, тип, громкость]
var _music_i := 0
var _music_buf := PackedFloat32Array()
var _music_wanted := false
var _music_bytes := PackedByteArray()
var _enc_i := 0
## Играет радио в машине — фоновая музыка притихает.
var _ducked := false


func _ready() -> void:
	_rng.seed = 7
	process_mode = Node.PROCESS_MODE_ALWAYS
	_makers["step"] = func() -> AudioStreamWAV: return _make(_step(), false)
	_makers["land"] = func() -> AudioStreamWAV: return _make(_thud(0.18, 70.0), false)
	_makers["jump"] = func() -> AudioStreamWAV: return _make(_thud(0.1, 110.0), false)
	_makers["engine"] = func() -> AudioStreamWAV: return _make(_engine(), true)
	_makers["starter"] = func() -> AudioStreamWAV: return _make(_starter(), false)
	_makers["stall"] = func() -> AudioStreamWAV: return _make(_stall(), false)
	_makers["grind"] = func() -> AudioStreamWAV: return _make(_grind(), false)
	_makers["crash"] = func() -> AudioStreamWAV: return _make(_crash(), false)
	_makers["cash"] = func() -> AudioStreamWAV: return _make(_cash(), false)
	_makers["click"] = func() -> AudioStreamWAV: return _make(_tone(1200.0, 0.04, 0.3), false)
	_makers["bird"] = func() -> AudioStreamWAV: return _make(_bird(), false)
	_makers["crickets"] = func() -> AudioStreamWAV: return _make(_crickets(), true)
	_makers["bark"] = func() -> AudioStreamWAV: return _make(_bark(), false)
	_makers["rain"] = func() -> AudioStreamWAV: return _make(_rain(), true)
	_makers["chicken"] = func() -> AudioStreamWAV: return _make(_chicken(), false)
	_makers["horn"] = func() -> AudioStreamWAV: return _make(_horn(), false)
	_makers["siren"] = func() -> AudioStreamWAV: return _make(_siren(), true)
	_makers["bell"] = func() -> AudioStreamWAV: return _make(_bell(), false)
	_makers["hammer"] = func() -> AudioStreamWAV: return _make(_hammer(), false)
	_makers["splash"] = func() -> AudioStreamWAV: return _make(_splash(), false)
	_makers["skid"] = func() -> AudioStreamWAV: return _make(_skid(), true)
	_makers["quest"] = func() -> AudioStreamWAV: return _make(_quest(), false)
	_makers["moo"] = func() -> AudioStreamWAV: return _make(_moo(), false)
	_makers["gravel"] = func() -> AudioStreamWAV: return _make(_gravel(), true)
	_makers["step_grass"] = func() -> AudioStreamWAV: return _make(_step_grass(), false)
	_makers["rooster"] = func() -> AudioStreamWAV: return _make(_rooster(), false)
	_makers["thunder"] = func() -> AudioStreamWAV: return _make(_thunder(), false)
	_makers["whistle"] = func() -> AudioStreamWAV: return _make(_whistle(), false)
	_makers["step_snow"] = func() -> AudioStreamWAV: return _make(_step_snow(), false)
	_makers["grass"] = func() -> AudioStreamWAV: return _make(_grass(), true)
	_makers["engine_moped"] = func() -> AudioStreamWAV: return _make(_engine_moped(), true)
	_makers["engine_moto"] = func() -> AudioStreamWAV: return _make(_engine_moto(), true)
	_makers["engine_izh"] = func() -> AudioStreamWAV: return _make(_engine_izh(), true)
	_makers["engine_diesel"] = func() -> AudioStreamWAV: return _make(_engine_diesel(), true)
	_makers["engine_tractor"] = func() -> AudioStreamWAV: return _make(_engine_tractor(), true)
	_makers["engine_volga"] = func() -> AudioStreamWAV: return _make(_engine_volga(), true)
	_makers["engine_zaz"] = func() -> AudioStreamWAV: return _make(_engine_zaz(), true)
	# Голоса людей: смех, крики, гомон толпы, болельщики
	_makers["laugh_man"] = func() -> AudioStreamWAV: return _make(_laugh(5, 165.0, 120.0, "а", 1.0, 0.11, 0.06, 0.06), false)
	_makers["laugh_woman"] = func() -> AudioStreamWAV: return _make(_laugh(5, 300.0, 250.0, "а", 1.17, 0.09, 0.05, 0.05), false)
	_makers["laugh_kid"] = func() -> AudioStreamWAV: return _make(_laugh(6, 400.0, 470.0, "и", 1.3, 0.07, 0.045, 0.04), false)
	_makers["shout_hey"] = func() -> AudioStreamWAV: return _make(_shout_hey(), false)
	_makers["shout_yahoo"] = func() -> AudioStreamWAV: return _make(_shout_yahoo(), false)
	_makers["kids_play"] = func() -> AudioStreamWAV: return _make(_kids_play(), false)
	_makers["cheer"] = func() -> AudioStreamWAV: return _make(_cheer(), false)
	_makers["auu"] = func() -> AudioStreamWAV: return _make(_auu(), false)
	_makers["chatter"] = func() -> AudioStreamWAV: return _make(_chatter(), true)
	# Уличный музыкант: дворовая песня под «восьмёрку» и перебор
	_makers["busker_0"] = func() -> AudioStreamWAV: return _make(_busker_song(0), false)
	_makers["busker_1"] = func() -> AudioStreamWAV: return _make(_busker_song(1), false)
	for n in _makers:
		_streams[n] = Assets.sound("effects/" + n, _makers[n])
	SettingsManager.changed.connect(_apply_music_volume)


## Включить фоновую музыку: соберётся за пару секунд и заиграет петлёй.
func start_music() -> void:
	if _music_wanted:
		return
	_music_wanted = true
	if Assets.has_sound("music/music"):
		_start_player(Assets.sound("music/music", Callable()))
		return
	_plan_music()


func music_ready() -> bool:
	return music_player != null


func _process(_delta: float) -> void:
	if not _music_wanted or music_player != null:
		return
	var t0 := Time.get_ticks_usec()
	while _music_i < _music_events.size() and Time.get_ticks_usec() - t0 < 4000:
		_render_event(_music_events[_music_i])
		_music_i += 1
	if _music_i < _music_events.size():
		return
	# Перевод в 16 бит — тоже частями
	if _music_bytes.size() != _music_buf.size() * 2:
		_music_bytes.resize(_music_buf.size() * 2)
	while _enc_i < _music_buf.size() and Time.get_ticks_usec() - t0 < 4000:
		var end := mini(_enc_i + 4000, _music_buf.size())
		for i in range(_enc_i, end):
			_music_bytes.encode_s16(i * 2, int(clampf(_music_buf[i], -1.0, 1.0) * 32000.0))
		_enc_i = end
	if _enc_i >= _music_buf.size():
		_start_player(_music_stream())


## Готовая петля музыки из собранного буфера.
func _music_stream() -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = MUSIC_RATE
	s.stereo = false
	s.data = _music_bytes
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = _music_buf.size()
	return s


func _start_player(s: AudioStream) -> void:
	music_player = AudioStreamPlayer.new()
	music_player.stream = s
	add_child(music_player)
	_apply_music_volume()
	music_player.play()


## Собрать музыку целиком сразу — для tools/bake_assets.gd.
func render_music_now() -> AudioStreamWAV:
	_music_events.clear()
	_plan_music()
	for e in _music_events:
		_render_event(e)
	_music_bytes.resize(_music_buf.size() * 2)
	for i in _music_buf.size():
		_music_bytes.encode_s16(i * 2, int(clampf(_music_buf[i], -1.0, 1.0) * 32000.0))
	return _music_stream()


func _apply_music_volume() -> void:
	if music_player:
		var v := SettingsManager.music * (0.0 if _ducked else 1.0)
		music_player.volume_db = linear_to_db(maxf(v, 0.001) * 0.45)
		music_player.stream_paused = v < 0.01


func duck_music(on: bool) -> void:
	if on != _ducked:
		_ducked = on
		_apply_music_volume()


func _midi(n: int) -> float:
	return 440.0 * pow(2.0, (n - 69) / 12.0)


## Восемь тактов: Am – F – C – G – Am – F – G – E. Мягкие аккорды,
## бас на первую и третью долю, сверху — перебор, как у гитары у костра.
func _plan_music() -> void:
	var beat := 60.0 / MUSIC_BPM
	var bar := beat * 4.0
	var chords := [[45, [0, 3, 7]], [41, [0, 4, 7]], [48, [0, 4, 7]], [43, [0, 4, 7]],
		[45, [0, 3, 7]], [41, [0, 4, 7]], [43, [0, 4, 7]], [40, [0, 4, 7]]]
	var total := bar * chords.size()
	_music_buf.resize(int(total * MUSIC_RATE))
	_music_buf.fill(0.0)
	# Мелодия по тактам: ступени от корня аккорда (−1 — пауза), восьмыми
	var tunes := [
		[12, -1, 15, 19, 17, 15, 12, -1], [12, 16, 19, -1, 17, 16, 12, -1],
		[12, -1, 14, 16, 19, 16, 14, 12], [11, 14, 19, -1, 17, 14, 11, -1],
		[19, 17, 15, -1, 12, 15, 17, 19], [16, -1, 19, 21, 19, 16, 12, -1],
		[14, 17, 19, -1, 23, 19, 17, 14], [16, -1, 20, 23, -1, 20, 16, -1],
	]
	for i in chords.size():
		var root: int = chords[i][0]
		var t0 := i * bar
		for step in chords[i][1]:
			_music_events.append([t0, bar * 1.15, _midi(root + 12 + int(step)), "pad", 0.05])
		_music_events.append([t0, beat * 1.8, _midi(root), "bass", 0.2])
		_music_events.append([t0 + beat * 2.0, beat * 1.8, _midi(root + 7), "bass", 0.16])
		# Перебор: аккордовые ноты по восьмым, тихо
		for k in 8:
			var st: int = chords[i][1][k % 3]
			_music_events.append([t0 + k * beat * 0.5, beat * 1.2, _midi(root + 12 + st), "pluck", 0.06])
		var tune: Array = tunes[i]
		for k in 8:
			if int(tune[k]) >= 0:
				_music_events.append([t0 + k * beat * 0.5, beat * 1.4, _midi(root + 12 + int(tune[k])), "pluck", 0.13])


func _render_event(e: Array) -> void:
	var start := int(float(e[0]) * MUSIC_RATE)
	var n := int(float(e[1]) * MUSIC_RATE)
	var f: float = e[2]
	var kind: String = e[3]
	var vol: float = e[4]
	var size := _music_buf.size()
	var w := TAU * f / MUSIC_RATE
	for j in n:
		var t := float(j) / MUSIC_RATE
		var v := 0.0
		match kind:
			"pad":
				var env := minf(t / 0.35, 1.0) * minf((float(e[1]) - t) / 0.5, 1.0)
				v = (sin(w * j) + 0.25 * sin(2.0 * w * j + sin(t * 5.0) * 0.3)) * env
			"bass":
				v = (sin(w * j) + 0.4 * sin(2.0 * w * j)) * exp(-t * 3.0) * minf(t * 60.0, 1.0)
			"pluck":
				v = (sin(w * j) + 0.5 * sin(2.0 * w * j) + 0.2 * sin(3.0 * w * j)) * exp(-t * 4.5) * minf(t * 200.0, 1.0)
		# Петля: хвост уходит в начало
		var idx := (start + j) % size
		_music_buf[idx] += v * vol


func stream(sound: String) -> AudioStream:
	return _streams.get(sound)


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _streams.get(sound)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()


func play_at(sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams.get(sound)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 8.0
	p.max_distance = 90.0
	p.finished.connect(p.queue_free)
	tree.current_scene.add_child(p)
	p.global_position = pos
	p.play()


# --- Сборка звука -----------------------------------------------------------

func _make(samples: PackedFloat32Array, loop: bool, rate := RATE) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


func _buf(seconds: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(seconds * RATE))
	return a


## Короткий шорох шага: шум через фильтр, быстро гаснет.
func _step() -> PackedFloat32Array:
	var a := _buf(0.09)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.25
		a[i] = lp * exp(-t * 45.0) * 0.9
	return a


## Свисток инспектора: пронзительная трель с горошиной.
func _whistle() -> PackedFloat32Array:
	var a := _buf(0.9)
	var ph := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var f := 2900.0 + sin(t * TAU * 28.0) * 180.0
		ph += TAU * f / RATE
		var env := minf(t * 30.0, 1.0) * minf((0.9 - t) * 12.0, 1.0)
		a[i] = (sin(ph) * (0.7 + 0.3 * sin(t * TAU * 28.0))) * env * 0.25
	return a


## Гром: треск и долгий низкий раскат.
func _thunder() -> PackedFloat32Array:
	var a := _buf(3.5)
	var lp := 0.0
	var lp2 := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.02
		lp2 += (lp - lp2) * 0.05
		var crack := _rng.randf_range(-1.0, 1.0) * exp(-t * 14.0) * 0.5
		# Раскат перекатывается волнами
		var roll := (0.6 + 0.4 * sin(t * 5.0 + sin(t * 1.7) * 2.0)) * exp(-t * 0.9)
		a[i] = clampf(lp2 * 9.0 * roll + crack, -1.0, 1.0) * 0.9
	return a


## Петух: «ку-ка-ре-ку» — четыре слога, последний длинный и вверх-вниз.
func _rooster() -> PackedFloat32Array:
	var a := _buf(1.5)
	# [начало, длина, частота от, частота до]
	var syl := [[0.0, 0.14, 620.0, 700.0], [0.18, 0.14, 700.0, 760.0], [0.36, 0.16, 760.0, 900.0], [0.56, 0.8, 900.0, 640.0]]
	var ph := 0.0
	for s in syl:
		var start := int(float(s[0]) * RATE)
		var n := int(float(s[1]) * RATE)
		for j in n:
			var k := float(j) / n
			var f := lerpf(s[2], s[3], k if s[1] < 0.5 else sin(k * PI * 0.5))
			ph += TAU * f / RATE
			var env := minf(k * 12.0, 1.0) * minf((1.0 - k) * 8.0, 1.0)
			# Хрипловато: нечётные гармоники и немного шума
			var v := sin(ph) + 0.45 * sin(3.0 * ph) + 0.25 * sin(5.0 * ph) + _rng.randf_range(-0.12, 0.12)
			if start + j < a.size():
				a[start + j] = v * env * 0.28
	return a


## Шаг по траве: мягкий шелест подлиннее, без стука.
func _step_grass() -> PackedFloat32Array:
	var a := _buf(0.16)
	var lp := 0.0
	var lp2 := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.5
		lp2 += (lp - lp2) * 0.2
		a[i] = (lp - lp2) * minf(t * 60.0, 1.0) * exp(-t * 22.0) * 0.8
	return a


## Шаг по снегу: скрип — частые мелкие щелчки.
func _step_snow() -> PackedFloat32Array:
	var a := _buf(0.2)
	var c := 0.0
	for i in a.size():
		var t := float(i) / RATE
		if _rng.randf() < 0.02:
			c = _rng.randf_range(-1.0, 1.0)
		c *= 0.85
		a[i] = c * minf(t * 40.0, 1.0) * exp(-t * 14.0) * 0.7
	return a


## Глухой удар: низкий тон с шумом.
func _thud(dur: float, freq: float) -> PackedFloat32Array:
	var a := _buf(dur)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.08
		a[i] = (sin(TAU * freq * t) * 0.7 + lp * 0.8) * exp(-t * 22.0)
	return a


## Мотор: ровно 55 вспышек в секунду, секунда звука — петля без щелчка.
## Высоту тона меняет pitch_scale по оборотам.
func _engine() -> PackedFloat32Array:
	var a := _buf(1.0)
	var lp := 0.0
	var f := 55.0
	for i in a.size():
		var t := float(i) / RATE
		var ph := fmod(t * f, 1.0)
		var pulse := exp(-ph * 7.0)
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.15
		a[i] = (sin(TAU * f * t) * 0.35 + sin(TAU * f * 2.0 * t) * 0.2 + pulse * 0.35 + lp * 0.25 * pulse) * 0.8
	return a


## Сила каждой из n вспышек: у живого мотора они чуть разные. Свой
## генератор с постоянным зерном — петля звучит одинаково каждый раз.
func _jitter(n: int, spread: float, seed_: int) -> PackedFloat32Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	var k := PackedFloat32Array()
	k.resize(n)
	for i in n:
		k[i] = 1.0 - r.randf() * spread
	return k


## Мопед «Карпаты» (50 кубов, двухтактный): тонкое злое жужжание —
## узкие хлопки, почти без баса, с призвоном высоко.
func _engine_moped() -> PackedFloat32Array:
	var a := _buf(1.0)
	var f := 55.0
	var k := _jitter(55, 0.35, 501)
	var hp := 0.0
	var prev := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var ph := fmod(t * f, 1.0)
		var pulse := exp(-ph * 16.0) * k[int(t * f) % 55]
		var n := _rng.randf_range(-1.0, 1.0)
		hp = (n - prev) * 0.5
		prev = n
		var saw := ph * 2.0 - 1.0
		a[i] = (pulse * 0.5 + sin(TAU * f * 9.0 * t) * exp(-ph * 5.0) * 0.22 + saw * 0.12
				+ sin(TAU * f * 3.0 * t) * 0.12 + hp * pulse * 0.3) * 0.8
	return a


## «Ява» (двухтактная): звонкий «ринг-динг» — резкий хлопок и звон
## резонатора на выхлопе, бас средний.
func _engine_moto() -> PackedFloat32Array:
	var a := _buf(1.0)
	var f := 55.0
	var k := _jitter(55, 0.2, 502)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var ph := fmod(t * f, 1.0)
		var pulse := exp(-ph * 10.0) * k[int(t * f) % 55]
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.3
		a[i] = (pulse * 0.42 + sin(TAU * f * 5.0 * t) * exp(-ph * 3.5) * 0.3
				+ sin(TAU * f * t) * 0.25 + lp * pulse * 0.3) * 0.8
	return a


## ИЖ «Юпитер» (два цилиндра): низкое густое «бу-бу-бу» — мягкие тяжёлые
## толчки, каждый второй слабее; две секунды на 110 вспышек — петля ровная.
func _engine_izh() -> PackedFloat32Array:
	var a := _buf(2.0)
	var f := 55.0
	var k := _jitter(110, 0.15, 503)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var ph := fmod(t * f, 1.0)
		var idx := int(t * f) % 110
		var pulse := exp(-ph * 4.0) * k[idx] * (1.0 if idx % 2 == 0 else 0.7)
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.06
		a[i] = (sin(TAU * f * t) * 0.42 + sin(TAU * f * 0.5 * t) * 0.18 + pulse * 0.38
				+ sin(TAU * f * 2.0 * t) * 0.1 + lp * pulse * 0.9) * 0.8
	return a


## Дизель (грузовик, автобус): низкий гул и сухой стук-цокот на каждой вспышке.
func _engine_diesel() -> PackedFloat32Array:
	var a := _buf(1.0)
	var f := 55.0
	var k := _jitter(55, 0.25, 504)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var ph := fmod(t * f, 1.0)
		var pulse := exp(-ph * 5.0) * k[int(t * f) % 55]
		var n := _rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.1
		a[i] = (sin(TAU * f * t) * 0.4 + pulse * 0.3 + n * exp(-ph * 35.0) * 0.45 * k[int(t * f) % 55] + lp * 0.2) * 0.8
	return a


## Трактор: тяжёлое «тук-тук-тук» с железным позвякиванием.
func _engine_tractor() -> PackedFloat32Array:
	var a := _buf(1.0)
	var f := 55.0
	var k := _jitter(55, 0.3, 505)
	for i in a.size():
		var t := float(i) / RATE
		var ph := fmod(t * f, 1.0)
		var pulse := exp(-ph * 3.0) * k[int(t * f) % 55]
		a[i] = (pulse * 0.5 + sin(TAU * f * t) * 0.35 + _rng.randf_range(-1.0, 1.0) * exp(-ph * 25.0) * 0.35
				+ sin(TAU * f * 7.0 * t) * exp(-ph * 8.0) * 0.1) * 0.8
	return a


## «Волга»: мотор крупнее и мягче «Жигулей» — ровный низкий гул почти без треска.
func _engine_volga() -> PackedFloat32Array:
	var a := _buf(1.0)
	var f := 55.0
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var ph := fmod(t * f, 1.0)
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.08
		a[i] = (sin(TAU * f * t) * 0.5 + sin(TAU * f * 2.0 * t) * 0.25 + exp(-ph * 6.0) * 0.2 + lp * 0.12) * 0.8
	return a


## «Запорожец»: воздушное охлаждение — дребезжит и тарахтит.
func _engine_zaz() -> PackedFloat32Array:
	var a := _buf(1.0)
	var f := 55.0
	var k := _jitter(55, 0.4, 506)
	var prev := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var ph := fmod(t * f, 1.0)
		var pulse := exp(-ph * 9.0) * k[int(t * f) % 55]
		var n := _rng.randf_range(-1.0, 1.0)
		var hp := (n - prev) * 0.5
		prev = n
		a[i] = (pulse * 0.4 + sin(TAU * f * 3.0 * t) * 0.15 + hp * (0.5 + pulse) * 0.3
				+ sin(TAU * f * 11.0 * t) * exp(-ph * 4.0) * 0.12 + sin(TAU * f * t) * 0.15) * 0.8
	return a


# --- Голоса ------------------------------------------------------------------

## Форманты гласных (мужской голос), Гц: у женщин и детей выше в scale раз.
const VOWELS := {
	"а": Vector3(730, 1090, 2440), "о": Vector3(570, 840, 2410), "у": Vector3(300, 870, 2240),
	"э": Vector3(530, 1840, 2480), "и": Vector3(270, 2290, 3010),
}


## Слог голосом: связки (пила с высотой f0a → f0b) через три форманты
## гласной, как через рот; breath — сначала выдох «х», секунд. Гласная
## может перетекать в vowel_to («эй»). wrap — заворачивать в начало буфера
## (для петли).
func _voice(a: PackedFloat32Array, start: float, dur: float, f0a: float, f0b: float, vowel: String,
		scale := 1.0, amp := 1.0, breath := 0.0, vowel_to := "", wrap := false) -> void:
	var fa: Vector3 = VOWELS[vowel] * scale
	var fb: Vector3 = VOWELS[vowel_to if vowel_to != "" else vowel] * scale
	var bw := Vector3(90, 110, 160) * scale
	var gain := Vector3(1.0, 0.7, 0.35)
	var y1 := Vector3.ZERO
	var y2 := Vector3.ZERO
	var ph := 0.0
	var i0 := int(start * RATE)
	var nb := int(breath * RATE)
	var nv := maxi(int(dur * RATE), 1)
	for j in nb + nv:
		var idx := i0 + j
		if wrap:
			idx = idx % a.size()
		elif idx >= a.size():
			break
		var src := 0.0
		var env := 1.0
		var k := 0.0
		if j < nb:
			src = _rng.randf_range(-1.0, 1.0) * 0.5
			env = float(j) / nb
		else:
			var jv := j - nb
			k = float(jv) / nv
			var f0 := lerpf(f0a, f0b, k) * (1.0 + 0.015 * sin(TAU * 6.0 * jv / RATE))
			ph = fmod(ph + f0 / RATE, 1.0)
			src = 1.0 - 2.0 * ph + _rng.randf_range(-0.1, 0.1)
			env = minf(jv / (0.015 * RATE), 1.0) * minf((nv - jv) / (0.04 * RATE), 1.0)
		var f := fa.lerp(fb, k)
		var out := 0.0
		for m in 3:
			var r := exp(-PI * bw[m] / RATE)
			var y := (1.0 - r) * src + 2.0 * r * cos(TAU * f[m] / RATE) * y1[m] - r * r * y2[m]
			y2[m] = y1[m]
			y1[m] = y
			out += y * gain[m]
		a[idx] += out * amp * env


## Довести громкость до пика peak — у голосов разная сила форматов.
func _norm(a: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0
	for v in a:
		m = maxf(m, absf(v))
	if m > 0.0:
		for i in a.size():
			a[i] *= peak / m
	return a


## Смех: n слогов «ха» (или «хи»), высота от f0 к f0_end, к концу тише.
func _laugh(n: int, f0: float, f0_end: float, vowel: String, scale: float, syl: float, gap: float, breath: float) -> PackedFloat32Array:
	var a := _buf(n * (syl + gap + breath) + 0.25)
	var t := 0.03
	for i in n:
		var k := float(i) / maxf(n - 1, 1)
		var f := lerpf(f0, f0_end, k)
		_voice(a, t, syl * _rng.randf_range(0.85, 1.15), f * 1.08, f * 0.92, vowel, scale, lerpf(1.0, 0.55, k), breath)
		t += syl + gap + breath
	return _norm(a, 0.6)


## «Эй!» — окрик через двор.
func _shout_hey() -> PackedFloat32Array:
	var a := _buf(0.7)
	_voice(a, 0.03, 0.45, 205.0, 240.0, "э", 1.0, 1.0, 0.02, "и")
	return _norm(a, 0.75)


## «Эге-ге-гей!» — весело, на всю округу.
func _shout_yahoo() -> PackedFloat32Array:
	var a := _buf(1.25)
	_voice(a, 0.03, 0.14, 205.0, 215.0, "э")
	_voice(a, 0.22, 0.13, 245.0, 255.0, "э", 1.0, 0.9)
	_voice(a, 0.4, 0.6, 300.0, 255.0, "э", 1.0, 1.0, 0.0, "и")
	return _norm(a, 0.75)


## Дети играют: визг «а-а-а!», «и-и!» и хихиканье вперемешку.
func _kids_play() -> PackedFloat32Array:
	var a := _buf(1.7)
	_voice(a, 0.02, 0.6, 520.0, 650.0, "а", 1.35)
	_voice(a, 0.45, 0.3, 640.0, 720.0, "и", 1.35, 0.7)
	for i in 3:
		_voice(a, 0.95 + i * 0.12, 0.07, 440.0, 420.0, "и", 1.3, 0.6, 0.03)
	_voice(a, 1.1, 0.45, 700.0, 560.0, "а", 1.35, 0.8)
	return _norm(a, 0.6)


## Трибуна: много голосов разом тянут «а-а-а» / «о-о-о» — гол!
func _cheer() -> PackedFloat32Array:
	var a := _buf(2.4)
	for i in 18:
		var woman := _rng.randf() < 0.35
		var f0 := _rng.randf_range(200.0, 290.0) if woman else _rng.randf_range(110.0, 180.0)
		_voice(a, _rng.randf_range(0.0, 0.4), _rng.randf_range(1.3, 1.8), f0 * 0.95, f0 * 1.1,
				"а" if _rng.randf() < 0.6 else "о", 1.17 if woman else 1.0, _rng.randf_range(0.5, 1.0))
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.1
		a[i] += lp * 0.4 * minf(t * 3.0, 1.0) * minf((2.4 - t) * 2.0, 1.0)
	return _norm(a, 0.7)


## «Ау!» в роще — и эхо.
func _auu() -> PackedFloat32Array:
	var a := _buf(1.8)
	_voice(a, 0.03, 0.25, 300.0, 330.0, "а", 1.17)
	_voice(a, 0.27, 0.5, 340.0, 285.0, "у", 1.17, 0.9)
	var dry := a.duplicate()
	for echo in [[0.45, 0.3], [0.9, 0.12]]:
		var d := int(float(echo[0]) * RATE)
		for i in range(d, a.size()):
			a[i] += dry[i - d] * float(echo[1])
	return _norm(a, 0.65)


## Гомон: несколько человек говорят наперебой, слов не разобрать.
## Четыре секунды петлёй — слоги заворачиваются в начало без щелчка.
func _chatter() -> PackedFloat32Array:
	var a := _buf(4.0)
	var speakers := [[120.0, 1.0], [150.0, 1.0], [230.0, 1.17], [260.0, 1.17], [200.0, 1.17]]
	var vowels := VOWELS.keys()
	for i in 80:
		var s: Array = speakers[_rng.randi() % speakers.size()]
		var f0: float = float(s[0]) * _rng.randf_range(0.9, 1.15)
		_voice(a, _rng.randf_range(0.0, 4.0), _rng.randf_range(0.07, 0.2), f0, f0 * _rng.randf_range(0.85, 1.1),
				vowels[_rng.randi() % vowels.size()], float(s[1]), _rng.randf_range(0.4, 1.0),
				0.03 if _rng.randf() < 0.4 else 0.0, "", true)
	return _norm(a, 0.5)


## Аккорды на шести струнах (MIDI, −1 — струну не трогают).
const GUITAR_CHORDS := {
	"Am": [-1, 45, 52, 57, 60, 64], "Dm": [-1, -1, 50, 57, 62, 65], "E": [40, 47, 52, 56, 59, 64],
	"C": [-1, 48, 52, 55, 60, 64], "G": [43, 47, 50, 55, 59, 67], "F": [41, 48, 53, 57, 60, 65],
	"Em": [40, 47, 52, 55, 59, 64], "D": [-1, -1, 50, 57, 62, 66],
}


## Песня уличного музыканта. 0 — дворовая в ля миноре: бой «восьмёрка»
## и голос без слов; 1 — перебор в ми миноре. По такту на аккорд.
func _busker_song(n: int) -> PackedFloat32Array:
	var bpm := 100.0 if n == 0 else 112.0
	var prog: Array = ["Am", "Dm", "G", "C", "F", "Dm", "E", "Am"] if n == 0 else ["Em", "C", "G", "D", "Em", "C", "D", "Em"]
	var eighth := 30.0 / bpm
	var bar := eighth * 8.0
	var a := _buf(bar * (prog.size() + 1) + 0.5)
	# Ноты по струнам: [начало, MIDI, сила, яркость]
	var strings: Array = [[], [], [], [], [], []]
	for b in prog.size() + 1:
		var last := b == prog.size()
		var chord: Array = GUITAR_CHORDS[prog[mini(b, prog.size() - 1)]]
		var t0 := b * bar
		if last:
			# Последний аккорд — один долгий удар
			_strum(strings, chord, t0, true, 1.0)
			break
		if n == 0:
			# Восьмёрка: вниз, вниз-вверх, вверх, вниз-вверх
			for e in [[0, true, 1.0], [2, true, 0.8], [3, false, 0.55], [5, false, 0.6], [6, true, 0.8], [7, false, 0.55]]:
				_strum(strings, chord, t0 + e[0] * eighth, e[1], e[2])
		else:
			# Перебор: бас, третья, вторая, первая, вторая, третья, бас, вторая
			var bass := 0
			while chord[bass] < 0:
				bass += 1
			var order := [bass, 3, 4, 5, 4, 3, mini(bass + 1, 2), 4]
			for e in 8:
				var s: int = order[e]
				strings[s].append([t0 + e * eighth, chord[s], 0.9 if e == 0 else 0.6, 0.5])
	for s in 6:
		var ev: Array = strings[s]
		for i in ev.size():
			var end: float = ev[i + 1][0] if i + 1 < ev.size() else ev[i][0] + 2.5
			_pluck(a, ev[i][0], minf(end, ev[i][0] + 2.5), _midi(ev[i][1]), ev[i][2], ev[i][3])
	if n == 0:
		# Голос без слов по нотам аккорда: четверть, четверть, половинка
		var vowels := ["а", "о", "э", "а", "у", "о", "а", "о"]
		for b in prog.size():
			var chord: Array = GUITAR_CHORDS[prog[b]]
			# Ноты аккорда в мужском голосе: от ми до ре
			var top: Array = []
			for m in chord:
				if m >= 48:
					var x: int = m
					while x > 62:
						x -= 12
					if not top.has(x):
						top.append(x)
			top.sort()
			var notes := [top[top.size() - 1], top[maxi(top.size() - 2, 0)], top[0]]
			var lens := [2.0, 2.0, 3.6]
			var t := b * bar + eighth * 0.1
			for k in 3:
				var f := _midi(notes[k])
				_voice(a, t, eighth * lens[k], f, f * (0.99 if k == 2 else 1.0), vowels[(b + k) % vowels.size()], 1.0, 0.22, 0.0)
				t += eighth * (lens[k] + 0.4 if k < 2 else 0.0)
	# Корпус гитары: немного срезать верха; мягкий ограничитель — тихие
	# удары громче, редкие пики не глушат всю песню
	var lp := 0.0
	for i in a.size():
		lp += (a[i] - lp) * 0.55
		a[i] = lp
	_norm(a, 1.0)
	for i in a.size():
		a[i] = tanh(a[i] * 4.0)
	return _norm(a, 0.7)


## Удар по струнам: вниз — от баса к первой, вверх — по верхним четырём обратно.
func _strum(strings: Array, chord: Array, t: float, down: bool, amp: float) -> void:
	var order := [0, 1, 2, 3, 4, 5] if down else [5, 4, 3, 2]
	var k := 0
	for s in order:
		if chord[s] < 0:
			continue
		strings[s].append([t + k * 0.011, chord[s], amp * (1.0 if down else 0.8), 0.6 if down else 0.8])
		k += 1


## Щипок струны (Карплус — Стронг): шум в линии задержки длиной в период
## гаснет и мягчает сам. До end — следующая нота глушит струну.
func _pluck(a: PackedFloat32Array, start: float, end: float, f: float, amp: float, bright: float) -> void:
	var n := maxi(int(RATE / f), 2)
	var line := PackedFloat32Array()
	line.resize(n)
	var lp := 0.0
	var mean := 0.0
	for i in n:
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * bright
		line[i] = lp
		mean += lp
	mean /= n
	for i in n:
		line[i] -= mean
	var i0 := int(start * RATE)
	var i1 := mini(int(end * RATE), a.size())
	var p := 0
	for j in range(i0, i1):
		var cur := line[p]
		line[p] = (cur + line[(p + 1) % n]) * 0.4985
		p = (p + 1) % n
		a[j] += cur * amp * minf(float(i1 - j) / 220.0, 1.0)


## Стартер: визг с подвыванием, в конце мотор схватывает.
func _starter() -> PackedFloat32Array:
	var a := _buf(0.9)
	var phase := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var f := 18.0 + 6.0 * sin(t * 30.0) + t * 30.0
		phase += f / RATE
		var whine := sin(TAU * phase * 8.0) * 0.25
		var chug := exp(-fmod(phase, 1.0) * 6.0) * 0.5
		a[i] = (whine + chug) * minf(t * 20.0, 1.0) * (1.0 - t / 0.9 * 0.3)
	return a


## Заглох: тон падает и дёргается.
func _stall() -> PackedFloat32Array:
	var a := _buf(0.7)
	var phase := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var f := lerpf(28.0, 6.0, t / 0.7)
		phase += f / RATE
		a[i] = (exp(-fmod(phase, 1.0) * 5.0) * 0.7 + sin(TAU * phase * 2.0) * 0.2) * (1.0 - t / 0.7)
	return a


## Скрежет шестерён: металлический шум с быстрыми «зубьями».
func _grind() -> PackedFloat32Array:
	var a := _buf(0.45)
	for i in a.size():
		var t := float(i) / RATE
		var teeth := 1.0 if fmod(t * 180.0, 1.0) < 0.35 else 0.2
		a[i] = (_rng.randf_range(-1.0, 1.0) * teeth * 0.6 + sin(TAU * 1900.0 * t) * 0.15) * (1.0 - t / 0.45)
	return a


func _crash() -> PackedFloat32Array:
	var a := _buf(0.5)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.4
		a[i] = (lp + sin(TAU * 60.0 * t) * 0.6) * exp(-t * 9.0)
	return a


## Касса: два колокольчика.
func _cash() -> PackedFloat32Array:
	var a := _buf(0.5)
	for i in a.size():
		var t := float(i) / RATE
		var v := sin(TAU * 1568.0 * t) * exp(-t * 9.0)
		if t > 0.1:
			v += sin(TAU * 2093.0 * (t - 0.1)) * exp(-(t - 0.1) * 8.0)
		a[i] = v * 0.4
	return a


func _tone(freq: float, dur: float, vol: float) -> PackedFloat32Array:
	var a := _buf(dur)
	for i in a.size():
		var t := float(i) / RATE
		a[i] = sin(TAU * freq * t) * vol * (1.0 - t / dur)
	return a


## Птица: три свиста с изгибом частоты.
func _bird() -> PackedFloat32Array:
	var a := _buf(0.6)
	var phase := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var k := fmod(t, 0.2) / 0.2
		var on := 1.0 if k < 0.6 else 0.0
		var f := 3200.0 + sin(k * PI) * 1400.0
		phase += f / RATE
		a[i] = sin(TAU * phase) * on * sin(minf(k / 0.6, 1.0) * PI) * 0.25
	return a


## Сверчки: трели по 4 щелчка, секунда — петля.
func _crickets() -> PackedFloat32Array:
	var a := _buf(1.0)
	for i in a.size():
		var t := float(i) / RATE
		var burst := fmod(t, 0.5)
		var on := 1.0 if burst < 0.16 and fmod(burst, 0.04) < 0.025 else 0.0
		a[i] = sin(TAU * 4400.0 * t) * on * 0.12
	return a


## Лай: два коротких «гав» — шум с низким тоном.
func _bark() -> PackedFloat32Array:
	var a := _buf(0.55)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var local := fmod(t, 0.28)
		var env := exp(-local * 18.0) if local < 0.18 else 0.0
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.3
		var f := 420.0 - local * 900.0
		a[i] = (sin(TAU * f * local) * 0.6 + lp * 0.5) * env * 0.8
	return a


func _chicken() -> PackedFloat32Array:
	var a := _buf(0.35)
	for i in a.size():
		var t := float(i) / RATE
		var local := fmod(t, 0.12)
		var f := 900.0 + local * 3000.0
		a[i] = sin(TAU * f * local) * exp(-local * 25.0) * 0.35
	return a


## Дождь: шум с мягким фильтром и редкими каплями, две секунды петлёй.
func _rain() -> PackedFloat32Array:
	var a := _buf(2.0)
	var lp := 0.0
	for i in a.size():
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.35
		var drop := _rng.randf_range(-1.0, 1.0) * 0.6 if _rng.randf() < 0.002 else 0.0
		a[i] = lp * 0.35 + drop
	# Сглаживаем стык петли
	var fade := 400
	for i in fade:
		var k := float(i) / fade
		a[i] = a[i] * k + a[a.size() - fade + i] * (1.0 - k)
	return a


## Шины по гравию: частые щелчки камешков поверх глухого шума.
func _gravel() -> PackedFloat32Array:
	var a := _buf(1.2)
	var lp := 0.0
	var click := 0.0
	for i in a.size():
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.08
		if _rng.randf() < 0.006:
			click = _rng.randf_range(0.3, 0.8) * (1.0 if _rng.randf() < 0.5 else -1.0)
		click *= 0.93
		a[i] = lp * 0.5 + click * _rng.randf_range(0.6, 1.0)
	_loop_fade(a)
	return a


## Шины по траве: мягкий шелест, чуть волнами.
func _grass() -> PackedFloat32Array:
	var a := _buf(1.5)
	var lp := 0.0
	var lp2 := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.25
		lp2 += (lp - lp2) * 0.3
		a[i] = (lp - lp2) * 0.9 * (0.75 + 0.25 * sin(t * TAU * 2.0))
	_loop_fade(a)
	return a


func _loop_fade(a: PackedFloat32Array) -> void:
	var fade := 400
	for i in fade:
		var k := float(i) / fade
		a[i] = a[i] * k + a[a.size() - fade + i] * (1.0 - k)


func _horn() -> PackedFloat32Array:
	var a := _buf(0.6)
	for i in a.size():
		var t := float(i) / RATE
		var env := minf(t * 30.0, 1.0) * minf((0.6 - t) * 20.0, 1.0)
		a[i] = (signf(sin(TAU * 400.0 * t)) * 0.15 + signf(sin(TAU * 500.0 * t)) * 0.15) * env
	return a


## Школьный звонок: электрический, дребезжащий, две секунды.
func _bell() -> PackedFloat32Array:
	var a := _buf(2.2)
	for i in a.size():
		var t := float(i) / RATE
		# Молоточек бьёт по чашке ~25 раз в секунду: звон с дребезгом
		var strike := exp(-fmod(t, 0.04) * 60.0)
		var ring := sin(TAU * 1250.0 * t) + 0.5 * sin(TAU * 2610.0 * t) + 0.3 * sin(TAU * 3900.0 * t)
		var env := minf(t * 30.0, 1.0) * minf((2.2 - t) * 4.0, 1.0)
		a[i] = ring * (0.25 + 0.75 * strike) * env * 0.2
	return a


## Сирена милиции: два тона по полсекунды, петлёй — «уа-уа».
func _siren() -> PackedFloat32Array:
	var a := _buf(2.0)
	var phase := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var f := 660.0 if fmod(t, 1.0) < 0.5 else 880.0
		phase += TAU * f / RATE
		# Мягкий «квадрат»: основной тон и две нечётные гармоники
		a[i] = (sin(phase) + sin(phase * 3.0) / 3.0 + sin(phase * 5.0) / 5.0) * 0.22
	return a


## Стук молотка — для стройки.
func _hammer() -> PackedFloat32Array:
	var a := _buf(0.9)
	for i in a.size():
		var t := float(i) / RATE
		var local := fmod(t, 0.3)
		a[i] = (sin(TAU * 900.0 * local) * 0.5 + _rng.randf_range(-0.3, 0.3)) * exp(-local * 40.0)
	return a


## Всплеск: шипящий шум, быстро гаснет.
func _splash() -> PackedFloat32Array:
	var a := _buf(0.5)
	var hp := 0.0
	var prev := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var n := _rng.randf_range(-1.0, 1.0)
		hp = 0.7 * (hp + n - prev)
		prev = n
		a[i] = hp * exp(-t * 7.0) * 0.5
	return a


## Визг шин: высокий тон, дрожащий по частоте, с шипением; петля 1 с.
func _skid() -> PackedFloat32Array:
	var a := _buf(1.0)
	var phase := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var f := 1100.0 + sin(TAU * 7.0 * t) * 120.0 + sin(TAU * 13.0 * t) * 60.0
		phase += f / RATE
		a[i] = sin(TAU * phase) * 0.25 + _rng.randf_range(-0.12, 0.12)
	return a


## «Му-у»: низкий гудящий тон, поднимается и опадает, с хрипотцой.
func _moo() -> PackedFloat32Array:
	var a := _buf(1.1)
	var phase := 0.0
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var f := 110.0 + 55.0 * sin(clampf(t / 1.1, 0.0, 1.0) * PI) - t * 20.0
		phase += f / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.2
		var env := minf(t * 8.0, 1.0) * minf((1.1 - t) * 4.0, 1.0)
		var v := sin(TAU * phase) * 0.5 + sin(TAU * phase * 2.0) * 0.25 + sin(TAU * phase * 3.0) * 0.12
		a[i] = (v + lp * 0.15) * env * 0.55
	return a


## Задание выполнено: три восходящие ноты с колокольным хвостом.
func _quest() -> PackedFloat32Array:
	var a := _buf(0.9)
	var notes := [523.25, 659.25, 783.99]
	for i in a.size():
		var t := float(i) / RATE
		var v := 0.0
		for k in notes.size():
			var t0: float = k * 0.12
			if t >= t0:
				var tt := t - t0
				v += (sin(TAU * notes[k] * tt) + 0.3 * sin(TAU * notes[k] * 2.0 * tt)) * exp(-tt * 4.0)
		a[i] = v * 0.22
	return a
