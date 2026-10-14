// 핍-보이 CRT 단색(SD-12 §3.11 인물 수첩 얼굴 · §2 화면 체계): 그림의 밝기만 남겨 초록 명암으로 칠한다.
shader_type canvas_item;

uniform vec4 dark : source_color = vec4(0.043, 0.122, 0.063, 1.0);   // U[1]
uniform vec4 light : source_color = vec4(0.486, 0.941, 0.557, 1.0);  // U[6]

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	l = floor(clamp(l * 1.15, 0.0, 1.0) * 5.0 + 0.5) / 5.0;          // 6단 명암(도트 화면 느낌)
	COLOR = vec4(mix(dark.rgb, light.rgb, l), c.a * COLOR.a);
}
