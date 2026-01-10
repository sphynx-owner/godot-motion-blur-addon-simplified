@tool
extends Node3D

@export var source_mesh: Mesh

@export var rotation_axis: Vector3 = Vector3(1, 0, 0)

@export var radial_chunk_resolution: int = 10

@export var subdivisions: int = 10

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
	
	var face_vertices: PackedVector3Array = source_mesh.get_faces()
	
	var local_vertices: PackedVector2Array
	
	var normalized_rotation_axis: Vector3 = rotation_axis.normalized()
	
	var max_radius: float = 0
	
	for vertex in face_vertices:
		var local_vertex: Vector2 = _vertex_to_axis_local(vertex, normalized_rotation_axis)
		
		local_vertices.append(local_vertex)
		
		if local_vertex.x > max_radius:
			max_radius = local_vertex.x
	
	var normalized_vertices: PackedVector2Array
	
	var normalization_factor: float = 1 / max_radius
	
	for vertex in local_vertices:
		normalized_vertices.append(vertex * Vector2(normalization_factor, 1))
	
	var radial_chunks: PackedVector2Array
	
	for i in radial_chunk_resolution:
		radial_chunks.append(Vector2(-INF, INF))
	
	for i in range(normalized_vertices.size() / 3):
		var vertex1: Vector2 = normalized_vertices[i]
		var vertex2: Vector2 = normalized_vertices[i + 1]
		var vertex3: Vector2 = normalized_vertices[i + 2]
		
		_rasterize_vertices_onto_chunks(
			vertex1, 
			vertex2, 
			radial_chunk_resolution, 
			radial_chunks
		)
		
		_rasterize_vertices_onto_chunks(
			vertex2, 
			vertex3, 
			radial_chunk_resolution, 
			radial_chunks
		)
		
		_rasterize_vertices_onto_chunks(
			vertex3, 
			vertex1, 
			radial_chunk_resolution, 
			radial_chunks
		)
	
	# Choose the largest min and max depths given neighboring vertices.
	for i in radial_chunk_resolution:
		var previous_chunk: int = max(i - 1, 0)
		var next_chunk: int = min(i + 1, radial_chunk_resolution - 1)
		
		radial_chunks[i] = Vector2(
			max(
				radial_chunks[i].x, 
				max(
					radial_chunks[previous_chunk].x, 
					radial_chunks[next_chunk].x
				)
			),
			min(
				radial_chunks[i].y, 
				min(
					radial_chunks[previous_chunk].y, 
					radial_chunks[next_chunk].y
				)
			),
			
		)
	
	var cross_vector: Vector3 = Vector3(1, 0, 0) \
	if !normalized_rotation_axis.is_equal_approx(Vector3(1, 0, 0)) else Vector3(0, 1, 0)
	
	var perpendicular: Vector3 = rotation_axis.cross(cross_vector).normalized()
	
	var vertices: PackedVector3Array
	
	vertices.resize(radial_chunks.size() * 2)
	
	for i in range(radial_chunks.size()):
		var chunk: Vector2 = radial_chunks[i]
		var chunk_radius: float = (i + 0.5) * max_radius
		
		vertices[i] = _axis_local_to_vertex(
			Vector2(chunk.x, chunk_radius), 
			rotation_axis, 
			perpendicular
		)
		
		vertices[vertices.size() - 1 - i] = _axis_local_to_vertex(
			Vector2(chunk.y, chunk_radius), 
			rotation_axis, 
			perpendicular
		)
	
	vertices.resize(vertices.size() - vertices.size() % 3)
	
	# Initialize the ArrayMesh.
	var arr_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	
	# Create the Mesh.
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
	result_mesh = arr_mesh
	
	_mesh_instance.mesh = result_mesh


# NOTE: axis must be normalized
func _vertex_to_axis_local(vertex: Vector3, axis: Vector3) -> Vector2:
	var depth: float = axis.dot(vertex)
	
	var projected_radius: float = \
	(vertex - axis * depth).length()
	
	return Vector2(projected_radius, depth)


# NOTE: axis and perpendicular must be normalized
func _axis_local_to_vertex(axis_local: Vector2, axis: Vector3, perpendicular: Vector3) -> Vector3:
	return perpendicular * axis_local.x + axis * axis_local.y


# NOTE: a and b must be normalized vertexes
func _rasterize_vertices_onto_chunks(
	a: Vector2, 
	b: Vector2, 
	resolution: int, 
	chunks: PackedVector2Array
) -> void:
	if a.x > b.x:
		var temp: Vector2 = a
		a = b
		b = temp
	
	var slope: float = (b.y - a.y) / (b.x - a.x)
	
	var positive_slope: bool = slope >= 0
	
	var y_intersect: float = a.y - slope * a.x
	
	var starting_chunk: int = floor(a.x * resolution)
	
	var ending_chunk: int = floor(b.x * resolution)
	
	var chunk_count: int = ending_chunk + 1 - starting_chunk
	
	var temp_chunks: PackedVector2Array
	
	temp_chunks.resize(chunk_count)
	
	var min_x_offset: int = (0 if positive_slope else 1)
	var max_x_offset: int = (1 if positive_slope else 0)
	
	for i in chunk_count:
		var min_x: float = float(i + starting_chunk + min_x_offset) / float(resolution)
		var max_x: float = float(i + starting_chunk + max_x_offset) / float(resolution)
		
		temp_chunks[i] = Vector2(y_intersect + max_x * slope, y_intersect + min_x * slope)
	
	if positive_slope:
		temp_chunks[0].y = a.y
		temp_chunks[chunk_count - 1].x = b.y
	else:
		temp_chunks[0].x = a.y
		temp_chunks[chunk_count - 1].y = b.y
	
	for i in chunk_count:
		var output_chunk: int = i + starting_chunk
		
		if temp_chunks[i].x > chunks[output_chunk].x:
			chunks[output_chunk].x = temp_chunks[i].x
		
		if temp_chunks[i].y < chunks[output_chunk].y:
			chunks[output_chunk].y = temp_chunks[i].y
