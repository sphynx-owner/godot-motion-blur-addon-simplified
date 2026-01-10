@tool
class_name SpinMeshGenerator
extends Node3D

@export var source_mesh: Mesh

@export var rotation_axis: Vector3 = Vector3(1, 0, 0)

@export var rings: int = 16

@export var radial_segments: int = 32

@export var radial_padding: float = 0

@export var depth_padding: float = 0

@export var neighbor_max: bool = false

@export var result_mesh: Mesh

@export_tool_button("generate") var generate = _generate

var _mesh_instance: MeshInstance3D


func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	
	add_child(_mesh_instance)


func _generate() -> void:
	if !source_mesh:
		push_error("no source mesh provided")
		return
	
	
	result_mesh = SpinMesh.generate(
		source_mesh,
		rotation_axis,
		rings,
		radial_segments,
		radial_padding,
		depth_padding,
		neighbor_max
	)
	
	_mesh_instance.mesh = result_mesh
