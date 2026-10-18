// 바닥 합성 셰이더 v2 — 쯔꾸르풍(SD-16 §6.10). art/tools/ground.py GroundSet.render와 정수 단위로 같은 식이다(ground_check로 대조).
// 재질 텍스처를 월드 픽셀 좌표로 읽고, 가까운 타일 중심 4곳의 이중선형 가중치 + 재질별 매끈한 큰 얼룩 잡음으로 재질을 고른다(물결 경계).
// 경계는 쯔꾸르 오토타일처럼: 위 재질은 테두리(rim), 아래 재질은 그늘(shade). 그늘·그림자는 또렷한 띠·타원(디더 없음).
// 색을 섞지 않고 아틀라스 텍셀 하나를 고르므로 결과는 늘 팔레트 안 색이다.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D id_map : filter_nearest;      // RGBA8: R = 바닥 타일 아틀라스 번호, G = 덮개(아래 2비트: 0 없음, 1 벽, 2 소품, 3 평평한 구조물) + 도로 위계(위 3비트),
                                                // B · A = 칸 왼쪽 위 꼭짓점의 연석선 · 보도 바깥선 거리(1/16칸, 96 = 0 — 도로 경계 v3). 한 칸 테두리 포함
uniform sampler2D atlas : filter_nearest;       // 재질 × [A, B, A어둠, B어둠, A더어둠, B더어둠], 칸 cell×cell
uniform sampler2D decals : filter_nearest;      // 잔 소품 32×32 가로 줄, 아래 32줄은 어둠 벌
uniform sampler2D noise : filter_nearest;       // 256×256, R 큰 얼룩(경계 물결) · B 아주 큰 얼룩(A·B 벌)
uniform ivec2 origin;                           // id_map (1,1) 칸의 월드 타일
uniform ivec2 map_size;                         // id_map 크기(테두리 포함)
uniform int cell = 256;
uniform int mat_of[64];
uniform int force[64];
uniform int spread[16];
uniform int pri[16];
uniform int rim[16];
uniform int shade[16];
uniform int vthr[16];
uniform int dens[16];
uniform int hard[16];
uniform int soft[16];
uniform int curb[16];                            // 연석 띠(px): 낮은 재질과 만나는 가장자리(보도 — 1-R v2) · 색은 curb_rgb(팔레트 그대로)
uniform ivec3 curb_rgb[10];                           // 연석 넷 + 그늘 넷 + 중앙선 · 그늘(도로 경계 v3)
uniform int rd_mat[4];                                 // 도로 경계 v3: 차도 · 보도 · 분리대 화단 · 콘크리트(측구 · 골목) 재질
uniform int rd_car[8];                                 // 위계별 차도 반폭(px)
uniform int rd_med[8];                                 // 위계별 분리대 반폭(px, 0 없음)
uniform int rd_curb = 4;
uniform int rd_gut = 3;                                // 동네 길 측구 폭(px)
uniform int boff[32];
uniform int dlist[128];
uniform int dcount[16];

varying vec2 lp;

const int NEG = -1000000000;

void vertex() {
	lp = VERTEX;
}

ivec2 cell_at(int tx, int ty) {
	ivec2 p = clamp(ivec2(tx - origin.x + 1, ty - origin.y + 1), ivec2(0), map_size - ivec2(1));
	vec4 c = texelFetch(id_map, p, 0);
	return ivec2(int(round(c.r * 255.0)), int(round(c.g * 255.0)) & 3);
}

ivec4 raw_at(int tx, int ty) {
	ivec2 p = clamp(ivec2(tx - origin.x + 1, ty - origin.y + 1), ivec2(0), map_size - ivec2(1));
	vec4 c = texelFetch(id_map, p, 0);
	return ivec4(round(c * 255.0));
}

bool is_rd(int m) {
	return m == rd_mat[0] || m == rd_mat[1];
}

bool is_rdl(int m) {
	return m == rd_mat[0] || m == rd_mat[1] || m == rd_mat[3];
}

