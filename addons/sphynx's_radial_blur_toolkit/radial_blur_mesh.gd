@tool
extends MeshInstance3D
class_name RadialBlurMesh

@export var target_node : Node3D

## the rotation vector the current mesh blur's around
## locally
@export_enum("x", "y", "z") var local_rotation_axis : int 

@export var negate_local_rotation_axis : bool = false

## the rotation vector that the target mesh spins along locally
@export_enum("x", "y", "z") var target_local_rotation_axis : int

@export var negate_target_local_rotation_axis : bool = false

## make mesh visible for debugging
@export var show_debug : bool = false

## The smaller the values is, the closer the samples
## have to land along the same orbit as the mesh's position
## at that pixel relatively to the camera, meaning the blur sample is 
## filtered out if it will not have reached
## that position at any point along the rotation.
## Its most noticeable when the rotating element's axis is viewed
## at an angle.
## Setting the value too low will lead to partial blur 
## and can be unsatisfactory. This value represents world
## units for that offset threshold.
@export var sampling_error_threshold: float = 0.2

@onready var local_rotation_vector : Vector3 = Vector3(1 if local_rotation_axis == 0 else 0, 1 if local_rotation_axis == 1 else 0, 1 if local_rotation_axis == 2 else 0) * (1 if !negate_local_rotation_axis else -1)

@onready var target_local_rotation_vector : Vector3 = Vector3(1 if target_local_rotation_axis == 0 else 0, 1 if target_local_rotation_axis == 1 else 0, 1 if target_local_rotation_axis == 2 else 0) * (1 if !negate_target_local_rotation_axis else -1)

@onready var viewport := $RadialBlurViewport

@onready var camera := $RadialBlurViewport/Camera3D

@onready var mesh_copy := $MeshCopy

var mesh_last_rotation : float = 0;

var previous_mesh_basis : Basis = Basis()

var mesh_has_rotation_signal : bool = false

var signal_rotation_velocity : float = 0

var debug_toggle : float = 0

var axis_offset : float 

func _ready():
	mesh_copy.mesh = mesh
	camera.compositor.compositor_effects[0].texture_generated.connect(_on_depth_texture_generated)
	get_surface_override_material(0).set_shader_parameter("debug_color", Color(0, 0, 0, 0) if !show_debug else Color(1, 0, 0, 0.2))
	
	previous_mesh_basis = target_node.global_basis
	
	var target_rotation_vector : Vector3 = previous_mesh_basis.orthonormalized() * target_local_rotation_vector
	
	axis_offset = target_rotation_vector.dot(global_position - target_node.global_position)
	
	if target_node.has_signal("rotation_velocity_signal"):
		mesh_has_rotation_signal = true
		target_node.rotation_velocity_signal.connect(on_rotation_velocity_signal)
	
	deferred_update_cylinder_data.call_deferred()


func _on_depth_texture_generated(depth_texture: Texture2DRD) -> void:
	get_surface_override_material(0).set_shader_parameter("depth_texture", depth_texture)
	get_surface_override_material(0).set_shader_parameter("screen_texture", viewport.get_texture())


func on_rotation_velocity_signal(velocity : float):
	signal_rotation_velocity = velocity


func deferred_update_cylinder_data():
	get_surface_override_material(0).set_shader_parameter("local_rotation_axis", local_rotation_vector)
	get_surface_override_material(0).set_shader_parameter("sampling_error_threshold", sampling_error_threshold)


func _process(delta: float) -> void:
	if !target_node:
		return
	
	var target_transform : Transform3D = target_node.global_transform
	
	var target_rotation_vector : Vector3 = target_transform.orthonormalized().basis * target_local_rotation_vector
	
	var current_mesh_basis : Basis = target_transform.basis
	
	var difference_quat : Quaternion = Quaternion(current_mesh_basis.get_rotation_quaternion() * previous_mesh_basis.get_rotation_quaternion().inverse())
	
	var centered_angle : float = difference_quat.get_angle() - PI
	
	var angle = (PI - abs(centered_angle)) * abs(target_rotation_vector.dot(difference_quat.get_axis()))
	
	if mesh_has_rotation_signal:
		angle = signal_rotation_velocity
	
	get_surface_override_material(0).set_shader_parameter("rotation_speed", clamp(angle, -TAU, TAU))
	
	previous_mesh_basis = current_mesh_basis
	
	global_position = target_transform.origin + target_rotation_vector * axis_offset
	
	var alignment_quaternion : Quaternion = Quaternion(global_basis.orthonormalized() * local_rotation_vector, target_rotation_vector)
	
	global_basis = Basis(alignment_quaternion) * global_basis;
