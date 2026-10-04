class_name Town
extends RefCounted
## Город стоит в стороне от сёл: от Каменки до него — дорога через поля,
## лес и мост. Всё городское описано в своих координатах (как раньше, когда
## город был у самой Каменки), а в мир ставится сдвигом SHIFT: геометрия —
## через MeshBuilder.shift, узлы — встают под сдвинутого родителя,
## а логика, что сравнивает с игроком, переводит точки через w() и l().

const SHIFT := Vector3(700.0, 0, 0)


## Точка города → в мире.
static func w(p: Vector3) -> Vector3:
	return p + SHIFT


## Точка мира → в координатах города.
static func l(p: Vector3) -> Vector3:
	return p - SHIFT


## Прямоугольник в плане (X, Z) города → в мире.
static func wr(r: Rect2) -> Rect2:
	return Rect2(r.position + Vector2(SHIFT.x, SHIFT.z), r.size)


## Сдвиг в плане — для Vector2 (X, Z).
static func w2(p: Vector2) -> Vector2:
	return p + Vector2(SHIFT.x, SHIFT.z)
