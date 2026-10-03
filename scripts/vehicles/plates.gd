class_name Plates
extends RefCounted
## Номерные знаки, как в Союзе: белая табличка 520×112 мм, чёрные буквы —
## «а 12-34 КМ» (буква, четыре цифры, область). У машин — спереди и сзади,
## у мотоцикла и мопеда — только сзади, в две строки.
##
## Табличка — маленький меш, надпись — Label3D, которую видно только
## вблизи: издали её всё равно не прочесть, а телефону лишняя работа.

const LETTERS := "абвгдежзиклмнопрстуфхцчшэюя"
## Области: своя (Каменский район) — чаще остальных.
const REGIONS := ["КМ", "КМ", "КМ", "КИ", "ХА", "ДН", "ЛВ", "ОД"]
## Ближе этого надпись видна, дальше — только белая табличка.
const TEXT_RANGE := 16.0
const PLATE_RANGE := 70.0


## Номер по зерну: у одной машины — всегда один и тот же.
static func number(seed: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var letter := LETTERS[rng.randi() % LETTERS.length()]
	var digits := rng.randi_range(1, 9999)
	return "%s %02d-%02d %s" % [letter, digits / 100, digits % 100, REGIONS[rng.randi() % REGIONS.size()]]


## Повесить знаки на транспорт. spots — белые таблички самой модели
## (VehicleModels.plate: [место надписи, поворот, размер]); если их нет —
## таблички ставятся по габаритам box (AABB кузова), rear_only — мотоцикл.
static func attach(parent: Node3D, box: AABB, text: String, rear_only := false, spots: Array = []) -> Node3D:
	var root := Node3D.new()
	root.name = "Plates"
	parent.add_child(root)
	if spots.is_empty():
		spots = _box_spots(box, rear_only)
		_plate_mesh(root, spots)
	for s in spots:
		var size: Vector2 = s[2]
		# Узкая и высокая табличка (мотоцикл) — номер в две строки
		var two := size.x < size.y * 2.5
		var parts := text.split(" ")
		var t := "%s %s\n%s" % [parts[0], parts[1], parts[2]] if two else text
		_label(root, t, s[0], s[1], size)
	return root


## Таблички по габаритам: сзади и спереди посередине, на высоте бампера.
static func _box_spots(box: AABB, rear_only: bool) -> Array:
	if rear_only:
		return [[Vector3(0, box.position.y + minf(box.size.y * 0.45, 0.6), box.end.z + 0.02), 0.0, Vector2(0.2, 0.15)]]
	var y := box.position.y + clampf(box.size.y * 0.25, 0.4, 0.75)
	return [[Vector3(0, y, box.end.z + 0.02), 0.0, Vector2(0.52, 0.112)],
		[Vector3(0, y, box.position.z - 0.02), PI, Vector2(0.52, 0.112)]]


## Белые таблички с чёрной рамкой — для моделей без своих.
static func _plate_mesh(root: Node3D, spots: Array) -> void:
	var b := MeshBuilder.new()
	b.ground_shade = false
	for s in spots:
		var size: Vector2 = s[2]
		b.xf = Transform3D(Basis(Vector3.UP, s[1]), s[0])
		b.box(Vector3(-size.x * 0.5 - 0.012, -size.y * 0.5 - 0.012, -0.016), Vector3(size.x * 0.5 + 0.012, size.y * 0.5 + 0.012, -0.01), Color(0.08, 0.08, 0.08))
		b.box(Vector3(-size.x * 0.5, -size.y * 0.5, -0.01), Vector3(size.x * 0.5, size.y * 0.5, -0.004), Color(0.92, 0.92, 0.9))
	var mi := b.build_mesh()
	mi.name = "Plate"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = PLATE_RANGE
	root.add_child(mi)


## Надпись номера: чёрная, размером точно по табличке.
static func _label(root: Node3D, text: String, pos: Vector3, yaw: float, size: Vector2) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	var font := ThemeDB.fallback_font
	var w := 1.0
	for line in text.split("\n"):
		w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 48).x)
	var lines := text.count("\n") + 1
	l.pixel_size = minf(size.x * 0.88 / w, size.y * 0.8 / (48.0 * 1.25 * lines))
	l.outline_size = 0
	l.line_spacing = -6.0
	l.modulate = Color(0.05, 0.05, 0.05)
	l.double_sided = false
	l.shaded = false
	l.position = pos
	l.rotation.y = yaw
	l.visibility_range_end = TEXT_RANGE
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(l)
