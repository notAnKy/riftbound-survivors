shader_type canvas_item;

// A hard dark outline round every actor.
//
// This is most of what makes a sprite read against a floor: without it the
// silhouette dissolves into whatever it is standing on, and the fix is not more
// detail in the art, it is a line round the outside of it.
//
// The sprite is inset into its own frame first. Kenney's art often runs to the
// edge of its texture, and an outline drawn only where the texture is already
// transparent would have nowhere to go on those sides.

uniform vec4 outline_color : source_color = vec4(0.04, 0.035, 0.07, 1.0);
uniform float width : hint_range(0.0, 8.0) = 2.4;

// Carried from the vertex stage because assigning COLOR in fragment() throws
// away the node's modulate, which is what tints an enemy and flashes it on hit.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

// Outside the frame reads as empty rather than as a smeared edge pixel. Written
// inline rather than as a helper: passing TEXTURE into a function makes Godot
// treat it as a custom sampler and complain on every compile.
void fragment() {
	vec2 grow = TEXTURE_PIXEL_SIZE * width;
	float inset = 1.0 - 2.0 * max(grow.x, grow.y);
	vec2 uv = (UV - 0.5) / inset + 0.5;

	vec2 safe = clamp(uv, vec2(0.0), vec2(1.0));
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	float here = texture(TEXTURE, safe).a * inside;
	// Eight samples on a ring: enough for a smooth line at this thickness, and
	// cheap enough to run on several hundred enemies at once.
	float ring = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7853981;
		vec2 at = uv + vec2(cos(a), sin(a)) * grow;
		float on = step(0.0, at.x) * step(at.x, 1.0) * step(0.0, at.y) * step(at.y, 1.0);
		ring = max(ring, texture(TEXTURE, clamp(at, vec2(0.0), vec2(1.0))).a * on);
	}
	// Written as a branch rather than an early exit: Godot's shading language
	// does not allow `return` inside a processor function.
	if (here > 0.5) {
		COLOR = texture(TEXTURE, safe) * tint;
	} else {
		COLOR = vec4(outline_color.rgb, outline_color.a * smoothstep(0.15, 0.6, ring) * tint.a);
	}
}
