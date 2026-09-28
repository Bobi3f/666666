extends Node
## Все звуки игры синтезируются кодом при запуске — файлов со звуком нет.
##
## play(name) — звук интерфейса или «в голове» игрока (шаги, касса);
## play_at(name, pos) — звук в мире, тише с расстоянием;
## stream(name) — сам звук, для постоянных источников (мотор, дождь).

const RATE := 22050

var _streams := {}
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
	_streams["step"] = _make(_step(), false)
	_streams["land"] = _make(_thud(0.18, 70.0), false)
	_streams["jump"] = _make(_thud(0.1, 110.0), false)
	_streams["engine"] = _make(_engine(), true)
	_streams["starter"] = _make(_starter(), false)
	_streams["stall"] = _make(_stall(), false)
	_streams["grind"] = _make(_grind(), false)
	_streams["crash"] = _make(_crash(), false)
	_streams["cash"] = _make(_cash(), false)
	_streams["click"] = _make(_tone(1200.0, 0.04, 0.3), false)
	_streams["bird"] = _make(_bird(), false)
	_streams["crickets"] = _make(_crickets(), true)
	_streams["bark"] = _make(_bark(), false)
	_streams["rain"] = _make(_rain(), true)
	_streams["chicken"] = _make(_chicken(), false)
	_streams["horn"] = _make(_horn(), false)
	_streams["hammer"] = _make(_hammer(), false)
	_streams["splash"] = _make(_splash(), false)
	_streams["skid"] = _make(_skid(), true)
	_streams["quest"] = _make(_quest(), false)
	_streams["moo"] = _make(_moo(), false)
	SettingsManager.changed.connect(_apply_music_volume)


## Включить фоновую музыку: соберётся за пару секунд и заиграет петлёй.
func start_music() -> void:
	if _music_wanted:
		return
	_music_wanted = true
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
		var s := AudioStreamWAV.new()
		s.format = AudioStreamWAV.FORMAT_16_BITS
		s.mix_rate = MUSIC_RATE
		s.stereo = false
		s.data = _music_bytes
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = _music_buf.size()
		music_player = AudioStreamPlayer.new()
		music_player.stream = s
		add_child(music_player)
		_apply_music_volume()
		music_player.play()


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


func stream(sound: String) -> AudioStreamWAV:
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


func _horn() -> PackedFloat32Array:
	var a := _buf(0.6)
	for i in a.size():
		var t := float(i) / RATE
		var env := minf(t * 30.0, 1.0) * minf((0.6 - t) * 20.0, 1.0)
		a[i] = (signf(sin(TAU * 400.0 * t)) * 0.15 + signf(sin(TAU * 500.0 * t)) * 0.15) * env
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
