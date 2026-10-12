class_name LessonPanel
extends CanvasLayer
## Экран урока в школе. Три вида заданий:
##  • вопросы (математика, литература) — вопрос и три ответа кнопками;
##  • рисование — провести пальцем/мышью по бледному контуру;
##  • лепка — гончарный круг: ведёшь пальцем по краю глины, она
##    становится шире или уже на этой высоте; нужно повторить силуэт.
## Пока урок открыт, игра на паузе. В конце — сигнал done(оценка, отзыв).

signal done(grade: int, comment: String)

var mode := ""
var _items: Array = []  # вопросы: [вопрос, верный, неверный, неверный]
var _index := 0
var _right := 0
var _answers: Array = []
var _root: PanelContainer
var _title: Label
var _question: Label
var _buttons: Array[Button] = []
var _quiz_box: VBoxContainer
var _art_box: HBoxContainer
var _canvas: ArtCanvas
var _finish: Button
var _clear: Button


func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.offset_left = 40
	_root.offset_right = -40
	_root.offset_top = 20
	_root.offset_bottom = -20
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.22, 0.16, 0.97)
	sb.border_color = Color(0.5, 0.35, 0.22)
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	_root.add_theme_stylebox_override("panel", sb)
	add_child(_root)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_root.add_child(v)
	_title = Label.new()
	_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	_title.add_theme_font_size_override("font_size", 18)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	# Вопросы
	_quiz_box = VBoxContainer.new()
	_quiz_box.add_theme_constant_override("separation", 8)
	_quiz_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quiz_box.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_quiz_box)
	_question = Label.new()
	_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question.add_theme_font_size_override("font_size", 24)
	_question.add_theme_color_override("font_color", Color(0.97, 0.97, 0.95))
	_quiz_box.add_child(_question)
	for i in 3:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 50)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(answer.bind(i))
		_quiz_box.add_child(btn)
		_buttons.append(btn)
	# Рисование и лепка: холст слева, кнопки справа
	_art_box = HBoxContainer.new()
	_art_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_art_box.add_theme_constant_override("separation", 10)
	v.add_child(_art_box)
	_canvas = ArtCanvas.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.custom_minimum_size = Vector2(260, 180)
	_art_box.add_child(_canvas)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(150, 0)
	side.add_theme_constant_override("separation", 10)
	_art_box.add_child(side)
	_finish = Button.new()
	_finish.text = "Готово"
	_finish.custom_minimum_size = Vector2(0, 60)
	_finish.add_theme_font_size_override("font_size", 22)
	_finish.pressed.connect(finish_art)
	side.add_child(_finish)
	_clear = Button.new()
	_clear.text = "Заново"
	_clear.custom_minimum_size = Vector2(0, 50)
	_clear.add_theme_font_size_override("font_size", 20)
	_clear.pressed.connect(func() -> void: _canvas.reset())
	side.add_child(_clear)


## Вопросы по очереди: items — [вопрос, верный, неверный, неверный].
func start_quiz(title: String, items: Array) -> void:
	mode = "quiz"
	_items = items
	_index = 0
	_right = 0
	_title.text = title
	_quiz_box.visible = true
	_art_box.visible = false
	_show_question()
	_open()


func _show_question() -> void:
	var it: Array = _items[_index]
	_answers = [it[1], it[2], it[3]]
	_answers.shuffle()
	_question.text = "%d из %d. %s" % [_index + 1, _items.size(), it[0]]
	for i in 3:
		_buttons[i].text = "%d) %s" % [i + 1, _answers[i]]
	_buttons[0].grab_focus()


func right_index() -> int:
	return _answers.find(_items[_index][1])


func answer(i: int) -> void:
	if mode != "quiz" or not visible:
		return
	if _answers[i] == _items[_index][1]:
		_right += 1
		SoundLibrary.play("click", -6.0, 1.4)
	else:
		SoundLibrary.play("click", -6.0, 0.6)
	_index += 1
	if _index < _items.size():
		_show_question()
		return
	var n := _items.size()
	var grade := 5 if _right == n else (4 if _right >= n - 1 else (3 if _right >= n - 2 else 2))
	_close(grade, "верно %d из %d" % [_right, n])


