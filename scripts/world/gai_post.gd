extends Node3D
## Пост ГАИ на трассе у Каменки, напротив АЗС — там, где знаки «60».
## Кто проедет мимо поста быстрее 60 км/ч — свисток и штраф 200 грн
## (раз в полторы минуты). Без денег — строгое предупреждение.

const ZONE_X0 := -125.0
const ZONE_X1 := -75.0
const LIMIT := 60.0
const FINE := 200
const BOOTH := Vector3(-100.0, 0, -9.2)

var _cool := 0.0
var _cop: Node3D
var _fines := 0


func _ready() -> void:
	var b := MeshBuilder.new()
	# Будка: белая с синей полосой, окно, крыша
	var c := BOOTH
	b.box(c + Vector3(-1.3, 0, -1.1), c + Vector3(1.3, 2.4, 1.1), Color(0.9, 0.9, 0.88), true)
	b.box(c + Vector3(-1.31, 1.5, -1.11), c + Vector3(1.31, 1.75, 1.11), Color(0.15, 0.3, 0.65))
	b.box(c + Vector3(-0.9, 0.95, -1.12), c + Vector3(0.9, 1.45, -1.1), Color(0.35, 0.45, 0.5))
	b.box(c + Vector3(-1.5, 2.4, -1.3), c + Vector3(1.5, 2.55, 1.3), Color(0.3, 0.3, 0.32))
	add_child(b.build_mesh())
	var sign := Label3D.new()
	sign.text = "ГАИ"
	sign.font_size = 96
	sign.pixel_size = 0.006
	sign.outline_size = 10
	sign.modulate = Color(1, 1, 1)
	sign.position = c + Vector3(0, 1.62, 1.13)
	add_child(sign)
	# Инспектор у обочины, лицом к дороге, с полосатым жезлом
	var pb := MeshBuilder.new()
	pb.ground_shade = false
	preload("res://scripts/world/villagers.gd").person_model(pb, Color(0.3, 0.36, 0.3), Color(0.2, 0.25, 0.4), false, false)
	for i in 4:
		pb.box(Vector3(0.28, 0.9 + i * 0.1, -0.05), Vector3(0.32, 1.0 + i * 0.1, -0.01), Color(0.95, 0.95, 0.95) if i % 2 == 0 else Color(0.1, 0.1, 0.1))
	_cop = Node3D.new()
	_cop.add_child(pb.build_mesh())
	_cop.position = c + Vector3(1.8, 0, 2.2)
	_cop.rotation.y = PI
	add_child(_cop)


func _process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	var v := GameManager.vehicle as Vehicle
	if v == null or v.driver == null:
		return
	var p := v.global_position
	# Инспектор провожает взглядом
	if absf(p.x - _cop.position.x) < 60.0:
		var to := p - _cop.position
		_cop.rotation.y = lerp_angle(_cop.rotation.y, atan2(-to.x, -to.z), delta * 3.0)
	if _cool > 0.0 or p.x < ZONE_X0 or p.x > ZONE_X1 or absf(p.z) > 5.0:
		return
	var kmh := v.speed_kmh()
	if kmh <= LIMIT:
		return
	# Спор с Колькой — инспектор закрывает глаза (Колька — его племянник)
	var race = get_parent().get("_race")
	if race and race.active():
		return
	_cool = 90.0
	SoundLibrary.play_at("whistle", _cop.position + Vector3(0, 1.6, 0), 4.0)
	GameManager.vibrate(120)
	if GameManager.spend(FINE):
		_fines += 1
		QuestManager.event("fined")
		GameManager.notify("Инспектор ГАИ: «%d км/ч при ограничении 60! Штраф %d грн»" % [int(kmh), FINE])
	else:
		GameManager.notify("Инспектор ГАИ: «%d км/ч! Денег нет? В следующий раз — права отберу!»" % int(kmh))
