extends Camera3D

var to_look_at : bool = false;

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion && Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		global_rotation_degrees -= Vector3(event.relative.y, event.relative.x, 0) / 3
		global_rotation_degrees.x = clamp(global_rotation_degrees.x, -89, 89)
	
	#if Input.is_action_just_pressed("FIRE"):
		#to_look_at = !to_look_at
		#
		#reparent($"../MeshInstance3D8", true)
	
	if Input.is_action_just_pressed("ESC"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_VISIBLE
	pass

func _process(delta: float) -> void:
	var movement : Vector2 = Input.get_vector("A", "D", "W", "S")
	var elevation : float = Input.get_vector("Q", "E", "Q", "E").x
	global_position += global_basis * Vector3(movement.x, elevation, movement.y) * delta * 5;
	
	if to_look_at:
		look_at($"../../MeshInstance3D5".global_position)
