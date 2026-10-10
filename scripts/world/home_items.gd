extends Node3D
## Покупки из «Хозтоваров» у себя дома: телевизор в комнате, пёс Шарик
## с будкой во дворе, теплица над огородом. С базара: ковёр, магнитофон
## «Весна» (играет музыку), холодильник «ЗИЛ» (каждое утро +1 еды в запас),
## кресло-качалка. Появляются сразу после покупки и после перестройки дома
## встают на новые места.

var house_pos := Vector3.ZERO  # центр двора игрока (земля)
var door_x := 0.0  # смещение двери вдоль фасада

var _dog: Node3D
var _tail: Node3D
var _bark_cool := 0.0
var _t := 0.0
var _chair: Node3D
var _tape: AudioStreamPlayer3D


func _ready() -> void:
	Progress.home_changed.connect(rebuild)
	Progress.house_changed.connect(func(_l: int) -> void: rebuild.call_deferred())
	TimeManager.minute_passed.connect(func(_m: float) -> void: _fridge())
	rebuild.call_deferred()


## Холодильник: утром в нём находится что поесть — раз в сутки.
func _fridge() -> void:
	if not Progress.has_item("fridge") or Progress.fridge_day >= TimeManager.day or TimeManager.hour() < 6.0:
		return
	Progress.fridge_day = TimeManager.day
	NeedsManager.snacks += 1
	NeedsManager.changed.emit()
	GameManager.notify("В холодильнике «Морозко» нашлось что поесть: +1 еды в запас")


func _house() -> HouseInterior:
	return get_parent().get_node_or_null("House_%d_%d" % [int(house_pos.x), int(house_pos.z)]) as HouseInterior


func rebuild() -> void:
	# Убираем старое сразу из дерева: иначе новые узлы с теми же именами
	# получат чужие имена, пока старые ждут удаления
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_dog = null
	_chair = null
	_tape = null
	if Progress.has_item("rug"):
		_build_rug()
	if Progress.has_item("tape"):
		_build_tape()
	if Progress.has_item("fridge"):
		_build_fridge()
	if Progress.has_item("chair"):
		_build_chair()
	if Progress.has_item("tv"):
		_build_tv()
	if Progress.has_item("dog"):
		_build_dog()
	if Progress.has_item("greenhouse"):
		_build_greenhouse()


func _mesh(b: MeshBuilder, name: String) -> MeshInstance3D:
	var m := b.build_mesh()
	m.name = name
	# Вещи в доме — на слое интерьера: их освещают лампы дома
	m.layers = 1 | HouseInterior.INSIDE_LAYER
	add_child(m)
	return m


## Телевизор «Рубин» на тумбочке в углу комнаты, экран светится вечером.
func _build_tv() -> void:
	var h := _house()
	if h == null:
		return
	var r := h._room_rect()
	var b := MeshBuilder.new()
	b.ground_shade = false
	var wood := Color(0.4, 0.26, 0.15)
	var p := Vector3(r.position.x + 0.15, 0, r.position.y + 0.25)
	b.box(p, p + Vector3(0.55, 0.55, 0.8), wood)
	b.box(p + Vector3(0.05, 0.55, 0.05), p + Vector3(0.5, 1.05, 0.75), Color(0.18, 0.13, 0.1))
	b.box(p + Vector3(0.5, 0.62, 0.12), p + Vector3(0.52, 0.98, 0.6), Color(0.35, 0.45, 0.5))
	b.box(p + Vector3(0.5, 0.65, 0.63), p + Vector3(0.53, 0.72, 0.7), Color(0.8, 0.8, 0.8))
	b.box(p + Vector3(0.2, 1.05, 0.35), p + Vector3(0.25, 1.35, 0.4), Color(0.7, 0.7, 0.72))
	var m := _mesh(b, "TV")
	m.global_transform = h.global_transform
	# Отсвет экрана — мягкий голубоватый
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.6, 0.75, 1.0)
	glow.light_energy = 0.35
	glow.omni_range = 2.2
	glow.position = p + Vector3(0.9, 0.8, 0.4)
	glow.light_cull_mask = HouseInterior.INSIDE_LAYER
	m.add_child(glow)


