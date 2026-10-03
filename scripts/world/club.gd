class_name Club
extends Node3D
## Клуб с дискотекой: здание с вывеской, вход по билету, внутри танцпол
## из светящихся плиток, зеркальный шар, диджей за пультом, колонки, бар
## и танцующая молодёжь. Музыка своя — синтезируется кодом, 128 ударов в минуту.
##
## Танцевать — «E» на танцполе: двенадцать ударов, жми «E» в такт вспышкам.
## Попал хотя бы в девять — зажёг танцпол (в городе за лучший танец — приз,
## раз за вечер). Устаёшь, время идёт.
##
## Настройка — до add_child: название, место, размер, часы и дни работы, цена.

const Villagers := preload("res://scripts/world/villagers.gd")
const BPM := 128.0
const DANCE_BEATS := 12
const DANCE_GOOD := 9

var title := "Клуб"
## Центр здания; вход смотрит в +Z (yaw поворачивает)
var center := Vector3.ZERO
var yaw := 0.0
var size := Vector2(16, 11)
var wall_color := Color(0.85, 0.8, 0.65)
var accent := Color(0.7, 0.2, 0.25)
var open_hour := 20.0
var close_hour := 1.0
## Дни недели, когда дискотека (пусто — каждый день); как в TimeManager.WEEKDAYS
var days: Array = []
var fee := 20
var prize := 0
## Площадка перед входом (в координатах клуба, вход — в +Z)
var plaza := Rect2()

var dancing := false
var _beat_t := 0.0
var _beats := 0
var _hits := 0
var _pressed_beat := -1
var _paid_day := -99
var _prize_day := -99
var _tiles: Array[StandardMaterial3D] = []
var _ball: MeshInstance3D
var _dancers: Array[MeshInstance3D] = []
var _dj: MeshInstance3D
var _music: AudioStreamPlayer3D
var _light: OmniLight3D
var _porch: OmniLight3D
var _front: MeshInstance3D
var _door_block: CollisionShape3D
var _t := 0.0
var _xf := Transform3D.IDENTITY


func _ready() -> void:
	add_to_group("persist")
	_xf = Transform3D(Basis(Vector3.UP, yaw), center)
	_build()


## Сейчас дискотека? С учётом ночи после полуночи — это ещё вчерашний вечер.
func is_open() -> bool:
	var h := TimeManager.hour()
	var late := h < close_hour
	if not (h >= open_hour or late):
		return false
	if days.is_empty():
		return true
	var d: int = TimeManager.day - (1 if late else 0)
	return days.has(TimeManager.WEEKDAYS[d % 7])


## Какой вечер сейчас идёт (для билета и приза).
func _night() -> int:
	return TimeManager.day - (1 if TimeManager.hour() < close_hour else 0)


func _schedule_text() -> String:
	var when := "каждый вечер" if days.is_empty() else "по %s" % ", ".join(days)
	return "%s с %d:00 до %d:00" % [when, int(open_hour), int(close_hour)]


func _p(local: Vector3) -> Vector3:
	return _xf * local


