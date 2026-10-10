extends SceneTree
## Таблички: у домов Каменки номера, у остановок — названия, на углах —
## улицы; по-английски все надписи переведены (кроме номеров машин);
## вывески видно издали, остановки у трассы не пропадают вблизи.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	for i in 10: await process_frame
	var labels: Array = W.find_children("*", "Label3D", true, false)
	var texts := {}
	for l in labels: texts[l.text] = texts.get(l.text, 0) + 1

	print("== Номера домов и улицы")
	var nums := 0
	for n in range(1, 9):
		for l in labels:
			if l.text == str(n) and l.pixel_size > 0.0015 and l.pixel_size < 0.002: nums += 1; break
	ok(nums == 8, "дома ул. Садовой с номерами 1–8: %d" % nums)
	ok(texts.get("ул. Садовая", 0) >= 12, "«ул. Садовая» на домах и столбах: %d" % texts.get("ул. Садовая", 0))
	ok(texts.has("ул. Ленина") and texts.has("пр. Мира"), "угол Ленина и проспекта Мира в городе")

	print("== Остановки")
	ok(texts.has("Каменка") and texts.has("Город · Склад"), "остановки в Каменке и в городе подписаны")
	var turns := 0
	for t in texts:
		if String(t).ends_with(", поворот"): turns += 1
	ok(turns >= 6, "остановки на съездах с трассы: %d" % turns)
	var village_stops := 0
	for v in Region.VILLAGES:
		if texts.has(v.name): village_stops += 1
	ok(village_stops == Region.VILLAGES.size(), "в каждом селе остановка или указатель с названием: %d" % village_stops)
	var rs = W.find_child("Roadside", true, false)
	var big := 0
	if rs:
		for m in rs.find_children("*", "MeshInstance3D", true, false):
			if (m as MeshInstance3D).mesh and (m as MeshInstance3D).mesh.get_aabb().size.length() > 400.0: big += 1
	ok(rs != null and big == 0, "у остановок на трассе свои меши — вблизи не пропадают")

	print("== Видно издали")
	var near := []
	for l in labels:
		var h: float = l.font_size * l.pixel_size
		# В школе надписи в классах нарочно видно только внутри
		if l.get_parent().name == "School": continue
		if h >= 0.3 and l.visibility_range_end > 0.0 and l.visibility_range_end < 100.0:
			near.append(l.text)
	ok(near.is_empty(), "крупные вывески видно дальше 100 м: " + str(near.slice(0, 5)))

	print("== По-английски")
	var tr := LangTranslation.new()
	var cyr := RegEx.create_from_string("[А-Яа-яЁё]")
	var miss := []
	for l in labels:
		if l.get_parent().name == "Plates" or l.text.is_empty(): continue
		if cyr.search(tr.text(l.text)): miss.append(l.text)
	ok(miss.is_empty(), "все таблички переводятся: " + str(miss.slice(0, 5)))
	ok(tr.text("Озерцово, поворот") == "Ozertsovo turn" and tr.text("А") == "BUS", "остановка: " + tr.text("Озерцово, поворот"))

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
