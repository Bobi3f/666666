extends Node
## Задания: сюжетная цепочка от первого утра до кирпичного дома и просьбы
## жителей Каменки. Плюс статистика для журнала и финального экрана.
##
## Игра сообщает о событиях: QuestManager.event("earned", 400) — и все
## активные задания, которые ждут такого события, продвигаются.
## Шаг задания — это:
##   * {"event": имя, "count": сколько} — копится из событий;
##   * {"give": вещь, "count": сколько} — отдать жителю (говоря с ним);
##   * {"talk": true} — вернуться к тому, кто дал задание.
## Сюжетные задания идут по очереди сами, просьбы жителей берутся в разговоре.

signal changed
signal completed(id: String)
signal victory
## Любое событие игры — для ежедневных поручений.
signal fired(name: String, amount: float)

## Главный путь: мопед → первые работы → права → первая машина → дом.
const MAIN := ["m_morning", "m_wheels", "m_money", "m_license", "m_car", "m_neighbours", "m_house", "m_master"]

const QUESTS := {
	"m_morning": {"title": "Первое утро", "main": true, "steps": [
		{"text": "Позавтракай — съешь что-нибудь из запаса (Q)", "event": "ate", "count": 1},
		{"text": "Выйди во двор и открой карту (M)", "event": "map", "count": 1}]},
	"m_wheels": {"title": "Старый мопед", "main": true, "steps": [
		{"text": "Прокатись на мопеде «Карпаты» 500 м (он во дворе)", "event": "drive_m", "count": 500},
		{"text": "Заправься на АЗС у трассы", "event": "refuel", "count": 1}]},
	"m_money": {"title": "Первые деньги", "main": true, "steps": [
		{"text": "Заработай 800 грн: посылки на почте, склад, колхоз, АЗС, рыбалка", "event": "earned", "count": 800}]},
	"m_license": {"title": "Права", "main": true, "steps": [
		{"text": "Получи паспорт в сельсовете и медсправку в больнице", "event": "med_ok", "count": 1},
		{"text": "Сдай на права в автошколе у трассы (на учебных «Жигулях»)", "event": "license", "count": 1}]},
	"m_car": {"title": "Первая машина", "main": true, "reward": 300, "steps": [
		{"text": "Купи первую машину: соседские «Жигули» напротив дома или в автосалоне", "event": "car_bought", "count": 1}]},
	"m_neighbours": {"title": "Свой среди своих", "main": true, "steps": [
		{"text": "Выполни две просьбы жителей (поговори с ними — E)", "event": "side_done", "count": 2}]},
	"m_house": {"title": "Новый дом", "main": true, "reward": 1000, "steps": [
		{"text": "Накопи 12 000 грн — прораб у калитки построит дом", "event": "house_1", "count": 1}]},
	"m_master": {"title": "Хозяин Каменки", "main": true, "steps": [
		{"text": "Накопи 30 000 грн на кирпичный дом", "event": "house_2", "count": 1}]},

	"s_galya": {"title": "Уха для бабы Гали", "giver": "Баба Галя", "reward": 350, "snacks": 2,
		"offer": "Сынок, поймай мне пару рыбок на уху — пирожками угощу.",
		"thanks": "Вот это улов! Держи деньги и пирожки, горяченькие.",
		"steps": [{"text": "Принеси бабе Гале 2 рыбы (пруд, мостки)", "give": "fish", "count": 2}]},
	"s_mikhalych": {"title": "Картошка для деда", "giver": "Дед Михалыч", "reward": 250,
		"offer": "Спина не гнётся, огород не вскопал. Принеси три картошки, а?",
		"thanks": "Выручил, ей-богу. На, возьми за труды.",
		"steps": [{"text": "Отдай деду Михалычу 3 еды из запаса", "give": "snacks", "count": 3}]},
	"s_petrovich": {"title": "Ударник труда", "giver": "Бригадир Петрович", "reward": 500,
		"offer": "Сено горит, людей нет. Отработаешь две смены — премию выпишу.",
		"thanks": "Вот это по-нашему! Держи премию.",
		"steps": [{"text": "Отработай 2 смены в колхозе", "event": "kolkhoz", "count": 2},
			{"text": "Вернись к бригадиру Петровичу", "talk": true}]},
	"s_lyuda": {"title": "Лекарство для тёти Люды", "giver": "Тётя Люда", "reward": 300,
		"offer": "Давление скачет, а до города не доехать. Купи мне лекарство в ларьке у склада?",
		"thanks": "Спасибо, родной! Вот, возьми за хлопоты.",
		"steps": [{"text": "Купи лекарство в городском ларьке", "event": "medicine", "count": 1},
			{"text": "Отдай лекарство тёте Люде (остановка у трассы)", "give": "medicine", "count": 1}]},
	"s_vasya": {"title": "Школа механики", "giver": "Механик Васёк", "reward": 400,
		"offer": "На автомате и бабка поедет. А на механике проедешь километр? Жми T в машине.",
		"thanks": "Уважаю! Настоящий водитель. Держи.",
		"steps": [{"text": "Проедь 1 км на механической коробке (T — переключить)", "event": "manual_m", "count": 1000},
			{"text": "Вернись к механику Ваське на СТО", "talk": true}]},
	"s_olya": {"title": "Почта Каменки", "giver": "Почтальонка Оля", "reward": 300,
		"offer": "Ноги не держат. Разнесёшь три письма? Синие почтовые ящики с надписью «ПИСЬМО» у калиток сразу увидишь.",
		"thanks": "Какой ты молодец! Вот, из моей зарплаты.",
		"steps": [{"text": "Разнеси 3 письма по ящикам с надписью «ПИСЬМО»", "event": "letter", "count": 3},
			{"text": "Вернись к почтальонке Оле", "talk": true}]},
}