func _build() -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var b := MeshBuilder.new()
	b.xf = _xf
	var h := 4.2
	var wall := 0.25
	# Пол, стены с проёмом двери в передней стене, плоская крыша
	b.box(Vector3(-hx, 0, -hz), Vector3(hx, 0.06, hz), Color(0.22, 0.2, 0.22))
	b.box(Vector3(-hx, 0, -hz), Vector3(hx, h, -hz + wall), wall_color, true)
	b.box(Vector3(-hx, 0, -hz), Vector3(-hx + wall, h, hz), wall_color, true)
	b.box(Vector3(hx - wall, 0, -hz), Vector3(hx, h, hz), wall_color, true)
	b.box(Vector3(-hx, 0, hz - wall), Vector3(-1.1, h, hz), wall_color, true)
	b.box(Vector3(1.1, 0, hz - wall), Vector3(hx, h, hz), wall_color, true)
	b.box(Vector3(-1.1, 2.4, hz - wall), Vector3(1.1, h, hz), wall_color)
	b.box(Vector3(-hx - 0.2, h, -hz - 0.2), Vector3(hx + 0.2, h + 0.3, hz + 0.2), Color(0.3, 0.3, 0.32))
	# Внутри потолок тёмный, стены в тёмной краске
	b.box(Vector3(-hx + wall, h - 0.05, -hz + wall), Vector3(hx - wall, h - 0.02, hz - wall), Color(0.08, 0.07, 0.1))
	for s in [-1.0, 1.0]:
		b.box(Vector3(s * (hx - wall) - 0.01 * s, 0.06, -hz + wall), Vector3(s * (hx - wall) - 0.02 * s, h - 0.05, hz - wall), Color(0.12, 0.1, 0.16))
	b.box(Vector3(-hx + wall, 0.06, -hz + wall + 0.01), Vector3(hx - wall, h - 0.05, -hz + wall + 0.02), Color(0.12, 0.1, 0.16))
	# Козырёк над входом, полоса-вывеска, ступени
	b.box(Vector3(-2.2, 2.6, hz), Vector3(2.2, 2.75, hz + 1.6), Color(0.25, 0.25, 0.27))
	b.box(Vector3(-hx, h - 1.1, hz + 0.001), Vector3(hx, h - 0.2, hz + 0.05), accent)
	b.box(Vector3(-1.6, 0, hz), Vector3(1.6, 0.12, hz + 1.8), Color(0.55, 0.55, 0.53))
	# Диджейский пульт у дальней стены, колонки по бокам, бар справа
	var back := -hz + wall
	b.box(Vector3(-1.6, 0, back + 0.5), Vector3(1.6, 1.05, back + 1.4), Color(0.15, 0.15, 0.17), true)
	b.box(Vector3(-1.4, 1.05, back + 0.6), Vector3(-0.3, 1.12, back + 1.3), Color(0.3, 0.3, 0.32))
	b.box(Vector3(0.3, 1.05, back + 0.6), Vector3(1.4, 1.12, back + 1.3), Color(0.3, 0.3, 0.32))
	for s in [-1.0, 1.0]:
		var sp := Vector3(s * 3.4, 0, back + 0.8)
		b.box(sp + Vector3(-0.6, 0, -0.5), sp + Vector3(0.6, 2.2, 0.5), Color(0.08, 0.08, 0.09), true)
		for k in 2:
			b.box(sp + Vector3(-0.35, 0.5 + k * 0.9, 0.5), sp + Vector3(0.35, 1.2 + k * 0.9, 0.52), Color(0.25, 0.25, 0.27))
	var bar := Vector3(hx - wall - 1.0, 0, 0.5)
	b.box(bar + Vector3(-0.5, 0, -2.5), bar + Vector3(0.5, 1.1, 2.5), Color(0.35, 0.22, 0.15), true)
	b.box(bar + Vector3(-0.6, 1.1, -2.6), bar + Vector3(0.6, 1.16, 2.6), Color(0.5, 0.35, 0.25))
	for k in 5:
		b.box(bar + Vector3(0.7, 1.4, -2.0 + k * 0.9), bar + Vector3(0.85, 1.75, -1.8 + k * 0.9), [Color(0.3, 0.6, 0.3), Color(0.7, 0.5, 0.2), Color(0.5, 0.2, 0.2)][k % 3])
	if plaza.size != Vector2.ZERO:
		b.box(Vector3(plaza.position.x, 0, plaza.position.y), Vector3(plaza.end.x, 0.045, plaza.end.y), Color(0.34, 0.34, 0.35))
	add_child(b.build_mesh())
	add_child(b.build_body())
	# Вывески: над входом и на крыше
	var sign := Label3D.new()
	sign.text = title
	sign.font_size = 96
	sign.pixel_size = 0.008
	sign.outline_size = 10
	sign.modulate = Color(1.0, 0.95, 0.8)
	sign.position = _p(Vector3(0, h - 0.65, hz + 0.07))
	sign.rotation.y = yaw
	add_child(sign)
	var neon := Label3D.new()
	neon.text = "ДИСКОТЕКА"
	neon.font_size = 96
	neon.pixel_size = 0.007
	neon.outline_size = 14
	neon.modulate = Color(1.0, 0.4, 0.9)
	neon.outline_modulate = Color(0.5, 0.0, 0.5)
	neon.position = _p(Vector3(0, h + 0.9, hz - 0.2))
	neon.rotation.y = yaw
	add_child(neon)
	# Танцпол: плитки четырёх цветов, мигают в такт
	var colors := [Color(1.0, 0.2, 0.4), Color(0.2, 0.6, 1.0), Color(0.3, 1.0, 0.4), Color(1.0, 0.85, 0.2)]
	var floor_b: Array[MeshBuilder] = []
	for i in 4:
		var fb := MeshBuilder.new()
		fb.ground_shade = false
		floor_b.append(fb)
	var nx := int(size.x * 0.5) - 1
	var nz := int(size.y * 0.5) - 1
	for ix in nx:
		for iz in nz:
			var x0 := -nx * 0.5 + ix
			var z0 := -nz * 0.5 + iz + 0.8
			var k := (ix + iz * 3) % 4
			floor_b[k].box(Vector3(x0 + 0.04, 0.06, z0 + 0.04), Vector3(x0 + 0.96, 0.08, z0 + 0.96), Color.WHITE)
	for i in 4:
		var mi := floor_b[i].build_mesh(true)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = colors[i]
		mi.material_override = m
		mi.transform = _xf
		add_child(mi)
		_tiles.append(m)
	# Зеркальный шар под потолком
	_ball = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	sphere.radial_segments = 12
	sphere.rings = 6
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.85, 0.85, 0.9)
	bm.metallic = 1.0
	bm.roughness = 0.15
	sphere.material = bm
	_ball.mesh = sphere
	_ball.position = _p(Vector3(0, h - 0.8, 0.8))
	add_child(_ball)
	# Цветной свет над танцполом — только когда дискотека и игрок рядом
	_light = OmniLight3D.new()
	_light.omni_range = maxf(size.x, size.y) * 0.7
	_light.light_energy = 1.0
	_light.position = _p(Vector3(0, h - 1.2, 0.8))
	_light.visible = false
	add_child(_light)
	# Снаружи: окна светятся цветом танцпола, фонарь над входом
	var fw := MeshBuilder.new()
	fw.ground_shade = false
	for s in [-1.0, 1.0]:
		for k in 2:
			var x0: float = s * (2.2 + k * 2.4)
			fw.box(Vector3(x0 - 0.8, 1.2, hz + 0.01), Vector3(x0 + 0.8, 2.4, hz + 0.04), Color.WHITE)
	_front = fw.build_mesh(true)
	_front.transform = _xf
	_front.material_override = _tiles[1]
	add_child(_front)
	var lamp := MeshBuilder.new()
	lamp.ground_shade = false
	lamp.box(Vector3(-0.3, 2.45, hz + 1.2), Vector3(0.3, 2.58, hz + 1.5), Color(1.0, 0.92, 0.7))
	var lamp_mi := lamp.build_mesh(true)
	lamp_mi.transform = _xf
	add_child(lamp_mi)
	_porch = OmniLight3D.new()
	_porch.omni_range = 7.0
	_porch.light_energy = 1.2
	_porch.light_color = Color(1.0, 0.85, 0.6)
	_porch.position = _p(Vector3(0, 2.3, hz + 1.8))
	_porch.visible = false
	add_child(_porch)
	# Диджей и танцующие
	var shirts := [Color(0.8, 0.2, 0.3), Color(0.2, 0.4, 0.8), Color(0.9, 0.8, 0.2), Color(0.3, 0.7, 0.4),
		Color(0.7, 0.3, 0.8), Color(0.95, 0.95, 0.95), Color(0.2, 0.2, 0.25)]
	var spots := [Vector3(-2.2, 0.08, 0.2), Vector3(1.5, 0.08, -0.4), Vector3(-0.5, 0.08, 2.0),
		Vector3(2.4, 0.08, 1.9), Vector3(-2.8, 0.08, 2.6), Vector3(0.8, 0.08, 0.9)]
	for i in spots.size():
		var pb := MeshBuilder.new()
		pb.ground_shade = false
		Villagers.person_model(pb, shirts[i % shirts.size()], Color(0.25, 0.2, 0.15), false, i % 2 == 0)
		var mi := Villagers.walking_mesh(pb)
		mi.position = _p(spots[i])
		mi.rotation.y = yaw + randf() * TAU
		mi.visible = false
		add_child(mi)
		_dancers.append(mi)
	var db := MeshBuilder.new()
	db.ground_shade = false
	Villagers.person_model(db, Color(0.1, 0.1, 0.12), Color(0.9, 0.2, 0.2), false, false)
	_dj = Villagers.walking_mesh(db)
	_dj.position = _p(Vector3(0, 0.06, back + 1.9))
	_dj.rotation.y = yaw + PI
	_dj.visible = false
	add_child(_dj)
	# Дверь: закрыто — не пройти
	var door := StaticBody3D.new()
	_door_block = CollisionShape3D.new()
	var ds := BoxShape3D.new()
	ds.size = Vector3(2.2, 2.4, 0.3)
	_door_block.shape = ds
	_door_block.position = Vector3(0, 1.2, hz - 0.1)
	door.add_child(_door_block)
	door.transform = _xf
	add_child(door)
	var entry := InteractZone.create("", Vector3(3.0, 2.2, 2.0))
	entry.transform = _xf * Transform3D(Basis.IDENTITY, Vector3(0, 0, hz + 1.4))
	entry.prompt_fn = _entry_prompt
	entry.activated.connect(_enter)
	add_child(entry)
	var floor_zone := InteractZone.create("", Vector3(nx, 2.2, nz))
	floor_zone.transform = _xf * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.8))
	floor_zone.prompt_fn = _dance_prompt
	floor_zone.activated.connect(_dance_press)
	add_child(floor_zone)
	var drink := InteractZone.create("", Vector3(1.6, 2.2, 4.0))
	drink.transform = _xf * Transform3D(Basis.IDENTITY, bar + Vector3(-1.2, 0, 0))
	drink.prompt_fn = func() -> String:
		return "E — лимонад «Буратино» (20 грн)" if is_open() else ""
	drink.activated.connect(_drink)
	add_child(drink)
	_music = AudioStreamPlayer3D.new()
	_music.unit_size = 7.0
	_music.max_distance = 70.0
	_music.volume_db = -4.0
	_music.position = _p(Vector3(0, 2.0, back + 1.0))
	add_child(_music)


