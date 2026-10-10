extends Node
## Люди смотрят на игрока: кто ближе 8 м — поворачивает голову, а кто
## стоит (не сидит и не идёт) и не дотягивается взглядом — и сам
## разворачивается. Отошёл — снова смотрят куда смотрели. Всё делает
## шейдер человека (PersonModel.SHADER: look — голова, turn — тело).

const RANGE := 8.0
## Голову дальше не повернуть — дальше поворачивается тело.
const HEAD_MAX := 1.0
const BODY_MAX := 1.6
## Скорость поворота, рад/с.
const SPEED := 3.0

## Кто сейчас повёрнут: меш → [голова, тело].
var _turned := {}
## Кто рядом — пересматриваем раз в полсекунды, а не весь список каждый кадр.
var _near: Array = []
var _scan := 0.0


func _process(delta: float) -> void:
	var target := _target()
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.5
		_near.clear()
		if target != Vector3.INF:
			for n in get_tree().get_nodes_in_group("people"):
				var g := n as Node3D
				if g and g.global_position.distance_squared_to(target) < (RANGE + 6.0) * (RANGE + 6.0):
					_near.append(g)
	var seen := {}
	if target != Vector3.INF:
		for n in _near:
			var mi := n as MeshInstance3D
			if mi == null or not is_instance_valid(mi) or not mi.is_visible_in_tree():
				continue
			if mi.global_position.distance_squared_to(target) > RANGE * RANGE:
				continue
			seen[mi] = true
			_face(mi, target, delta)
	# Отошёл — поворачиваются обратно
	for mi in _turned.keys():
		if seen.has(mi):
			continue
		if not is_instance_valid(mi):
			_turned.erase(mi)
			continue
		var cur: Array = _turned[mi]
		cur[0] = move_toward(cur[0], 0.0, SPEED * delta)
		cur[1] = move_toward(cur[1], 0.0, SPEED * delta)
		_apply(mi, cur)
		if cur[0] == 0.0 and cur[1] == 0.0:
			_turned.erase(mi)


## Куда смотреть: голова игрока или его машина. INF — некуда.
func _target() -> Vector3:
	var v := GameManager.vehicle as Node3D
	if v:
		return v.global_position + Vector3(0, 1.4, 0)
	var p := GameManager.player as Node3D
	if p and p.is_inside_tree():
		return p.global_position + Vector3(0, 1.6, 0)
	return Vector3.INF


## Нужный угол: голову — сколько можно, остальное — телом (если стоит).
func _face(mi: MeshInstance3D, target: Vector3, delta: float) -> void:
	var local := mi.global_transform.affine_inverse() * target
	var raw := atan2(-local.x, -local.z)
	var mat := mi.material_override as ShaderMaterial
	if mat == null:
		return
	var cur: Array = _turned.get(mi, [0.0, 0.0])
	var want := raw
	var am = mat.get_shader_parameter("amount")
	var walking := am != null and float(am) > 0.05
	var head := clampf(want, -HEAD_MAX, HEAD_MAX)
	var body := 0.0
	if not walking and not bool(mi.get_meta("sit", false)):
		body = clampf(want - head, -BODY_MAX, BODY_MAX)
	cur[0] = move_toward(cur[0], head, SPEED * delta)
	cur[1] = move_toward(cur[1], body, SPEED * delta)
	_turned[mi] = cur
	_apply(mi, cur)


## Голова и тело вместе — для проверки.
static func angle_of(mi: MeshInstance3D) -> float:
	var mat := mi.material_override as ShaderMaterial
	if mat == null:
		return 0.0
	return float(mat.get_shader_parameter("look")) + float(mat.get_shader_parameter("turn"))


func _apply(mi: MeshInstance3D, cur: Array) -> void:
	var mat := mi.material_override as ShaderMaterial
	if mat:
		mat.set_shader_parameter("look", cur[0])
		mat.set_shader_parameter("turn", cur[1])
