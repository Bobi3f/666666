class_name VehicleModels
extends RefCounted
## Подробные модели транспорта из коробок: Жигули (и попутки на их основе),
## автобус ЛАЗ, мотоцикл Ява. Вперёд — к -Z, пол — y = 0.
##
## Колёса, стоп-сигналы и прочее подвижное сюда не входят: их добавляет
## тот, кто строит машину (vehicle.gd, traffic.gd).


## Жигули-«копейка»: кузов с выштамповками, двери со щелями и ручками,
## хромированные бамперы с клыками, решётка, круглые фары, зеркала,
## дворники, номера, салон с торпедо, рулём и сиденьями.
## glass_b — куда класть стёкла: у машины игрока они отдельным прозрачным
## мешем, иначе из салона дороги не видно; у попуток — вместе с кузовом.
static func zhiguli(b: MeshBuilder, paint: Color, interior := true, glass_b: MeshBuilder = null) -> void:
	var gb := glass_b if glass_b else b
	var dark := Color(0.07, 0.07, 0.08)
	var chrome := Color(0.78, 0.78, 0.8)
	var glass := Color(0.35, 0.45, 0.5)
	var seat := Color(0.32, 0.2, 0.15)
	var gap := paint.darkened(0.45)
	# Низ кузова, пороги, капот и багажник
	b.box(Vector3(-0.82, 0.34, -2.05), Vector3(0.82, 0.78, 2.05), paint)
	b.box(Vector3(-0.83, 0.3, -1.0), Vector3(0.83, 0.36, 1.1), dark)
	b.box(Vector3(-0.8, 0.78, -2.05), Vector3(0.8, 0.9, -0.62), paint)
	b.box(Vector3(-0.8, 0.78, 1.1), Vector3(0.8, 0.9, 2.05), paint)
	# Выштамповка-молдинг вдоль бока
	for x in [-0.835, 0.825]:
		b.box(Vector3(x, 0.6, -2.0), Vector3(x + 0.01, 0.63, 2.0), chrome)
	# Арки колёс — тёмные вырезы
	for z in [-1.3, 1.3]:
		for x in [-0.84, 0.8]:
			b.box(Vector3(x, 0.3, z - 0.42), Vector3(x + 0.04, 0.62, z + 0.42), dark)
	# Двери: щели и ручки
	for x in [-0.835, 0.825]:
		for z in [-0.6, 0.3, 1.1]:
			b.box(Vector3(x, 0.36, z - 0.01), Vector3(x + 0.01, 1.35, z + 0.01), gap)
		for z in [-0.2, 0.7]:
			b.box(Vector3(x - 0.01, 0.74, z), Vector3(x + 0.02, 0.77, z + 0.14), chrome)
	# Стойки, крыша, стёкла по кругу
	for x in [-0.74, 0.68]:
		b.box(Vector3(x, 0.9, -0.62), Vector3(x + 0.06, 1.42, -0.5), paint)
		b.box(Vector3(x, 0.9, 1.0), Vector3(x + 0.06, 1.42, 1.12), paint)
		b.box(Vector3(x, 0.9, 0.24), Vector3(x + 0.06, 1.42, 0.32), paint)
		gb.box(Vector3(x + 0.02, 0.92, -0.5), Vector3(x + 0.04, 1.38, 0.24), glass)
		gb.box(Vector3(x + 0.02, 0.92, 0.32), Vector3(x + 0.04, 1.38, 1.0), glass)
	b.box(Vector3(-0.76, 1.42, -0.64), Vector3(0.76, 1.48, 1.14), paint)
	gb.box(Vector3(-0.7, 0.92, -0.64), Vector3(0.7, 1.4, -0.6), glass)
	gb.box(Vector3(-0.7, 0.92, 1.12), Vector3(0.7, 1.4, 1.16), glass)
	# Водостоки на крыше, дворники
	for x in [-0.76, 0.72]:
		b.box(Vector3(x, 1.46, -0.64), Vector3(x + 0.04, 1.5, 1.14), chrome)
	for x in [-0.45, 0.1]:
		b.box(Vector3(x, 0.91, -0.66), Vector3(x + 0.4, 0.93, -0.64), dark)
	# Зеркала
	for x in [-0.95, 0.83]:
		b.box(Vector3(x, 0.92, -0.62), Vector3(x + 0.12, 1.02, -0.56), dark)
	# Бамперы с клыками и накладками
	for z in [-2.14, 2.04]:
		b.box(Vector3(-0.86, 0.32, z), Vector3(0.86, 0.44, z + 0.1), chrome)
		b.box(Vector3(-0.86, 0.34, z + 0.03), Vector3(0.86, 0.37, z + 0.07), dark)
		for x in [-0.45, 0.37]:
			b.box(Vector3(x, 0.28, z - 0.02), Vector3(x + 0.08, 0.5, z + 0.12), chrome)
	# Решётка радиатора с рёбрами, круглые двойные фары (по кусочку ромбом)
	b.box(Vector3(-0.4, 0.55, -2.07), Vector3(0.4, 0.78, -2.05), dark)
	for i in 6:
		b.box(Vector3(-0.38, 0.57 + i * 0.035, -2.08), Vector3(0.38, 0.585 + i * 0.035, -2.06), chrome)
	for x in [-0.72, -0.53, 0.43, 0.62]:
		b.box(Vector3(x - 0.01, 0.57, -2.08), Vector3(x + 0.1, 0.77, -2.05), chrome)
		b.box(Vector3(x + 0.01, 0.59, -2.09), Vector3(x + 0.08, 0.75, -2.07), Color(1.0, 0.97, 0.86))
	# Поворотники спереди, фонари сзади (стоп-сигналы — отдельно)
	for x in [-0.8, 0.66]:
		b.box(Vector3(x, 0.46, -2.07), Vector3(x + 0.14, 0.52, -2.05), Color(0.95, 0.6, 0.1))
		b.box(Vector3(x, 0.7, 2.05), Vector3(x + 0.14, 0.76, 2.07), Color(0.95, 0.6, 0.1))
	# Номера
	plate(b, Vector3(-0.26, 0.42, -2.16), Vector3(0.26, 0.53, -2.15))
	plate(b, Vector3(-0.26, 0.48, 2.06), Vector3(0.26, 0.6, 2.07))
	# Выхлопная труба, эмблема
	b.box(Vector3(0.45, 0.24, 1.9), Vector3(0.53, 0.3, 2.2), dark)
	b.box(Vector3(-0.05, 0.82, -2.06), Vector3(0.05, 0.86, -2.04), chrome)
	if not interior:
		b.box(Vector3(-0.7, 0.9, -0.6), Vector3(0.7, 1.4, 1.1), Color(0.12, 0.12, 0.13))
		return
	# Салон: потолок, торпедо с приборами, руль, рычаги, сиденья с подголовниками
	b.box(Vector3(-0.7, 1.4, -0.58), Vector3(0.7, 1.42, 1.08), Color(0.85, 0.82, 0.75))
	var panel := Color(0.26, 0.22, 0.19)
	b.box(Vector3(-0.72, 0.9, -0.58), Vector3(0.72, 1.02, -0.32), panel)
	b.box(Vector3(-0.5, 1.0, -0.4), Vector3(-0.22, 1.08, -0.33), Color(0.1, 0.1, 0.1))
	for x in [-0.46, -0.33]:
		b.box(Vector3(x, 1.01, -0.331), Vector3(x + 0.1, 1.07, -0.329), Color(0.9, 0.85, 0.6))
	b.box(Vector3(0.05, 0.95, -0.33), Vector3(0.35, 1.0, -0.32), Color(0.15, 0.15, 0.15))
	var rim := Color(0.12, 0.12, 0.12)
	b.box(Vector3(-0.52, 0.96, -0.2), Vector3(-0.2, 0.99, -0.18), rim)
	b.box(Vector3(-0.52, 1.17, -0.2), Vector3(-0.2, 1.2, -0.18), rim)
	b.box(Vector3(-0.52, 0.96, -0.2), Vector3(-0.49, 1.2, -0.18), rim)
	b.box(Vector3(-0.23, 0.96, -0.2), Vector3(-0.2, 1.2, -0.18), rim)
	b.box(Vector3(-0.37, 0.96, -0.32), Vector3(-0.35, 1.05, -0.19), rim)
	b.box(Vector3(-0.03, 0.7, -0.1), Vector3(0.03, 0.95, -0.04), rim)
	b.box(Vector3(-0.05, 0.93, -0.12), Vector3(0.05, 0.98, -0.02), Color(0.2, 0.2, 0.2))
	for x in [-0.36, 0.36]:
		b.box(Vector3(x - 0.25, 0.6, 0.1), Vector3(x + 0.25, 0.72, 0.55), seat)
		b.box(Vector3(x - 0.25, 0.72, 0.5), Vector3(x + 0.25, 1.2, 0.6), seat)
		b.box(Vector3(x - 0.12, 1.2, 0.52), Vector3(x + 0.12, 1.34, 0.58), seat.darkened(0.1))
	b.box(Vector3(-0.7, 0.6, 0.72), Vector3(0.7, 0.72, 1.02), seat)
	b.box(Vector3(-0.7, 0.72, 0.98), Vector3(0.7, 1.12, 1.06), seat)