## Состояние: id → {"state": 0 — не начато, 1 — идёт, 2 — выполнено, "step": шаг, "n": счётчик}
var quests := {}
## Вещи для заданий (лекарство, письма).
var items := {}
var stats := {"earned": 0, "fish": 0, "shifts": 0, "deliveries": 0, "km": 0.0, "quests": 0, "fainted": 0}
var won := false


func _ready() -> void:
	reset()


func reset() -> void:
	quests.clear()
	for id in QUESTS:
		quests[id] = {"state": 0, "step": 0, "n": 0.0}
	items.clear()
	stats = {"earned": 0, "fish": 0, "shifts": 0, "deliveries": 0, "km": 0.0, "quests": 0, "fainted": 0}
	won = false
	quests[MAIN[0]].state = 1
	changed.emit()


# --- События ---------------------------------------------------------------

func event(name: String, amount: float = 1.0) -> void:
	fired.emit(name, amount)
	match name:
		"earned":
			stats.earned += int(amount)
		"fish":
			stats.fish += int(amount)
		"kolkhoz", "shift":
			stats.shifts += 1
		"delivery":
			stats.deliveries += 1
		"drive_m":
			stats.km += amount / 1000.0
	var any := false
	for id in quests:
		var q: Dictionary = quests[id]
		if q.state != 1:
			continue
		var step: Dictionary = QUESTS[id].steps[q.step]
		if step.get("event", "") != name:
			continue
		q.n += amount
		any = true
		if q.n >= float(step.count):
			_advance(id)
	if any and name != "drive_m" and name != "manual_m":
		changed.emit()


## Разговор с жителем. Возвращает реплику по заданию или "" — тогда
## житель говорит своё обычное.
func talk(npc: String) -> String:
	for id in quests:
		var def: Dictionary = QUESTS[id]
		if def.get("giver", "") != npc:
			continue
		var q: Dictionary = quests[id]
		if q.state == 0:
			q.state = 1
			q.step = 0
			q.n = 0.0
			_on_step_start(id)
			SoundLibrary.play("click")
			changed.emit()
			return "%s (Новое задание: «%s» — J)" % [def.offer, def.title]
		if q.state != 1:
			continue
		var step: Dictionary = def.steps[q.step]
		if step.get("talk", false):
			_advance(id)
			return def.thanks
		if step.has("give"):
			var need: int = step.count
			if _has(step.give, need):
				_take(step.give, need)
				_advance(id)
				return def.thanks
			return "Жду: %s" % step.text.to_lower()
	return ""


func _has(item: String, n: int) -> bool:
	match item:
		"fish":
			return NeedsManager.fish >= n
		"snacks":
			return NeedsManager.snacks >= n
	return int(items.get(item, 0)) >= n


func _take(item: String, n: int) -> void:
	match item:
		"fish":
			NeedsManager.fish -= n
		"snacks":
			NeedsManager.snacks -= n
		_:
			items[item] = int(items.get(item, 0)) - n
			if items[item] <= 0:
				items.erase(item)


func give_item(item: String, n := 1) -> void:
	items[item] = int(items.get(item, 0)) + n
	changed.emit()


