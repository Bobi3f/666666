class_name MyGarage
extends Node3D
## Личный гараж у дома игрока в Каменке: вся своя техника стоит внутри,
## E у ворот — список: выкатить нужную (встаёт на дорожку перед домом),
## загнать обратно, загнать всё разом (откуда угодно — как будто пригнал).
## Техника в гараже не видна и не считается — это и быстрее (Vehicle.garaged).

## Коробка гаража справа от дома: x, z — от и до; ворота — к улице (+Z).
const BOX := Rect2(-119.5, -60.0, 6.0, 7.5)
## Куда выкатывается техника: дорожка перед домом, носом к улице.
const EXIT := Vector3(-126.7, 0.1, -47.0)

var panel: GaragePanel


func build(world: Node3D) -> void:
	name = "MyGarage"
	var b := MeshBuilder.new()
	var x0 := BOX.position.x
	var x1 := BOX.end.x
	var z0 := BOX.position.y
	var z1 := BOX.end.y
	var wall := Color(0.62, 0.6, 0.56)
	var h := 2.8
	# Стены (передняя — с проёмом под ворота), крыша, ворота
	b.box(Vector3(x0, 0, z0), Vector3(x0 + 0.2, h, z1), wall, true)
	b.box(Vector3(x1 - 0.2, 0, z0), Vector3(x1, h, z1), wall, true)
	b.box(Vector3(x0, 0, z0), Vector3(x1, h, z0 + 0.2), wall, true)
	b.box(Vector3(x0, 0, z1 - 0.2), Vector3(x0 + 0.6, h, z1), wall, true)
	b.box(Vector3(x1 - 0.6, 0, z1 - 0.2), Vector3(x1, h, z1), wall, true)
	b.box(Vector3(x0 + 0.6, 2.3, z1 - 0.2), Vector3(x1 - 0.6, h, z1), wall, true)
	b.box(Vector3(x0 - 0.2, h, z0 - 0.2), Vector3(x1 + 0.2, h + 0.15, z1 + 0.3), Color(0.38, 0.4, 0.42))
	# Ворота — железные, крашеные, с рёбрами
	var gate := Color(0.25, 0.42, 0.32)
	b.box(Vector3(x0 + 0.6, 0, z1 - 0.12), Vector3(x1 - 0.6, 2.3, z1 - 0.08), gate, true)
	for k in 5:
		var x := x0 + 0.9 + k * (BOX.size.x - 1.8) / 4.0
		b.box(Vector3(x - 0.04, 0.1, z1 - 0.08), Vector3(x + 0.04, 2.2, z1 - 0.04), gate.darkened(0.25))
	# Бетонный пятак перед воротами и дорожка к выезду
	b.box(Vector3(x0, 0, z1), Vector3(x1, 0.03, z1 + 3.0), Color(0.55, 0.55, 0.53))
	var mesh := b.build_mesh()
	mesh.material_override = MeshBuilder.detail_material()
	add_child(mesh)
	add_child(b.build_body())
	var lbl := Label3D.new()
	lbl.text = "ГАРАЖ"
	lbl.font_size = 72
	lbl.pixel_size = 0.006
	lbl.outline_size = 8
	lbl.modulate = Color(1.0, 0.9, 0.6)
	lbl.position = Vector3((x0 + x1) * 0.5, 2.55, z1 + 0.02)
	lbl.visibility_range_end = 130.0
	add_child(lbl)
	var zone := InteractZone.create("", Vector3(4.0, 2.2, 3.0))
	zone.position = Vector3((x0 + x1) * 0.5, 0, z1 + 1.6)
	zone.prompt_fn = prompt
	zone.activated.connect(open)
	add_child(zone)
	panel = GaragePanel.new()
	panel.garage = self
	world.add_child(panel)


func prompt() -> String:
	var inside := 0
	for v in vehicles():
		if (v as Vehicle).garaged:
			inside += 1
	return "E — гараж: выбрать технику (в гараже %d из %d)" % [inside, vehicles().size()]


func open() -> void:
	# Пять своих машин и мотоциклов — для главы «Коллекционер»
	if vehicles().size() >= 5:
		QuestManager.event("garage_5")
	panel.open()


## Вся своя техника (не учебная, не колхозный трактор).
func vehicles() -> Array:
	var out := []
	for v in get_tree().get_nodes_in_group("vehicles"):
		if (v as Vehicle).mine():
			out.append(v)
	return out


## Выкатить v на дорожку перед домом. Кто там уже стоял — в гараж.
func take_out(v: Vehicle) -> void:
	for o in vehicles():
		var other := o as Vehicle
		if other != v and not other.garaged and other.driver == null and other.global_position.distance_to(EXIT) < 5.0:
			other.set_garaged(true)
	if v.driver:
		return
	v.set_garaged(false, Transform3D(Basis(Vector3.UP, PI), EXIT))
	SoundLibrary.play("grind", -10.0, 0.6)
	QuestManager.event("garage_out")
	GameManager.notify("Выкатил из гаража «%s». Стоит на дорожке у дома" % v.spec.title)


## Загнать v в гараж (откуда угодно, кроме той, на которой едешь).
func store(v: Vehicle) -> bool:
	if v.garaged or v.driver != null:
		return false
	v.set_garaged(true)
	return true


## Вся своя техника — в гараж. Сколько загнали.
func store_all() -> int:
	var n := 0
	for v in vehicles():
		if store(v as Vehicle):
			n += 1
	if n > 0:
		SoundLibrary.play("grind", -10.0, 0.6)
		GameManager.notify("В гараже вся техника: загнал %d" % n)
	return n
