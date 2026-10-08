class_name LoadingScreen
extends CanvasLayer
## Экран загрузки: тёмный фон, название, полоска и совет. Им пользуются
## запуск игры (boot.gd) и меню — при «Новой игре» и «Продолжить».

const AMBER := Color(0.95, 0.7, 0.24)
const TIPS := [
	"Мопеду права не нужны, а «Семёрке» — нужна. Автошкола — в городе, автобус туда ходит с остановки у трассы.",
	"Паспорт делают в сельсовете, медсправку — в больнице в городе.",
	"Мопед ест мало бензина, но в горку тянет еле-еле.",
	"Почта: посылки по домам или мешок в почту другого села — коробки везёшь на мопеде.",
	"Хочется пить — колонка на деревенской улице бесплатная.",
	"Устал — иди домой спать: кровать переводит игру на утро.",
	"Сильно разбил машину — ремонт на СТО у трассы.",
	"Стрелка вверху экрана показывает, куда ехать по заданию.",
]

var _bar: ProgressBar
var _label: Label
var _tip: Label


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(420, 0)
	center.add_child(box)
	var title := Label.new()
	title.text = "FIRST GEAR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", AMBER)
	box.add_child(title)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(0.94, 0.9, 0.81))
	box.add_child(_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 14)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(0.18, 0.19, 0.21)
	bgs.set_corner_radius_all(7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = AMBER
	fill.set_corner_radius_all(7)
	_bar.add_theme_stylebox_override("background", bgs)
	_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_bar)
	_tip = Label.new()
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(420, 0)
	_tip.add_theme_font_size_override("font_size", 16)
	_tip.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_tip.text = "Совет: " + TIPS[randi() % TIPS.size()]
	box.add_child(_tip)
	set_progress(0.0, "Загрузка…")


func set_progress(v: float, text := "") -> void:
	if _bar:
		_bar.value = clampf(v, 0.0, 1.0)
	if text != "" and _label:
		_label.text = text


func progress() -> float:
	return _bar.value if _bar else 0.0
