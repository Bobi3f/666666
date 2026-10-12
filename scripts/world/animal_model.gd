class_name AnimalModel
extends RefCounted
## Звери в том же духе, что и люди (PersonModel): округлое туловище,
## голова с мордой, глазами и ушами, ноги-многогранники, хвост.
## Метки в альфе — для шейдера шага (villagers.gd → ANIMAL_SHADER): ноги по
## диагонали 0.9 и 0.8, хвост 0.5. Зверь смотрит в −Z, лапы на нуле.

const P := preload("res://scripts/world/person_model.gd")


## Собака-дворняга: fur — масть. Высота в холке около 0,5 м.
static func dog(b: MeshBuilder, fur: Color) -> void:
	var dark := fur.darkened(0.3)
	var belly := fur.lightened(0.18)
	# Туловище и грудь, живот светлее
	P.limb(b, Vector3(0, 0.42, 0.28), Vector3(0, 0.44, -0.26), Vector2(0.12, 0.12), Vector2(0.14, 0.15), fur, true)
	P.ball(b, Vector3(0, 0.44, -0.27), Vector3(0.14, 0.15, 0.13), fur, 4, 8)
	P.ball(b, Vector3(0, 0.36, 0.0), Vector3(0.09, 0.06, 0.24), belly, 3, 8)
	# Шея и голова, морда, нос, глаза, висячие уши
	P.limb(b, Vector3(0, 0.48, -0.32), Vector3(0, 0.6, -0.42), Vector2(0.075, 0.075), Vector2(0.07, 0.07), fur)
	var h := Vector3(0, 0.64, -0.46)
	P.ball(b, h, Vector3(0.095, 0.085, 0.1), fur, 4, 8)
	P.limb(b, h + Vector3(0, -0.02, -0.06), h + Vector3(0, -0.035, -0.18), Vector2(0.055, 0.045), Vector2(0.04, 0.035), belly, true)
	P.ball(b, h + Vector3(0, -0.025, -0.185), Vector3(0.022, 0.018, 0.015), Color(0.06, 0.05, 0.05), 2, 6)
	for s in [-1.0, 1.0]:
		b.box(h + Vector3(s * 0.045 - 0.012, 0.025, -0.088), h + Vector3(s * 0.045 + 0.012, 0.045, -0.08), Color(0.08, 0.06, 0.05))
		P.limb(b, h + Vector3(s * 0.07, 0.06, 0.0), h + Vector3(s * 0.1, -0.03, -0.01), Vector2(0.018, 0.035), Vector2(0.012, 0.04), dark)
	# Лапы: по диагонали одна пара — 0.9, другая — 0.8
	for p in [Vector2(-0.07, -0.24), Vector2(0.07, -0.24), Vector2(-0.07, 0.24), Vector2(0.07, 0.24)]:
		b.alpha = 0.9 if (p.x < 0.0) == (p.y < 0.0) else 0.8
		P.limb(b, Vector3(p.x, 0.38, p.y), Vector3(p.x, 0.03, p.y), Vector2(0.035, 0.04), Vector2(0.028, 0.03), fur.darkened(0.08))
		P.ball(b, Vector3(p.x, 0.025, p.y - 0.015), Vector3(0.032, 0.025, 0.04), dark, 2, 6)
	# Хвост бубликом вверх
	b.alpha = 0.5
	P.limb(b, Vector3(0, 0.47, 0.32), Vector3(0, 0.6, 0.42), Vector2(0.03, 0.03), Vector2(0.025, 0.025), fur)
	P.limb(b, Vector3(0, 0.6, 0.42), Vector3(0, 0.62, 0.34), Vector2(0.025, 0.025), Vector2(0.018, 0.018), fur, true)
	b.alpha = 1.0


## Курица: пузатое тельце, хвост веером, гребешок, бородка, клюв.
static func chicken(b: MeshBuilder, feather: Color) -> void:
	var red := Color(0.85, 0.12, 0.1)
	var yellow := Color(0.95, 0.68, 0.2)
	P.ball(b, Vector3(0, 0.25, 0.0), Vector3(0.11, 0.1, 0.15), feather, 4, 8)
	P.ball(b, Vector3(0, 0.3, 0.12), Vector3(0.07, 0.09, 0.06), feather.darkened(0.12), 3, 6)
	P.limb(b, Vector3(0, 0.3, -0.1), Vector3(0, 0.4, -0.15), Vector2(0.045, 0.045), Vector2(0.04, 0.04), feather)
	var h := Vector3(0, 0.43, -0.16)
	P.ball(b, h, Vector3(0.042, 0.045, 0.045), feather, 3, 6)
	P.limb(b, h + Vector3(0, 0.0, -0.035), h + Vector3(0, -0.01, -0.075), Vector2(0.012, 0.01), Vector2(0.003, 0.003), yellow, true)
	P.ball(b, h + Vector3(0, 0.05, 0.0), Vector3(0.008, 0.03, 0.035), red, 2, 6)
	P.ball(b, h + Vector3(0, -0.045, -0.03), Vector3(0.008, 0.02, 0.012), red, 2, 6)
	for s in [-1.0, 1.0]:
		b.box(h + Vector3(s * 0.04 - 0.004, 0.008, -0.022), h + Vector3(s * 0.04 + 0.004, 0.018, -0.012), Color(0.05, 0.05, 0.05))
		P.limb(b, Vector3(s * 0.035, 0.17, 0.0), Vector3(s * 0.035, 0.01, -0.01), Vector2(0.008, 0.008), Vector2(0.007, 0.007), yellow)
		b.box(Vector3(s * 0.035 - 0.02, 0.0, -0.05), Vector3(s * 0.035 + 0.02, 0.01, 0.01), yellow)


