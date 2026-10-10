class_name SmoothCamera
extends Camera3D
## Камера, которая плавно следует за точкой-меткой.
##
## Персонаж и машины двигаются в физике — 60 раз в секунду. Экран
## обновляется с другой частотой (телефон, браузер, 144 Гц монитор), и
## камера, привязанная к ним напрямую, дёргается. Здесь камера отдельная
## (top_level): каждый физический шаг запоминаем, где была метка, а каждый
## кадр ставим камеру между прошлым и текущим положением.
##
## Поворот головы мышью или пальцем меняется между шагами физики — его берём
## сразу, без сглаживания (interpolate_rotation = false), иначе мышь «плывёт».
## Плавный подъём на ступеньку и прочие скачки — через kick().

var target: Node3D
var interpolate_rotation := true

var _prev := Transform3D.IDENTITY
var _cur := Transform3D.IDENTITY
var _ready_xf := false
## Сдвиг камеры, который быстро гасится: ступенька, толчок.
var _offset := Vector3.ZERO


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# После того, как персонаж и машины сдвинулись в этом шаге физики
	process_physics_priority = 100
	process_priority = 100


func _physics_process(_delta: float) -> void:
	# Камер у машин и людей десятки, смотрит одна — остальные не считаем;
	# станет текущей — начнёт с места метки
	if not current or target == null or not is_instance_valid(target):
		_ready_xf = false
		return
	_prev = _cur
	_cur = target.global_transform
	# Телепорт (загрузка, автобус, обморок) — не размазываем перелёт
	if not _ready_xf or _prev.origin.distance_to(_cur.origin) > 3.0:
		_prev = _cur
		_ready_xf = true


func _process(delta: float) -> void:
	if not current or target == null or not is_instance_valid(target):
		return
	if not _ready_xf:
		_prev = target.global_transform
		_cur = _prev
		_ready_xf = true
	var f := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	var origin := _prev.origin.lerp(_cur.origin, f)
	var basis := target.global_transform.basis
	if interpolate_rotation:
		basis = _prev.basis.orthonormalized().slerp(_cur.basis.orthonormalized(), f)
	_offset = _offset.lerp(Vector3.ZERO, minf(delta * 12.0, 1.0))
	global_transform = Transform3D(basis.orthonormalized(), origin + _offset)


## Смягчить скачок метки: камера начнёт с отставания на delta и догонит.
func kick(delta: Vector3) -> void:
	_offset -= delta


## Сразу поставить камеру на метку (после телепорта).
func snap() -> void:
	_ready_xf = false
	_offset = Vector3.ZERO