## Колесо Жигулей: шина, диск, колпак с «звёздочкой».
## Белая табличка под номер. Где она — запоминается в builder (метка
## «plates»): потом на неё ложится надпись номера (см. Plates).
static func plate(b: MeshBuilder, mn: Vector3, mx: Vector3) -> void:
	b.box(mn, mx, Color(0.92, 0.92, 0.9))
	var spots: Array = b.get_meta("plates", [])
	var c := (mn + mx) * 0.5
	var back := c.z > 0.0
	# Надпись — на лицевой стороне, чуть впереди таблички
	var face := Vector3(c.x, c.y, mx.z + 0.004 if back else mn.z - 0.004)
	spots.append([b.xf * face, (b.xf.basis.get_euler().y) + (0.0 if back else PI), Vector2(mx.x - mn.x, mx.y - mn.y)])
	b.set_meta("plates", spots)


## rim — цвет дисков с базара (null — заводские серые).
static func car_wheel(b: MeshBuilder, r: float, w: float, rim: Variant = null) -> void:
	var tyre := Color(0.07, 0.07, 0.08)
	var disc: Color = rim if rim is Color else Color(0.55, 0.55, 0.57)
	# Шина — восьмигранник из трёх повёрнутых брусков
	for a in [0.0, PI / 4.0, PI / 2.0, 3.0 * PI / 4.0]:
		var saved := b.xf
		b.xf = saved * Transform3D(Basis(Vector3.RIGHT, a), Vector3.ZERO)
		b.box(Vector3(-w * 0.5, -r, -r * 0.42), Vector3(w * 0.5, r, r * 0.42), tyre)
		b.xf = saved
	b.box(Vector3(-w * 0.52, -r * 0.55, -r * 0.55), Vector3(w * 0.52, r * 0.55, r * 0.55), disc)
	b.box(Vector3(-w * 0.56, -r * 0.3, -r * 0.3), Vector3(w * 0.56, r * 0.3, r * 0.3), disc.lightened(0.3) if rim is Color else Color(0.82, 0.82, 0.84))
	for a in [0.0, PI / 2.0]:
		var saved := b.xf
		b.xf = saved * Transform3D(Basis(Vector3.RIGHT, a), Vector3.ZERO)
		b.box(Vector3(-w * 0.58, -r * 0.5, -0.02), Vector3(w * 0.58, r * 0.5, 0.02), Color(0.35, 0.35, 0.37))
		b.xf = saved


## Автобус ЛАЗ: окна рядами с простенками, двери-гармошки, маршрутный
## указатель, бамперы, фары, решётка сзади, крыша с люками.
static func bus(b: MeshBuilder, paint: Color, size: Vector3) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var glass := Color(0.25, 0.32, 0.38)
	var dark := Color(0.08, 0.08, 0.09)
	var white := Color(0.92, 0.9, 0.85)
	b.box(Vector3(-hx, 0.45, -hz), Vector3(hx, 3.1, hz), paint)
	b.box(Vector3(-hx - 0.01, 0.45, -hz), Vector3(hx + 0.01, 1.05, hz), paint.darkened(0.35))
	b.box(Vector3(-hx - 0.012, 1.05, -hz), Vector3(hx + 0.012, 1.12, hz), white)
	# Окна рядами с простенками
	var z := -hz + 1.2
	while z < hz - 0.9:
		for x in [-hx - 0.015, hx + 0.005]:
			b.box(Vector3(x, 1.5, z), Vector3(x + 0.01, 2.55, z + 1.05), glass)
		z += 1.25
	# Лобовое и заднее стёкла, маршрутный указатель
	b.box(Vector3(-hx + 0.12, 1.25, -hz - 0.015), Vector3(hx - 0.12, 2.6, -hz), glass)
	b.box(Vector3(-hx + 0.25, 1.6, hz), Vector3(hx - 0.25, 2.5, hz + 0.015), glass)
	b.box(Vector3(-0.8, 2.7, -hz - 0.02), Vector3(0.8, 2.95, -hz), dark)
	b.box(Vector3(-0.7, 2.74, -hz - 0.025), Vector3(0.7, 2.91, -hz - 0.02), Color(0.95, 0.75, 0.2))
	# Двери справа по ходу (+X): две гармошки
	for dz in [-hz + 0.6, 0.6]:
		b.box(Vector3(hx + 0.005, 0.5, dz), Vector3(hx + 0.02, 2.6, dz + 1.1), dark)
		for k in 4:
			b.box(Vector3(hx + 0.02, 0.65, dz + 0.08 + k * 0.26), Vector3(hx + 0.03, 2.45, dz + 0.24 + k * 0.26), glass)
	# Фары, бампер, решётка моторного отсека сзади
	for x in [-hx + 0.2, hx - 0.5]:
		b.box(Vector3(x, 0.7, -hz - 0.03), Vector3(x + 0.3, 0.9, -hz), Color(1.0, 0.97, 0.86))
	b.box(Vector3(-hx, 0.3, -hz - 0.15), Vector3(hx, 0.5, -hz), dark)
	b.box(Vector3(-hx, 0.3, hz), Vector3(hx, 0.5, hz + 0.15), dark)
	for i in 6:
		b.box(Vector3(-hx + 0.3, 0.6 + i * 0.12, hz), Vector3(hx - 0.3, 0.66 + i * 0.12, hz + 0.02), dark)
	# Крыша: люки и козырёк
	b.box(Vector3(-hx + 0.05, 3.1, -hz + 0.05), Vector3(hx - 0.05, 3.18, hz - 0.05), paint.lightened(0.1))
	for zz in [-2.0, 1.5]:
		b.box(Vector3(-0.5, 3.18, zz), Vector3(0.5, 3.26, zz + 0.8), Color(0.6, 0.6, 0.6))
	# Колёса с арками
	for zz in [-hz + 1.7, hz - 2.0]:
		for x in [-hx - 0.02, hx - 0.28]:
			b.box(Vector3(x, 0.0, zz - 0.52), Vector3(x + 0.3, 1.0, zz + 0.52), dark)
			b.box(Vector3(x + (0.29 if x > 0 else -0.01), 0.3, zz - 0.25), Vector3(x + (0.31 if x > 0 else 0.01), 0.7, zz + 0.25), Color(0.6, 0.6, 0.62))


## Ява: трубчатая рама, каплевидный бак с хромом, двухместное седло,
## вилка, фара, спидометр, руль с рукоятками, крылья, глушители, подножки.
static func java(b: MeshBuilder, paint: Color) -> void:
	var dark := Color(0.08, 0.08, 0.09)
	var chrome := Color(0.8, 0.8, 0.82)
	var engine := Color(0.42, 0.42, 0.44)
	# Рама
	b.box(Vector3(-0.04, 0.38, -0.55), Vector3(0.04, 0.46, 0.62), dark)
	b.box(Vector3(-0.035, 0.46, -0.6), Vector3(0.035, 0.9, -0.52), dark)
	# Бак: основа, хромированные боковины, крышка
	b.box(Vector3(-0.19, 0.62, -0.46), Vector3(0.19, 0.86, 0.04), paint)
	b.box(Vector3(-0.2, 0.66, -0.36), Vector3(0.2, 0.8, -0.06), chrome)
	b.box(Vector3(-0.05, 0.86, -0.3), Vector3(0.05, 0.89, -0.2), chrome)
	# Седло с кантом и ручкой пассажира
	b.box(Vector3(-0.17, 0.8, 0.02), Vector3(0.17, 0.9, 0.68), Color(0.1, 0.09, 0.09))
	b.box(Vector3(-0.18, 0.79, 0.02), Vector3(0.18, 0.81, 0.68), Color(0.8, 0.8, 0.78))
	b.box(Vector3(-0.2, 0.86, 0.5), Vector3(0.2, 0.9, 0.54), chrome)
	# Мотор, цилиндр с рёбрами, картер
	b.box(Vector3(-0.2, 0.28, -0.35), Vector3(0.2, 0.52, 0.12), engine)
	for i in 5:
		b.box(Vector3(-0.14, 0.52 + i * 0.03, -0.3), Vector3(0.14, 0.535 + i * 0.03, -0.05), engine.lightened(0.15))
	b.box(Vector3(-0.22, 0.3, -0.12), Vector3(0.22, 0.42, 0.1), engine.darkened(0.2))
	# Вилка, крыло, фара с ободом, спидометр, руль и рукоятки
	for x in [-0.09, 0.07]:
		b.box(Vector3(x, 0.32, -0.86), Vector3(x + 0.03, 0.98, -0.8), chrome)
	b.box(Vector3(-0.1, 0.62, -1.05), Vector3(0.1, 0.66, -0.6), paint)
	b.box(Vector3(-0.1, 0.88, -1.0), Vector3(0.1, 1.06, -0.86), chrome)
	b.box(Vector3(-0.08, 0.9, -1.01), Vector3(0.08, 1.04, -1.0), Color(1.0, 0.97, 0.86))
	b.box(Vector3(-0.05, 1.06, -0.92), Vector3(0.05, 1.12, -0.86), dark)
	b.box(Vector3(-0.38, 1.02, -0.8), Vector3(0.38, 1.05, -0.76), chrome)
	for x in [-0.4, 0.3]:
		b.box(Vector3(x, 1.01, -0.81), Vector3(x + 0.1, 1.06, -0.75), dark)
	for x in [-0.44, 0.37]:
		b.box(Vector3(x, 1.06, -0.78), Vector3(x + 0.07, 1.14, -0.76), dark)
	# Заднее крыло с номером, фонарь (стоп — отдельно)
	b.box(Vector3(-0.1, 0.6, 0.45), Vector3(0.1, 0.66, 0.95), paint)
	plate(b, Vector3(-0.1, 0.44, 0.9), Vector3(0.1, 0.6, 0.92))
	# Два глушителя-«рыбки»
	for x in [0.17, -0.25]:
		b.box(Vector3(x, 0.26, -0.1), Vector3(x + 0.08, 0.34, 0.95), chrome)
		b.box(Vector3(x - 0.01, 0.25, 0.8), Vector3(x + 0.09, 0.35, 0.97), chrome.darkened(0.1))
	# Подножки и педаль тормоза
	for x in [-0.3, 0.22]:
		b.box(Vector3(x, 0.32, -0.05), Vector3(x + 0.08, 0.35, 0.05), dark)
	# Спицы колёс рисует колесо, здесь — щитки цепи
	b.box(Vector3(0.1, 0.3, 0.1), Vector3(0.13, 0.4, 0.6), dark)


