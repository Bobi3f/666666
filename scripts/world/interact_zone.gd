class_name InteractZone
extends Area3D
## Место, где по E что-то происходит: ларёк, склад, кровать, машина.
## Игрок, войдя в зону, видит подсказку prompt.

signal activated

@export var prompt := "E — действие"


static func create(p: String, size: Vector3) -> InteractZone:
	var z := InteractZone.new()
	z.prompt = p
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position.y = size.y * 0.5
	z.add_child(cs)
	return z


func _ready() -> void:
	monitorable = false
	body_entered.connect(func(b: Node3D) -> void:
		if b.has_method("enter_zone"):
			b.enter_zone(self))
	body_exited.connect(func(b: Node3D) -> void:
		if b.has_method("exit_zone"):
			b.exit_zone(self))


func activate() -> void:
	activated.emit()