## Корова: бочкообразное туловище в пятнах, вымя, голова с рогами,
## хвост с кисточкой. i — какие пятна и масть.
static func cow(b: MeshBuilder, i: int) -> void:
	var white := Color(0.92, 0.9, 0.86)
	var spot: Color = [Color(0.2, 0.17, 0.15), Color(0.5, 0.3, 0.18), Color(0.35, 0.22, 0.15)][i % 3]
	var body := white if i % 2 == 0 else spot
	P.limb(b, Vector3(0, 1.0, 0.75), Vector3(0, 1.02, -0.75), Vector2(0.34, 0.33), Vector2(0.36, 0.34), body, true)
	# Пятна — плоские эллипсы на боках
	var other := spot if body == white else white
	for k in 3:
		var z := -0.5 + k * 0.45 + 0.05 * float(i % 2)
		for s in [-1.0, 1.0]:
			if (k + i) % 2 == 0 or s > 0.0:
				P.ball(b, Vector3(s * 0.32, 1.02 + 0.08 * float(k % 2), z), Vector3(0.05, 0.16, 0.2), other, 3, 6)
	P.ball(b, Vector3(0, 0.66, 0.42), Vector3(0.13, 0.08, 0.14), Color(0.92, 0.7, 0.68), 3, 8)
	# Шея и голова: морда светлее, ноздри, глаза, уши, рога
	P.limb(b, Vector3(0, 1.1, -0.72), Vector3(0, 1.18, -1.0), Vector2(0.18, 0.2), Vector2(0.14, 0.16), body)
	var h := Vector3(0, 1.15, -1.12)
	P.ball(b, h, Vector3(0.14, 0.16, 0.16), body, 4, 8)
	P.limb(b, h + Vector3(0, -0.06, -0.1), h + Vector3(0, -0.12, -0.26), Vector2(0.11, 0.09), Vector2(0.1, 0.08), Color(0.85, 0.72, 0.68), true)
	for s in [-1.0, 1.0]:
		b.box(h + Vector3(s * 0.04 - 0.015, -0.12, -0.27), h + Vector3(s * 0.04 + 0.015, -0.09, -0.262), Color(0.15, 0.1, 0.1))
		b.box(h + Vector3(s * 0.11 - 0.015, 0.04, -0.125), h + Vector3(s * 0.11 + 0.015, 0.07, -0.11), Color(0.06, 0.05, 0.05))
		P.limb(b, h + Vector3(s * 0.12, 0.06, 0.02), h + Vector3(s * 0.24, 0.02, 0.04), Vector2(0.03, 0.06), Vector2(0.02, 0.05), body)
		P.limb(b, h + Vector3(s * 0.08, 0.13, 0.02), h + Vector3(s * 0.17, 0.22, 0.0), Vector2(0.022, 0.022), Vector2(0.008, 0.008), Color(0.9, 0.87, 0.78), true)
	# Ноги с копытами
	for p in [Vector2(-0.22, -0.55), Vector2(0.22, -0.55), Vector2(-0.22, 0.55), Vector2(0.22, 0.55)]:
		b.alpha = 0.9 if (p.x < 0.0) == (p.y > 0.0) else 0.8
		P.limb(b, Vector3(p.x, 0.85, p.y), Vector3(p.x, 0.08, p.y), Vector2(0.075, 0.08), Vector2(0.05, 0.055), body.darkened(0.06))
		P.limb(b, Vector3(p.x, 0.09, p.y), Vector3(p.x, 0.0, p.y - 0.01), Vector2(0.055, 0.06), Vector2(0.06, 0.065), Color(0.15, 0.12, 0.1), true)
	# Хвост с кисточкой
	b.alpha = 0.5
	P.limb(b, Vector3(0, 1.25, 0.95), Vector3(0, 0.6, 1.03), Vector2(0.02, 0.02), Vector2(0.018, 0.018), body)
	P.ball(b, Vector3(0, 0.55, 1.03), Vector3(0.04, 0.08, 0.04), Color(0.15, 0.12, 0.1), 2, 6)
	b.alpha = 1.0
