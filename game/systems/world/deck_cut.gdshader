// 고가 상판 가림(SD-16 §6.5 '인물이 그 뒤로 들어가면 가리는 부분을 50% 투명(디더 체커)'):
// 주인공이 상판 아래(층 0 그늘)나 상판 남쪽 끝 바로 앞에 서면 몸 둘레 40px는 비우고, 그 밖 반경은 2px 체커(50%), 가장자리 1/4은 25%만 비워 경계를 흐린다.
// 반투명 대신 디더 — 팔레트 밖 색이 생기지 않는다. 좌표는 월드 픽셀(카메라와 무관하게 무늬가 땅에 붙는다).
shader_type canvas_item;
uniform vec2 hole = vec2(-99999.0, -99999.0);
uniform float radius = 0.0;
varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (radius > 0.0) {
		float d = distance(wpos, hole);
		if (d < radius) {
			vec2 q = floor(wpos / 2.0);
			float odd = mod(q.x + q.y, 2.0);
			if (d < 40.0) {
				discard;                                       // 주인공 몸 둘레는 완전히 비운다(디더에 섞여 몸이 안 보이지 않게)
			} else if (d < radius * 0.75) {
				if (odd > 0.5) discard;
			} else if (odd > 0.5 && mod(q.x, 2.0) < 0.5) {
				discard;
			}
		}
	}
}