## Рисование по контуру: shape — "sun", "house", "tree", "apple", "fish".
func start_draw(title: String, shape: String) -> void:
	mode = "draw"
	_title.text = title
	_quiz_box.visible = false
	_art_box.visible = true
	_clear.visible = true
	_canvas.setup_draw(shape)
	_open()


## Лепка: shape — "vase", "jug", "pot", "bowl".
func start_clay(title: String, shape: String) -> void:
	mode = "clay"
	_title.text = title
	_quiz_box.visible = false
	_art_box.visible = true
	_clear.visible = true
	_canvas.setup_clay(shape)
	_open()


func finish_art() -> void:
	if not visible or mode == "quiz":
		return
	var s := _canvas.score()
	var grade := 5 if s >= 0.8 else (4 if s >= 0.62 else (3 if s >= 0.42 else 2))
	_close(grade, "похоже на %d%%" % int(s * 100.0))


func canvas() -> ArtCanvas:
	return _canvas


func _open() -> void:
	visible = true
	get_tree().paused = true


func _close(grade: int, comment: String) -> void:
	visible = false
	mode = ""
	get_tree().paused = false
	done.emit(grade, comment)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		if mode == "quiz":
			match k.physical_keycode:
				KEY_1, KEY_KP_1:
					answer(0)
				KEY_2, KEY_KP_2:
					answer(1)
				KEY_3, KEY_KP_3:
					answer(2)
		elif k.physical_keycode == KEY_ENTER or k.physical_keycode == KEY_E:
			finish_art()
		get_viewport().set_input_as_handled()


