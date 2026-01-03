extends Node3D

@export var speed: float = 600.0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func set_speed(value: float) -> void:
	speed = value


func get_speed() -> float:
	return speed


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	%PathFollow3D.progress += delta * speed
