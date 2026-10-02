extends Control
## Стрелка-навигатор вверху экрана: куда ехать и сколько метров. Ведёт к
## цели идущей работы (GameManager.nav_target), развоза хлеба, а если их нет —
## к месту по шагу сюжетного задания (таблица QUEST_TARGETS ниже).
## Рядом с целью (ближе 8 м) прячется.

## [задание, шаг] → [что показывать, где] — где: Vector3 или имя узла мира.
const QUEST_TARGETS := {
	"m_wheels:0": ["Мопед", "Moped"],
	"m_wheels:1": ["АЗС", Vector3(-110.0, 0, 13.0)],
	"m_money:0": ["Почта — посылки", Vector3(-59.1, 0, -46.6)],
	"m_license:0": ["", ""],
	"m_license:1": ["Автошкола", Vector3(-11.0, 0, -17.5)],
	"m_car:0": ["«Жигули» у соседа", "Car"],
}

var _label: Label
var _target := Vector3.INF
var _name := ""


func _ready() -> void:
	add_to_group("nav")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(60, 60)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Подпись — слева от стрелки, на одной высоте: под ней кнопки телефона
	_label.position = Vector2(-306, 19)
	_label.size = Vector2(300, 22)
	add_child(_label)


## Под мини-картой (там не мешает ни полоскам, ни кнопкам); без мини-карты —
## справа сверху.
func _place() -> void:
	var mini := get_tree().get_first_node_in_group("minimap") as Control
	var vs := get_viewport().get_visible_rect().size
	if mini and mini.is_visible_in_tree():
		var r := mini.get_global_rect()
		position = Vector2(r.end.x - size.x, r.end.y + 26.0)
	else:
		position = Vector2(vs.x - size.x - 150.0, 12.0)


## Куда сейчас вести: [имя, точка] или ["", INF].
func current() -> Array:
	if GameManager.nav_target != Vector3.INF:
		return [GameManager.nav_label, GameManager.nav_target]
	if Progress.delivery_active:
		return ["Сельмаг — хлеб", Vector3(-51.0, 0, -24.0)]
	var id := QuestManager.active_main()
	if id == "":
		return ["", Vector3.INF]
	var key := "%s:%d" % [id, int(QuestManager.quests[id].step)]
	if key == "m_license:0":
		return ["Сельсовет — паспорт", Civic.COUNCIL] if not Progress.has_doc("passport") else ["Больница — медсправка", Civic.HOSPITAL]
	if not QUEST_TARGETS.has(key):
		return ["", Vector3.INF]
	var t: Array = QUEST_TARGETS[key]
	if t[1] is Vector3:
		return t
	var world := get_tree().current_scene
	var n := world.get_node_or_null(String(t[1])) as Node3D if world else null
	# На мопеде к мопеду не ведём
	if n == null or n == GameManager.vehicle:
		return ["", Vector3.INF]
	return [t[0], n.global_position]


func _process(_delta: float) -> void:
	var c := current()
	_name = c[0]
	_target = c[1]
	var who := (GameManager.vehicle if GameManager.vehicle else GameManager.player) as Node3D
	var cam := get_viewport().get_camera_3d()
	var show := _target != Vector3.INF and who != null and cam != null
	if show:
		var d := Vector2(_target.x - who.global_position.x, _target.z - who.global_position.z)
		show = d.length() > 8.0
		if show:
			_label.text = "%s · %d м" % [_name, int(d.length())] if _name != "" else "%d м" % int(d.length())
	visible = show
	if show:
		_place()
	queue_redraw()


func _draw() -> void:
	if _target == Vector3.INF:
		return
	var cam := get_viewport().get_camera_3d()
	var who := (GameManager.vehicle if GameManager.vehicle else GameManager.player) as Node3D
	if cam == null or who == null:
		return
	# Угол до цели относительно взгляда камеры: вверх — прямо
	var fwd := -cam.global_transform.basis.z
	var look := atan2(fwd.x, -fwd.z)
	var to := _target - who.global_position
	var ang := atan2(to.x, -to.z) - look
	var c := size * 0.5
	draw_circle(c, 26.0, Color(0.08, 0.08, 0.09, 0.7))
	draw_arc(c, 26.0, 0.0, TAU, 32, Color(0.95, 0.7, 0.24), 2.0)
	var dir := Vector2(sin(ang), -cos(ang))
	var side := Vector2(-dir.y, dir.x)
	var tip := c + dir * 18.0
	var pts := PackedVector2Array([tip, c - dir * 10.0 + side * 11.0, c - dir * 4.0, c - dir * 10.0 - side * 11.0])
	draw_colored_polygon(pts, Color(1.0, 0.78, 0.3))