## Труба от a до c квадратного сечения 2t — рама, вилка, выхлоп, дуги.
static func tube(b: MeshBuilder, a: Vector3, c: Vector3, t: float, col: Color) -> void:
	var d := c - a
	var l := d.length()
	if l < 0.001:
		return
	var up := Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT
	var saved := b.xf
	b.xf = saved * Transform3D(Basis.looking_at(d, up), (a + c) * 0.5)
	b.box(Vector3(-t, -t, -l * 0.5), Vector3(t, t, l * 0.5), col)
	b.xf = saved


## Ломаная из труб по точкам — изогнутая труба.
static func pipe(b: MeshBuilder, pts: Array, t: float, col: Color) -> void:
	for i in pts.size() - 1:
		tube(b, pts[i], pts[i + 1], t, col)


## Круглая шайба-восьмигранник: фара, крышки мотора, пробка бака.
static func disc(b: MeshBuilder, c: Vector3, axis: Vector3, r: float, thick: float, col: Color) -> void:
	var up := Vector3.UP if absf(axis.normalized().y) < 0.95 else Vector3.RIGHT
	var base := Basis.looking_at(axis, up)
	var saved := b.xf
	for k in 4:
		b.xf = saved * Transform3D(base * Basis(Vector3.BACK, k * PI / 4.0), c)
		b.box(Vector3(-r, -r * 0.414, -thick * 0.5), Vector3(r, r * 0.414, thick * 0.5), col)
	b.xf = saved


## Щиток по дуге вокруг колеса (в плоскости YZ): от угла a0 до a1, угол
## отсчитан от «вверх» в сторону «вперёд» (−Z).
static func fender(b: MeshBuilder, c: Vector3, r: float, a0: float, a1: float, w: float, col: Color) -> void:
	var n := 7
	var prev := Vector3.ZERO
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		var p := c + Vector3(0, cos(a) * r, -sin(a) * r)
		if i > 0:
			var d := p - prev
			var saved := b.xf
			b.xf = saved * Transform3D(Basis.looking_at(d, Vector3.RIGHT), (p + prev) * 0.5)
			b.box(Vector3(-0.012, -w, -d.length() * 0.55), Vector3(0.012, w, d.length() * 0.55), col)
			b.xf = saved
		prev = p


