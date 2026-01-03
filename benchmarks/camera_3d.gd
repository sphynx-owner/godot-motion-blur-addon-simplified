extends Camera3D

var speed: float = 10

@export var initial_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED

# Blocks input before the window is focused on. 
# Solves camera misalignment at the start of the scene
var _started := false

func _ready():
	await RenderingServer.frame_post_draw
	Input.mouse_mode = initial_mouse_mode
	_started = true


func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if !_started:
		return
	
	if event is InputEventMouseMotion && Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation_degrees = Vector3(
			clamp(rotation_degrees.x - event.relative.y / 3, -89, 89), 
			rotation_degrees.y - event.relative.x / 3, 
			rotation_degrees.z
		)
	
	if event is InputEventMouseButton && Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		match event.button_index:
			MouseButton.MOUSE_BUTTON_WHEEL_UP:
				speed *= 1.1
			
			MouseButton.MOUSE_BUTTON_WHEEL_DOWN:
				speed /= 1.1
	
	if Input.is_action_just_pressed("ESC"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	var movement : Vector2 = Input.get_vector("A", "D", "W", "S")
	var elevation : float = Input.get_vector("Q", "E", "Q", "E").x
	position += basis * Vector3(movement.x, elevation, movement.y) * delta * speed;