func _advance(id: String) -> void:
	var q: Dictionary = quests[id]
	var def: Dictionary = QUESTS[id]
	q.step += 1
	q.n = 0.0
	if q.step >= def.steps.size():
		_complete(id)
		return
	_on_step_start(id)
	SoundLibrary.play("click", -4.0)
	GameManager.notify("«%s»: %s" % [def.title, def.steps[q.step].text])
	changed.emit()


## Шаги, которые что-то выдают при старте (письма почтальонки).
func _on_step_start(id: String) -> void:
	if id == "s_olya" and quests[id].step == 0:
		items["letters"] = 3
	# Документы уже есть — сразу к экзамену
	if id == "m_license" and quests[id].step == 0 and Progress.has_doc("med"):
		_advance.call_deferred(id)


func _complete(id: String) -> void:
	var q: Dictionary = quests[id]
	var def: Dictionary = QUESTS[id]
	q.state = 2
	stats.quests += 1
	var reward := int(def.get("reward", 0))
	var parts: Array[String] = []
	if reward > 0:
		GameManager.add_money(reward)
		parts.append("+%d грн" % reward)
	if def.has("snacks"):
		NeedsManager.snacks += int(def.snacks)
		parts.append("+%d еды" % int(def.snacks))
	SoundLibrary.play("quest")
	GameManager.notify("Задание выполнено: «%s» %s" % [def.title, " ".join(parts)])
	completed.emit(id)
	if not def.get("main", false):
		event("side_done")
	# Следующее сюжетное — само
	var i := MAIN.find(id)
	if i >= 0 and i + 1 < MAIN.size():
		var next: String = MAIN[i + 1]
		quests[next].state = 1
		# Если условие уже выполнено раньше (дом построен до задания) — засчитываем
		if (next == "m_house" and Progress.house_level >= 1) or (next == "m_master" and Progress.house_level >= 2):
			_advance.call_deferred(next)
		elif (next == "m_license" and Progress.license) or (next == "m_car" and _owns_car()):
			_complete.call_deferred(next)
		else:
			_on_step_start(next)
	elif id == MAIN[-1]:
		won = true
		victory.emit()
	changed.emit()


## Есть ли своя машина (не мопед и не мотоцикл).
func _owns_car() -> bool:
	for k in ["car", "vaz2107", "niva", "volga", "truck"]:
		if Progress.owns(k):
			return true
	return false


# --- Для интерфейса --------------------------------------------------------

func active_main() -> String:
	for id in MAIN:
		if quests[id].state == 1:
			return id
	return ""


func step_text(id: String) -> String:
	var q: Dictionary = quests[id]
	var def: Dictionary = QUESTS[id]
	if q.state != 1:
		return ""
	var step: Dictionary = def.steps[q.step]
	var t: String = step.text
	if step.has("event") and int(step.count) > 1:
		var n := int(q.n)
		if step.event == "drive_m" or step.event == "manual_m":
			t += " — %d / %d м" % [n, int(step.count)]
		elif step.event == "earned":
			t += " — %d / %d" % [n, int(step.count)]
		else:
			t += " — %d / %d" % [n, int(step.count)]
	return t


## Строки для трекера на экране: сюжетное задание и до двух просьб.
func tracker_lines() -> Array[String]:
	var lines: Array[String] = []
	var m := active_main()
	if m != "":
		lines.append("» %s: %s" % [QUESTS[m].title, step_text(m)])
	elif won:
		lines.append("» Ты — хозяин Каменки! Играй дальше в своё удовольствие")
	var side := 0
	for id in quests:
		if QUESTS[id].get("main", false) or quests[id].state != 1:
			continue
		if side < 2:
			lines.append("• %s: %s" % [QUESTS[id].title, step_text(id)])
		side += 1
	return lines


func save_state() -> Dictionary:
	return {"quests": quests, "items": items, "stats": stats, "won": won}


func load_state(d: Dictionary) -> void:
	reset()
	var saved: Dictionary = d.get("quests", {})
	for id in saved:
		if quests.has(id):
			var s: Dictionary = saved[id]
			quests[id] = {"state": int(s.get("state", 0)), "step": int(s.get("step", 0)), "n": float(s.get("n", 0.0))}
	items = d.get("items", {}).duplicate()
	for k in items:
		items[k] = int(items[k])
	var st: Dictionary = d.get("stats", {})
	for k in stats:
		if st.has(k):
			stats[k] = st[k]
	won = bool(d.get("won", false))
	changed.emit()