## «ИЖ Юпитер-5» как на плакате «Общий вид мотоцикла»: скруглённый
## красный бак с чёрной эмблемой «ИЖ», красные инструментальные ящики
## «Юпитер 5», двухцилиндровый мотор с рёбрами наклоном вперёд и круглыми
## крышками, изогнутые трубы к двум глушителям, дуги безопасности,
## наклонная вилка в кожухах, круглая фара и щиток приборов, высокий руль
## с зеркалом, рифлёное седло с ремнём, щитки по дуге колёс, поворотники,
## пружины задней подвески, подставка и кикстартер. Надписи — Label3D
## по мете "labels".
static func izh(b: MeshBuilder, paint: Color) -> void:
	var frame := Color(0.17, 0.15, 0.14)
	var chrome := Color(0.68, 0.7, 0.73)
	var alloy := Color(0.63, 0.64, 0.65)
	var seat := Color(0.22, 0.17, 0.13)
	var amber := Color(1.0, 0.62, 0.15)
	var cover := Color(0.42, 0.35, 0.29)
	var front := Vector3(0, 0.32, -0.76)
	var rear := Vector3(0, 0.32, 0.64)
	var head := Vector3(0, 1.02, -0.5)
	# Рама: рулевая колонка, хребет под баком, двойная люлька под мотором,
	# задняя часть под седлом, маятник к заднему колесу
	tube(b, head + Vector3(0, -0.14, 0.04), head + Vector3(0, 0.06, -0.01), 0.04, frame)
	pipe(b, [head, Vector3(0, 0.9, 0.2), Vector3(0, 0.84, 0.8)], 0.025, frame)
	for sx in [-1.0, 1.0]:
		var x: float = 0.06 * sx
		pipe(b, [head + Vector3(x, -0.1, 0.02), Vector3(x, 0.6, -0.42), Vector3(x, 0.3, -0.32), Vector3(x, 0.28, 0.2), Vector3(x, 0.55, 0.3), Vector3(x, 0.86, 0.22)], 0.018, frame)
		tube(b, Vector3(0.13 * sx, 0.84, 0.2), Vector3(0.13 * sx, 0.84, 0.86), 0.016, frame)
		tube(b, Vector3(0.12 * sx, 0.38, 0.2), rear + Vector3(0.11 * sx, 0, 0), 0.022, frame)
	# Мотор: картер с круглыми крышками, коробка передач, два цилиндра
	disc(b, Vector3(0, 0.42, -0.04), Vector3.RIGHT, 0.17, 0.36, alloy)
	b.box(Vector3(-0.15, 0.3, 0.0), Vector3(0.15, 0.5, 0.22), alloy.darkened(0.08))
	for sx in [-1.0, 1.0]:
		disc(b, Vector3(0.2 * sx, 0.42, -0.04), Vector3.RIGHT, 0.13, 0.05, alloy.lightened(0.15))
		disc(b, Vector3(0.21 * sx, 0.42, -0.04), Vector3.RIGHT, 0.05, 0.04, alloy.darkened(0.2))
	var lean := Basis(Vector3.RIGHT, 0.32)
	for cx in [-0.09, 0.09]:
		var saved := b.xf
		b.xf = saved * Transform3D(lean, Vector3(cx, 0.52, -0.2))
		for i in 7:
			var y := i * 0.033
			var w := 0.085 if i % 2 == 0 else 0.1
			b.box(Vector3(-w * 0.85, y, -w), Vector3(w * 0.85, y + 0.022, w), alloy.lightened(0.18))
		b.box(Vector3(-0.055, 0.0, -0.06), Vector3(0.055, 0.24, 0.06), alloy.darkened(0.25))
		b.box(Vector3(-0.08, 0.24, -0.09), Vector3(0.08, 0.3, 0.09), alloy.lightened(0.05))
		b.xf = saved
		# Карбюратор позади цилиндра
		b.box(Vector3(cx - 0.04, 0.56, 0.0), Vector3(cx + 0.04, 0.64, 0.1), alloy.darkened(0.1))
	# Выхлоп: от каждого цилиндра вперёд-вниз, по бокам назад к глушителям
	for sx in [-1.0, 1.0]:
		var x: float = sx
		pipe(b, [Vector3(0.1 * x, 0.66, -0.36), Vector3(0.17 * x, 0.6, -0.5), Vector3(0.22 * x, 0.42, -0.52),
			Vector3(0.24 * x, 0.29, -0.4), Vector3(0.25 * x, 0.27, 0.1)], 0.03, chrome)
		tube(b, Vector3(0.25 * x, 0.28, 0.05), Vector3(0.25 * x, 0.37, 0.96), 0.055, chrome)
		disc(b, Vector3(0.25 * x, 0.375, 0.97), Vector3.BACK, 0.05, 0.03, chrome.darkened(0.2))
		disc(b, Vector3(0.25 * x, 0.378, 0.985), Vector3.BACK, 0.02, 0.02, Color(0.05, 0.05, 0.05))
		# Дуги безопасности
		pipe(b, [Vector3(0.06 * x, 0.86, -0.46), Vector3(0.3 * x, 0.68, -0.5), Vector3(0.31 * x, 0.42, -0.5), Vector3(0.08 * x, 0.3, -0.38)], 0.018, chrome)
		# Красный инструментальный ящик с эмблемой
		var xb: float = 0.17 if x > 0.0 else -0.24
		b.box(Vector3(xb, 0.52, 0.06), Vector3(xb + 0.07, 0.76, 0.36), paint)
		b.box(Vector3(xb + 0.005, 0.5, 0.08), Vector3(xb + 0.065, 0.52, 0.34), paint.darkened(0.2))
		b.box(Vector3(xb + 0.005, 0.76, 0.08), Vector3(xb + 0.065, 0.78, 0.34), paint.darkened(0.1))
		var xe: float = 0.241 * x
		b.box(Vector3(minf(xe, xe + 0.004 * x), 0.6, 0.1), Vector3(maxf(xe, xe + 0.004 * x), 0.67, 0.32), Color(0.08, 0.08, 0.08))
		# Задняя подвеска: шток и пружина
		var s0 := Vector3(0.16 * x, 0.36, 0.6)
		var s1 := Vector3(0.15 * x, 0.86, 0.46)
		tube(b, s0, s1, 0.018, chrome)
		for k in 8:
			var sp := s0.lerp(s1, 0.18 + k * 0.08)
			b.box(sp - Vector3(0.035, 0.007, 0.035), sp + Vector3(0.035, 0.007, 0.035), chrome.lightened(0.12))
		# Подножки
		tube(b, Vector3(0.12 * x, 0.32, 0.0), Vector3(0.26 * x, 0.32, 0.0), 0.016, frame)
	# Бак: скруглённый — слои от узкого низа к широкой середине и покатому верху
	var layers := [[0.8, 0.12, -0.44, -0.02], [0.84, 0.16, -0.5, 0.01], [0.89, 0.175, -0.52, 0.02],
		[0.94, 0.17, -0.52, 0.02], [0.98, 0.155, -0.5, 0.0], [1.01, 0.13, -0.46, -0.03], [1.035, 0.09, -0.4, -0.07]]
	for i in layers.size() - 1:
		var L: Array = layers[i]
		var N: Array = layers[i + 1]
		b.box(Vector3(-float(L[1]), float(L[0]), float(L[2])), Vector3(float(L[1]), float(N[0]), float(L[3])), paint)
	disc(b, Vector3(0, 1.05, -0.3), Vector3.UP, 0.05, 0.04, chrome)
	disc(b, Vector3(0, 1.07, -0.3), Vector3.UP, 0.025, 0.02, paint.darkened(0.3))
	for sx in [-1.0, 1.0]:
		var xt: float = 0.176 * sx
		b.box(Vector3(minf(xt, xt + 0.005 * sx), 0.87, -0.44), Vector3(maxf(xt, xt + 0.005 * sx), 0.95, -0.07), Color(0.06, 0.06, 0.06))
		b.box(Vector3(minf(xt, xt + 0.008 * sx), 0.9, -0.21), Vector3(maxf(xt, xt + 0.008 * sx), 0.915, -0.09), Color(0.95, 0.95, 0.95))
		# Наколенники — резиновые накладки по бокам бака
		b.box(Vector3(minf(0.165 * sx, 0.172 * sx), 0.86, -0.04), Vector3(maxf(0.165 * sx, 0.172 * sx), 0.95, 0.02), Color(0.1, 0.1, 0.1))
	# Седло: длинное, рифлёное, с ремнём пассажира
	b.box(Vector3(-0.155, 0.86, 0.0), Vector3(0.155, 0.95, 0.8), seat)
	b.box(Vector3(-0.135, 0.95, 0.02), Vector3(0.135, 0.985, 0.78), seat.lightened(0.05))
	var z := 0.06
	while z < 0.76:
		b.box(Vector3(-0.136, 0.985, z), Vector3(0.136, 0.988, z + 0.012), seat.darkened(0.35))
		z += 0.07
	b.box(Vector3(-0.16, 0.86, 0.42), Vector3(0.16, 0.99, 0.45), seat.darkened(0.45))
	# Щитки по дуге колёс: передний короткий, задний длинный, с брызговиком
	fender(b, front, 0.38, -0.7, 1.25, 0.075, chrome)
	fender(b, rear, 0.39, -2.2, 0.35, 0.085, chrome)
	b.box(Vector3(-0.07, 0.2, 0.96), Vector3(0.07, 0.36, 0.98), Color(0.08, 0.08, 0.08))
	# Задний фонарь на кронштейне, поворотники, номер
	b.box(Vector3(-0.09, 0.81, 0.9), Vector3(0.09, 0.93, 1.0), Color(0.5, 0.08, 0.06))
	b.box(Vector3(-0.1, 0.8, 0.88), Vector3(0.1, 0.82, 0.98), chrome)
	for sx in [-1.0, 1.0]:
		tube(b, Vector3(0.05 * sx, 0.78, 0.86), Vector3(0.16 * sx, 0.78, 0.88), 0.01, frame)
		disc(b, Vector3(0.19 * sx, 0.78, 0.88), Vector3.BACK, 0.035, 0.08, amber)
	plate(b, Vector3(-0.1, 0.56, 1.01), Vector3(0.1, 0.7, 1.03))
	# Вилка с наклоном: сверху в кожухах, снизу хромированные перья
	for sx in [-1.0, 1.0]:
		var top := head + Vector3(0.085 * sx, 0.05, 0.0)
		var axle := front + Vector3(0.085 * sx, 0, 0)
		var mid := top.lerp(axle, 0.5)
		tube(b, top, mid, 0.032, cover)
		tube(b, mid, axle, 0.022, chrome)
	disc(b, front, Vector3.RIGHT, 0.12, 0.16, alloy.lightened(0.1))
	# Фара: круглый корпус, ободок, стекло; над ней щиток приборов
	var hp := head + Vector3(0, -0.04, -0.24)
	disc(b, hp + Vector3(0, 0, 0.05), Vector3.FORWARD, 0.125, 0.16, chrome.darkened(0.15))
	disc(b, hp + Vector3(0, 0, -0.035), Vector3.FORWARD, 0.13, 0.02, chrome)
	disc(b, hp + Vector3(0, 0, -0.048), Vector3.FORWARD, 0.105, 0.01, Color(0.78, 0.92, 0.96))
	for sx in [-1.0, 1.0]:
		tube(b, hp + Vector3(0.13 * sx, 0, 0.05), head + Vector3(0.085 * sx, -0.1, 0.0), 0.012, frame)
	b.box(head + Vector3(-0.14, 0.08, -0.2), head + Vector3(0.14, 0.15, -0.03), frame)
	# Передние поворотники на стойках у фары
	for sx in [-1.0, 1.0]:
		tube(b, hp + Vector3(0.1 * sx, -0.06, 0.06), hp + Vector3(0.22 * sx, -0.06, 0.06), 0.01, frame)
		disc(b, hp + Vector3(0.25 * sx, -0.06, 0.04), Vector3.FORWARD, 0.035, 0.08, amber)
	# Высокий руль, рукоятки, рычаги, зеркало
	var hb := head + Vector3(0, 0.17, -0.02)
	for sx in [-1.0, 1.0]:
		pipe(b, [hb, hb + Vector3(0.18 * sx, 0.08, 0.02), hb + Vector3(0.32 * sx, 0.12, 0.1), hb + Vector3(0.36 * sx, 0.12, 0.13)], 0.012, chrome)
		tube(b, hb + Vector3(0.36 * sx, 0.12, 0.13), hb + Vector3(0.46 * sx, 0.12, 0.17), 0.022, Color(0.05, 0.05, 0.05))
		tube(b, hb + Vector3(0.3 * sx, 0.13, 0.1), hb + Vector3(0.42 * sx, 0.12, 0.06), 0.008, chrome)
	tube(b, hb + Vector3(0.3, 0.12, 0.09), hb + Vector3(0.36, 0.36, 0.05), 0.008, chrome)
	b.box(hb + Vector3(0.3, 0.34, 0.03), hb + Vector3(0.44, 0.46, 0.05), Color(0.55, 0.6, 0.62))
	# Центральная подставка (сложена), кикстартер и педаль передач
	tube(b, Vector3(-0.1, 0.27, 0.12), Vector3(0.1, 0.27, 0.12), 0.016, frame)
	for sx in [-1.0, 1.0]:
		tube(b, Vector3(0.1 * sx, 0.27, 0.12), Vector3(0.1 * sx, 0.22, 0.38), 0.014, frame)
	pipe(b, [Vector3(0.24, 0.45, 0.12), Vector3(0.27, 0.36, 0.22), Vector3(0.27, 0.34, 0.32)], 0.013, chrome)
	pipe(b, [Vector3(-0.24, 0.4, -0.02), Vector3(-0.27, 0.34, -0.14)], 0.012, chrome)
	b.set_meta("labels", [
		["ИЖ", Vector3(0.182, 0.91, -0.3), PI / 2.0, 0.0022, Color(0.97, 0.97, 0.97)],
		["ИЖ", Vector3(-0.182, 0.91, -0.3), -PI / 2.0, 0.0022, Color(0.97, 0.97, 0.97)],
		["ЮПИТЕР 5", Vector3(0.246, 0.635, 0.21), PI / 2.0, 0.0011, Color(0.97, 0.97, 0.97)],
		["ЮПИТЕР 5", Vector3(-0.246, 0.635, 0.21), -PI / 2.0, 0.0011, Color(0.97, 0.97, 0.97)],
	])