## Холст: рисунок по контуру или силуэт глины. Координаты фигур — доли
## холста 0..1, так холст подстраивается под любой экран.
class ArtCanvas:
	extends Control

	const SLICES := 24
	const PROFILES := {
		"vase": [[0.0, 0.35], [0.3, 0.72], [0.75, 0.22], [1.0, 0.42]],
		"jug": [[0.0, 0.45], [0.45, 0.78], [0.8, 0.3], [1.0, 0.36]],
		"pot": [[0.0, 0.42], [0.5, 0.72], [1.0, 0.58]],
		"bowl": [[0.0, 0.25], [0.4, 0.52], [1.0, 0.88]],
	}
	var kind := ""
	var target: Array[Vector2] = []  # точки контура (доли холста)
	var strokes: Array = []  # линии игрока: Array[PackedVector2Array] в долях
	var profile: Array[float] = []
	var goal: Array[float] = []
	var _drawing := false
	var _spin := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func reset() -> void:
		strokes.clear()
		profile.clear()
		for i in SLICES:
			profile.append(0.55)
		queue_redraw()

	func setup_draw(shape: String) -> void:
		kind = "draw"
		target.clear()
		for line in _shape_lines(shape):
			var pts: Array = line
			for i in pts.size() - 1:
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[i + 1]
				var n := maxi(int(a.distance_to(b) / 0.025), 1)
				for k in n:
					target.append(a.lerp(b, float(k) / n))
		reset()

	func setup_clay(shape: String) -> void:
		kind = "clay"
		goal.clear()
		var pts: Array = PROFILES.get(shape, PROFILES.pot)
		for i in SLICES:
			var t := float(i) / (SLICES - 1)
			var w := 0.5
			for k in pts.size() - 1:
				var p0: Array = pts[k]
				var p1: Array = pts[k + 1]
				if t >= float(p0[0]) and t <= float(p1[0]):
					var f := (t - float(p0[0])) / maxf(float(p1[0]) - float(p0[0]), 0.001)
					w = lerpf(float(p0[1]), float(p1[1]), smoothstep(0.0, 1.0, f))
			goal.append(w)
		reset()

	## Контуры для рисования: списки ломаных в долях холста.
	static func _shape_lines(shape: String) -> Array:
		var out := []
		match shape:
			"sun":
				out.append(_circle(Vector2(0.5, 0.5), 0.22, 28))
				for i in 8:
					var a := TAU * i / 8.0
					var d := Vector2(cos(a), sin(a))
					out.append([Vector2(0.5, 0.5) + d * 0.28, Vector2(0.5, 0.5) + d * 0.4])
			"house":
				out.append([Vector2(0.28, 0.9), Vector2(0.28, 0.5), Vector2(0.72, 0.5), Vector2(0.72, 0.9), Vector2(0.28, 0.9)])
				out.append([Vector2(0.22, 0.52), Vector2(0.5, 0.18), Vector2(0.78, 0.52)])
				out.append([Vector2(0.44, 0.9), Vector2(0.44, 0.7), Vector2(0.56, 0.7), Vector2(0.56, 0.9)])
			"tree":
				out.append([Vector2(0.5, 0.1), Vector2(0.3, 0.4), Vector2(0.4, 0.4), Vector2(0.24, 0.7), Vector2(0.76, 0.7),
					Vector2(0.6, 0.4), Vector2(0.7, 0.4), Vector2(0.5, 0.1)])
				out.append([Vector2(0.45, 0.7), Vector2(0.45, 0.88), Vector2(0.55, 0.88), Vector2(0.55, 0.7)])
			"apple":
				out.append(_circle(Vector2(0.5, 0.58), 0.28, 30))
				out.append([Vector2(0.5, 0.3), Vector2(0.53, 0.14)])
				out.append([Vector2(0.53, 0.22), Vector2(0.66, 0.16), Vector2(0.6, 0.26), Vector2(0.53, 0.22)])
			_:
				var body := []
				for i in 29:
					var a := TAU * i / 28.0
					body.append(Vector2(0.45 + cos(a) * 0.25, 0.5 + sin(a) * 0.15))
				out.append(body)
				out.append([Vector2(0.7, 0.5), Vector2(0.88, 0.36), Vector2(0.88, 0.64), Vector2(0.7, 0.5)])
		return out

	static func _circle(c: Vector2, r: float, n: int) -> Array:
		var pts := []
		for i in n + 1:
			var a := TAU * i / n
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		return pts

	## Квадрат, в котором рисуем (доли → точки экрана).
	func _area() -> Rect2:
		var s := minf(size.x, size.y)
		return Rect2((size.x - s) * 0.5, (size.y - s) * 0.5, s, s)

	func to_px(p: Vector2) -> Vector2:
		var r := _area()
		return r.position + p * r.size

	func to_unit(px: Vector2) -> Vector2:
		var r := _area()
		return (px - r.position) / r.size

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb and mb.button_index == MOUSE_BUTTON_LEFT:
			_drawing = mb.pressed
			if mb.pressed:
				if kind == "draw":
					strokes.append(PackedVector2Array())
				touch(to_unit(mb.position))
			accept_event()
			return
		var mm := event as InputEventMouseMotion
		if mm and _drawing:
			touch(to_unit(mm.position))
			accept_event()

	## Касание в точке u (доли холста): рисунок — продолжить линию,
	## глина — ширина на этой высоте тянется к пальцу.
	func touch(u: Vector2) -> void:
		if kind == "draw":
			if strokes.is_empty():
				strokes.append(PackedVector2Array())
			var s: PackedVector2Array = strokes[strokes.size() - 1]
			s.append(u)
			strokes[strokes.size() - 1] = s
		else:
			var t := clampf((0.92 - u.y) / 0.84, 0.0, 1.0)
			var i := int(round(t * (SLICES - 1)))
			var w := clampf(absf(u.x - 0.5) / 0.4, 0.08, 1.0)
			for k in range(-2, 3):
				var j := i + k
				if j >= 0 and j < SLICES:
					var f := 0.6 if k == 0 else (0.35 if absi(k) == 1 else 0.15)
					profile[j] = lerpf(profile[j], w, f)
		queue_redraw()

	## Насколько похоже: 0..1.
	func score() -> float:
		if kind == "draw":
			var pts: Array[Vector2] = []
			for s in strokes:
				for p in (s as PackedVector2Array):
					pts.append(p)
			if pts.is_empty():
				return 0.0
			var covered := 0
			for t in target:
				for p in pts:
					if p.distance_to(t) < 0.045:
						covered += 1
						break
			var stray := 0
			for p in pts:
				var near := false
				for t in target:
					if p.distance_to(t) < 0.06:
						near = true
						break
				if not near:
					stray += 1
			var c := float(covered) / target.size()
			var s2 := float(stray) / pts.size()
			return clampf(c - s2 * 0.6, 0.0, 1.0)
		var err := 0.0
		for i in SLICES:
			err += absf(profile[i] - goal[i])
		err /= SLICES
		return clampf(1.0 - err * 3.0, 0.0, 1.0)

	func _process(delta: float) -> void:
		if kind == "clay" and is_visible_in_tree():
			_spin += delta * 6.0
			queue_redraw()

	func _draw() -> void:
		var r := _area()
		draw_rect(r, Color(0.93, 0.91, 0.85) if kind == "draw" else Color(0.2, 0.25, 0.22))
		if kind == "draw":
			for t in target:
				draw_circle(to_px(t), 2.2, Color(0.6, 0.6, 0.6, 0.7))
			for s in strokes:
				var line: PackedVector2Array = s
				if line.size() >= 2:
					var px := PackedVector2Array()
					for p in line:
						px.append(to_px(p))
					draw_polyline(px, Color(0.15, 0.3, 0.75), 4.0, true)
				elif line.size() == 1:
					draw_circle(to_px(line[0]), 2.0, Color(0.15, 0.3, 0.75))
			return
		# Гончарный круг и глина: силуэт симметричный, полоски крутятся
		draw_rect(Rect2(to_px(Vector2(0.1, 0.92)), Vector2(r.size.x * 0.8, r.size.y * 0.05)), Color(0.35, 0.35, 0.37))
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for i in SLICES:
			var y := 0.92 - float(i) / (SLICES - 1) * 0.84
			var w := profile[i] * 0.4
			left.append(to_px(Vector2(0.5 - w, y)))
			right.append(to_px(Vector2(0.5 + w, y)))
		var poly := PackedVector2Array(left)
		for i in range(SLICES - 1, -1, -1):
			poly.append(right[i])
		draw_colored_polygon(poly, Color(0.72, 0.42, 0.28))
		for k in 5:
			var x := 0.5 + sin(_spin + k * 1.2) * 0.3
			for i in SLICES - 1:
				var y0 := 0.92 - float(i) / (SLICES - 1) * 0.84
				var y1 := 0.92 - float(i + 1) / (SLICES - 1) * 0.84
				var w0 := profile[i] * 0.4
				var w1 := profile[i + 1] * 0.4
				var xa := 0.5 + (x - 0.5) * w0 / 0.4
				var xb := 0.5 + (x - 0.5) * w1 / 0.4
				draw_line(to_px(Vector2(xa, y0)), to_px(Vector2(xb, y1)), Color(0.62, 0.35, 0.22), 2.0)
		# Образец — пунктир
		for i in SLICES - 1:
			var y0 := 0.92 - float(i) / (SLICES - 1) * 0.84
			var y1 := 0.92 - float(i + 1) / (SLICES - 1) * 0.84
			for s in [-1.0, 1.0]:
				draw_dashed_line(to_px(Vector2(0.5 + s * goal[i] * 0.4, y0)), to_px(Vector2(0.5 + s * goal[i + 1] * 0.4, y1)), Color(1, 1, 0.85), 2.0, 6.0)
