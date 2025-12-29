#[compute]
#version 450

#define FLT_MAX 3.402823466e+38
#define FLT_MIN 1.175494351e-38
#define M_PI 3.1415926535897932384626433832795

layout(set = 0, binding = 0) uniform sampler2D color_sampler;
layout(set = 0, binding = 1) uniform sampler2D velocity_sampler;
layout(set = 0, binding = 2) uniform sampler2D neighbor_max;
layout(set = 0, binding = 3) uniform sampler2D tile_variance;
layout(rgba16f, set = 0, binding = 4) uniform writeonly image2D output_color;


layout(push_constant, std430) uniform Params 
{	
	float minimum_user_threshold;
	float importance_bias;
	float maximum_jitter_value;
	float motion_blur_intensity;
	int tile_size;
	int sample_count;
	int frame;
	int nan4;
} params;

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

// Guertin's functions https://research.nvidia.com/sites/default/files/pubs/2013-11_A-Fast-and/Guertin2013MotionBlur-small.pdf
// ----------------------------------------------------------
float z_compare(float a, float b, float sze)
{
	return clamp(1. - sze * (a - b), 0, 1);
}
// ----------------------------------------------------------

// from https://www.shadertoy.com/view/ftKfzc
// ----------------------------------------------------------
float interleaved_gradient_noise(vec2 uv){
	uv += float(params.frame)  * (vec2(47, 17) * 0.695);

    vec3 magic = vec3( 0.06711056, 0.00583715, 52.9829189 );

    return fract(magic.z * fract(dot(uv, magic.xy)));
}
// ----------------------------------------------------------

// from https://github.com/bradparks/KinoMotion__unity_motion_blur/tree/master
// ----------------------------------------------------------
vec2 safenorm(vec2 v)
{
	float l = max(length(v), 1e-6);
	return v / l * int(l >= 0.5);
}

vec2 jitter_tile(vec2 uvi)
{
	float rx, ry;
	float angle = interleaved_gradient_noise(uvi + vec2(2, 0)) * M_PI * 2;
	rx = cos(angle);
	ry = sin(angle);
	return vec2(rx, ry) / textureSize(neighbor_max, 0) / 4;
}
// ----------------------------------------------------------