func _entry_prompt() -> String:
	if not is_open():
		return "%s: закрыто. Дискотека %s" % [title, _schedule_text()]
	if _paid_day == _night():
		return ""
	return "E — билет на дискотеку: %d грн" % fee


func _enter() -> void:
	if not is_open() or _paid_day == _night():
		return
	if not GameManager.spend(fee):
		return
	_paid_day = _night()
	SoundLibrary.play("click", -4.0)
	QuestManager.event("disco")
	GameManager.notify("%s: заходи! Танцпол — «E» в такт музыке" % title)


func _dance_prompt() -> String:
	if not is_open() or _paid_day != _night():
		return ""
	if dancing:
		return "E — в такт! (%d из %d)" % [_hits, DANCE_BEATS]
	return "E — танцевать"


func _dance_press() -> void:
	if not is_open() or _paid_day != _night():
		return
	if not dancing:
		if NeedsManager.energy < 8.0:
			GameManager.notify("Ноги не держат — пора спать")
			return
		dancing = true
		_beats = 0
		_hits = 0
		_pressed_beat = -1
		_beat_t = 0.0
		GameManager.challenge_line = "Танцуй: жми «E», когда вспыхивает пол"
		return
	# Попадание: близко к удару и не дважды на один удар
	var period := 60.0 / BPM
	var ph := fmod(_beat_t, period)
	var err := minf(ph, period - ph)
	var beat := int(roundf(_beat_t / period))
	if err < 0.13 and beat != _pressed_beat:
		_pressed_beat = beat
		_hits += 1


