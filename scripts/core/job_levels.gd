class_name JobLevels
extends RefCounted
## Уровни работ: чем больше смен отработал, тем выше уровень и плата.
## Подработка — 3 уровня, официальная работа (с трудовой книжкой) — 5.
## Опыт — число законченных смен, хранится в Progress.job_xp по id работы
## (тот же id, что у RouteJob / CarryJob / события смены).

## id → [название, официальная ли]
const JOBS := {
	"parcel": ["Почта", false],
	"hitch": ["Попутчик", false],
	"pump": ["Заправщик", false],
	"bread": ["Хлебовоз", false],
	"sweep": ["Дворник", false],
	"garden_job": ["Садовник в Липках", false],
	"kolkhoz": ["Колхоз, сено", false],
	"shift": ["Склад, грузчик", false],
	"logs": ["Лесоруб", false],
	"bus_shift": ["Рейсовый автобус", true],
	"sto_shift": ["Механик на СТО", true],
	"factory": ["Завод «Искра»", true],
}
## Сколько смен нужно до уровня (первый — сразу).
const SIDE_XP := [0, 4, 12]
const OFFICIAL_XP := [0, 3, 8, 15, 25]
## Во сколько раз больше платят на уровне.
const SIDE_PAY := [1.0, 1.25, 1.5]
const OFFICIAL_PAY := [1.0, 1.2, 1.45, 1.7, 2.0]
const SIDE_NAMES := ["новичок", "опытный", "мастер"]
const OFFICIAL_NAMES := ["стажёр", "работник", "старший", "мастер", "начальник смены"]


static func official(id: String) -> bool:
	return JOBS.has(id) and bool(JOBS[id][1])


static func xp(id: String) -> int:
	return int(Progress.job_xp.get(id, 0))


static func _table(id: String) -> Array:
	return OFFICIAL_XP if official(id) else SIDE_XP


static func max_level(id: String) -> int:
	return _table(id).size()


## Уровень 1…3 (подработка) или 1…5 (официальная).
static func level(id: String) -> int:
	var l := 0
	for need in _table(id):
		if xp(id) >= int(need):
			l += 1
	return maxi(l, 1)


static func level_name(id: String) -> String:
	return (OFFICIAL_NAMES if official(id) else SIDE_NAMES)[level(id) - 1]


static func mult(id: String) -> float:
	if not JOBS.has(id):
		return 1.0
	return (OFFICIAL_PAY if official(id) else SIDE_PAY)[level(id) - 1]


## Плата с учётом уровня, круглыми десятками (мелкие — до гривны).
static func pay(id: String, base: int) -> int:
	var p := float(base) * mult(id)
	return int(round(p / 10.0)) * 10 if base >= 50 else int(round(p))


## Сколько смен до следующего уровня (0 — уже последний).
static func to_next(id: String) -> int:
	var t := _table(id)
	var l := level(id)
	return 0 if l >= t.size() else int(t[l]) - xp(id)


## «ур. 2/3 · опытный» — для подсказок и журнала.
static func tag(id: String) -> String:
	if not JOBS.has(id):
		return ""
	return "ур. %d/%d · %s" % [level(id), max_level(id), level_name(id)]


## Смена отработана: +1 опыта; новый уровень — сообщение. Новый уровень или 0.
static func add(id: String) -> int:
	if not JOBS.has(id):
		return 0
	var before := level(id)
	Progress.job_xp[id] = xp(id) + 1
	var after := level(id)
	if after > before:
		SoundLibrary.play("quest", -4.0)
		GameManager.notify("%s: новый уровень %d/%d — %s, плата ×%s" % [JOBS[id][0], after, max_level(id), level_name(id), String.num(mult(id), 2)])
		QuestManager.event("job_level")
		return after
	return 0