## Колесо мотоцикла: шина-кольцо из восьми сегментов, хромированный обод,
## спицы крест-накрест и ступица с барабаном — сквозь колесо видно.
static func moto_wheel(b: MeshBuilder, r: float, rim: Variant = null) -> void:
	var tyre := Color(0.07, 0.07, 0.08)
	var spoke: Color = rim if rim is Color else Color(0.72, 0.73, 0.76)
	var seg := r * 0.42
	for i in 8:
		var saved := b.xf
		b.xf = saved * Transform3D(Basis(Vector3.RIGHT, i * PI / 4.0), Vector3.ZERO)
		b.box(Vector3(-0.05, r - 0.085, -seg), Vector3(0.05, r, seg), tyre)
		b.box(Vector3(-0.025, r - 0.115, -seg * 0.85), Vector3(0.025, r - 0.08, seg * 0.85), spoke)
		b.box(Vector3(-0.006, 0.0, -0.005), Vector3(0.006, r - 0.1, 0.005), Color(0.82, 0.83, 0.85))
		b.xf = saved
	b.box(Vector3(-0.07, -0.08, -0.08), Vector3(0.07, 0.08, 0.08), Color(0.6, 0.6, 0.62))
	b.box(Vector3(-0.08, -0.03, -0.03), Vector3(0.08, 0.03, 0.03), Color(0.4, 0.4, 0.42))


## Салон: торпедо с приборами, руль перед водителем (слева), сиденья.
## dz — где торпедо по Z, y — уровень пола, hx — полуширина салона.
static func _cabin(b: MeshBuilder, dz: float, y: float, hx: float, seat_z: float, rear: bool) -> void:
	var panel := Color(0.24, 0.21, 0.19)
	var seat := Color(0.3, 0.22, 0.17)
	var rim := Color(0.12, 0.12, 0.12)
	b.box(Vector3(-hx, y + 0.3, dz), Vector3(hx, y + 0.42, dz + 0.26), panel)
	b.box(Vector3(-hx * 0.7, y + 0.4, dz + 0.18), Vector3(-hx * 0.3, y + 0.48, dz + 0.26), Color(0.1, 0.1, 0.1))
	var wx := -hx * 0.5
	for p in [[-0.16, 0.36, 0.16, 0.39], [-0.16, 0.57, 0.16, 0.6], [-0.16, 0.36, -0.13, 0.6], [0.13, 0.36, 0.16, 0.6]]:
		b.box(Vector3(wx + p[0], y + p[1], dz + 0.38), Vector3(wx + p[2], y + p[3], dz + 0.4), rim)
	b.box(Vector3(wx - 0.01, y + 0.36, dz + 0.26), Vector3(wx + 0.01, y + 0.45, dz + 0.39), rim)
	for sx in [-hx * 0.5, hx * 0.5]:
		b.box(Vector3(sx - 0.25, y, seat_z), Vector3(sx + 0.25, y + 0.12, seat_z + 0.45), seat)
		b.box(Vector3(sx - 0.25, y + 0.12, seat_z + 0.4), Vector3(sx + 0.25, y + 0.62, seat_z + 0.5), seat)
	if rear:
		b.box(Vector3(-hx + 0.05, y, seat_z + 0.65), Vector3(hx - 0.05, y + 0.12, seat_z + 0.95), seat)
		b.box(Vector3(-hx + 0.05, y + 0.12, seat_z + 0.9), Vector3(hx - 0.05, y + 0.52, seat_z + 1.0), seat)


## «Нива»: короткая, высокая, трёхдверная; пластиковые расширители арок,
## багажник на крыше, круглые фары в квадратной решётке.
static func niva(b: MeshBuilder, paint: Color, glass_b: MeshBuilder = null) -> void:
	var gb := glass_b if glass_b else b
	var dark := Color(0.08, 0.08, 0.09)
	var glass := Color(0.35, 0.45, 0.5)
	var chrome := Color(0.7, 0.7, 0.72)
	b.box(Vector3(-0.84, 0.4, -1.87), Vector3(0.84, 1.0, 1.87), paint)
	b.box(Vector3(-0.8, 1.0, -1.87), Vector3(0.8, 1.06, -0.75), paint)
	b.box(Vector3(-0.86, 0.36, -1.9), Vector3(0.86, 0.5, 1.9), dark)
	for z in [-1.1, 1.1]:
		for x in [-0.88, 0.8]:
			b.box(Vector3(x, 0.5, z - 0.46), Vector3(x + 0.08, 0.8, z + 0.46), dark)
	# Стойки и крыша, сзади — вертикальная пятая дверь
	for x in [-0.8, 0.74]:
		b.box(Vector3(x, 1.0, -0.76), Vector3(x + 0.06, 1.62, -0.66), paint)
		b.box(Vector3(x, 1.0, 0.3), Vector3(x + 0.06, 1.62, 0.4), paint)
		b.box(Vector3(x, 1.0, 1.72), Vector3(x + 0.06, 1.62, 1.87), paint)
		gb.box(Vector3(x + 0.02, 1.06, -0.66), Vector3(x + 0.04, 1.56, 0.3), glass)
		gb.box(Vector3(x + 0.02, 1.06, 0.4), Vector3(x + 0.04, 1.56, 1.72), glass)
	b.box(Vector3(-0.82, 1.62, -0.78), Vector3(0.82, 1.68, 1.87), paint)
	gb.box(Vector3(-0.74, 1.06, -0.76), Vector3(0.74, 1.6, -0.72), glass)
	gb.box(Vector3(-0.7, 1.08, 1.84), Vector3(0.7, 1.56, 1.88), glass)
	# Багажник на крыше
	for x in [-0.72, 0.66]:
		b.box(Vector3(x, 1.68, -0.6), Vector3(x + 0.06, 1.76, 1.7), dark)
	for z in [-0.5, 0.3, 1.1]:
		b.box(Vector3(-0.72, 1.76, z), Vector3(0.72, 1.8, z + 0.06), dark)
	# Морда: решётка, круглые фары, бампер
	b.box(Vector3(-0.78, 0.6, -1.89), Vector3(0.78, 0.98, -1.87), dark)
	for x in [-0.66, 0.46]:
		b.box(Vector3(x, 0.68, -1.91), Vector3(x + 0.2, 0.88, -1.88), Color(1.0, 0.97, 0.86))
	b.box(Vector3(-0.2, 0.7, -1.9), Vector3(0.2, 0.86, -1.88), chrome)
	for z in [-1.98, 1.87]:
		b.box(Vector3(-0.88, 0.36, z), Vector3(0.88, 0.5, z + 0.11), dark)
	plate(b, Vector3(-0.26, 0.42, -2.0), Vector3(0.26, 0.52, -1.99))
	plate(b, Vector3(-0.26, 0.55, 1.88), Vector3(0.26, 0.65, 1.89))
	for x in [-0.82, 0.68]:
		b.box(Vector3(x, 0.8, 1.87), Vector3(x + 0.14, 0.95, 1.89), Color(0.9, 0.2, 0.15))
	b.box(Vector3(-0.72, 1.58, -0.7), Vector3(0.72, 1.6, 1.8), Color(0.8, 0.78, 0.72))
	_cabin(b, -0.66, 0.62, 0.72, 0.05, true)