## Ковёр с узором посреди комнаты.
func _build_rug() -> void:
	var h := _house()
	if h == null:
		return
	var r := h._room_rect()
	var c := Vector3(r.get_center().x, 0.012, r.get_center().y - 0.6)
	var b := MeshBuilder.new()
	b.ground_shade = false
	var rings := [Color(0.55, 0.1, 0.1), Color(0.85, 0.7, 0.35), Color(0.45, 0.08, 0.1), Color(0.15, 0.25, 0.45), Color(0.8, 0.65, 0.3)]
	var w := 1.1
	var d := 0.8
	for i in rings.size():
		var k := 1.0 - i * 0.18
		var y := c.y + i * 0.002
		b.quad(Vector3(c.x - w * k, y, c.z + d * k), Vector3(c.x + w * k, y, c.z + d * k), Vector3(c.x + w * k, y, c.z - d * k), Vector3(c.x - w * k, y, c.z - d * k), rings[i])
	var m := _mesh(b, "Rug")
	m.global_transform = h.global_transform


## Магнитофон «Весна» на тумбочке: по E играет кассету.
func _build_tape() -> void:
	var h := _house()
	if h == null:
		return
	var r := h._room_rect()
	var p := Vector3(r.position.x + 0.12, 0, r.position.y + 1.25)
	var b := MeshBuilder.new()
	b.ground_shade = false
	b.box(p, p + Vector3(0.45, 0.6, 0.55), Color(0.42, 0.28, 0.17))
	var t := p + Vector3(0.08, 0.6, 0.05)
	b.box(t, t + Vector3(0.28, 0.24, 0.45), Color(0.15, 0.15, 0.16))
	b.box(t + Vector3(0.28, 0.03, 0.04), t + Vector3(0.29, 0.21, 0.16), Color(0.55, 0.55, 0.57))
	b.box(t + Vector3(0.28, 0.03, 0.29), t + Vector3(0.29, 0.21, 0.41), Color(0.55, 0.55, 0.57))
	b.box(t + Vector3(0.28, 0.08, 0.18), t + Vector3(0.295, 0.17, 0.27), Color(0.75, 0.7, 0.55))
	b.box(t + Vector3(0.12, 0.24, 0.05), t + Vector3(0.14, 0.27, 0.4), Color(0.8, 0.8, 0.82))
	var m := _mesh(b, "Tape")
	m.global_transform = h.global_transform
	_tape = AudioStreamPlayer3D.new()
	_tape.stream = Assets.sound("music/radio_1", Callable())
	_tape.position = t + Vector3(0.15, 0.12, 0.22)
	_tape.unit_size = 4.0
	_tape.max_distance = 25.0
	m.add_child(_tape)
	var z := InteractZone.create("E — магнитофон «Ветерок»", Vector3(1.4, 1.6, 1.6))
	z.name = "TapeZone"
	z.prompt_fn = func() -> String:
		return "E — выключить магнитофон" if _tape and _tape.playing else "E — включить магнитофон «Ветерок»"
	z.position = p + Vector3(0.6, 0, 0.27)
	z.activated.connect(toggle_tape)
	m.add_child(z)


func toggle_tape() -> void:
	if _tape == null or _tape.stream == null:
		return
	if _tape.playing:
		_tape.stop()
	else:
		_tape.volume_db = linear_to_db(maxf(SettingsManager.music, 0.01)) + 2.0
		_tape.play()


