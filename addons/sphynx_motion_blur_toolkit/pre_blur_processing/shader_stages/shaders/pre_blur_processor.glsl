#[compute]
#version 450

#define FLT_MAX 3.402823466e+38
#define FLT_MIN 1.175494351e-38
#define MAX_VIEWS 2

layout(set = 0, binding = 0) uniform sampler2D depth_sampler;
layout(set = 0, binding = 1) uniform sampler2D vector_sampler;
layout(rgba32f, set = 0, binding = 2) uniform writeonly image2D vector_output;

struct SceneData {
	mat4 projection_matrix;
	mat4 inv_projection_matrix;
	mat3x4 inv_view_matrix;
	mat3x4 view_matrix;

	mat4 projection_matrix_view[MAX_VIEWS];
	mat4 inv_projection_matrix_view[MAX_VIEWS];
	vec4 eye_offset[MAX_VIEWS];

	mat4 main_cam_inv_view_matrix;

	vec2 viewport_size;
	vec2 screen_pixel_size;

	vec4 directional_penumbra_shadow_kernel[32];
	vec4 directional_soft_shadow_kernel[32];
	vec4 penumbra_shadow_kernel[32];
	vec4 soft_shadow_kernel[32];

	vec2 shadow_atlas_pixel_size;
	vec2 directional_shadow_pixel_size;
	float radiance_pixel_size;
	float radiance_border_size;
	vec2 reflection_atlas_border_size;

	uint directional_light_count;
	float dual_paraboloid_side;
	float z_far;
	float z_near;

	float roughness_limiter_amount;
	float roughness_limiter_limit;
	float opaque_prepass_threshold;

	uint flags;

	mat3 radiance_inverse_xform;
	vec4 ambient_light_color_energy;

	float ambient_color_sky_mix;
	float fog_density;
	float fog_height;
	float fog_height_density;

	float fog_depth_curve;
	float fog_depth_begin;
	float fog_depth_end;
	float fog_sun_scatter;
	vec3 fog_light_color;
	float fog_aerial_perspective;

	float time;
	float taa_frame_count;
	vec2 taa_jitter;

	float emissive_exposure_normalization;
	float IBL_exposure_normalization;

	uint camera_visible_layers;
	float pass_alpha_multiplier;
};

layout(set = 0, binding = 3, std140) uniform SceneDataBlock {
	SceneData data;
	SceneData prev_data;
} scene;

layout(push_constant, std430) uniform Params {
	float rotation_velocity_multiplier;
	float movement_velocity_multiplier;
	float object_velocity_multiplier;
	float rotation_velocity_lower_threshold;
	float movement_velocity_lower_threshold;
	float object_velocity_lower_threshold;
	float rotation_velocity_upper_threshold;
	float movement_velocity_upper_threshold;
	float object_velocity_upper_threshold;
	float support_fsr2;
	float motion_blur_intensity;
	float nan_fl_2;
} params;

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

float sharp_step(float lower, float upper, float x) {
	return clamp((x - lower) / (upper - lower), 0.0, 1.0);
}

