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

## Главный путь: мопед → первые работы → права → первая машина → дом →
## город (парк с Олей, бурса, СТО) → своё СТО → свадьба → автобус → хозяин района.
const MAIN := ["m_morning", "m_wheels", "m_money", "m_license", "m_car", "m_neighbours", "m_house", "m_master",
	"m_park", "m_college", "m_sto_work", "m_own_sto", "m_wedding", "m_bus", "m_district"]

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
		{"text": "Сдай на права в автошколе в городе (на учебных «Жигулях»)", "event": "license", "count": 1}]},
	"m_car": {"title": "Первая машина", "main": true, "reward": 300, "steps": [
		{"text": "Купи первую машину: соседские «Жигули» напротив дома или в автосалоне", "event": "car_bought", "count": 1}]},
	"m_neighbours": {"title": "Свой среди своих", "main": true, "steps": [
		{"text": "Выполни две просьбы жителей (поговори с ними — E)", "event": "side_done", "count": 2}]},
	"m_house": {"title": "Новый дом", "main": true, "reward": 1000, "steps": [
		{"text": "Накопи 12 000 грн — прораб у калитки построит дом", "event": "house_1", "count": 1}]},
	"m_master": {"title": "Хозяин Каменки", "main": true, "reward": 500, "steps": [
		{"text": "Накопи 30 000 грн на кирпичный дом", "event": "house_2", "count": 1}]},
	# Шаг с "to" — к кому идти (поговорить или отдать вещь), "say" — что он ответит.
	"m_park": {"title": "Огни города", "main": true, "reward": 300, "steps": [
		{"text": "Позови Олю гулять и прокатись с ней на колесе обозрения в городском парке", "event": "wheel_olya", "count": 1}]},
	"m_college": {"title": "Бурса", "main": true, "reward": 500, "steps": [
		{"text": "Пройди 3 урока на курсах автослесаря в бурсе (урок в день, 8:00–17:00)", "event": "college_lesson", "count": 3},
		{"text": "Сдай экзамен в бурсе — получи корочку автослесаря", "event": "course", "count": 1}]},
	"m_sto_work": {"title": "Подмастерье", "main": true, "reward": 500, "steps": [
		{"text": "Отработай 2 смены на СТО «Автосервис» в городе", "event": "sto_shift", "count": 2},
		{"text": "Заработай 3000 грн", "event": "earned", "count": 3000},
		{"text": "Поговори с механиком Васьком на СТО у Каменки — у него к тебе дело", "talk": true, "to": "Механик Васёк",
			"say": "Хозяин нашей СТО на пенсию собрался, мастерскую продаёт — 15 000. Выкупишь — пойду к тебе механиком, вдвоём озолотимся!"}]},
	"m_own_sto": {"title": "Своё СТО", "main": true, "reward": 1000, "steps": [
		{"text": "Выкупи СТО у Каменки за 15 000 грн (табличка у ворот)", "event": "business_sto", "count": 1},
		{"text": "Найми Васька механиком — поговори с ним", "talk": true, "to": "Механик Васёк",
			"say": "По рукам, начальник! С утра открываю ворота — клиенты повалят. Доход с СТО теперь больше на 300 в день."}]},
	"m_wedding": {"title": "Свадьба", "main": true, "reward": 2000, "steps": [
		{"text": "Стань Оле парнем: симпатия 70 (разговоры, подарки, катание, танцы)", "event": "girl_love", "count": 1},
		{"text": "Купи кольцо и свадебное платье на городском рынке (лавка «К свадьбе»)", "event": "wedding_set", "count": 1},
		{"text": "Своди Олю в «Метелицу» и закажи столик (дискотека в городе, с 21:00)", "event": "metelitsa_table", "count": 1},
		{"text": "Признайся Оле и сделай предложение — в разговоре с ней", "event": "proposal", "count": 1},
		{"text": "Свадьба: приведи Олю в сельсовет Каменки — там распишут (8:00–17:00, кроме вс)", "event": "wedding", "count": 1}]},
	"m_bus": {"title": "Рейсовый", "main": true, "reward": 1000, "steps": [
		{"text": "Сдай в автошколе на категорию D (автобус)", "event": "license_d", "count": 1},
		{"text": "Оформи трудовую книжку в сельсовете", "event": "doc_work_book", "count": 1},
		{"text": "Отъезди 2 рейса на рейсовом автобусе (у городской остановки, 500 грн за рейс)", "event": "bus_shift", "count": 2}]},
	"m_district": {"title": "Хозяин района", "main": true, "reward": 3000, "steps": [
		{"text": "Выкупи ларёк у склада в городе (5000 грн)", "event": "business_kiosk", "count": 1},
		{"text": "Разберись с Жорой из Озерцово: перекупи его ларёк или устрой у своего три дня акции", "event": "rival_done", "count": 1},
		{"text": "Открой автопарк: нужны три своих машины (табличка у гаражей в городе)", "event": "business_fleet", "count": 1}]},

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

	# Просьбы в городе: "start_items" — что житель даёт с собой при старте.
	"t_nikolaich": {"title": "Как новенькая", "giver": "Мастер Николаич", "reward": 400,
		"offer": "Ездишь на убитом? Поставь хоть один узел новый — у меня, у стеллажа. Увидишь, как поедет.",
		"thanks": "Другое дело! Машина — она уход любит. Держи за науку.",
		"steps": [{"text": "Поменяй у своей машины хоть один узел на новый (мастер СТО «Автосервис»)", "event": "part_renewed", "count": 1},
			{"text": "Вернись к мастеру Николаичу на СТО «Автосервис»", "talk": true}]},
	"t_zoya": {"title": "Ярмарочный день", "giver": "Продавщица Зоя", "reward": 400,
		"offer": "Урожай девать некуда? Вези на ярмарку — продашь, приходи, расскажешь.",
		"thanks": "Вот это торговля! На, премия от рынка.",
		"steps": [{"text": "Продай урожай на ярмарке", "event": "fair_sold", "count": 1},
			{"text": "Вернись к продавщице Зое у рынка", "talk": true}]},
	"t_sidorenko": {"title": "Народная дружина", "giver": "Лейтенант Сидоренко", "reward": 500,
		"offer": "Людей в патруле не хватает. Отъездишь с нами смену — грамоту выпишу. И премию.",
		"thanks": "Благодарность от отделения! Держи премию.",
		"steps": [{"text": "Отъезди смену в милицейском патруле (отделение в городе)", "event": "patrol", "count": 1},
			{"text": "Вернись к лейтенанту Сидоренко", "talk": true}]},
	"t_stepanych": {"title": "Дворовый субботник", "giver": "Дворник Степаныч", "reward": 300,
		"offer": "Спина отваливается. Поработай за меня на складе грузчиком — смену, а я тебе заплачу.",
		"thanks": "Выручил старика! Держи.",
		"steps": [{"text": "Отработай смену грузчиком на складе в городе", "event": "shift", "count": 1},
			{"text": "Вернись к дворнику Степанычу во двор пятиэтажек", "talk": true}]},
	"t_dimka": {"title": "Гонщик из бурсы", "giver": "Студент Димка", "reward": 400,
		"offer": "Говорят, Колька из Каменки всех обгоняет. Обгонишь его — с меня причитается!",
		"thanks": "Ну ты дал! Вся бурса про тебя говорит.",
		"steps": [{"text": "Обгони Кольку в гонке до моста (Каменка, у трассы)", "event": "race_won", "count": 1},
			{"text": "Вернись к студенту Димке у бурсы", "talk": true}]},

	# Просьбы в сёлах района: у магазина каждого села стоит житель.
	"v_ozertsovo": {"title": "Уха по-озерцовски", "giver": "Дядя Коля из Озерцово", "reward": 400,
		"offer": "Сети порвались, а гости на носу. Привези три рыбы — отблагодарю.",
		"thanks": "Ай, молодец! Будет уха. Держи.",
		"steps": [{"text": "Привези дяде Коле в Озерцово 3 рыбы", "give": "fish", "count": 3}]},
	"v_pervomai": {"title": "Лекарство за реку", "giver": "Бабка Нюра из Первомая", "reward": 350,
		"offer": "Мост старый, до города не дойти. Купи мне лекарство в городском ларьке, сынок.",
		"thanks": "Дай бог здоровья! Возьми, не отказывайся.",
		"steps": [{"text": "Купи лекарство в городском ларьке", "event": "medicine", "count": 1},
			{"text": "Отдай лекарство бабке Нюре в Первомае", "give": "medicine", "count": 1}]},
	"v_toshiki": {"title": "Грибная охота", "giver": "Грибник Толик из Тошиков", "reward": 400,
		"offer": "Спорим, пять грибов за день не найдёшь? В лесу их — косой коси.",
		"thanks": "Нашёл-таки! Проиграл я спор, держи.",
		"steps": [{"text": "Найди в лесу 5 грибов", "event": "mushroom", "count": 5},
			{"text": "Вернись к грибнику Толику в Тошики", "talk": true}]},
	"v_zarechye": {"title": "Мёд для Каменки", "giver": "Пасечник Иван из Заречья", "reward": 300, "snacks": 1,
		"start_items": {"honey": 1},
		"offer": "Обещал бабе Гале в Каменку банку мёда, а ехать не на чем. Отвезёшь?",
		"thanks": "Довёз? Вот спасибо! И тебе баночку.",
		"steps": [{"text": "Отвези мёд бабе Гале в Каменку", "give": "honey", "count": 1, "to": "Баба Галя",
			"say": "Мёд от Ивана! Ой, уважил старуху."},
			{"text": "Вернись к пасечнику Ивану в Заречье", "talk": true}]},
	"v_sosnovka": {"title": "Черника для тёти Люды", "giver": "Лесник Пётр из Сосновки", "reward": 350, "snacks": 1,
		"start_items": {"berries": 1},
		"offer": "Черники ведро набрал — сестре в Каменку, Люде. Отвези, а?",
		"thanks": "Довёз? Ну, спасибо, брат. Держи на дорогу.",
		"steps": [{"text": "Отвези ведро черники тёте Люде в Каменку", "give": "berries", "count": 1, "to": "Тётя Люда",
			"say": "От Петьки черника! Варенья наварю — заходи на чай."},
			{"text": "Вернись к леснику Петру в Сосновку", "talk": true}]},
	"v_krasny_yar": {"title": "Провизия для сторожа", "giver": "Сторож Михей из Красного Яра", "reward": 350,
		"offer": "Магазин у нас пустой. Привези с городского рынка поесть — две порции.",
		"thanks": "Вот это пир! Спасибо, выручил.",
		"steps": [{"text": "Купи еды на рынке в городе", "event": "market", "count": 1},
			{"text": "Отдай сторожу Михею в Красном Яре 2 еды", "give": "snacks", "count": 2}]},
	"v_berezovka": {"title": "Подмени таксиста", "giver": "Дачница Вера из Берёзовки", "reward": 500,
		"offer": "Муж таксует в городе, а сегодня слёг. Отвези за него два заказа — нужны права.",
		"thanks": "Спасибо! Диспетчер даже не заметил.",
		"steps": [{"text": "Отвези 2 пассажиров на такси (стоянка в городе, нужны права)", "event": "taxi", "count": 2},
			{"text": "Вернись к дачнице Вере в Берёзовку", "talk": true}]},
	"v_luzhki": {"title": "Хлеб для Лужков", "giver": "Доярка Таня из Лужков", "reward": 500,
		"offer": "Хлеб к нам не возят — далеко. Возьми заказ на складе в городе, развези два раза.",
		"thanks": "Свежий хлеб! Спасибо, весь колхоз благодарит.",
		"steps": [{"text": "Развези хлеб со склада в городе 2 раза", "event": "delivery", "count": 2},
			{"text": "Вернись к доярке Тане в Лужки", "talk": true}]},
	"v_gorki": {"title": "По родному краю", "giver": "Вожатый Палыч из Горок", "reward": 500,
		"offer": "В лагере я детей по району водил. А ты наш район знаешь? Накатай десять километров — потом расскажешь.",
		"thanks": "Вот теперь ты наш, районный! Держи.",
		"steps": [{"text": "Проедь 10 км по району", "event": "drive_m", "count": 10000},
			{"text": "Вернись к вожатому Палычу в Горки", "talk": true}]},
	"v_zaozerye": {"title": "Разгрузка фуры", "giver": "Дальнобойщик Гриша из Заозерья", "reward": 400,
		"offer": "Грузчиков не дозовёшься, а фура стоит. Потаскай хоть пять грузов — на складе в городе или в колхозе, мне всё равно.",
		"thanks": "Красавец! Фура пошла. Держи за работу.",
		"steps": [{"text": "Перенеси 5 грузов: ящики на складе в городе или тюки в колхозе", "event": "carry", "count": 5},
			{"text": "Вернись к дальнобойщику Грише в Заозерье", "talk": true}]},
	"v_stepnoe": {"title": "Пахота в Степном", "giver": "Агроном Зина из Степного", "reward": 400,
		"offer": "Трактористов нет, поле стоит. Вспахал бы ты хоть одно — в Каменке трактор у сарая.",
		"thanks": "Вспахал? Вот это хозяин! Держи.",
		"steps": [{"text": "Вспаши поле на тракторе (наряд у колхозного сарая в Каменке)", "event": "plough", "count": 1},
			{"text": "Вернись к агроному Зине в Степное", "talk": true}]},
	"v_malinovka": {"title": "Трофей Быстрой", "giver": "Рыбак Лёня из Малиновки", "reward": 600,
		"offer": "В Быстрой сом живёт — во! Поймаешь трофейную рыбу — поверю, что ты рыбак.",
		"thanks": "Трофей! Ну, рыбак. Уважаю.",
		"steps": [{"text": "Поймай трофейную рыбу", "event": "trophy", "count": 1},
			{"text": "Вернись к рыбаку Лёне в Малиновку", "talk": true}]},
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
## житель говорит своё обычное. Шаг может вести к другому жителю ("to").
func talk(npc: String) -> String:
	# Сперва — то, чего житель ждёт (поговорить, принять вещь), потом новое
	for id in quests:
		var def: Dictionary = QUESTS[id]
		var q: Dictionary = quests[id]
		if q.state != 1:
			continue
		var step: Dictionary = def.steps[q.step]
		if step.get("to", def.get("giver", "")) != npc:
			continue
		var say: String = step.get("say", def.get("thanks", ""))
		if step.get("talk", false):
			_advance(id)
			return say
		if step.has("give"):
			var need: int = step.count
			if _has(step.give, need):
				_take(step.give, need)
				_advance(id)
				return say
			return "Жду: %s" % step.text.to_lower()
	for id in quests:
		var def: Dictionary = QUESTS[id]
		var q: Dictionary = quests[id]
		# Сюжетные задания начинаются сами, просьбу даёт житель
		if q.state != 0 or def.get("giver", "") != npc or def.get("main", false):
			continue
		q.state = 1
		q.step = 0
		q.n = 0.0
		_on_step_start(id)
		SoundLibrary.play("click")
		changed.emit()
		return "%s (Новое задание: «%s» — J)" % [def.offer, def.title]
	return ""