ivec2 nz(int x, int y) {
	vec4 c = texelFetch(noise, ivec2(x & 255, y & 255), 0);
	return ivec2(int(round(c.r * 255.0)), int(round(c.b * 255.0)));
}

bool low_nb(int x, int y, int m0) {
	ivec2 c = cell_at(x, y);
	return pri[mat_of[c.x]] < pri[m0] && c.y != 1 && c.y != 3;
}

uint thash(int tx, int ty) {
	uint h = (uint(tx) * 0x8DA6B343u) ^ (uint(ty) * 0xD8163841u);
	h ^= h >> 13u;
	h *= 0x85EBCA6Bu;
	h ^= h >> 16u;
	return h;
}

// 동네 길 · 콘크리트 골목(위계 6): B = 길 가장자리 거리, A = 골목 가장자리 거리 — 곧은 가장자리 + 길 쪽 측구(파이썬 render와 같은 식)
void road_local(int X, int Y, int tx, int ty, int fx, int fy, int m0, ivec4 r00, ivec4 r10, ivec4 r01, ivec4 r11, bool walld,
		inout int win_m, inout bool dark, inout bool curb_on) {
	int ex1 = 2 * fx + 1;
	int ey1 = 2 * fy + 1;
	int ex0 = 64 - ex1;
	int ey0 = 64 - ey1;
	int L = ex0 * ey0 * (r00.b - 96) + ex1 * ey0 * (r10.b - 96) + ex0 * ey1 * (r01.b - 96) + ex1 * ey1 * (r11.b - 96);
	int LA = ex0 * ey0 * (r00.a - 96) + ex1 * ey0 * (r10.a - 96) + ex0 * ey1 * (r01.a - 96) + ex1 * ey1 * (r11.a - 96);
	const int K = 2048;
	bool st = L < 0;
	bool gut = L >= 0 && L < rd_gut * K;
	bool al = !st && !gut && LA < 0;
	bool lout = !st && !gut && !al;
	bool useb = L <= LA;
	int gx = useb ? (r10.b + r11.b) - (r00.b + r01.b) : (r10.a + r11.a) - (r00.a + r01.a);
	int gy = useb ? (r01.b + r11.b) - (r00.b + r10.b) : (r01.a + r11.a) - (r00.a + r10.a);
	bool hx = abs(gx) >= abs(gy);
	int l_out = mat_of[cell_at(tx + (hx ? sign(gx) : 0), ty + (hx ? 0 : sign(gy))).x];
	int sub = is_rdl(m0) ? l_out : m0;
	if (is_rdl(sub)) sub = 0;
	if (st) win_m = rd_mat[0];
	if (gut || al) win_m = rd_mat[3];
	if (lout && is_rdl(win_m)) win_m = sub;
	dark = walld || (gut && L < K) || (al && LA >= -K) || (lout && dark);
	curb_on = false;
}