## Холодильник «ЗИЛ» в углу кухни.
func _build_fridge() -> void:
	var h := _house()
	if h == null:
		return
	var k := h._kitchen_rect()
	var p := Vector3(k.end.x - 0.7, 0, k.position.y + 0.05)
	var b := MeshBuilder.new()
	b.ground_shade = false
	var white := Color(0.93, 0.93, 0.9)
	b.box(p, p + Vector3(0.62, 1.55, 0.6), white, true)
	b.box(p + Vector3(0.0, 1.55, 0.0), p + Vector3(0.62, 1.62, 0.6), white.darkened(0.08))
	b.box(p + Vector3(0.02, 1.0, 0.6), p + Vector3(0.6, 1.02, 0.61), Color(0.6, 0.6, 0.6))
	b.box(p + Vector3(0.5, 0.75, 0.6), p + Vector3(0.55, 1.35, 0.65), Color(0.75, 0.76, 0.78))
	b.box(p + Vector3(0.18, 1.4, 0.6), p + Vector3(0.44, 1.46, 0.605), Color(0.7, 0.15, 0.12))
	var m := _mesh(b, "Fridge")
	m.global_transform = h.global_transform
	var body := b.build_body()
	add_child(body)
	body.global_transform = h.global_transform


## Кресло-качалка у телевизора — само тихонько покачивается.
func _build_chair() -> void:
	var h := _house()
	if h == null:
		return
	var r := h._room_rect()
	var b := MeshBuilder.new()
	b.ground_shade = false
	var wood := Color(0.48, 0.3, 0.16)
	var seat := Color(0.62, 0.2, 0.15)
	for x in [-0.3, 0.26]:
		b.box(Vector3(x, 0, -0.4), Vector3(x + 0.04, 0.05, 0.4), wood)
		b.box(Vector3(x, 0.05, -0.2), Vector3(x + 0.04, 0.45, -0.16), wood)
		b.box(Vector3(x, 0.05, 0.2), Vector3(x + 0.04, 0.45, 0.24), wood)
		b.box(Vector3(x, 0.62, -0.25), Vector3(x + 0.04, 0.66, 0.15), wood)
	b.box(Vector3(-0.3, 0.42, -0.25), Vector3(0.3, 0.5, 0.25), seat)
	b.box(Vector3(-0.3, 0.5, 0.2), Vector3(0.3, 1.1, 0.28), seat)
	b.box(Vector3(-0.3, 1.1, 0.18), Vector3(0.3, 1.16, 0.3), wood)
	_chair = Node3D.new()
	_chair.name = "Chair"
	add_child(_chair)
	_chair.global_transform = h.global_transform * Transform3D(Basis(Vector3.UP, PI * 0.75), Vector3(r.position.x + 1.7, 0, r.position.y + 0.9))
	var m := b.build_mesh()
	m.layers = 1 | HouseInterior.INSIDE_LAYER
	_chair.add_child(m)


## Пёс у будки во дворе, виляет хвостом. Будка у бедного и среднего
## двора уже стоит пустая; у кирпичного дома и коттеджа её нет — ставим свою.
func _build_dog() -> void:
	var base := house_pos + Vector3(3.6, 0, 8.2)
	if Progress.house_level >= 2:
		_build_kennel(base)
	_build_dog_at(base)


func _build_kennel(base: Vector3) -> void:
	var b := MeshBuilder.new()
	b.ground_shade = false
	var plank := Color(0.5, 0.35, 0.2)
	b.box(Vector3(-0.6, 0, -0.5), Vector3(0.6, 0.8, 0.5), plank)
	b.quad(Vector3(-0.7, 0.8, 0.6), Vector3(0.7, 0.8, 0.6), Vector3(0.7, 1.15, 0), Vector3(-0.7, 1.15, 0), Color(0.3, 0.3, 0.32))
	b.quad(Vector3(0.7, 0.8, -0.6), Vector3(-0.7, 0.8, -0.6), Vector3(-0.7, 1.15, 0), Vector3(0.7, 1.15, 0), Color(0.3, 0.3, 0.32))
	b.box(Vector3(-0.22, 0.02, 0.5), Vector3(0.22, 0.5, 0.51), Color(0.08, 0.06, 0.05))
	b.add_collider(Vector3(-0.6, 0, -0.5), Vector3(0.6, 0.9, 0.5))
	var kennel := _mesh(b, "Kennel")
	kennel.global_position = base
	add_child(b.build_body())
	get_child(get_child_count() - 1).global_position = base