## Есть ли у жителя что сказать по заданию: новая просьба или ждёт тебя
## (поговорить, отдать вещь) — над ним в подсказке «(!)».
func has_line_for(npc: String) -> bool:
	for id in quests:
		var def: Dictionary = QUESTS[id]
		var q: Dictionary = quests[id]
		if q.state == 0 and def.get("giver", "") == npc and not def.get("main", false):
			return true
		if q.state == 1:
			var step: Dictionary = def.steps[q.step]
			if step.get("to", def.get("giver", "")) == npc and (step.get("talk", false) or (step.has("give") and _has(step.give, int(step.count)))):
				return true
	return false


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


## Начало шага: выдать вещи с собой (письма, мёд) и засчитать сразу, если
## условие уже выполнено раньше (документы есть, дом построен, дело куплено).
func _on_step_start(id: String) -> void:
	var q: Dictionary = quests[id]
	if q.step == 0:
		if id == "s_olya":
			items["letters"] = 3
		var give: Dictionary = QUESTS[id].get("start_items", {})
		for k in give:
			items[k] = int(items.get(k, 0)) + int(give[k])
	if _step_done(id, q.step):
		_advance_if.call_deferred(id, q.step)


## Продвинуть, если задание всё ещё на этом шаге (отложенный вызов).
func _advance_if(id: String, step: int) -> void:
	var q: Dictionary = quests[id]
	if q.state == 1 and q.step == step:
		_advance(id)


