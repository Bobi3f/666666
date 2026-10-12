extends SceneTree
## Память на телефоне: мир — меши с индексами и сжатыми вершинами, вершин
## в меру (на iPhone Safari перезагружал страницу, когда игра брала больше
## гигабайта), заготовки построителей освобождены после постройки.
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
	for i in 5: await process_frame
	print("== Вершины")
	var total := 0
	var meshes := 0
	for m in W.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not (mi.mesh is ArrayMesh): continue
		meshes += 1
		for s in mi.mesh.get_surface_count():
			total += mi.mesh.surface_get_array_len(s)
	ok(total < 5000000, "вершин во всём мире: %d (было 6,5 млн)" % total)
	print("== Формат кусков мира")
	var chunk: MeshInstance3D = null
	for c in W.get_node("WorldMesh").get_children():
		if String(c.name).begins_with("Chunk_"): chunk = c; break
	ok(chunk != null and chunk.mesh.surface_get_array_index_len(0) > 0, "куски мира с индексами: 4 вершины на четырёхугольник")
	ok(chunk != null and (chunk.mesh.surface_get_format(0) & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES) != 0, "вершины кусков сжаты — видеопамяти вдвое меньше")
	var reg_chunks := 0
	for c in W.get_node("Region/RegionMesh").get_children():
		if String(c.name).begins_with("Chunk_"): reg_chunks += 1
	ok(reg_chunks > 0 and reg_chunks < 1400, "округа частями, кусков в меру: %d" % reg_chunks)
	print("== Заготовки освобождены")
	var reg = W.get_node("Region")
	ok(reg._d._chunks.is_empty() and reg._d.triangle_count() == 0, "заготовки округи пусты")
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