void main() {
	ivec2 render_size = ivec2(textureSize(vector_sampler, 0));
	ivec2 uvi = ivec2(gl_GlobalInvocationID.xy);
	if (uvi.x >= render_size.x || uvi.y >= render_size.y) {
		return;
	}

	vec2 uvn = vec2(uvi + vec2(0.5)) / vec2(render_size);

	SceneData scene_data = scene.data;
	SceneData previous_scene_data = scene.prev_data;

	float depth = textureLod(depth_sampler, uvn, 0.0).x;

	vec4 view_position = inverse(scene_data.projection_matrix) * vec4(uvn * 2.0 - 1.0, depth, 1.0);
	view_position.xyz /= view_position.w;

	mat4 view_mat = mat4(scene_data.view_matrix);
	mat4 inv_view_mat = mat4(scene_data.inv_view_matrix);
	mat4 prev_view_mat = mat4(previous_scene_data.view_matrix);

	vec4 world_local_position = inv_view_mat * vec4(view_position.xyz, 1.0);

	vec4 view_past_position = prev_view_mat * vec4(world_local_position.xyz, 1.0);
	vec4 view_past_ndc = previous_scene_data.projection_matrix * view_past_position;
	view_past_ndc.xyz /= view_past_ndc.w;

	vec3 past_uv = vec3(view_past_ndc.xy * 0.5 + 0.5, view_past_position.z);
	vec4 view_past_ndc_cache = view_past_ndc;

	vec3 camera_uv_change = past_uv - vec3(uvn, view_position.z);

	world_local_position = mat4(mat3(inv_view_mat)) * vec4(view_position.xyz, 1.0);

	view_past_position = mat4(mat3(prev_view_mat)) * vec4(world_local_position.xyz, 1.0);
	view_past_ndc = previous_scene_data.projection_matrix * view_past_position;
	view_past_ndc.xyz /= view_past_ndc.w;

	past_uv = vec3(view_past_ndc.xy * 0.5 + 0.5, view_past_position.z);

	vec3 camera_rotation_uv_change = past_uv - vec3(uvn, view_position.z);
	vec3 camera_movement_uv_change = camera_uv_change - camera_rotation_uv_change;

	vec3 base_velocity = vec3(
		textureLod(vector_sampler, uvn, 0.0).xy +
			mix(vec2(0.0), camera_uv_change.xy, step(depth, 0.0)),
		depth == 0.0 ? 0.0 : camera_uv_change.z
	);

	if (params.support_fsr2 > 0.5 && dot(base_velocity.xy, base_velocity.xy) >= 1.0) {
		base_velocity = camera_uv_change;
	}

	vec3 object_uv_change = base_velocity - camera_uv_change.xyz;

	vec3 total_velocity =
		camera_rotation_uv_change * params.rotation_velocity_multiplier *
			sharp_step(
				params.rotation_velocity_lower_threshold,
				params.rotation_velocity_upper_threshold,
				length(camera_rotation_uv_change.xy) * params.rotation_velocity_multiplier * params.motion_blur_intensity
			) +
		camera_movement_uv_change * params.movement_velocity_multiplier *
			sharp_step(
				params.movement_velocity_lower_threshold,
				params.movement_velocity_upper_threshold,
				length(camera_movement_uv_change.xy) * params.movement_velocity_multiplier * params.motion_blur_intensity
			) +
		object_uv_change * params.object_velocity_multiplier *
			sharp_step(
				params.object_velocity_lower_threshold,
				params.object_velocity_upper_threshold,
				length(object_uv_change.xy) * params.object_velocity_multiplier * params.motion_blur_intensity
			);

	if (dot(object_uv_change.xy, object_uv_change.xy) > 0.000001) {
		total_velocity.z = 0.0;
		base_velocity.z = 0.0;
	}

	if (dot(total_velocity.xy * 99.0, total_velocity.xy * 100.0) >= dot(base_velocity.xy * 100.0, base_velocity.xy * 100.0)) {
		total_velocity = base_velocity;
	}

	float total_velocity_length = max(FLT_MIN, length(total_velocity.xy));
	total_velocity = total_velocity * clamp(total_velocity_length, 0.0, 1.0) / total_velocity_length;

	imageStore(
		vector_output,
		uvi,
		vec4(
			total_velocity * (view_past_ndc_cache.w < 0.0 ? -1.0 : 1.0),
			depth == 0.0 ? (-1.0 / 0.0) : view_position.z
		)
	);

#ifdef DEBUG
	vec2 velocity = textureLod(vector_sampler, uvn, 0.0).xy;
	float velocity_length = length(velocity);
	velocity = velocity * clamp(velocity_length, 0.0, 10.0) / max(FLT_MIN, velocity_length);
	imageStore(debug_6_image, uvi, vec4(velocity * (view_past_ndc_cache.w < 0.0 ? -1.0 : 1.0), view_past_ndc_cache.w < 0.0 ? 1.0 : 0.0, 1.0));
	imageStore(debug_7_image, uvi, vec4(camera_uv_change.xy, 0.0, 1.0));
#endif
}