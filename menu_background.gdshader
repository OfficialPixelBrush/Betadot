shader_type canvas_item;

uniform float brightness = 0.5f;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
    vec2 tileSize = vec2(1.0 / 16.0);
    vec2 tileCoord = vec2(2.0, 0.0); // tile position in atlas
    float zoom = 3.0;
	
    vec2 uv = UV * zoom;
    uv = fract(uv);           // loop inside tile (cleaner than mod)
    uv *= tileSize;           // scale back to atlas size
    uv += tileCoord * tileSize; // offset to correct tile

    COLOR = texture(TEXTURE, uv)*vec4(brightness,brightness,brightness,1.0);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