## Выполнено ли условие шага уже сейчас — для сюжетных глав, которые
## игрок мог пройти наперёд (старое сохранение, купил раньше времени).
func _step_done(id: String, step: int) -> bool:
	match [id, step]:
		["m_license", 0]:
			return Progress.has_doc("med")
		["m_license", 1]:
			return Progress.license
		["m_car", 0]:
			return _owns_car()
		["m_house", 0]:
			return Progress.house_level >= 1
		["m_master", 0]:
			return Progress.house_level >= 2
		["m_college", 0]:
			return Progress.has_item("mechanic") or _college_lessons() >= 3
		["m_college", 1]:
			return Progress.has_item("mechanic")
		["m_own_sto", 0]:
			return Daily.owns("sto")
		["m_wedding", 0]:
			var g := _girl()
			return g != null and (g.rel >= Girl.LOVE or g.engaged or g.married)
		["m_wedding", 1]:
			var g2 := _girl()
			return (Progress.has_item("ring") and Progress.has_item("dress")) or (g2 != null and (g2.engaged or g2.married))
		["m_wedding", 3]:
			var g3 := _girl()
			return g3 != null and (g3.engaged or g3.married)
		["m_wedding", 4]:
			var g4 := _girl()
			return g4 != null and g4.married
		["m_bus", 0]:
			return Progress.has_category("D")
		["m_bus", 1]:
			return Progress.has_doc("work_book")
		["m_district", 0]:
			return Daily.owns("kiosk")
		["m_district", 1]:
			return Daily.rival == Daily.Rival.BOUGHT or Daily.rival == Daily.Rival.RUINED
		["m_district", 2]:
			return Daily.owns("fleet")
	return false


func _girl() -> Girl:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("girl") as Girl


func _college_lessons() -> int:
	if not is_inside_tree():
		return 0
	var e := get_tree().get_first_node_in_group("town_east")
	return int(e.course_lessons) if e else 0


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
	if id == "m_own_sto":
		Daily.hire("vasya")
	# Следующее сюжетное — само (если условие уже выполнено — засчитается)
	var i := MAIN.find(id)
	if i >= 0 and i + 1 < MAIN.size():
		_start_main(MAIN[i + 1])
	elif id == MAIN[-1]:
		won = true
		victory.emit()
	changed.emit()


func _start_main(id: String) -> void:
	quests[id].state = 1
	quests[id].step = 0
	quests[id].n = 0.0
	_on_step_start(id)


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
		lines.append("» Ты — хозяин района! Играй дальше в своё удовольствие")
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
	# Старое сохранение: сюжет кончался на кирпичном доме — дальше новые главы
	for k in MAIN.size() - 1:
		if quests[MAIN[k]].state == 2 and quests[MAIN[k + 1]].state == 0:
			_start_main(MAIN[k + 1])
			break
	changed.emit()