void fragment() {
	int X = origin.x * 32 + int(floor(lp.x));
	int Y = origin.y * 32 + int(floor(lp.y));
	int tx = X >> 5;
	int ty = Y >> 5;
	int fx = X & 31;
	int fy = Y & 31;
	ivec2 own = cell_at(tx, ty);
	int m0 = mat_of[own.x];
	bool hard0 = hard[m0] == 1;

	int ax = (X - 16) >> 5;
	int ay = (Y - 16) >> 5;
	int u = (X - 16) - ax * 32;
	int v = (Y - 16) - ay * 32;
	int wx1 = 2 * u + 1;
	int wy1 = 2 * v + 1;
	int wx0 = 64 - wx1;
	int wy0 = 64 - wy1;
	int mats[4];
	int ws[4];
	ivec2 cxy[4] = ivec2[](ivec2(ax, ay), ivec2(ax + 1, ay), ivec2(ax, ay + 1), ivec2(ax + 1, ay + 1));
	ws[0] = wx0 * wy0;
	ws[1] = wx1 * wy0;
	ws[2] = wx0 * wy1;
	ws[3] = wx1 * wy1;
	for (int k = 0; k < 4; k++) {
		ivec2 c = cell_at(cxy[k].x, cxy[k].y);
		mats[k] = (c.y == 1 || c.y == 3) ? m0 : mat_of[c.x]; // 벽·구조물에 덮인 바닥은 섞지 않는다
	}
	int raw[4];
	int sc[4];
	for (int k = 0; k < 4; k++) {
		int mk = mats[k];
		int W = 0;
		for (int j = 0; j < 4; j++) {
			W += mats[j] == mk ? ws[j] : 0;
		}
		int n = 3 * (nz(X + ((mk * 73) & 255), Y + ((mk * 151) & 255)).x - 128);
		raw[k] = 3 * W + spread[mk] * n;
		sc[k] = (hard[mk] == 1 && mk != m0) ? NEG : raw[k];
	}
	int best_s = NEG;
	int best_m = 99;
	int own_s = NEG;
	for (int k = 0; k < 4; k++) {
		if (sc[k] > best_s || (sc[k] == best_s && mats[k] < best_m)) {
			best_s = sc[k];
			best_m = mats[k];
		}
		if (mats[k] == m0) {
			own_s = max(own_s, raw[k]);
		}
	}
	int win_m = hard0 ? m0 : best_m;
	int win_s = hard0 ? own_s : best_s;
	int second = NEG;
	int sec_m = 99;
	for (int k = 0; k < 4; k++) {
		if (mats[k] != win_m && (raw[k] > second || (raw[k] == second && mats[k] < sec_m))) {
			second = raw[k];
			sec_m = mats[k];
		}
	}
	bool dark = false;
	bool deep = false;
	bool curb_on = false;
	int ck = 1;
	if (second != NEG) {
		int margin = win_s - second;
		int pw = pri[win_m];
		int ps = pri[sec_m];
		// 쯔꾸르 오토타일: 위 재질은 테두리, 아래 재질은 (위 재질이 테두리를 가질 때만) 그늘, 같은 높이(실내 이음매)는 그늘
		int band = pw > ps ? rim[win_m] : ((pw == ps || rim[sec_m] > 0) ? shade[win_m] : 0);
		bool both_soft = soft[win_m] == 1 && soft[sec_m] == 1;
		if (both_soft) band = 0;
		dark = band > 0 && margin < band * 768 && curb[win_m] == 0;       // 연석 재질은 연석 띠가 테두리를 대신한다

		if (both_soft && margin < 7680) {                                  // 경계에서 10px 안쪽: 50% → 0% 디더 섞기
			int p_mix = ((7680 - margin) * 128) / 7680;
			int hp = int((thash(X >> 1, Y >> 1) >> 5u) & 255u);
			if (hp < p_mix) win_m = sec_m;
		}
	}
	int fn = cell_at(tx, ty - 1).y;
	if (fn == 1 && fy < 2) deep = true;                                // 벽 발치 그늘(또렷한 2단 띠)
	if (fn == 1 && fy < 5) dark = true;
	if (cell_at(tx - 1, ty).y == 1 && fx < 2) dark = true;
	if (cell_at(tx + 1, ty).y == 1 && fx > 29) dark = true;
	int q0 = (fx - 16) * (fx - 16) * 36 + (fy - 29) * (fy - 29) * 169;   // 소품 그림자 타원(아래 타일로 3px 넘친다)
	int q1 = (fx - 16) * (fx - 16) * 36 + (fy + 3) * (fy + 3) * 169;
	if ((own.y == 2 && q0 <= 6084) || (fn == 2 && q1 <= 6084)) dark = true;

	int cw = curb[m0];
	if (cw > 0 && win_m == m0) {                                          // 연석(1-R v2): 낮은 이웃 타일 쪽 가장자리에서 cw px — 곧은 띠 · 바깥 모서리 네모
		int dd = 99;
		bool lN = low_nb(tx, ty - 1, m0);
		bool lS = low_nb(tx, ty + 1, m0);
		bool lW = low_nb(tx - 1, ty, m0);
		bool lE = low_nb(tx + 1, ty, m0);
		if (lN) dd = min(dd, fy);
		if (lS) dd = min(dd, 31 - fy);
		if (lW) dd = min(dd, fx);
		if (lE) dd = min(dd, 31 - fx);
		if (!lN && !lW && low_nb(tx - 1, ty - 1, m0)) dd = min(dd, max(fx, fy));
		if (!lN && !lE && low_nb(tx + 1, ty - 1, m0)) dd = min(dd, max(31 - fx, fy));
		if (!lS && !lW && low_nb(tx - 1, ty + 1, m0)) dd = min(dd, max(fx, 31 - fy));
		if (!lS && !lE && low_nb(tx + 1, ty + 1, m0)) dd = min(dd, max(31 - fx, 31 - fy));
		if (dd < cw) {
			curb_on = true;
			ck = dd == 0 ? 0 : (dd == cw - 1 ? 3 : (int((thash(X, Y) >> 7u) & 7u) == 0 ? 2 : 1));
		}
	}
	bool walld = deep || (fn == 1 && fy < 5) || (cell_at(tx - 1, ty).y == 1 && fx < 2) || (cell_at(tx + 1, ty).y == 1 && fx > 29)
		|| (own.y == 2 && q0 <= 6084) || (fn == 2 && q1 <= 6084);
	// 도로 경계 v3(리드 지시 2026-10-18): 간선 둘레 칸 — 꼭짓점 거리 이중선형 → 차도 · 배수 그늘 · 연석 · 같은 폭 보도 · 바깥 테 · 분리대 · 노란 겹 중앙선
	bool paint = false;
	ivec3 pc = ivec3(0);
	ivec4 r00 = raw_at(tx, ty);
	int rc = (r00.g >> 2) & 7;
	if (rc > 0) {
		ivec4 r10 = raw_at(tx + 1, ty);
		ivec4 r01 = raw_at(tx, ty + 1);
		ivec4 r11 = raw_at(tx + 1, ty + 1);
		if (rc == 6) {
			rc = 0;
			road_local(X, Y, tx, ty, fx, fy, m0, r00, r10, r01, r11, walld, win_m, dark, curb_on);
		}
	}
	if (rc > 0) {
		ivec4 r10 = raw_at(tx + 1, ty);
		ivec4 r01 = raw_at(tx, ty + 1);
		ivec4 r11 = raw_at(tx + 1, ty + 1);
		int ex1 = 2 * fx + 1;
		int ey1 = 2 * fy + 1;
		int ex0 = 64 - ex1;
		int ey0 = 64 - ey1;
		int EE = ex0 * ey0 * (r00.b - 96) + ex1 * ey0 * (r10.b - 96) + ex0 * ey1 * (r01.b - 96) + ex1 * ey1 * (r11.b - 96);
		int SS = ex0 * ey0 * (r00.a - 96) + ex1 * ey0 * (r10.a - 96) + ex0 * ey1 * (r01.a - 96) + ex1 * ey1 * (r11.a - 96);
		const int K = 2048;
		int mh = rd_med[rc];
		int h2 = rd_car[rc] / 2;                                           // 꼭짓점이 중앙선 어느 쪽(덮개 바이트 5비트) — 부호 있는 거리로 이어 분리대 · 중앙선이 곧다
		int c = abs(ex0 * ey0 * (1 - 2 * ((r00.g >> 5) & 1)) * (r00.b - 96 + h2) + ex1 * ey0 * (1 - 2 * ((r10.g >> 5) & 1)) * (r10.b - 96 + h2)
			+ ex0 * ey1 * (1 - 2 * ((r01.g >> 5) & 1)) * (r01.b - 96 + h2) + ex1 * ey1 * (1 - 2 * ((r11.g >> 5) & 1)) * (r11.b - 96 + h2));
		bool road = EE < 0;
		bool med = road && mh > 0 && c < mh * K;
		int m_in = mh * K - c;
		bool med_curb = med && m_in < 2 * K;
		bool cline = road && !med && mh == 0 && rc <= 4 && c >= K && c < 3 * K && nz(X >> 2, Y >> 2).x >= 70;
		bool gutter = road && !med && EE >= -2 * K;
		bool kerb = EE >= 0 && EE < rd_curb * K;
		bool walk = EE >= rd_curb * K && SS < 0;
		bool edging = walk && SS >= -K;
		bool outside = !road && !kerb && !walk;
		int gx = (r10.a + r11.a) - (r00.a + r01.a);
		int gy = (r01.a + r11.a) - (r00.a + r10.a);
		bool hx = abs(gx) >= abs(gy);
		int m_out = mat_of[cell_at(tx + (hx ? sign(gx) : 0), ty + (hx ? 0 : sign(gy))).x];
		int sub = is_rd(m0) ? m_out : m0;
		if (is_rd(sub)) sub = 0;
		if (road && !med) win_m = rd_mat[0];
		if (med) win_m = rd_mat[2];
		if (walk) win_m = rd_mat[1];
		if (outside && is_rd(win_m) && ((r00.g >> 6) & 1) == 0) win_m = sub;   // 동네 길 칸(6비트)의 보도 바깥 아스팔트는 그 길 몫
		dark = walld || gutter || edging || (outside && dark);
		curb_on = false;
		int wd = walld ? 4 : 0;
		if (kerb) {
			int kd = EE / K;
			int kk = kd == 0 ? 0 : (kd == rd_curb - 1 ? 3 : (int((thash(X, Y) >> 7u) & 7u) == 0 ? 2 : 1));
			pc = curb_rgb[kk + wd];
			paint = true;
		}
		if (med_curb) {
			pc = curb_rgb[(m_in / K == 0 ? 0 : 1) + wd];
			paint = true;
		}
		if (cline) {
			pc = curb_rgb[8 + (walld ? 1 : 0)];
			paint = true;
		}
	}
	int oxw = (win_m * 73) & 255;
	int oyw = (win_m * 151) & 255;
	int var = nz(X + oxw, Y + oyw).y > vthr[win_m] ? 1 : 0;
	int col = var + (deep ? 4 : (dark ? 2 : 0));
	int bx = boff[win_m * 2] * var;
	int by = boff[win_m * 2 + 1] * var;
	vec4 outc = texelFetch(atlas, ivec2(col * cell + ((X + bx) & (cell - 1)), win_m * cell + ((Y + by) & (cell - 1))), 0);
	if (curb_on) {
		ivec3 cc = curb_rgb[ck + (walld ? 4 : 0)];
		outc = vec4(vec3(cc) / 255.0, 1.0);
	}
	if (paint) {
		outc = vec4(vec3(pc) / 255.0, 1.0);
	}

	uint h = thash(tx, ty);
	int fo = force[own.x];
	bool has = win_m == m0 && !paint && (fo >= 0 || (int(h & 255u) < dens[m0] && dcount[m0] > 0));
	if (has) {
		int di = fo;
		int dox = 0;
		int doy = 0;
		int flip = 0;
		if (fo < 0) {
			di = dlist[m0 * 8 + int((h >> 8u) % uint(max(dcount[m0], 1)))];
			dox = int((h >> 16u) & 7u) - 4;
			doy = int((h >> 19u) & 7u) - 4;
			flip = int((h >> 22u) & 1u);
		}
		int sx = fx - dox;
		int sy = fy - doy;
		if (flip == 1) sx = 31 - sx;
		if (sx >= 0 && sx < 32 && sy >= 0 && sy < 32) {
			vec4 dc = texelFetch(decals, ivec2(di * 32 + sx, sy + ((dark || deep) ? 32 : 0)), 0);
			if (dc.a > 0.5) outc = dc;
		}
	}
	COLOR = vec4(outc.rgb, 1.0);
}
