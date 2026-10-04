class_name Roads
extends RefCounted
## Где какие дороги за пределами трассы и деревни — одна карта для всех:
## мир рисует по ней дороги и не сажает на них деревья, машина узнаёт
## покрытие (гравий держит почти как асфальт, лесной грунт — как деревенский).
##
## Прямоугольники — Rect2(x, z, ширина по x, длина по z).

## Полевое кольцо: от конца деревенской улицы мимо колхоза на север,
## вдоль поля на восток и между автодромом и пашней — к трассе. Гравий.
const FIELD := [
	Rect2(-57, -40, 52, 5),
	Rect2(-9, -89, 5, 54),
	Rect2(-9, -89, 34, 5),
	Rect2(21, -89, 4, 83.5),
]
## Лесная дорога: от пруда на север и через лес на восток, к полевой. Грунт.
const FOREST := [
	Rect2(-167, -89, 4.5, 46.5),
	Rect2(-167, -89, 158, 5),
]
## Речка с севера до огородов и мост на лесной дороге.
const STREAM := Rect2(-112, -200, 4, 125)
const BRIDGE := Rect2(-114, -89.5, 8, 6)


static func _in(list: Array, x: float, z: float, margin := 0.0) -> bool:
	for r in list:
		if (r as Rect2).grow(margin).has_point(Vector2(x, z)):
			return true
	return false


static func on_gravel(x: float, z: float) -> bool:
	return _in(FIELD, x, z)


static func on_forest_road(x: float, z: float) -> bool:
	return _in(FOREST, x, z) or Region.on_road(x, z)


## Можно ли здесь сажать дерево: не на дорогах и не в речке.
static func tree_ok(x: float, z: float) -> bool:
	return not (_in(FIELD, x, z, 2.5) or _in(FOREST, x, z, 2.5) or STREAM.grow(2.5).has_point(Vector2(x, z)))


static func all_rects() -> Array:
	return FIELD + FOREST


## Асфальт: трасса, заправка и СТО у Каменки, автодром с въездом, город.
static func on_asphalt(x: float, z: float) -> bool:
	if absf(z) < 4.2:
		return true
	if x > -120.0 and x < -78.0 and z > 0.0 and z < 21.0:
		return true
	# Город (в своих координатах): автошкола на западе, улицы и дворы
	x -= Town.SHIFT.x
	z -= Town.SHIFT.z
	if x > -41.0 and x < -5.0 and z > 1.0 and z < 72.0:
		for r in AutoSchool.ASPHALT:
			if (r as Rect2).has_point(Vector2(x, z)):
				return true
	if x > 38.0 and x < 200.0 and z > 0.0 and z < 200.0:
		return true
	# Восточная улица и проезд к ней (TownEast)
	return TownEast.EAST_STREET.has_point(Vector2(x, z)) or TownEast.EAST_ROAD.has_point(Vector2(x, z))
