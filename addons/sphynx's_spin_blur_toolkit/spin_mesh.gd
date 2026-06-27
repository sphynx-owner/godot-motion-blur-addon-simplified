class_name SpinMesh
extends ArrayMesh


static func generate(
	meshes: Dictionary[MeshInstance3D, Transform3D], 
	rotation_axis: Vector3, 
	rings: int = 16, 
	radial_segments: int = 32, 
	fill_center: bool = true,
	unify_meshes: bool = false,
	radial_padding: float = 0, 
	depth_padding: float = 0, 
	neighbor_max: bool = false
) -> SpinMesh:
	if meshes.is_empty():
		push_error("no meshes provided")
		return
	
	var arr_mesh = SpinMesh.new()
	
	var all_face_vertices: Array[PackedVector3Array]
	
	if unify_meshes:
		all_face_vertices = [[]]
	
	for mesh_instance: MeshInstance3D in meshes.keys():
		var face_vertices: PackedVector3Array = mesh_instance.mesh.get_faces()
		
		var transform: Transform3D = meshes[mesh_instance]
		
		for i in face_vertices.size():
			face_vertices[i] = transform * face_vertices[i]
		
		if unify_meshes:
			all_face_vertices[0].append_array(face_vertices)
			
		else:
			all_face_vertices.append(face_vertices)
	
	for face_vertices: PackedVector3Array in all_face_vertices:
		# These will be axis local vertices, meaning their orientation around the axis is lost,
		# and instead only their profile relatively to the axis is maintained, i.e. their distand
		# from the axis, and offset along that axis' direction.
		var local_vertices: PackedVector2Array
		
		local_vertices.resize(face_vertices.size())
		
		var normalized_rotation_axis: Vector3 = rotation_axis.normalized()
		
		var max_radius: float = 0
		
		for i in range(face_vertices.size()):
			var local_vertex: Vector2 = _vertex_to_axis_local(face_vertices[i], normalized_rotation_axis)
			
			local_vertices[i] = local_vertex
			
			if local_vertex.x > max_radius:
				max_radius = local_vertex.x
		
		# These will not be normalized in the traditional sense. Instead, we normalize
		# the radius of all local vertices to a mapping between 0 and 1, for easier 
		# rasterization onto chunks.
		var normalized_vertices: PackedVector2Array
		
		normalized_vertices.resize(local_vertices.size())
		
		# We add a small epsilon so that all vertices are guaranteed to fall within the
		# unit radius
		var normalization_factor: float = 1.0 / (max(max_radius, 0) + 0.001)
		
		for i in range(local_vertices.size()):
			normalized_vertices[i] = local_vertices[i] * Vector2(normalization_factor, 1)
		
		# Radial chunks define the rings of vertices that would make out the final spin mesh.
		# They contain the maximum and minimum depth of the mesh at every given ring, which is also
		# the offsets of the front and back offsets of the generated vertex rings, respectively.
		var radial_chunks: PackedVector2Array
		
		radial_chunks.resize(rings)
		
		radial_chunks.fill(Vector2(-INF, INF))
		
		# When using source_mesh.get_faces(), we get an array of vertex triplets, for each
		# triangle that makes out the mesh. We now loop on each one of those triplets, which
		# is basically looping through each face of the mesh, which allows us to rasterize
		# while accounting for the edges of faces to be included in the min-max depth.
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
		
		var blobs: Dictionary[int, PackedVector2Array]
		
		var current_blob: PackedVector2Array
		
		var outside_blob: bool = true
		
		for i in neighbor_max_radial_chunks.size():
			var chunk: Vector2 = neighbor_max_radial_chunks[i]
			
			if chunk.x == -INF:
				outside_blob = true
				continue
			
			if outside_blob:
				current_blob = []
				blobs[i] = current_blob
				outside_blob = false
			
			current_blob.append(chunk)
		
		if fill_center:
			var first_blob_offset: int = blobs.keys().front()
			
			if first_blob_offset > 0:
				var first_blob: PackedVector2Array = blobs[first_blob_offset]
				
				blobs.erase(first_blob_offset)
				
				blobs[0] = first_blob
				
				for i in first_blob_offset:
					first_blob.insert(0, first_blob[0])
		
		var cross_vector: Vector3 = Vector3(1, 0, 0) \
		if !normalized_rotation_axis.is_equal_approx(Vector3(1, 0, 0)) else Vector3(0, 1, 0)
		
		var perpendicular: Vector3 = normalized_rotation_axis.cross(cross_vector).normalized()
		
		for blob_offset in blobs.keys():
			var blob: PackedVector2Array = blobs[blob_offset]
			
			var profile_vertices: PackedVector3Array
			
			profile_vertices.resize(blob.size() * 2)
			
			# We loop from the end, or from the outside chunks inward, so we are guaranteed
			# a first valid chunk range, and thus a valid latest_chunk_cache.
			for i in range(blob.size() - 1, -1, -1):
				var chunk: Vector2 = blob[i]
				
				var chunk_radius: float = float(i + blob_offset) / (rings - 1) * max_radius
				
				if chunk.x == -INF:
					pass
				
				profile_vertices[i] = _axis_local_to_vertex(
					Vector2(chunk_radius + radial_padding, chunk.x + depth_padding), 
					normalized_rotation_axis, 
					perpendicular
				)
				
				profile_vertices[profile_vertices.size() - 1 - i] = _axis_local_to_vertex(
					Vector2(chunk_radius + radial_padding, chunk.y - depth_padding), 
					normalized_rotation_axis, 
					perpendicular
				)
			
			profile_vertices.append(profile_vertices[0])
			
			var profile_stride: int = profile_vertices.size()
			
			var all_unique_vertices: PackedVector3Array
			
			all_unique_vertices.resize(profile_stride * radial_segments)
			
			var angle_interval: float = TAU / radial_segments
			
			for i in range(radial_segments):
				for j in range(profile_stride):
					all_unique_vertices[profile_stride * i + j] = \
					profile_vertices[j].rotated(normalized_rotation_axis, angle_interval * i)
			
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


