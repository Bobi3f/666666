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


## Красивые номера: одинаковые цифры, «77-77», «00-07», «12-34».
static func nice_numbers(seed: int, n: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out := []
	while out.size() < n:
		var d := rng.randi_range(1, 9)
		var e := rng.randi_range(0, 9)
		var digits: String = ["%d%d-%d%d" % [d, d, d, d], "%d%d-%d%d" % [d, e, d, e],
			"00-0%d" % d, "%d0-00" % d, "%d%d-%d%d" % [d, e, e, d]][rng.randi() % 5]
		var t := "%s %s %s" % [LETTERS[rng.randi() % LETTERS.length()], digits, REGIONS[rng.randi() % REGIONS.size()]]
		if not out.has(t):
			out.append(t)
	return out


## Номер, набранный игроком, — в правильный вид «а 12-34 КМ»; "" — если так
## номер не пишут. Пробелы и чёрточка — как угодно, регистр — любой.
static func parse(raw: String) -> String:
	var t := raw.strip_edges().replace(" ", "").replace("-", "")
	var re := RegEx.create_from_string("^([а-яё])(\\d{4})([а-яё]{2})$")
	var m := re.search(t.to_lower())
	if m == null:
		return ""
	var d := m.get_string(2)
	return "%s %s-%s %s" % [m.get_string(1), d.substr(0, 2), d.substr(2, 2), m.get_string(3).to_upper()]


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


## Подогнать размер надписи под рамку w×h (метры): ни одна строка не
## шире, все строки вместе не выше. Для номеров, эмблем, надписей на бортах.
static func fit(l: Label3D, size: Vector2) -> void:
	var font: Font = l.font if l.font else ThemeDB.fallback_font
	var w := 1.0
	for line in l.text.split("\n"):
		w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x)
	var lines := l.text.count("\n") + 1
	var h := font.get_height(l.font_size) * lines + l.line_spacing * (lines - 1)
	l.pixel_size = minf(size.x / w, size.y / maxf(h, 1.0))


## Надпись номера: чёрная, размером точно по табличке.
static func _label(root: Node3D, text: String, pos: Vector3, yaw: float, size: Vector2) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.outline_size = 0
	l.line_spacing = -6.0
	fit(l, Vector2(size.x * 0.88, size.y * 0.8))
	l.modulate = Color(0.05, 0.05, 0.05)
	l.double_sided = false
	l.shaded = false
	l.position = pos
	l.rotation.y = yaw
	l.visibility_range_end = TEXT_RANGE
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(l)
