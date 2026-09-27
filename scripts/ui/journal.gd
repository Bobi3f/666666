extends CanvasLayer
## Журнал (J): сюжет, просьбы жителей, вещи и статистика. Пока открыт —
## игра на паузе. Здесь же — экран победы, когда построен кирпичный дом.

var _panel: PanelContainer
var _text: RichTextLabel
var _title: Label
var _close_btn: Button
var _victory := false


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.07, 0.95)
	style.border_color = Color(0.75, 0.62, 0.35)
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	style.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	box.add_child(_title)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.scroll_active = true
	_text.custom_minimum_size = Vector2(760, 470)
	_text.add_theme_font_size_override("normal_font_size", 17)
	_text.add_theme_font_size_override("bold_font_size", 18)
	box.add_child(_text)
	_close_btn = Button.new()
	_close_btn.custom_minimum_size = Vector2(0, 40)
	_close_btn.pressed.connect(_close)
	box.add_child(_close_btn)
	_panel.visible = false
	QuestManager.victory.connect(_on_victory)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_J:
		if _panel.visible:
			_close()
		elif not get_tree().paused:
			_open(false)
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_ESCAPE and _panel.visible:
		_close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _panel.visible


func _open(victory: bool) -> void:
	_victory = victory
	_title.text = "Ты — хозяин Каменки!" if victory else "Журнал"
	_close_btn.text = "Играть дальше" if victory else "Закрыть (J)"
	_text.text = _victory_text() if victory else _journal_text()
	_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close() -> void:
	_panel.visible = false
	get_tree().paused = false
	if not GameManager.touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_victory() -> void:
	# Дать дослушать звук и прочитать сообщение
	await get_tree().create_timer(1.5).timeout
	_open(true)


func _journal_text() -> String:
	var t := ""
	t += "[b][color=#f0d890]СЮЖЕТ[/color][/b]\n"
	for id in QuestManager.MAIN:
		t += _quest_line(id)
	t += "\n[b][color=#f0d890]ПРОСЬБЫ ЖИТЕЛЕЙ[/color][/b]\n"
	var unknown := 0
	for id in QuestManager.QUESTS:
		if QuestManager.QUESTS[id].get("main", false):
			continue
		if QuestManager.quests[id].state == 0:
			unknown += 1
			continue
		t += _quest_line(id)
	if unknown > 0:
		t += "[color=#9a9a9a]  Ещё %d — поговори с жителями, у кого «(!)» над подсказкой[/color]\n" % unknown
	t += "\n[b][color=#f0d890]ВЕЩИ[/color][/b]\n"
	t += "  Деньги: %d грн   Еда в запасе: %d   Рыба: %d\n" % [GameManager.money, NeedsManager.snacks, NeedsManager.fish]
	var extra: Array[String] = []
	if QuestManager.items.has("medicine"):
		extra.append("лекарство для тёти Люды")
	if QuestManager.items.has("letters"):
		extra.append("писем: %d" % int(QuestManager.items.letters))
	if not extra.is_empty():
		t += "  В сумке: %s\n" % ", ".join(extra)
	for v in [GameManager.car, GameManager.moto]:
		var veh := v as Vehicle
		if veh:
			t += "  %s: бензин %d / %d л, состояние %d%%\n" % [veh.spec.title, int(ceilf(veh.fuel)), int(veh.tank()), int(veh.condition)]
	t += "\n" + _stats_text()
	return t


func _quest_line(id: String) -> String:
	var q: Dictionary = QuestManager.quests[id]
	var def: Dictionary = QuestManager.QUESTS[id]
	match q.state:
		2:
			return "  [color=#7fbf6a]+ %s — готово[/color]\n" % def.title
		1:
			var giver := " (%s)" % def.giver if def.has("giver") else ""
			return "  [b]» %s[/b]%s\n      %s\n" % [def.title, giver, QuestManager.step_text(id)]
	return "  [color=#777777]· %s[/color]\n" % def.title


func _stats_text() -> String:
	var s := QuestManager.stats
	var t := "[b][color=#f0d890]СТАТИСТИКА[/color][/b]\n"
	t += "  Дней в Каменке: %d   Заработано всего: %d грн\n" % [TimeManager.day, int(s.earned)]
	t += "  Смен отработано: %d   Развозов хлеба: %d   Рыбы поймано: %d\n" % [int(s.shifts), int(s.deliveries), int(s.fish)]
	t += "  Проехано: %.1f км   Заданий выполнено: %d   Обмороков: %d\n" % [float(s.km), int(s.quests), int(s.fainted)]
	return t


func _victory_text() -> String:
	var t := "[center]Из покосившейся избы — в кирпичный дом под черепицей.\n"
	t += "Вся Каменка знает: этот своего добьётся.[/center]\n\n"
	t += _stats_text()
	t += "\n[color=#9a9a9a]Игра продолжается: рыбачь, помогай соседям, катайся на Яве. Журнал — J.[/color]"
	return t