void main() 
{
	// The size of the output texture
	ivec2 render_size = ivec2(textureSize(color_sampler, 0));

	// Resolution of neighbor max texture (max velocity tiles)
	ivec2 tile_render_size = ivec2(textureSize(neighbor_max, 0));

	// The pixel we are running the shader for.
	ivec2 uvi = ivec2(gl_GlobalInvocationID.xy);

	// If the pixel we are in is outside the target render's size, we 
	// exit early
	if ((uvi.x >= render_size.x) || (uvi.y >= render_size.y)) 
	{
		return;
	}

	// We convert the pixel position into a texturing sampling position
	// we add 0.5 to offset the sampling to be in the "middle" of the pixel
	// and avoid artifacts caused by bilinear interpolation.
	vec2 x = (vec2(uvi) + vec2(0.5)) / vec2(render_size);

	// We get the neighbor-max velocity for the tile we are in, with some jitter
	// between tiles to hide seams between them.
	// We then multiply the velocity by the render size to get its magnitude
	// in pixels. We also mulitply it by the blur intensity factor.
	// TODO @sphynx-owner: figure out whether adding half a tile size to x is 
	// correct. 
	vec4 vnzw =  textureLod(neighbor_max, x + vec2(0.5) / vec2(tile_render_size) + jitter_tile(uvi), 0.0) * vec4(render_size / 2., 1, 1) * params.motion_blur_intensity;

	// We get the xy components of the max tile velocity. Velocities can have a z
	// component too (we generate it in the pre-blur processing stage for stationary
	// elements), but it is used separately and does not express itself visually in the
	// blur (it represents the movement of elements towards the camera, which means
	// they don't visually move).
	vec2 vn = vnzw.xy;

	float vn_length = length(vn);

	vec4 base_color = textureLod(color_sampler, x, 0.0);

	// We get the true velocity at the current pixel, mulitplied by the motion blur intensity.
	vec4 vxzw = textureLod(velocity_sampler, x, 0.0) * vec4(render_size / 2., 1, 1) * params.motion_blur_intensity;

	if(vn_length < 0.5)
	{
		imageStore(output_color, uvi, base_color);
#ifdef DEBUG
		imageStore(debug_1_image, uvi, base_color);
		imageStore(debug_2_image, uvi, vec4(vn / render_size * 2, 0, 1));
		imageStore(debug_3_image, uvi, vec4(vxzw.xy / render_size * 2, 0, 1));
		imageStore(debug_4_image, uvi, vec4(0));
#endif
		return;
	}

	// We normalize neighbor-max velocity
	vec2 wn = safenorm(vn);

	// We get the xy components of the true velocity (see declaration of vn)
	vec2 vx = vxzw.xy;

	float vx_length = max(0.5, length(vx));

	vec2 wx = safenorm(vx);
	
	// We get some random value for the current pixel. This will be used to
	// jitter the blur sampling, and achieve smoother looking blur gradient
	// with a fraction of the sample count.
	float j = interleaved_gradient_noise(uvi) * 2. - 1.;

	// Get the depth at current pixel
	float zx = vxzw.w;

	// A safe initial weight close to 0
	float weight = 1e-6;

	// Create an initial color sum
	vec4 sum = base_color * weight;

	// This is a naive weight, averaging data using the true velocity
	float nai_weight = 1e-6;
	
	// This is a naive sum, averaging data using the true velocity
	vec4 nai_sum = base_color * nai_weight;

	for(int i = 0; i < params.sample_count; i++)
	{
		// A point in time along the blur interval, used to scale velocity vectors to sample for color.
		float t = mix(-1.0, 1.0, (i + j * params.maximum_jitter_value + 1.0) / (params.sample_count + 1.0));
		
		// We alternate arbitrarily between using the true velocity and the neighbor max velocity.
		bool use_vn = ((i % 2) == 0);

		// Velocity vector to use for sampling
		vec2 d = use_vn ? vn : vx;

		// Depth component of the velocity vector to use for sampling
		float dz = use_vn ? vnzw.z : vxzw.z;

		// Normalized vector to use for sampling
		vec2 wd = use_vn ? wn : wx;

		// magnitude of sample offset?
		// TODO @sphynx-owner: figure out why vn_length and not d
		float T = abs(t * length(d));

		// Get sample point
		vec2 y = x + t * d / vec2(render_size);

		// how much does the true velocity's direction match the sampling offset?
		float wa = abs(dot(wx, wd));
		
		// Get the true velocity at the sample point.
		vec4 vyzw = textureLod(velocity_sampler, y, 0.0) * vec4(render_size / 2, 1, 1) * params.motion_blur_intensity;
		
		// Get the xy component of the velocity at the sample point
		// TODO @sphynx-owner: what? why are we subtracting a float from the vector?
		vec2 vy = vyzw.xy; 

		// Get length of true velocity at sample point
		float vy_length = max(0.5, length(vy));

		vec2 wy = safenorm(vy);

		// Get the depth at the sample point.
		float zy = vyzw.w - dz * t;

		// If we are using the neighbor max velocity to sample, we
		// feed the result of overlapping velocities into 
		// an overlay color sum.
		if(use_vn)
		{
			// Whether the velocity at the sample point reaches in front
			// of the current pixel's geometry.
			float f = z_compare(-zy, -zx, 20000);

			// How aligned is the velocity at the sample point with 
			// the sampling direction.
			float wb = abs(dot(wy, wd));

			// If the velocity at the sample point reaches the current
			// pixel and overlaps in front of it, we add color to the overlay sum.
			float ay = f * step(T, vy_length * wb);

			weight += ay; 

			sum += textureLod(color_sampler, y, 0.0) * ay;
		}

		// Whether the velocity at the sample point falls behind the current
		// pixel's geometry.
		float b = z_compare(-zx, -zy, 20000);

		// If the true velocity at the current pixel reaches the sample point,
		// and it is either the same or behind current geometry, we add color at the sample
		// point to the base color sum.
		float nai_ay = b * step(T, vx_length * wa);

		nai_weight += nai_ay;

		nai_sum += textureLod(color_sampler, y, 0.0) * nai_ay;
	}

	sum /= weight;

	weight /= params.sample_count;

	nai_sum /= nai_weight;

	sum = mix(nai_sum, sum, weight);

	imageStore(output_color, uvi, sum);
#ifdef DEBUG
	imageStore(debug_1_image, uvi, base_color);
	imageStore(debug_2_image, uvi, vec4(vn / render_size * 2, 0, 1));
	imageStore(debug_3_image, uvi, vec4(vx / render_size * 2, 0, 1));
	imageStore(debug_4_image, uvi, vxzw);
#endif
}