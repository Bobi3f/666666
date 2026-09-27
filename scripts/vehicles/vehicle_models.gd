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
static func zhiguli(b: MeshBuilder, paint: Color, interior := true) -> void:
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
		b.box(Vector3(x + 0.02, 0.92, -0.5), Vector3(x + 0.04, 1.38, 0.24), glass)
		b.box(Vector3(x + 0.02, 0.92, 0.32), Vector3(x + 0.04, 1.38, 1.0), glass)
	b.box(Vector3(-0.76, 1.42, -0.64), Vector3(0.76, 1.48, 1.14), paint)
	b.box(Vector3(-0.7, 0.92, -0.64), Vector3(0.7, 1.4, -0.6), glass)
	b.box(Vector3(-0.7, 0.92, 1.12), Vector3(0.7, 1.4, 1.16), glass)
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
	b.box(Vector3(-0.26, 0.42, -2.16), Vector3(0.26, 0.53, -2.15), Color(0.92, 0.92, 0.9))
	b.box(Vector3(-0.26, 0.48, 2.06), Vector3(0.26, 0.6, 2.07), Color(0.92, 0.92, 0.9))
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
static func car_wheel(b: MeshBuilder, r: float, w: float) -> void:
	var tyre := Color(0.07, 0.07, 0.08)
	var disc := Color(0.55, 0.55, 0.57)
	# Шина — восьмигранник из трёх повёрнутых брусков
	for a in [0.0, PI / 4.0, PI / 2.0, 3.0 * PI / 4.0]:
		var saved := b.xf
		b.xf = saved * Transform3D(Basis(Vector3.RIGHT, a), Vector3.ZERO)
		b.box(Vector3(-w * 0.5, -r, -r * 0.42), Vector3(w * 0.5, r, r * 0.42), tyre)
		b.xf = saved
	b.box(Vector3(-w * 0.52, -r * 0.55, -r * 0.55), Vector3(w * 0.52, r * 0.55, r * 0.55), disc)
	b.box(Vector3(-w * 0.56, -r * 0.3, -r * 0.3), Vector3(w * 0.56, r * 0.3, r * 0.3), Color(0.82, 0.82, 0.84))
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
	b.box(Vector3(-0.1, 0.44, 0.9), Vector3(0.1, 0.6, 0.92), Color(0.92, 0.92, 0.9))
	# Два глушителя-«рыбки»
	for x in [0.17, -0.25]:
		b.box(Vector3(x, 0.26, -0.1), Vector3(x + 0.08, 0.34, 0.95), chrome)
		b.box(Vector3(x - 0.01, 0.25, 0.8), Vector3(x + 0.09, 0.35, 0.97), chrome.darkened(0.1))
	# Подножки и педаль тормоза
	for x in [-0.3, 0.22]:
		b.box(Vector3(x, 0.32, -0.05), Vector3(x + 0.08, 0.35, 0.05), dark)
	# Спицы колёс рисует колесо, здесь — щитки цепи
	b.box(Vector3(0.1, 0.3, 0.1), Vector3(0.13, 0.4, 0.6), dark)


## Колесо мотоцикла: шина-восьмигранник, обод, ступица, спицы.
static func moto_wheel(b: MeshBuilder, r: float) -> void:
	var tyre := Color(0.07, 0.07, 0.08)
	for a in [0.0, PI / 4.0, PI / 2.0, 3.0 * PI / 4.0]:
		var saved := b.xf
		b.xf = saved * Transform3D(Basis(Vector3.RIGHT, a), Vector3.ZERO)
		b.box(Vector3(-0.05, -r, -r * 0.42), Vector3(0.05, r, r * 0.42), tyre)
		b.box(Vector3(-0.03, -r * 0.8, -r * 0.33), Vector3(0.03, r * 0.8, r * 0.33), Color(0.75, 0.75, 0.78))
		b.box(Vector3(-0.01, -r * 0.78, -0.006), Vector3(0.01, r * 0.78, 0.006), Color(0.85, 0.85, 0.87))
		b.xf = saved
	b.box(Vector3(-0.07, -0.06, -0.06), Vector3(0.07, 0.06, 0.06), Color(0.5, 0.5, 0.52))
