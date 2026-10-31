shader_type spatial;
// Placeholder territory overlay: moving diagonal stripes in the side's colour, as in the design's
// deployment boards. World units are inches.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 stripe_color : source_color = vec4(0.376, 0.62, 0.886, 0.42);
uniform vec4 gap_color : source_color = vec4(0.239, 0.455, 0.659, 0.16);
// Stripe period in inches.
uniform float period = 1.0;
// Inches per second the stripes move; negative moves them the other way.
uniform float speed = 0.5;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = fract((world_position.x + world_position.z + TIME * speed) / period);
	vec4 color = t < 0.5 ? stripe_color : gap_color;
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
