shader_type canvas_item;
// Diagonal stripes in a rounded box with a border: the design's placeholder for unit and army art.

uniform vec2 size = vec2(52.0);
uniform vec4 stripe_color : source_color = vec4(0.145, 0.161, 0.192, 1.0);
uniform vec4 gap_color : source_color = vec4(0.125, 0.141, 0.169, 1.0);
uniform vec4 border_color : source_color = vec4(0.204, 0.227, 0.271, 1.0);
uniform float stripe_width = 8.0;
uniform float radius = 8.0;
uniform float border_width = 1.0;

// Signed distance from p to a box of half-size b with rounded corners of radius r.
float rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 pixel = UV * size;
	float stripe = step(stripe_width, mod(pixel.x + pixel.y, stripe_width * 2.0));
	vec4 fill = mix(stripe_color, gap_color, stripe);
	float distance = rounded_box(pixel - size * 0.5, size * 0.5, min(radius, min(size.x, size.y) * 0.5));
	vec4 color = mix(fill, border_color, step(-border_width, distance));
	COLOR = vec4(color.rgb, color.a * clamp(0.5 - distance, 0.0, 1.0));
}
