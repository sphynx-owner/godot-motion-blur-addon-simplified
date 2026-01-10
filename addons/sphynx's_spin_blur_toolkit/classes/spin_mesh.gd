class_name SpinMesh
extends ArrayMesh


static func generate(
	source_mesh: Mesh, 
	rotation_axis: Vector3, 
	rings: int = 16, 
	radial_segments: int = 32, 
	radial_padding: float = 0, 
	depth_padding: float = 0, 
	neighbor_max: bool = false
) -> SpinMesh:
	if !source_mesh:
		push_error("no source mesh provided")
		return
	
	var face_vertices: PackedVector3Array = source_mesh.get_faces()
	
	var local_vertices: PackedVector2Array
	
	local_vertices.resize(face_vertices.size())
	
	var normalized_rotation_axis: Vector3 = rotation_axis.normalized()
	
	var max_radius: float = 0
	
	for i in range(face_vertices.size()):
		var local_vertex: Vector2 = _vertex_to_axis_local(face_vertices[i], normalized_rotation_axis)
		
		local_vertices[i] = local_vertex
		
		if local_vertex.x > max_radius:
			max_radius = local_vertex.x
	
	max_radius += 0.01
	
	var normalized_vertices: PackedVector2Array
	
	normalized_vertices.resize(local_vertices.size())
	
	var normalization_factor: float = 1 / max_radius
	
	for i in range(local_vertices.size()):
		normalized_vertices[i] = local_vertices[i] * Vector2(normalization_factor, 1)
	
	var radial_chunks: PackedVector2Array
	
	radial_chunks.resize(rings)
	
	radial_chunks.fill(Vector2(-INF, INF))
	
	for i in range(normalized_vertices.size() / 3):
		var vertex1: Vector2 = normalized_vertices[i * 3]
		var vertex2: Vector2 = normalized_vertices[i * 3 + 1]
		var vertex3: Vector2 = normalized_vertices[i * 3 + 2]
		
		_rasterize_vertices_onto_chunks(
			vertex1, 
			vertex2, 
			rings, 
			radial_chunks
		)
		
		_rasterize_vertices_onto_chunks(
			vertex2, 
			vertex3, 
			rings, 
			radial_chunks
		)
		
		_rasterize_vertices_onto_chunks(
			vertex3, 
			vertex1, 
			rings, 
			radial_chunks
		)
	
	var neighbor_max_radial_chunks: PackedVector2Array
	
	neighbor_max_radial_chunks.resize(radial_chunks.size())
	
	# Choose the largest min and max depths given neighboring vertices.
	for i in range(rings):
		var previous_chunk: int = max(i - 1, 0)
		var next_chunk: int = min(i + 1, rings - 1)
		
		if neighbor_max:
			neighbor_max_radial_chunks[i] = Vector2(
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
				)
			)
			
		else:
			neighbor_max_radial_chunks[i] = radial_chunks[i]
	
	var cross_vector: Vector3 = Vector3(1, 0, 0) \
	if !normalized_rotation_axis.is_equal_approx(Vector3(1, 0, 0)) else Vector3(0, 1, 0)
	
	var perpendicular: Vector3 = rotation_axis.cross(cross_vector).normalized()
	
	var profile_vertices: PackedVector3Array
	
	profile_vertices.resize(neighbor_max_radial_chunks.size() * 2)
	
	var latest_chunk_cache: Vector2
	
	for i in range(neighbor_max_radial_chunks.size() - 1, -1, -1):
		var chunk: Vector2 = neighbor_max_radial_chunks[i]
		var chunk_radius: float = (i + 1.0) / rings * max_radius
		
		if chunk.x > -INF:
			latest_chunk_cache = chunk
		
		profile_vertices[i] = _axis_local_to_vertex(
			Vector2(chunk_radius + radial_padding, (chunk.x if chunk.x > -INF else latest_chunk_cache.x) + depth_padding), 
			rotation_axis, 
			perpendicular
		)
		
		profile_vertices[profile_vertices.size() - 1 - i] = _axis_local_to_vertex(
			Vector2(chunk_radius + radial_padding, (chunk.y if chunk.y < INF else latest_chunk_cache.y) - depth_padding), 
			rotation_axis, 
			perpendicular
		)
	
	var profile_stride: int = profile_vertices.size()
	
	var all_unique_vertices: PackedVector3Array
	
	all_unique_vertices.resize(profile_stride * radial_segments)
	
	var angle_interval: float = TAU / radial_segments
	
	for i in range(radial_segments):
		for j in range(profile_stride):
			all_unique_vertices[profile_stride * i + j] = profile_vertices[j].rotated(normalized_rotation_axis, angle_interval * i)
	
	var vertices: PackedVector3Array
	vertices.resize((profile_stride - 1) * 6 * radial_segments)
	
	for i in radial_segments:
		for j in range(profile_stride - 1):
			var bl: Vector3 = all_unique_vertices[profile_stride * i + j]
			var br: Vector3 = all_unique_vertices[profile_stride * i + j + 1]
			var tl: Vector3 = all_unique_vertices[profile_stride * ((i + 1) % radial_segments) + j]
			var tr: Vector3 = all_unique_vertices[profile_stride * ((i + 1) % radial_segments) + j + 1]
			
			var vertices_offset: int = ((profile_stride - 1) * i + j) * 6
			
			vertices[vertices_offset + 0] = bl
			vertices[vertices_offset + 1] = tr
			vertices[vertices_offset + 2] = br
			vertices[vertices_offset + 3] = bl
			vertices[vertices_offset + 4] = tl
			vertices[vertices_offset + 5] = tr
	
	var arr_mesh = SpinMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return arr_mesh


# NOTE: axis must be normalized
static func _vertex_to_axis_local(vertex: Vector3, axis: Vector3) -> Vector2:
	var depth: float = axis.dot(vertex)
	
	var projected_radius: float = \
	(vertex - axis * depth).length()
	
	return Vector2(projected_radius, depth)


# NOTE: axis and perpendicular must be normalized
static func _axis_local_to_vertex(axis_local: Vector2, axis: Vector3, perpendicular: Vector3) -> Vector3:
	return perpendicular * axis_local.x + axis * axis_local.y


# NOTE: a and b must be normalized vertexes
static func _rasterize_vertices_onto_chunks(
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
	
	for i in range(chunk_count):
		var min_x: float = float(i + starting_chunk + min_x_offset) / float(resolution)
		var max_x: float = float(i + starting_chunk + max_x_offset) / float(resolution)
		
		temp_chunks[i] = Vector2(y_intersect + max_x * slope, y_intersect + min_x * slope)
	
	if positive_slope:
		temp_chunks[0].y = a.y
		temp_chunks[chunk_count - 1].x = b.y
	else:
		temp_chunks[0].x = a.y
		temp_chunks[chunk_count - 1].y = b.y
	
	for i in range(chunk_count):
		var output_chunk: int = i + starting_chunk
		
		if temp_chunks[i].x > chunks[output_chunk].x:
			chunks[output_chunk].x = temp_chunks[i].x
		
		if temp_chunks[i].y < chunks[output_chunk].y:
			chunks[output_chunk].y = temp_chunks[i].y