func _finish_dance() -> void:
	dancing = false
	GameManager.challenge_line = ""
	TimeManager.advance(30.0)
	NeedsManager.rest(-5.0)
	QuestManager.event("dance")
	if _hits >= DANCE_GOOD:
		if prize > 0 and _prize_day != _night():
			_prize_day = _night()
			GameManager.add_money(prize)
			SoundLibrary.play("cash")
			GameManager.notify("Ты зажёг танцпол! %d из %d в такт — приз за лучший танец %d грн" % [_hits, DANCE_BEATS, prize])
		else:
			GameManager.notify("Ты зажёг танцпол! %d из %d в такт — все смотрят на тебя" % [_hits, DANCE_BEATS])
		QuestManager.event("dance_star")
	else:
		GameManager.notify("Потанцевал: %d из %d в такт. Слушай бит — «E» на вспышку пола" % [_hits, DANCE_BEATS])


func _drink() -> void:
	if GameManager.spend(20):
		NeedsManager.eat(6.0)
		NeedsManager.rest(3.0)
		SoundLibrary.play("click", -4.0)
		GameManager.notify("Лимонад «Буратино» — холодный, с пузырьками")


func _process(delta: float) -> void:
	_t += delta
	var open := is_open()
	var pass_ok := open and _paid_day == _night()
	if _door_block.disabled != pass_ok:
		_door_block.disabled = pass_ok
	var p := GameManager.player as Node3D
	var near := p != null and p.global_position.distance_to(center) < 70.0
	var live := open and near
	_light.visible = live
	_porch.visible = live
	_front.visible = open
	_dj.visible = open
	for d in _dancers:
		d.visible = open
	if live and not _music.playing:
		if _music.stream == null:
			_music.stream = _disco_loop()
		_music.play()
	elif not live and _music.playing:
		_music.stop()
	if dancing and (not open or p == null or p.global_position.distance_to(center) > maxf(size.x, size.y)):
		dancing = false
		GameManager.challenge_line = ""
	if not live:
		return
	# Бит: пол вспыхивает на каждый удар, цвета бегут по кругу
	var period := 60.0 / BPM
	var beat_pos := fmod(_t, period) / period
	var flash := 1.0 - beat_pos
	var step := int(_t / period)
	var colors := [Color(1.0, 0.2, 0.4), Color(0.2, 0.6, 1.0), Color(0.3, 1.0, 0.4), Color(1.0, 0.85, 0.2)]
	for i in 4:
		var c: Color = colors[(i + step) % 4]
		_tiles[i].albedo_color = c * (0.35 + 0.65 * flash)
	_light.light_color = colors[step % 4]
	_ball.rotation.y += delta * 0.8
	for i in _dancers.size():
		var d := _dancers[i]
		Villagers.set_walk(d, _t * TAU * BPM / 60.0 * 0.5 + i, 0.8)
		d.position.y = center.y + 0.08 + absf(sin(_t * PI * BPM / 60.0 + i)) * 0.12
		d.rotation.y += delta * (0.6 if i % 2 == 0 else -0.5)
	Villagers.set_walk(_dj, _t * TAU * BPM / 60.0 * 0.5, 0.3)
	if dancing:
		_beat_t += delta
		var b := int(_beat_t / period)
		if b >= DANCE_BEATS:
			_finish_dance()
		else:
			GameManager.challenge_line = "Танцуй в такт: %d из %d, удар %d/%d" % [_hits, DANCE_BEATS, b + 1, DANCE_BEATS]


