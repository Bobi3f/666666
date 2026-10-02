extends Node3D
## Покупки из «Хозтоваров» у себя дома: телевизор в комнате, пёс Шарик
## с будкой во дворе, теплица над огородом. Появляются сразу после покупки
## и после перестройки дома встают на новые места.

var house_pos := Vector3.ZERO  # центр двора игрока (земля)
var door_x := 0.0  # смещение двери вдоль фасада

var _dog: Node3D
var _tail: Node3D
var _bark_cool := 0.0
var _t := 0.0


func _ready() -> void:
	Progress.home_changed.connect(rebuild)
	Progress.house_changed.connect(func(_l: int) -> void: rebuild.call_deferred())
	rebuild.call_deferred()


func _house() -> HouseInterior:
	return get_parent().get_node_or_null("House_%d_%d" % [int(house_pos.x), int(house_pos.z)]) as HouseInterior


func rebuild() -> void:
	# Убираем старое сразу из дерева: иначе новые узлы с теми же именами
	# получат чужие имена, пока старые ждут удаления
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_dog = null
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


## Пёс у будки во дворе, виляет хвостом. Будка у бедного и среднего
## двора уже стоит пустая; у кирпичного дома её нет — ставим свою.
func _build_dog() -> void:
	var base := house_pos + Vector3(3.6, 0, 8.2)
	if Progress.max_level():
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
	if _dog == null or not is_instance_valid(_dog):
		return
	_t += delta
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
