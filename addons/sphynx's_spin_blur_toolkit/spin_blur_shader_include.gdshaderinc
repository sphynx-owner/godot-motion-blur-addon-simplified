const float EPSILON = 0.00001;

uniform sampler2D screen_texture : filter_nearest, source_color;

uniform sampler2D depth_texture : filter_nearest, source_color;

uniform vec3 local_rotation_axis = vec3(0, 1, 0);

uniform float rotation_speed = 0;

uniform int sample_count = 8;

uniform float sampling_error_threshold = 0.1;

uniform float fade_in = 1;

uniform float blur_intensity;

uniform float rolling_shutter_amount = 1.0;


//https://www.shadertoy.com/view/fdtfWM
vec3 rotate(float angle, vec3 axis, vec3 point) // NOTE: axis must be unit!
{
	float c = cos(angle);
	float s = sin(angle);
	return c * point + s * cross(axis, point) + (1.0 - c) * (dot(point, axis) * axis); // Rodrigues' Rotation Formula
}


// from https://www.shadertoy.com/view/ftKfzc
float interleaved_gradient_noise(vec2 uv, int FrameId){
	uv += float(FrameId)  * (vec2(47, 17) * 0.695);
	
	 vec3 magic = vec3( 0.06711056, 0.00583715, 52.9829189 );
	
	return fract(magic.z * fract(dot(uv, magic.xy)));
}


void fragment() {
	vec3 view_rotation_axis = normalize(mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX) * local_rotation_axis);
	
	// get noise sample to smooth out banding, value between 0 and 1.
	float j = interleaved_gradient_noise(SCREEN_UV * vec2(VIEWPORT_SIZE), int(TIME * 247.0) % 10);
	
	// position of the fragment relatively to node origin in view space
	vec3 node_relative_position = VERTEX - NODE_POSITION_VIEW;
	
	// we extract the uv coordinate of the node origin
	vec4 node_ndc = PROJECTION_MATRIX * vec4(NODE_POSITION_VIEW, 1.0);
	node_ndc.xyz /= node_ndc.w;
	vec2 node_uv = (node_ndc.xy + 1.0) * 0.5;
	
	// We use the node origin uv coordinate to ensure rolling shutter angle offset is
	// always 0 around the center of the node.
	float rolling_shutter_uv_amount = (SCREEN_UV.y - node_uv.y) * rolling_shutter_amount;
	
	// get the square to compare against dot operation (length squared)
	float squared_sampling_error_threshold = max(sampling_error_threshold * sampling_error_threshold, EPSILON);
	
	// total of valid samples
	float weight = 0.;
	
	// total of valid/valid-yet-transparent samples
	float alpha_weight = 1e-5;
	
	// total color
	vec4 sum = vec4(0);
	
	for(int i = 0; i < sample_count; i++)
	{
		float t = (float(i) + j) / float(sample_count) - 0.5;
		
		// note: rolling shutter amount affects the angle independently of the blur intensity and sample time.
		float angle = (t * blur_intensity + rolling_shutter_uv_amount) * rotation_speed;
		
		vec3 node_rotated_sample = rotate(angle, view_rotation_axis, node_relative_position);
		
		// Get uv of naively-rotated position
		vec4 current_ndc = PROJECTION_MATRIX * vec4(node_rotated_sample + NODE_POSITION_VIEW, 1);
		current_ndc.xyz /= current_ndc.w;
		vec2 current_uv = (current_ndc.xy + 1.) * 0.5;
		
		// skip if navie position is out of frame
		if (current_uv.x < 0. || current_uv.x > 1. || current_uv.y < 0. || current_uv.y > 1.)
		{
			continue;
		}
		
		// get depth at naive position
		float current_depth = texture(depth_texture, current_uv).x;
		
		// If depth is 0.0, it's an indicator of no geometry at that naive
		// position, and we can skip it, making sure to still accumulate transparency
		if(current_depth == 0.0) {
			alpha_weight += 1.0;
			continue;
		}
		
		// get view position of sampled geometry
		vec4 current_view_position = INV_PROJECTION_MATRIX * vec4(vec3(current_ndc.xy, current_depth), 1.0);
		current_view_position.xyz /= current_view_position.w;
		
		// unrotate the position back to compare with view position
		vec3 unrotated_position = rotate(-angle, view_rotation_axis, current_view_position.xyz - NODE_POSITION_VIEW) + NODE_POSITION_VIEW;
		
		// Get the view-perpendicular error between the view position and the unrotated sampled position
		vec2 current_unrotated_perpendicular_component = unrotated_position.xy - VERTEX.xy;
		
		// This is a heuristical check to discard of sampled positions that do not travel on the
		// same circumference as the view position.
		if(dot(current_unrotated_perpendicular_component, current_unrotated_perpendicular_component) >= squared_sampling_error_threshold) {
			continue;
		}
		
		weight += 1.;
		alpha_weight += 1.0;
		sum += texture(screen_texture, current_uv);
	}
	
	sum.xyz /= weight;
	sum.a /= alpha_weight;
	
	ALBEDO = sum.xyz;
	ALPHA = sum.a * fade_in;
}