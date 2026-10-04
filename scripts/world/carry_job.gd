class_name CarryJob
extends Node3D
## Работа руками по шагам: взял груз (тюк сена, мешок), донёс, положил —
## и так, пока смена не кончится. Каждый донесённый груз оплачивается сразу,
## идёт время, тратятся силы. Над тем местом, куда идти, прыгает жёлтая
## стрелка; сверху экрана — сколько осталось. Груз виден в руках, куча
## на месте погрузки тает, в кузове растёт.
##
## Смену можно бросить: уйти далеко или сесть в машину — заплачено уже
## за донесённое. Вся смена — событие для заданий и достижений.

signal finished(done: int)

var title := "Работа"
var item_name := "груз"
## Где берём груз и куда несём (точки на земле)
var pickup := Vector3.ZERO
var drop := Vector3.ZERO
## Где лежит куча груза и куда его складывают: начало ряда, шаг, в ряду
var pile_at := Vector3.ZERO
var stack_at := Vector3.ZERO
var stack_yaw := 0.0
var per_row := 4
var total := 8
var pay_each := 50
var minutes_each := 20.0
var energy_each := 2.0
var item_size := Vector3(0.9, 0.5, 0.5)
var item_color := Color(0.75, 0.65, 0.35)
## Событие за всю смену: kolkhoz, shift
var event_name := ""
## Почему нельзя начать (пусто — можно)
var can_start: Callable

var active := false
var carrying := false
var done := 0

var _held: MeshInstance3D
var _pile: Array[MeshInstance3D] = []
var _stack: Array[MeshInstance3D] = []
var _arrow: MeshInstance3D
var _t := 0.0


## Всё настроено — строим кучу, кузов, стрелку и зоны.
func setup() -> void:
	var mesh := BoxMesh.new()
	mesh.size = item_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = item_color
	mat.roughness = 0.95
	mesh.material = mat
	var basis := Basis(Vector3.UP, stack_yaw)
	for i in total:
		var p := MeshInstance3D.new()
		p.mesh = mesh
		p.position = pile_at + basis * _slot(i)
		p.rotation.y = stack_yaw + randf_range(-0.08, 0.08)
		add_child(p)
		_pile.append(p)
		var s := MeshInstance3D.new()
		s.mesh = mesh
		s.position = stack_at + basis * _slot(i)
		s.rotation.y = stack_yaw
		s.visible = false
		add_child(s)
		_stack.append(s)
	_held = MeshInstance3D.new()
	_held.mesh = mesh
	_held.visible = false
	add_child(_held)
	_arrow = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.35
	cone.bottom_radius = 0.0
	cone.height = 0.7
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(1.0, 0.8, 0.15)
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone.material = am
	_arrow.mesh = cone
	_arrow.visible = false
	add_child(_arrow)
	var take := InteractZone.create("", Vector3(3.0, 2.2, 2.6))
	take.position = pickup
	take.prompt_fn = func() -> String:
		if not active:
			return ""
		return "E — взять %s" % item_name if not carrying else ""
	take.activated.connect(pick)
	add_child(take)
	var put := InteractZone.create("", Vector3(3.0, 2.2, 3.0))
	put.position = drop
	put.prompt_fn = func() -> String:
		return "E — положить %s (+%d грн)" % [item_name, pay_each] if active and carrying else ""
	put.activated.connect(put_down)
	add_child(put)


## Место груза в куче: ряды по per_row, слоями вверх.
func _slot(i: int) -> Vector3:
	var layer := i / (per_row * 2)
	var k := i % (per_row * 2)
	var row := k / per_row
	var col := k % per_row
	return Vector3((col - (per_row - 1) * 0.5) * (item_size.x + 0.05), item_size.y * (layer + 0.5), (row - 0.5) * (item_size.z + 0.05))


## Подсказка у места, где начинают смену.
func start_prompt() -> String:
	if active:
		return ""
	return "E — %s: %d × %d грн, по %d мин на каждый" % [title, total, pay_each, int(minutes_each)]


func start() -> void:
	if active:
		return
	var why: String = can_start.call() if can_start.is_valid() else ""
	if why != "":
		GameManager.notify(why)
		return
	active = true
	carrying = false
	done = 0
	_refresh()
	SoundLibrary.play("click", -4.0)
	GameManager.notify("%s: носи %s — жёлтая стрелка покажет, куда. Уйдёшь — смена кончится" % [title, item_name])


func pick() -> void:
	if not active or carrying:
		return
	if NeedsManager.energy < energy_each:
		GameManager.notify("Сил больше нет — %d из %d, остальное завтра" % [done, total])
		stop()
		return
	carrying = true
	SoundLibrary.play("step_grass", -4.0, 0.7)
	_refresh()


func put_down() -> void:
	if not active or not carrying:
		return
	carrying = false
	done += 1
	TimeManager.advance(minutes_each)
	NeedsManager.rest(-energy_each)
	GameManager.add_money(pay_each)
	SoundLibrary.play("cash", -6.0)
	QuestManager.event("carry")
	if done >= total:
		active = false
		GameManager.challenge_line = ""
		if event_name != "":
			QuestManager.event(event_name)
		GameManager.notify("%s: смена окончена — %d × %d = %d грн. %s" % [title, total, pay_each, total * pay_each, TimeManager.clock_text()])
		finished.emit(done)
		# Кузов разгрузят, куча снова наберётся к следующей смене
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if not active:
				done = 0
				_refresh())
	_refresh()


## Бросил смену: заплачено за донесённое.
func stop() -> void:
	if not active:
		return
	active = false
	carrying = false
	GameManager.challenge_line = ""
	GameManager.notify("%s: смена брошена — донёс %d из %d, получил %d грн" % [title, done, total, done * pay_each])
	finished.emit(done)
	done = 0
	_refresh()


## Для тестов и долгой игры: пройти всю смену сразу.
func simulate_all() -> void:
	start()
	while active:
		pick()
		if not active:
			break
		put_down()


func _refresh() -> void:
	for i in total:
		_pile[i].visible = i >= done + (1 if carrying else 0) or not active and done == 0
		_stack[i].visible = i < done
	_held.visible = carrying
	_arrow.visible = active
	if active:
		_arrow.global_position = (drop if carrying else pickup) + Vector3(0, 2.6, 0)
		GameManager.challenge_line = "%s: %d из %d — %s" % [title, done, total, "неси к стрелке" if carrying else "возьми %s" % item_name]


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	var p := GameManager.player as Node3D
	# Сел в машину или ушёл далеко — смена брошена
	if GameManager.vehicle != null or p == null or p.global_position.distance_to(drop) > 60.0:
		stop()
		return
	var target := drop if carrying else pickup
	_arrow.global_position = target + Vector3(0, 2.6 + sin(_t * 4.0) * 0.2, 0)
	_arrow.rotation.y = _t * 2.0
	if carrying:
		# Груз в руках перед грудью
		var fwd := -p.global_transform.basis.z
		fwd.y = 0.0
		_held.global_position = p.global_position + fwd.normalized() * 0.5 + Vector3(0, 1.15, 0)
		_held.rotation.y = p.rotation.y