## This function takes an edge (two vertices), and projects it onto the discrete chunk intervals
## it crosses to give them new min-max values. In addition the vertices also expand the chunks they
## are in.
## See screenshots/edge_rasterization_scheme.png for a slightly better idea of how an edge
## is rasterized onto chunks
# NOTE: a and b must be normalized vertexes
static func _rasterize_vertices_onto_chunks(
	a: Vector2, 
	b: Vector2, 
	rings: int, 
	chunks: PackedVector2Array
) -> void:
	if a.x > b.x:
		var temp: Vector2 = a
		a = b
		b = temp
	
	var slope: float = (b.y - a.y) / (b.x - a.x)
	
	# The intersection of the slope with the y axis.
	var y_intersect: float = a.y - slope * a.x
	
	var resolution: int = rings - 1
	
	var starting_chunk: int = floori(a.x * resolution)
	
	var ending_chunk: int = floori(b.x * resolution) + 1
	
	var chunk_count: int = ending_chunk - starting_chunk + 1
	
	var temp_chunks: PackedVector2Array
	
	temp_chunks.resize(chunk_count)
	
	temp_chunks.fill(Vector2(-INF, INF))
	
	var is_positive_slope: bool = slope >= 0
	
	var start: int = 0
	var end: int = chunk_count - 1
	
	temp_chunks[start] = Vector2(a.y, a.y)
	temp_chunks[end] = Vector2(b.y, b.y) 
	
	var start_adjacent: int = start + 1
	var end_adjacent: int = end - 1
	
	var start_adjacent_intersect: float = y_intersect + (float(start_adjacent + starting_chunk) / float(resolution)) * slope
	var end_adjacent_intersect: float = y_intersect + (float(end_adjacent + starting_chunk) / float(resolution)) * slope
	
	if is_positive_slope:
		temp_chunks[start_adjacent] = Vector2(min(b.y, start_adjacent_intersect), a.y)
		
		temp_chunks[end_adjacent] = \
		Vector2(b.y, min(temp_chunks[end_adjacent].y, max(a.y, end_adjacent_intersect)))
		
	else:
		temp_chunks[start_adjacent] = Vector2(a.y, max(b.y, start_adjacent_intersect))
		
		temp_chunks[end_adjacent] = \
		Vector2(max(temp_chunks[end_adjacent].x, min(a.y, end_adjacent_intersect)), b.y)
	
	# Loop through all middle chunks if there are any
	for i in range(start_adjacent + 1, end_adjacent):
		var chunk_intersect: float = y_intersect + (float(i + starting_chunk) / float(resolution)) * slope
		temp_chunks[i] = Vector2(chunk_intersect, chunk_intersect)
	
	for i in range(chunk_count):
		var output_chunk: int = i + starting_chunk
		
		chunks[output_chunk].x = max(temp_chunks[i].x, chunks[output_chunk].x)
		
		chunks[output_chunk].y = min(temp_chunks[i].y, chunks[output_chunk].y)