func _build_dog_at(base: Vector3) -> void:
	# Пёс: туловище, голова, уши, лапы и хвост отдельным узлом
	_dog = Node3D.new()
	_dog.name = "Dog"
	add_child(_dog)
	_dog.global_position = base + Vector3(-0.35, 0, 1.3)
	var d := MeshBuilder.new()
	d.ground_shade = false
	var fur := Color(0.62, 0.45, 0.25)
	d.box(Vector3(-0.14, 0.25, -0.35), Vector3(0.14, 0.5, 0.25), fur)
	d.box(Vector3(-0.12, 0.42, 0.22), Vector3(0.12, 0.64, 0.45), fur)
	d.box(Vector3(-0.06, 0.45, 0.45), Vector3(0.06, 0.55, 0.56), fur.darkened(0.2))
	d.box(Vector3(-0.02, 0.5, 0.56), Vector3(0.02, 0.54, 0.58), Color(0.05, 0.05, 0.05))
	for x in [-0.1, 0.06]:
		d.box(Vector3(x, 0.62, 0.3), Vector3(x + 0.05, 0.72, 0.36), fur.darkened(0.35))
		d.box(Vector3(x, 0.54, 0.44), Vector3(x + 0.04, 0.58, 0.45), Color(0.05, 0.05, 0.05))
	for p in [Vector2(-0.12, -0.3), Vector2(0.06, -0.3), Vector2(-0.12, 0.16), Vector2(0.06, 0.16)]:
		d.box(Vector3(p.x, 0, p.y), Vector3(p.x + 0.06, 0.26, p.y + 0.07), fur.darkened(0.1))
	_dog.add_child(d.build_mesh())
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.45, -0.35)
	var t := MeshBuilder.new()
	t.ground_shade = false
	t.box(Vector3(-0.025, 0, -0.25), Vector3(0.025, 0.05, 0), fur.darkened(0.15))
	_tail.add_child(t.build_mesh())
	_dog.add_child(_tail)
	_dog.rotation.y = PI


## Теплица над огородом: рама и мутноватая плёнка.
func _build_greenhouse() -> void:
	var c := house_pos + Vector3(0, 0, -11.8)
	var frame := MeshBuilder.new()
	frame.ground_shade = false
	var metal := Color(0.75, 0.77, 0.78)
	var hx := 11.2
	var hz := 3.0
	for x in range(-11, 12, 2):
		for z in [-hz, hz]:
			frame.box(Vector3(x - 0.04, 0, z - 0.04), Vector3(x + 0.04, 1.8, z + 0.04), metal)
		frame.box(Vector3(x - 0.04, 1.8, -hz), Vector3(x + 0.04, 2.5, 0.04), metal)
		frame.box(Vector3(x - 0.04, 1.8, -0.04), Vector3(x + 0.04, 2.5, hz), metal)
	frame.box(Vector3(-hx, 2.46, -0.05), Vector3(hx, 2.54, 0.05), metal)
	var fm := _mesh(frame, "GreenhouseFrame")
	fm.global_position = c
	# Плёнка — одна прозрачная оболочка
	var film := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(hx * 2.0, 2.4, hz * 2.0)
	film.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.95, 0.9, 0.18)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.2
	film.material_override = mat
	film.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	film.name = "GreenhouseFilm"
	add_child(film)
	film.global_position = c + Vector3(0, 1.2, 0)


func _process(delta: float) -> void:
	_t += delta
	if _chair and is_instance_valid(_chair):
		(_chair.get_child(0) as Node3D).rotation.x = sin(_t * 1.6) * 0.06
	if _dog == null or not is_instance_valid(_dog):
		return
	_bark_cool -= delta
	var p := GameManager.player as Node3D
	var near := p != null and p.global_position.distance_to(_dog.global_position) < 7.0
	# Хозяин рядом — хвост ходуном, пёс смотрит на него
	_tail.rotation.y = sin(_t * (14.0 if near else 3.0)) * (0.7 if near else 0.25)
	if near:
		var to := p.global_position - _dog.global_position
		_dog.rotation.y = lerp_angle(_dog.rotation.y, atan2(to.x, to.z), delta * 3.0)
		if _bark_cool <= 0.0:
			SoundLibrary.play_at("bark", _dog.global_position, -4.0, 1.25)
			_bark_cool = 25.0