## «Волга» ГАЗ-24: длинный седан, много хрома, решётка с вертикальными
## прутьями, олень на капоте.
static func volga(b: MeshBuilder, paint: Color, glass_b: MeshBuilder = null) -> void:
	var gb := glass_b if glass_b else b
	var dark := Color(0.07, 0.07, 0.08)
	var glass := Color(0.35, 0.45, 0.5)
	var chrome := Color(0.82, 0.82, 0.84)
	b.box(Vector3(-0.9, 0.34, -2.36), Vector3(0.9, 0.82, 2.36), paint)
	b.box(Vector3(-0.86, 0.82, -2.36), Vector3(0.86, 0.9, -0.88), paint)
	b.box(Vector3(-0.86, 0.82, 1.25), Vector3(0.86, 0.9, 2.36), paint)
	for x in [-0.905, 0.895]:
		b.box(Vector3(x, 0.62, -2.3), Vector3(x + 0.01, 0.65, 2.3), chrome)
	for z in [-1.4, 1.4]:
		for x in [-0.91, 0.87]:
			b.box(Vector3(x, 0.32, z - 0.44), Vector3(x + 0.04, 0.62, z + 0.44), dark)
	for x in [-0.8, 0.74]:
		b.box(Vector3(x, 0.9, -0.88), Vector3(x + 0.06, 1.4, -0.76), paint)
		b.box(Vector3(x, 0.9, 0.2), Vector3(x + 0.06, 1.4, 0.3), paint)
		b.box(Vector3(x, 0.9, 1.12), Vector3(x + 0.06, 1.4, 1.25), paint)
		gb.box(Vector3(x + 0.02, 0.92, -0.76), Vector3(x + 0.04, 1.36, 0.2), glass)
		gb.box(Vector3(x + 0.02, 0.92, 0.3), Vector3(x + 0.04, 1.36, 1.12), glass)
	b.box(Vector3(-0.82, 1.4, -0.88), Vector3(0.82, 1.47, 1.25), paint)
	gb.box(Vector3(-0.74, 0.92, -0.9), Vector3(0.74, 1.38, -0.86), glass)
	gb.box(Vector3(-0.74, 0.92, 1.23), Vector3(0.74, 1.38, 1.27), glass)
	# Решётка с прутьями, фары, бамперы, олень
	b.box(Vector3(-0.72, 0.5, -2.38), Vector3(0.72, 0.78, -2.36), dark)
	for i in 13:
		var x := -0.68 + i * 0.113
		b.box(Vector3(x, 0.5, -2.39), Vector3(x + 0.03, 0.78, -2.37), chrome)
	for x in [-0.86, 0.62]:
		b.box(Vector3(x, 0.54, -2.39), Vector3(x + 0.24, 0.76, -2.36), Color(1.0, 0.97, 0.86))
	for z in [-2.48, 2.36]:
		b.box(Vector3(-0.92, 0.3, z), Vector3(0.92, 0.42, z + 0.12), chrome)
		for x in [-0.5, 0.42]:
			b.box(Vector3(x, 0.26, z - 0.02), Vector3(x + 0.08, 0.5, z + 0.14), chrome)
	b.box(Vector3(-0.03, 0.9, -2.28), Vector3(0.03, 1.02, -2.08), chrome)
	plate(b, Vector3(-0.26, 0.4, -2.5), Vector3(0.26, 0.5, -2.49))
	plate(b, Vector3(-0.26, 0.5, 2.37), Vector3(0.26, 0.6, 2.38))
	for x in [-0.88, 0.7]:
		b.box(Vector3(x, 0.6, 2.36), Vector3(x + 0.18, 0.76, 2.38), Color(0.9, 0.2, 0.15))
	b.box(Vector3(-0.76, 1.38, -0.84), Vector3(0.76, 1.4, 1.2), Color(0.82, 0.8, 0.74))
	_cabin(b, -0.8, 0.5, 0.76, -0.05, true)


## Грузовик ГАЗ-53: длинный капот, кабина, деревянный кузов с бортами.
static func gaz53(b: MeshBuilder, paint: Color, glass_b: MeshBuilder = null) -> void:
	var gb := glass_b if glass_b else b
	var dark := Color(0.08, 0.08, 0.09)
	var glass := Color(0.35, 0.45, 0.5)
	var wood := Color(0.52, 0.4, 0.26)
	# Рама
	b.box(Vector3(-0.5, 0.6, -3.2), Vector3(0.5, 0.8, 3.2), dark)
	# Капот и крылья
	b.box(Vector3(-0.72, 0.8, -3.25), Vector3(0.72, 1.55, -2.1), paint)
	for x in [-1.18, 0.72]:
		b.box(Vector3(x, 0.95, -3.1), Vector3(x + 0.46, 1.12, -1.95), paint)
	b.box(Vector3(-0.66, 0.85, -3.27), Vector3(0.66, 1.45, -3.25), dark)
	for i in 8:
		b.box(Vector3(-0.62 + i * 0.16, 0.88, -3.28), Vector3(-0.58 + i * 0.16, 1.42, -3.26), Color(0.5, 0.5, 0.5))
	for x in [-1.05, 0.8]:
		b.box(Vector3(x, 1.12, -3.0), Vector3(x + 0.25, 1.32, -2.9), Color(1.0, 0.97, 0.86))
	b.box(Vector3(-1.15, 0.55, -3.4), Vector3(1.15, 0.72, -3.25), dark)
	# Кабина
	b.box(Vector3(-1.1, 0.8, -2.1), Vector3(1.1, 1.5, -0.9), paint)
	b.box(Vector3(-1.1, 2.2, -2.15), Vector3(1.1, 2.3, -0.9), paint)
	b.box(Vector3(-1.1, 1.5, -0.95), Vector3(1.1, 2.2, -0.9), paint)
	for x in [-1.1, 1.04]:
		b.box(Vector3(x, 1.5, -2.15), Vector3(x + 0.06, 2.2, -2.05), paint)
		gb.box(Vector3(x + 0.02, 1.52, -2.05), Vector3(x + 0.04, 2.15, -1.1), glass)
		b.box(Vector3(x, 1.5, -1.1), Vector3(x + 0.06, 2.2, -0.95), paint)
	gb.box(Vector3(-1.02, 1.55, -2.17), Vector3(1.02, 2.15, -2.13), glass)
	b.box(Vector3(-1.1, 1.52, -2.18), Vector3(1.1, 1.55, -2.1), paint)
	# Кузов: пол и борта
	b.box(Vector3(-1.15, 1.0, -0.8), Vector3(1.15, 1.1, 3.2), wood)
	for x in [-1.15, 1.09]:
		b.box(Vector3(x, 1.1, -0.8), Vector3(x + 0.06, 1.7, 3.2), wood)
	b.box(Vector3(-1.15, 1.1, -0.8), Vector3(1.15, 1.7, -0.74), wood)
	b.box(Vector3(-1.15, 1.1, 3.14), Vector3(1.15, 1.7, 3.2), wood)
	for z in [0.4, 1.6, 2.8]:
		for x in [-1.17, 1.1]:
			b.box(Vector3(x, 1.1, z), Vector3(x + 0.07, 1.72, z + 0.08), wood.darkened(0.3))
	plate(b, Vector3(-0.26, 1.2, 3.21), Vector3(0.26, 1.34, 3.22))
	for x in [-1.05, 0.9]:
		b.box(Vector3(x, 0.85, 3.18), Vector3(x + 0.15, 0.95, 3.22), Color(0.9, 0.2, 0.15))
	b.box(Vector3(-1.05, 2.15, -2.1), Vector3(1.05, 2.18, -0.95), Color(0.3, 0.32, 0.3))
	_cabin(b, -2.05, 1.12, 0.95, -1.6, false)


## Трактор МТЗ-80 «Беларус»: длинный узкий капот, кабина над задним мостом,
## огромные задние колёса под крыльями, выхлопная труба, грузы спереди.
static func tractor(b: MeshBuilder, paint: Color, glass_b: MeshBuilder = null) -> void:
	var gb := glass_b if glass_b else b
	var dark := Color(0.1, 0.1, 0.11)
	var glass := Color(0.35, 0.45, 0.5)
	var white := Color(0.9, 0.9, 0.88)
	# Рама и мосты
	b.box(Vector3(-0.35, 0.45, -2.0), Vector3(0.35, 0.75, 1.1), dark)
	b.box(Vector3(-0.75, 0.62, 0.8), Vector3(0.75, 0.82, 1.0), dark)
	b.box(Vector3(-0.7, 0.38, -1.5), Vector3(0.7, 0.48, -1.3), dark)
	# Капот с решёткой и фарами
	b.box(Vector3(-0.42, 0.75, -2.05), Vector3(0.42, 1.45, -0.2), paint)
	b.box(Vector3(-0.38, 0.8, -2.07), Vector3(0.38, 1.4, -2.05), dark)
	for i in 6:
		b.box(Vector3(-0.34, 0.86 + i * 0.09, -2.08), Vector3(0.34, 0.9 + i * 0.09, -2.06), Color(0.5, 0.5, 0.52))
	for x in [-0.36, 0.22]:
		b.box(Vector3(x, 1.25, -2.12), Vector3(x + 0.14, 1.38, -2.06), Color(1.0, 0.97, 0.86))
	# Грузы спереди
	for i in 5:
		b.box(Vector3(-0.5 + i * 0.2, 0.45, -2.35), Vector3(-0.32 + i * 0.2, 0.8, -2.07), Color(0.25, 0.27, 0.3))
	# Выхлопная труба
	b.box(Vector3(0.22, 1.45, -1.3), Vector3(0.3, 2.45, -1.22), dark)
	# Кабина
	var cy := 1.3
	b.box(Vector3(-0.72, cy - 0.1, -0.35), Vector3(0.72, cy, 1.25), dark)
	b.box(Vector3(-0.75, cy + 1.3, -0.4), Vector3(0.75, cy + 1.42, 1.3), white)
	for x in [-0.75, 0.69]:
		for z in [-0.4, 1.19]:
			b.box(Vector3(x, cy, z), Vector3(x + 0.06, cy + 1.3, z + 0.11), paint)
	b.box(Vector3(-0.75, cy, 1.19), Vector3(0.75, cy + 0.5, 1.3), paint)
	gb.box(Vector3(-0.69, cy + 0.1, -0.4), Vector3(0.69, cy + 1.28, -0.37), glass)
	gb.box(Vector3(-0.69, cy + 0.5, 1.22), Vector3(0.69, cy + 1.28, 1.25), glass)
	for x in [-0.74, 0.71]:
		gb.box(Vector3(x, cy + 0.2, -0.29), Vector3(x + 0.03, cy + 1.28, 1.19), glass)
	# Крылья над задними колёсами
	for x in [-1.12, 0.72]:
		b.box(Vector3(x, 1.5, 0.15), Vector3(x + 0.4, 1.56, 1.65), paint)
		b.box(Vector3(x, 1.1, 1.6), Vector3(x + 0.4, 1.56, 1.66), paint)
	# Щиток с приборами, руль на колонке, сиденье
	b.box(Vector3(-0.45, cy, -0.35), Vector3(0.45, cy + 0.55, -0.15), Color(0.2, 0.2, 0.22))
	b.box(Vector3(-0.04, cy + 0.3, -0.15), Vector3(0.04, cy + 0.72, 0.1), dark)
	for p in [[-0.2, 0.7, 0.2, 0.73], [-0.2, 0.9, 0.2, 0.93], [-0.2, 0.7, -0.17, 0.93], [0.17, 0.7, 0.2, 0.93]]:
		b.box(Vector3(p[0], cy + p[1], 0.08), Vector3(p[2], cy + p[3], 0.12), dark)
	b.box(Vector3(-0.28, cy + 0.25, 0.55), Vector3(0.28, cy + 0.38, 0.95), Color(0.3, 0.22, 0.17))
	b.box(Vector3(-0.28, cy + 0.38, 0.9), Vector3(0.28, cy + 0.9, 1.0), Color(0.3, 0.22, 0.17))
	# Навеска для плуга сзади
	b.box(Vector3(-0.5, 0.7, 1.1), Vector3(0.5, 0.8, 1.6), dark)
	for x in [-0.45, 0.35]:
		b.box(Vector3(x, 0.5, 1.5), Vector3(x + 0.1, 0.9, 1.6), dark)