## Танцевальная петля на два такта: бочка на каждую долю, хэт между ними,
## бас по нотам ля минор — фа — до — соль, аккорд-«стаб» на слабые доли.
## Готовая петля — sounds/music/disco.wav (собрать её здесь же — заметная
## пауза на телефоне при входе на дискотеку).
static var _loop: AudioStream


static func _disco_loop() -> AudioStream:
	if _loop == null:
		_loop = Assets.sound("music/disco", make_disco_loop)
	return _loop


static func make_disco_loop() -> AudioStreamWAV:
	var rate := 16000
	var beat := 60.0 / BPM
	var beats := 8
	var n := int(beat * beats * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var bass_notes := [45, 41, 48, 43]  # A2 F2 C3 G2
	var rng := RandomNumberGenerator.new()
	rng.seed = 128
	for i in n:
		var t := float(i) / rate
		var bt := fmod(t, beat)
		var bi := int(t / beat)
		# Бочка: частота падает от 120 до 45 Гц
		var kf := 45.0 + 75.0 * exp(-bt * 30.0)
		var kick := sin(TAU * kf * bt) * exp(-bt * 9.0) * 0.8
		# Хэт на «и»
		var off := fmod(t + beat * 0.5, beat)
		var hat := rng.randf_range(-1.0, 1.0) * exp(-off * 60.0) * 0.18
		# Бас восьмыми на слабые доли
		var note: int = bass_notes[(bi / 2) % 4]
		var bf := 440.0 * pow(2.0, (note - 69) / 12.0)
		var bass := (1.0 if fmod(t * bf, 1.0) < 0.5 else -1.0) * 0.16 * (1.0 - exp(-off * 40.0)) * exp(-off * 3.0)
		# Аккорд-стаб на вторую и четвёртую долю
		var stab := 0.0
		if bi % 2 == 1:
			for k in [0, 3, 7]:
				var sf := bf * 2.0 * pow(2.0, k / 12.0)
				stab += sin(TAU * sf * bt) * 0.07
			stab *= exp(-bt * 6.0)
		buf[i] = clampf(kick + hat + bass + stab, -1.0, 1.0)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(buf[i] * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = bytes
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = n
	return s


func save_state() -> Dictionary:
	return {"paid": _paid_day, "prize": _prize_day}


func load_state(d: Dictionary) -> void:
	_paid_day = int(d.get("paid", -99))
	_prize_day = int(d.get("prize", -99))