# --- Попутки: новые модели и сборка с колёсами ---------------------------------

## «Москвич-412»: угловатый седан, узкие вертикальные фонари, решётка во
## всю морду с прямоугольными фарами.
static func moskvich(b: MeshBuilder, paint: Color) -> void:
	var dark := Color(0.07, 0.07, 0.08)
	var chrome := Color(0.78, 0.78, 0.8)
	var glass := Color(0.3, 0.4, 0.46)
	b.box(Vector3(-0.78, 0.32, -2.05), Vector3(0.78, 0.82, 2.05), paint)
	b.box(Vector3(-0.72, 0.82, -0.75), Vector3(0.72, 1.36, 1.0), paint)
	b.box(Vector3(-0.66, 0.84, -0.8), Vector3(0.66, 1.3, -0.76), glass)
	b.box(Vector3(-0.66, 0.86, 1.0), Vector3(0.66, 1.28, 1.04), glass)
	for x in [-0.73, 0.71]:
		b.box(Vector3(x, 0.9, -0.66), Vector3(x + 0.02, 1.28, 0.1), glass)
		b.box(Vector3(x, 0.9, 0.18), Vector3(x + 0.02, 1.28, 0.9), glass)
		b.box(Vector3(x - 0.02 * signf(x), 0.55, -1.95), Vector3(x + 0.04, 0.58, 1.95), chrome)
	b.box(Vector3(-0.74, 0.5, -2.07), Vector3(0.74, 0.76, -2.05), dark)
	for x in [-0.7, 0.42]:
		b.box(Vector3(x, 0.56, -2.09), Vector3(x + 0.28, 0.7, -2.06), Color(1.0, 0.97, 0.86))
	for x in [-0.76, 0.66]:
		b.box(Vector3(x, 0.5, 2.05), Vector3(x + 0.1, 0.8, 2.07), Color(0.9, 0.2, 0.15))
	for z in [-2.15, 2.05]:
		b.box(Vector3(-0.8, 0.36, z), Vector3(0.8, 0.46, z + 0.1), chrome)
	plate(b, Vector3(-0.22, 0.4, 2.15), Vector3(0.22, 0.5, 2.16))


## ЗАЗ-968 «Запорожец»: маленький, мотор сзади — по бокам «уши»
## воздухозаборников, впереди багажник без решётки.
static func zaporozhets(b: MeshBuilder, paint: Color) -> void:
	var dark := Color(0.07, 0.07, 0.08)
	var chrome := Color(0.78, 0.78, 0.8)
	var glass := Color(0.3, 0.4, 0.46)
	b.box(Vector3(-0.74, 0.3, -1.85), Vector3(0.74, 0.8, 1.85), paint)
	b.box(Vector3(-0.68, 0.8, -0.55), Vector3(0.68, 1.36, 0.95), paint)
	b.box(Vector3(-0.6, 0.84, -0.6), Vector3(0.6, 1.3, -0.56), glass)
	b.box(Vector3(-0.6, 0.86, 0.95), Vector3(0.6, 1.28, 0.99), glass)
	for x in [-0.69, 0.67]:
		b.box(Vector3(x, 0.88, -0.48), Vector3(x + 0.02, 1.28, 0.85), glass)
	# «Уши» над задними колёсами
	for x in [-0.86, 0.74]:
		b.box(Vector3(x, 0.62, 0.9), Vector3(x + 0.12, 0.98, 1.5), paint.darkened(0.1))
		b.box(Vector3(x + (0.0 if x < 0.0 else 0.11), 0.68, 0.95), Vector3(x + (0.01 if x < 0.0 else 0.12), 0.92, 1.45), dark)
	for x in [-0.62, 0.4]:
		b.box(Vector3(x, 0.55, -1.87), Vector3(x + 0.22, 0.72, -1.85), Color(1.0, 0.97, 0.86))
	b.box(Vector3(-0.1, 0.6, -1.87), Vector3(0.1, 0.72, -1.86), chrome)
	for x in [-0.66, 0.5]:
		b.box(Vector3(x, 0.55, 1.85), Vector3(x + 0.16, 0.7, 1.87), Color(0.9, 0.2, 0.15))
	b.box(Vector3(-0.5, 0.45, 1.85), Vector3(0.5, 0.52, 1.88), dark)
	for z in [-1.95, 1.85]:
		b.box(Vector3(-0.76, 0.32, z), Vector3(0.76, 0.42, z + 0.1), chrome)


## УАЗ-452 «буханка»: высокий фургон с плоским лбом, круглые фары,
## окна по бокам, запаска на задней двери.
static func uaz(b: MeshBuilder, paint: Color) -> void:
	var dark := Color(0.07, 0.07, 0.08)
	var glass := Color(0.3, 0.4, 0.46)
	var white := Color(0.9, 0.9, 0.86)
	b.box(Vector3(-0.95, 0.45, -2.2), Vector3(0.95, 2.1, 2.2), paint)
	b.box(Vector3(-0.9, 2.1, -2.1), Vector3(0.9, 2.18, 2.1), paint.lightened(0.08))
	b.box(Vector3(-0.96, 0.45, -2.2), Vector3(0.96, 0.9, 2.2), white if paint.v < 0.6 else paint.darkened(0.2))
	b.box(Vector3(-0.85, 1.3, -2.22), Vector3(0.85, 1.95, -2.2), glass)
	b.box(Vector3(-0.04, 1.3, -2.23), Vector3(0.04, 1.95, -2.21), paint)
	for x in [-0.96, 0.94]:
		var z := -1.9
		while z < 1.8:
			b.box(Vector3(x, 1.35, z), Vector3(x + 0.02, 1.85, z + 0.7), glass)
			z += 0.95
	for x in [-0.75, 0.55]:
		b.box(Vector3(x, 0.85, -2.23), Vector3(x + 0.2, 1.05, -2.2), Color(1.0, 0.97, 0.86))
	b.box(Vector3(-0.3, 0.6, -2.22), Vector3(0.3, 1.0, -2.2), dark)
	b.box(Vector3(-0.95, 0.4, -2.35), Vector3(0.95, 0.55, -2.2), dark)
	b.box(Vector3(-0.35, 0.9, 2.2), Vector3(0.35, 1.6, 2.35), dark)
	for x in [-0.9, 0.78]:
		b.box(Vector3(x, 0.8, 2.2), Vector3(x + 0.12, 1.0, 2.22), Color(0.9, 0.2, 0.15))


## КамАЗ-5320 с тентом: кабина над мотором, высокий кузов под брезентом,
## три оси.
static func kamaz(b: MeshBuilder, paint: Color) -> void:
	var dark := Color(0.08, 0.08, 0.09)
	var glass := Color(0.3, 0.4, 0.46)
	var tent := Color(0.4, 0.45, 0.35)
	b.box(Vector3(-0.55, 0.65, -3.8), Vector3(0.55, 0.9, 4.0), dark)
	# Кабина
	b.box(Vector3(-1.25, 0.9, -4.0), Vector3(1.25, 2.9, -2.3), paint)
	b.box(Vector3(-1.1, 1.9, -4.02), Vector3(1.1, 2.7, -4.0), glass)
	for x in [-1.26, 1.24]:
		b.box(Vector3(x, 1.9, -3.9), Vector3(x + 0.02, 2.6, -3.0), glass)
	b.box(Vector3(-1.1, 1.0, -4.03), Vector3(1.1, 1.5, -4.0), dark)
	for x in [-1.1, 0.8]:
		b.box(Vector3(x, 1.05, -4.05), Vector3(x + 0.3, 1.25, -4.02), Color(1.0, 0.97, 0.86))
	b.box(Vector3(-1.25, 0.7, -4.15), Vector3(1.25, 0.95, -4.0), Color(0.5, 0.5, 0.52))
	b.box(Vector3(-1.2, 2.9, -3.8), Vector3(1.2, 3.3, -2.5), paint.lightened(0.1))
	# Кузов с тентом
	b.box(Vector3(-1.25, 1.2, -2.1), Vector3(1.25, 1.3, 4.1), Color(0.45, 0.35, 0.25))
	b.box(Vector3(-1.25, 1.3, -2.1), Vector3(1.25, 3.3, 4.1), tent)
	for z in [-1.0, 0.5, 2.0, 3.5]:
		for x in [-1.27, 1.25]:
			b.box(Vector3(x, 1.3, z), Vector3(x + 0.02, 3.3, z + 0.06), tent.darkened(0.25))
	for x in [-1.1, 0.9]:
		b.box(Vector3(x, 0.9, 4.1), Vector3(x + 0.2, 1.05, 4.12), Color(0.9, 0.2, 0.15))


## Размер коробки столкновений попутки [ширина, высота, длина].
const NPC_SIZE := {
	"car": Vector3(1.7, 1.4, 4.2), "volga": Vector3(1.8, 1.5, 4.8), "niva": Vector3(1.7, 1.7, 3.8),
	"moskvich": Vector3(1.6, 1.4, 4.2), "zaz": Vector3(1.5, 1.4, 3.8), "uaz": Vector3(1.95, 2.2, 4.5),
	"truck": Vector3(2.3, 2.4, 6.6), "kamaz": Vector3(2.5, 3.3, 8.2), "bus": Vector3(2.5, 3.0, 10.0),
	"tractor": Vector3(1.9, 2.8, 4.2),
}


## Попутка целиком: кузов и колёса (у своей машины колёса крутятся
## отдельно, у попуток — в том же меше).
static func npc(b: MeshBuilder, kind: String, paint: Color) -> void:
	var wheels: Array = []
	var r := 0.3
	var w := 0.2
	match kind:
		"volga":
			volga(b, paint)
			wheels = [Vector3(-0.8, 0.33, -1.42), Vector3(0.8, 0.33, -1.42), Vector3(-0.8, 0.33, 1.42), Vector3(0.8, 0.33, 1.42)]
			r = 0.33
		"niva":
			niva(b, paint)
			wheels = [Vector3(-0.76, 0.33, -1.1), Vector3(0.76, 0.33, -1.1), Vector3(-0.76, 0.33, 1.1), Vector3(0.76, 0.33, 1.1)]
			r = 0.33
		"moskvich":
			moskvich(b, paint)
			wheels = [Vector3(-0.72, 0.3, -1.3), Vector3(0.72, 0.3, -1.3), Vector3(-0.72, 0.3, 1.25), Vector3(0.72, 0.3, 1.25)]
		"zaz":
			zaporozhets(b, paint)
			wheels = [Vector3(-0.68, 0.28, -1.1), Vector3(0.68, 0.28, -1.1), Vector3(-0.68, 0.28, 1.15), Vector3(0.68, 0.28, 1.15)]
			r = 0.28
		"uaz":
			uaz(b, paint)
			wheels = [Vector3(-0.86, 0.38, -1.2), Vector3(0.86, 0.38, -1.2), Vector3(-0.86, 0.38, 1.25), Vector3(0.86, 0.38, 1.25)]
			r = 0.38
			w = 0.24
		"truck":
			gaz53(b, paint)
			wheels = [Vector3(-0.98, 0.46, -2.45), Vector3(0.98, 0.46, -2.45), Vector3(-0.95, 0.46, 1.55), Vector3(0.95, 0.46, 1.55)]
			r = 0.46
			w = 0.3
		"kamaz":
			kamaz(b, paint)
			wheels = [Vector3(-1.05, 0.5, -3.1), Vector3(1.05, 0.5, -3.1), Vector3(-1.05, 0.5, 1.8), Vector3(1.05, 0.5, 1.8),
				Vector3(-1.05, 0.5, 2.9), Vector3(1.05, 0.5, 2.9)]
			r = 0.5
			w = 0.34
		"bus":
			bus(b, paint, NPC_SIZE.bus)
		"tractor":
			tractor(b, paint)
			for p in [[Vector3(-0.92, 0.72, 0.9), 0.72, 0.42], [Vector3(0.92, 0.72, 0.9), 0.72, 0.42],
					[Vector3(-0.78, 0.42, -1.4), 0.42, 0.22], [Vector3(0.78, 0.42, -1.4), 0.42, 0.22]]:
				var saved := b.xf
				b.xf = saved * Transform3D(Basis.IDENTITY, p[0])
				car_wheel(b, p[1], p[2])
				b.xf = saved
		_:
			zhiguli(b, paint, false)
			wheels = [Vector3(-0.78, 0.29, -1.3), Vector3(0.78, 0.29, -1.3), Vector3(-0.78, 0.29, 1.3), Vector3(0.78, 0.29, 1.3)]
			r = 0.29
	for p in wheels:
		var saved := b.xf
		b.xf = saved * Transform3D(Basis.IDENTITY, p)
		car_wheel(b, r, w)
		b.xf = saved


## Мопед «Карпаты»: открытая рама «под юбку», бачок между коленями,
## узкое седло, вилка с круглой фарой, багажник сзади, педали.
static func moped(b: MeshBuilder, paint: Color) -> void:
	var dark := Color(0.08, 0.08, 0.09)
	var chrome := Color(0.8, 0.8, 0.82)
	var engine := Color(0.45, 0.45, 0.47)
	# Рама: рулевая колонка, наклонная труба вниз, хребет назад
	b.box(Vector3(-0.03, 0.55, -0.6), Vector3(0.03, 0.98, -0.52), paint)
	var saved := b.xf
	b.xf = saved * Transform3D(Basis(Vector3.RIGHT, 0.75), Vector3(0, 0.48, -0.36))
	b.box(Vector3(-0.035, -0.04, -0.3), Vector3(0.035, 0.04, 0.3), paint)
	b.xf = saved
	b.box(Vector3(-0.035, 0.3, -0.18), Vector3(0.035, 0.38, 0.62), paint)
	b.box(Vector3(-0.03, 0.38, 0.12), Vector3(0.03, 0.8, 0.18), paint)
	# Бачок и мотор с цилиндром
	b.box(Vector3(-0.12, 0.42, -0.3), Vector3(0.12, 0.6, -0.08), paint.lightened(0.15))
	b.box(Vector3(-0.05, 0.6, -0.24), Vector3(0.05, 0.63, -0.16), chrome)
	b.box(Vector3(-0.14, 0.14, -0.15), Vector3(0.14, 0.34, 0.15), engine)
	for i in 4:
		b.box(Vector3(-0.1, 0.34 + i * 0.025, -0.12), Vector3(0.1, 0.35 + i * 0.025, 0.02), engine.lightened(0.15))
	# Глушитель
	b.box(Vector3(0.12, 0.18, -0.05), Vector3(0.18, 0.24, 0.62), chrome.darkened(0.15))
	# Седло и багажник
	b.box(Vector3(-0.13, 0.8, 0.05), Vector3(0.13, 0.88, 0.45), Color(0.12, 0.1, 0.09))
	b.box(Vector3(-0.12, 0.72, 0.48), Vector3(0.12, 0.75, 0.78), dark)
	for x in [-0.12, 0.1]:
		b.box(Vector3(x, 0.32, 0.6), Vector3(x + 0.02, 0.74, 0.62), dark)
	# Вилка, руль, фара, спидометр
	for x in [-0.07, 0.05]:
		b.box(Vector3(x, 0.28, -0.66), Vector3(x + 0.02, 0.96, -0.62), chrome)
	b.box(Vector3(-0.33, 0.98, -0.6), Vector3(0.33, 1.01, -0.56), chrome)
	for x in [-0.36, 0.27]:
		b.box(Vector3(x, 0.97, -0.61), Vector3(x + 0.09, 1.02, -0.55), dark)
	b.box(Vector3(-0.09, 0.8, -0.74), Vector3(0.09, 0.95, -0.62), chrome)
	b.box(Vector3(-0.07, 0.82, -0.75), Vector3(0.07, 0.93, -0.74), Color(1.0, 0.97, 0.86))
	b.box(Vector3(-0.04, 0.95, -0.66), Vector3(0.04, 1.0, -0.6), dark)
	# Крылья
	b.box(Vector3(-0.07, 0.56, -0.86), Vector3(0.07, 0.6, -0.4), paint)
	b.box(Vector3(-0.07, 0.56, 0.32), Vector3(0.07, 0.6, 0.82), paint)
	plate(b, Vector3(-0.08, 0.42, 0.78), Vector3(0.08, 0.56, 0.8))
	# Педали на шатунах
	for s in [-1.0, 1.0]:
		b.box(Vector3(s * 0.16 - 0.03, 0.2, -0.02), Vector3(s * 0.16 + 0.03, 0.24, 0.12), dark)
		b.box(Vector3(s * 0.2 - 0.05, 0.2, 0.08), Vector3(s * 0.2 + 0.05, 0.23, 0.16), dark)
