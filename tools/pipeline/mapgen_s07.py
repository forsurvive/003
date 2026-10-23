"""S-07 실내 맵 원고 초안 생성기 (단계 0-5, SD-09a §L-R01-01 ③). 방 사각형·문·출구·소품을 조합해 maps/s07/V-xx.map을 쓴다.
원고(.map)가 정본이다 — 이 스크립트는 처음 짤 때 칸 수를 틀리지 않게 돕는 도구이고, 손으로 고친 원고를 덮어쓰지 않도록
`--force` 없이는 이미 있는 파일을 건너뛴다.
벽 규칙(map_compile): 위아래 방 사이 벽 3줄(윗면·벽면 윗칸·벽면 아랫칸), 옆 방 사이 벽 1칸. 맵 맨 위 3줄·맨 아래 1줄은 벽."""
import os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "maps", "s07")


class M:
    def __init__(self, mid, name, w, h, note=""):
        self.id, self.name, self.w, self.h, self.note = mid, name, w, h, note
        self.g = [["#"] * w for _ in range(h)]
        self.cmds = []

    def room(self, x0, y0, x1, y1, ch="."):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.g[y][x] = ch
        return self

    def fill_if(self, x0, y0, x1, y1, ch, only="."):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if self.g[y][x] in only:
                    self.g[y][x] = ch

    def hguide(self, y, x0, x1):
        for x in range(x0, x1 + 1):
            self.g[y][x] = "+" if self.g[y][x] == "|" else "-"

    def vguide(self, x, y0, y1):
        for y in range(y0, y1 + 1):
            self.g[y][x] = "+" if self.g[y][x] == "-" else "|"

    def door(self, x, y_north_floor, kind=None, label=None, locked=False, ch="."):
        """위 방 바닥 끝줄 y_north_floor와 아래 방 사이 벽(3줄)에 문. 문 그림은 벽면 윗칸(y+2)."""
        for y in range(y_north_floor + 1, y_north_floor + 4):
            self.g[y][x] = ch
        args = f"door {x} {y_north_floor + 2}" + (f" kind={kind}" if kind else "") + (" locked" if locked else "") + \
            (f' "{label}"' if label else "")
        self.cmds.append(args)

    def arch(self, x0, x1, y_north_floor, ch="."):
        for y in range(y_north_floor + 1, y_north_floor + 4):
            for x in range(x0, x1 + 1):
                self.g[y][x] = ch

    def hole(self, x, y, ch="."):
        self.g[y][x] = ch

    def exit_n(self, x, y_top_floor, to, kind=None, label=None):
        """방 북벽(맨 위)으로 나가는 문: 벽 3줄을 뚫고 맨 윗줄이 출구."""
        for y in range(y_top_floor - 3, y_top_floor):
            self.g[y][x] = "."
        self.cmds.append(f"door {x} {y_top_floor - 2}" + (f" kind={kind}" if kind else "") + (f' "{label}"' if label else ""))
        self.cmds.append(f"exit {x} {y_top_floor - 3} {to} from_{self.id}")
        self.cmds.append(f"mark from_{to} {x} {y_top_floor} S")

    def exit_s(self, x, y_bottom_floor, to):
        for y in range(y_bottom_floor + 1, self.h):
            self.g[y][x] = "."
        self.cmds.append(f"exit {x} {self.h - 1} {to} from_{self.id}")
        self.cmds.append(f"mark from_{to} {x} {y_bottom_floor} N")

    def exit_w(self, y, x_left_floor, to):
        for x in range(0, x_left_floor):
            self.g[y][x] = "."
        self.cmds.append(f"exit 0 {y} {to} from_{self.id}")
        self.cmds.append(f"mark from_{to} {x_left_floor} {y} E")

    def exit_e(self, y, x_right_floor, to):
        for x in range(x_right_floor + 1, self.w):
            self.g[y][x] = "."
        self.cmds.append(f"exit {self.w - 1} {y} {to} from_{self.id}")
        self.cmds.append(f"mark from_{to} {x_right_floor} {y} W")

    def exit_at(self, x, y, to, mark_xy, mark_dir):
        """계단·덕트처럼 방 안 칸에서 나가는 출구."""
        self.cmds.append(f"exit {x} {y} {to} from_{self.id}")
        self.cmds.append(f"mark from_{to} {mark_xy[0]} {mark_xy[1]} {mark_dir}")

    def p(self, name, x, y):
        self.cmds.append(f"prop {name} {x} {y}")

    def c(self, line):
        self.cmds.append(line)

    def text(self):
        cmds = [c + ' cond="year() == 2277"' if c.startswith("npc ") and "cond=" not in c else c for c in self.cmds]
        out = [f"# {self.id} {self.name} — SD-09a §L-R01-01 ③. {self.note}".rstrip(), f"map {self.id} {self.name}", "set s07", "grid"]
        out += ["".join(r) for r in self.g]
        out += ["end", ""]
        out += cmds
        return "\n".join(out) + "\n"


# ---------------------------------------------------------------- V-08 의무과 (40×30) — MQ-P1 S1 무대
def v08():
    m = M("V-08", "의무과", 40, 30, "의무실(분만대, MQ-P1 S1)·진료소·약품 창고·격리실·대기실·냉동 안치실")
    m.room(1, 3, 12, 10, "o").room(14, 3, 25, 10, "o").room(27, 3, 38, 10, ".")      # 북쪽: 의무실·진료소·약품 창고
    m.room(1, 14, 38, 17, ".").hguide(16, 1, 38)                                       # 복도
    m.room(1, 21, 10, 27, "o").room(12, 21, 26, 27, ".").room(28, 21, 38, 27, "~")    # 남쪽: 격리실·대기실·안치실
    m.door(7, 10, label="의무실"); m.door(20, 10, label="진료소"); m.door(32, 10, label="약품")
    m.door(5, 17, label="격리"); m.arch(18, 20, 17); m.door(33, 17, label="안치")
    m.exit_s(19, 27, "V-01")
    # 의무실 — 견본 21_scene_birth 배치: 약장 둘(흔들인형)·세면대·링거대·분만 침대·아기 바구니·등록 단말 수레·칸막이·의무관 책상
    m.p("med_cabinet", 1, 3); m.p("med_cabinet", 2, 3); m.p("bobblehead", 2, 1); m.p("sink", 4, 3); m.p("wall_clock", 9, 1)
    m.p("iv_stand", 5, 4); m.p("birth_bed", 6, 4); m.p("bassinet", 7, 6); m.p("terminal_cart", 8, 4)
    m.p("screen_partition", 11, 3); m.p("exam_bed", 10, 5); m.p("clinic_desk", 2, 7); m.p("stool", 3, 8); m.p("file_cabinet", 12, 3)
    m.c("mark bed 6 5 S"); m.c("mark nurse 5 5 E"); m.c("mark bed_side 9 5 W"); m.c("mark terminal 8 5 N"); m.c("mark door 7 10 N")
    m.c("mark mother_end 6 7 S"); m.c("mark center 6 8 S")
    m.c('text 8 4 "세진 SJ-RT7 진공관 등록 단말. 6번 칸 \'관제망 회선 확인\'만 입력할 수 없게 막혀 있다."')
    m.c('text 6 4 "분만 침대. 시트에서 소독약 냄새가 난다." h=2')
    m.c('text 7 6 "신생아 바구니. 볼트 청색 담요가 개어 있다."')
    m.c('text 1 3 "약장. 붕대, 소독약, 이름표가 바랜 앰풀이 줄지어 있다."')
    m.c('text 2 3 "약장 위에 흔들인형 하나가 고개를 끄덕이고 있다. 안전모를 쓰고 구급함을 든 든든이다."')
    # 진료소
    m.p("exam_bed", 15, 4); m.p("exam_bed", 15, 8); m.p("curtain", 18, 4); m.p("med_cabinet", 24, 3); m.p("med_cabinet", 25, 3)
    m.p("desk", 21, 7); m.p("chair_n", 22, 8); m.p("wall_terminal", 20, 1); m.p("emblem", 17, 1)
    # 약품 창고
    for x in (27, 29, 31):
        m.p("crate_metal", x, 3)
    m.p("bookshelf", 35, 3); m.p("med_cabinet", 33, 3); m.p("med_cabinet", 34, 3); m.p("crate", 27, 6); m.p("crate", 28, 6)
    m.p("file_cabinet", 38, 3)
    m.c('text 35 3 "책장. 『응급 구조사 2급 문제집』이 꽂혀 있다." w=2')
    # 복도
    m.p("bench", 2, 14); m.p("water_cooler", 37, 14); m.p("planter", 12, 14); m.p("planter", 26, 14)
    m.c('sign 8 12 "의무실"'); m.c('sign 21 12 "진료소"'); m.c('sign 33 12 "약품 창고"')
    # 격리실
    m.p("exam_bed", 2, 23); m.p("exam_bed", 6, 23); m.p("wall_terminal", 8, 19); m.p("quarantine_sign", 2, 19); m.p("curtain", 2, 26)
    m.c('text 8 19 "격리실 단말: 2196 회색 열병 사망자 79명. 맨 아래 줄 — 격리 해제 2197-03."')
    # 대기실
    m.p("bench", 13, 23); m.p("bench", 13, 26); m.p("bench", 24, 23); m.p("bench", 24, 26); m.p("counter_clinic", 15, 22)
    m.p("planter", 22, 26); m.p("notice_board", 13, 19); m.p("slogan_crt2", 23, 19)
    # 안치실
    for x in (28, 31, 34):
        m.p("morgue_drawers", x, 21)
    m.p("exam_bed", 32, 25); m.p("sink", 38, 21)
    m.c('text 28 21 "냉동 안치실 서랍. 이름표 칸마다 같은 이름이 세대를 건너 되풀이된다." w=6')
    m.c('npc C-025 17 6 W route=진찰대:17,6,6;약장:23,4,4;창고:30,8,5;복도:20,15,3 bark="손 씻고 들어와. 여긴 의무과야."')
    return m


# ---------------------------------------------------------------- V-01 아트리움 (60×44)
def v01():
    m = M("V-01", "아트리움", 60, 44, "중앙 광장·성적 순위 게시판·공동 식당(돌잔치)·배급소·구내방송실")
    m.room(1, 3, 58, 26, ".")
    m.fill_if(1, 3, 58, 3, "="); m.fill_if(1, 3, 1, 26, "="); m.fill_if(58, 3, 58, 26, "=")
    m.fill_if(23, 11, 35, 18, "=")                                                          # 가운데 격자 마당
    m.hguide(15, 2, 57); m.vguide(29, 4, 26)
    m.room(1, 30, 30, 42, ",").room(32, 30, 46, 42, ".").room(48, 30, 58, 42, "c")      # 공동 식당·배급소·구내방송실
    m.arch(12, 16, 26, ","); m.door(39, 26, label="배급소"); m.door(53, 26, label="방송실")
    m.exit_n(29, 3, "V-00", label="정문"); m.exit_n(56, 3, "V-06", label="농장")
    m.exit_w(10, 1, "V-03"); m.exit_w(24, 1, "V-08"); m.exit_e(10, 58, "V-02"); m.exit_e(24, 58, "V-09")
    m.exit_s(8, 42, "V-04")
    # 북벽
    m.p("ration_window", 3, 1); m.p("emblem", 7, 1); m.p("slogan_crt", 10, 1); m.p("rank_board", 19, 1); m.p("wall_clock", 26, 1)
    m.p("slogan_crt3", 32, 1); m.p("booth_window", 37, 1); m.p("notice_board", 41, 1); m.p("emblem", 45, 1); m.p("wall_pipes", 48, 1)
    m.c('text 19 3 "제2277학년도 성적 순위. 가장자리에는 200년 치 이름 쪽지가 덧붙어 있다." w=6')
    m.c('text 3 3 "배급과 창구. 셔터가 반쯤 내려와 있다." w=2')
    # 광장
    for x, y in ((8, 8), (50, 8), (8, 21), (50, 21), (18, 8), (40, 8), (18, 21), (40, 21)):
        m.p("pillar", x, y)
    for x, y in ((24, 12), (33, 12), (24, 18), (33, 18)):                                 # 격자 마당 네 귀 화분
        m.p("planter", x, y)
    for x, y in ((26, 11), (31, 11), (26, 18), (31, 18)):
        m.p("bench", x, y)
    for x, y in ((12, 5), (44, 5), (12, 24), (44, 24)):
        m.p("planter", x, y)
    for x, y in ((3, 12), (3, 19), (55, 12), (55, 19)):
        m.p("bench", x, y)
    m.p("terminal_desk", 21, 13); m.p("terminal_desk", 37, 13)
    m.c('text 21 13 "안내 단말: 오늘의 배급 — 콩죽, 상추. 평가 일정 — 없음."'); m.c('text 37 13 "안내 단말: 출생 허가 대기 명단 열람 불가."')
    m.p("water_cooler", 57, 4); m.p("water_cooler", 2, 4)
    # 공동 식당
    for x in (3, 10, 17, 23):
        for y in (33, 37):
            if x == 23 and y == 37:
                continue
            m.p("canteen_table", x, y)
            for k in range(4):
                m.p("stool", x + k, y - 1)
                m.p("stool", x + k, y + 1)
    m.p("slogan_crt2", 3, 28); m.p("notice_board", 25, 28); m.p("water_cooler", 29, 30)
    # 2259 돌잔치(MQ-P1 S2·S3, SD-03a §7.1): 돌상·현수막·손님 6·윤정인·아기 하도윤, 밟는 칸 둘(하도윤이 기어 나옴 · 엄마 앞 돌잡이)
    era = 'cond="year() == 2259"'
    m.c(f"prop dol_table 24 40 {era}"); m.c(f"prop dol_banner 19 28 {era}")
    m.c("mark dol_mom 26 40 W"); m.c("mark dol_start 3 41 E"); m.c("mark doyun_block 9 40 W"); m.c("mark dol_front 23 41 E")
    m.c(f'npc C-001 26 40 W {era} bark="왔네. 엄마 여기 있어."')
    m.c(f'npc C-002 12 42 W look=K1-S3-HR00-H2-T01-0-PF11-HD00-EY00 {era} bark="까르르."')
    for nid, x, y, dd in (("N-R01-007", 5, 35, "S"), ("N-R01-008", 12, 35, "S"), ("N-R01-009", 19, 35, "S"),
                          ("N-R01-010", 8, 39, "N"), ("N-R01-020", 15, 39, "N"), ("N-R01-023", 20, 39, "N")):
        m.c(f"npc {nid} {x} {y} {dd} {era}")
    m.c(f'npc C-025 27 38 S {era} bark="돌 지난 아기는 걸음이 제일 바빠."')
    m.c(f'npc C-022 29 35 W {era} bark="…축하한다."')
    m.c(f'npc N-R01-011 22 35 S {era} bark="배급과에서 떡 쌀 두 홉 더 냈어."')
    m.c(f'npc N-R01-013 28 42 N look=K1-S1-HR09-H2-T01-0-PF11-HD00-EY00 {era} bark="나 이따 방송실에서 축하 방송 할 거야!"')
    m.c('trigger 7 39 w=2 h=4 scene=MQ-P1_S02_DOYUN cond="MQP1_STAGE == 20" once')
    m.c('trigger 22 39 w=6 h=4 scene=MQ-P1_S03 cond="MQP1_STAGE == 20"')
    # 2268 열 살 생일잔치(MQ-P2 S2, SD-03a §7.2): '생일 축하' 현수막, 윤정인(33세판 HR04)이 핍-보이를 채워 준다. 하도윤 가족·의사·이웃
    y68 = 'cond="year() == 2268"'
    m.c(f"prop bday_banner 9 28 {y68}")
    m.c("mark bday_front 13 40 E"); m.c("mark p2_canteen 14 31 S")
    m.c(f'npc C-001 15 40 W look=F1-S2-HR04-H1-T01-1-PF11-HD00-EY00 {y68} bark="열 살 생일 축하해."')
    m.c(f'npc C-002 11 40 E look=K1-S3-HR08-H2-T01-1-PF11-HD00-EY00 cond="year() == 2268 and MQP2_STAGE == 20" bark="생일이다! 간식 쿠폰 받았어?"')
    for nid, x, y, dd, bk in (("N-R01-007", 6, 39, "E", "도윤이 생일이랑 날이 같았지. 십 년 됐네."),
                              ("N-R01-008", 7, 41, "E", "콩떡 남았다. 하나 더 가져가렴."),
                              ("N-R01-010", 19, 39, "W", "축하해! 이제 핍-보이 차는 나이네."),
                              ("C-025", 18, 41, "W", "열 살 검진표는 다음 주에 와서 받아 가.")):
        m.c(f'npc {nid} {x} {y} {dd} {y68} bark="{bk}"')
    m.c('trigger 11 38 w=8 h=5 scene=MQ-P2_S02 cond="MQP2_STAGE == 20" once')
    # 2268 배급소(MQ-P2 S4, 카르마 튜토리얼): 배급 카드를 잃은 지우(6세)와 창구 주무관 전도하(24세). 바닥 틈 = 조사 3회 길
    m.c(f'npc N-R01-011 35 30 S look=M1-S3-HR04-H1-T11-0-PF11-HD00-EY00 {y68} bark="배급 카드부터 보여 주세요."')
    m.c('npc C-027 40 35 S look=K1-S3-HR07-H2-T01-1-PF11-HD00-EY00 cond="year() == 2268 and MQP2_RESULT == 0" bark="흐윽… 카드가 없어…"')
    m.c("mark p2_ration 39 33 S"); m.c("mark jiwoo_front 40 34 S")
    m.c('trigger 37 30 w=5 h=2 scene=MQ-P2_S04 cond="MQP2_STAGE == 40 and MQP2_RESULT == 0" once')
    m.c('text 37 39 "바닥 타일 사이가 벌어져 있다." w=2 seq="바닥 타일 사이에 틈이 있다. 어두워서 잘 안 보인다.|틈 속에서 뭔가 반짝였다. 손가락을 넣어 본다." '
        'scene=MQ-P2_S04_CARD cond="MQP2_STAGE == 40 and MQP2_RESULT == 0"')
    # 배급소
    m.p("ration_window", 34, 28); m.p("counter_ration", 34, 31); m.p("crate_metal", 45, 33); m.p("crate_metal", 46, 33)
    m.p("crate", 46, 31); m.p("notice_board", 43, 28); m.p("bench", 33, 41); m.p("bench", 43, 41); m.p("bench", 38, 37)
    m.c('text 34 31 "배급 창구: 이번 주부터 배급 반감 — 수경 농장 2·3동 곰팡이병." w=3 cond="year() == 2277"')
    m.c('text 34 31 "배급 창구: 이번 주 배급 — 콩죽, 상추. 생일자 간식 쿠폰 1장." w=3 cond="year() == 2268"')
    # 구내방송실
    m.p("terminal_desk", 52, 31); m.p("desk", 49, 31); m.p("bookshelf", 56, 30); m.p("chair_n", 53, 33)
    m.p("wall_terminal", 50, 28); m.p("slogan_crt2", 55, 28); m.p("record_locker", 49, 38); m.p("bench", 55, 40)
    m.c('text 52 31 "구내방송 송출기 ST-11. 진공관이 데워지는 냄새가 난다."')
    m.c('npc N-R01-011 40 36 S route=창구:35,32,8;창고:44,35,4 bark="배급 카드부터 보여 주세요."')
    m.c('npc N-R01-013 51 38 N route=송출기:52,33,10;문:53,30,4;게시판:42,14,5 bark="S-07 구내방송입니다. 오늘의 평가 일정을 알려 드립니다."')
    m.c('npc N-R01-023 14 20 E route=광장:14,20,10;식당:8,36,8 cond="year() == 2277 and MQP4_STAGE >= 20" bark="2196년 겨울에는 이 광장에 침대가 놓였지."')
    # 2277 개방의 날(MQ-P4 S1): 공동 식당 주민 회의. 앞(북쪽)에 윤정인·도경철, 주민은 탁자 사이 줄에서 북쪽을 본다. 아치를 지나면 회의가 열린다
    y77 = 'year() == 2277 and MQP4_STAGE <= 10'
    m.c("mark p4_meet 14 35 N")
    m.c(f'npc C-001 20 31 S cond="{y77}" bark="정오에 정문으로 모여 주세요."')
    m.c(f'npc C-022 23 31 S cond="{y77}" bark="…"')
    m.c(f'npc C-002 15 35 N cond="{y77}" bark="야, 이거 무슨 회의래?"')
    for nid, x, y in (("N-R01-023", 3, 35), ("N-R01-007", 6, 35), ("N-R01-008", 9, 35), ("N-R01-010", 19, 35),
                      ("N-R01-009", 22, 35), ("N-R01-020", 25, 35), ("N-R01-012", 5, 39), ("C-023", 11, 39),
                      ("C-026", 17, 39), ("C-025", 23, 39), ("N-R01-024", 27, 39)):
        m.c(f'npc {nid} {x} {y} N cond="{y77}"')
    m.c('trigger 12 28 w=5 h=2 scene=MQ-P4_S01 cond="MQP4_STAGE == 10" once')
    m.c('trigger 1 38 w=29 h=1 scene=MQ-P4_S01 cond="MQP4_STAGE == 10" once')               # 거주동 쪽(남서 계단)으로 들어와도
    m.c('enemy CR-473 10 15 arm=baton dir=E route=10,15,3;48,15,3;48,22,2;10,22,2 cond="MQP4_STAGE >= 30 and MQP4_STAGE < 60"')       # 탈출: 광장 순찰(순찰 1)
    m.c('npc N-R01-021 31 15 S route=놀이:31,15,4;게시판:24,4,3;화분:38,9,3 bark="게시판 맨 위 이름은 누구야?"')
    return m


# ---------------------------------------------------------------- V-00 정문 구역 (40×30)
def v00():
    m = M("V-00", "정문 구역", 40, 30, "톱니 방폭문·정문 제어실(레버)·검역실(전실)·출입 대장 책상·오버시어 비상문")
    m.room(8, 9, 31, 20, "=")                                                              # 방폭문 앞 데크(격자)
    m.fill_if(10, 11, 29, 20, ".", "=")
    m.hguide(15, 10, 29); m.vguide(19, 11, 20)
    m.room(1, 3, 6, 12, ".").room(33, 3, 38, 12, "~")                                      # 서쪽 비상문 통로·동쪽 제어실
    m.room(1, 16, 6, 20, "."); m.room(33, 16, 38, 20, ".")
    m.room(1, 24, 38, 27, "o")                                                             # 검역실(전실)
    for y in range(13, 16):
        m.hole(7, y + 4, "."); m.hole(32, y + 4, ".")
    m.hole(7, 18, "."); m.hole(32, 18, ".")
    for y in (21, 22, 23):                                                                  # 정비 통로(검역실 → 동쪽 아래 방, 0-9 은신 길)
        m.hole(37, y, ".")
    for y in (10, 11):
        m.hole(7, y, "."); m.hole(32, y, ".")
    m.door(3, 12, label="비상"); m.door(36, 12, label="제어")
    m.arch(17, 21, 20, "o")
    m.exit_s(19, 27, "V-01")
    m.exit_n(3, 3, "V-02", kind="hatch", label="비상 계단")
    m.exit_at(1, 26, "V-06", (2, 26), "E")                                                  # 검역실 바닥 배수구 ↔ 농장 배수로(배수 갱도)
    # 방폭문(벽 6칸 위로 걸친 192×192): 북벽 윗칸 y=7
    m.p("gear_frame", 16, 7); m.p("gear_door", 17, 7)
    m.c('text 17 8 "톱니 방폭문. 200년 동안 한 번도 굴러가지 않았다." w=6')
    m.p("lever_panel", 34, 1); m.p("wall_terminal", 37, 1); m.p("terminal_desk", 33, 4); m.p("file_cabinet", 38, 4)
    m.c('text 34 3 "정문 레버 2단. 오버시어 열쇠 없이는 움직이지 않는다." w=2')
    m.c('text 37 3 "정문 제어실 단말: 장문석 오버시어 일지 — 2077-10-23 23:52 문을 닫음."')
    m.p("desk", 10, 12); m.p("chair_s", 11, 11); m.p("crate_metal", 28, 11); m.p("crate_metal", 29, 11); m.p("bench", 2, 6)
    m.c('text 10 12 "출입 대장. 마지막 줄 날짜가 2077년이다." w=2')
    m.p("sink", 2, 24); m.p("sink", 3, 24); m.p("curtain", 30, 24); m.p("locker_row3", 7, 24); m.p("locker_row2", 33, 24)
    m.p("quarantine_sign", 12, 22); m.p("slogan_crt2", 24, 22); m.p("notice_board", 14, 22)
    m.c('npc N-R01-019 19 13 S route=정문:19,13,12;검역실:15,25,6 cond="year() == 2277 and MQP4_STAGE < 20" bark="정문 근처는 출입 금지 구역이야."')
    # 2277 개방식(MQ-P4 S2): 데크 앞줄 윤정인·도경철, 제어실 레버의 최보미, 주민 줄. 계엄군은 연출(show)로 문에서 걸어 들어온다
    y77 = 'year() == 2277 and MQP4_STAGE == 20'
    m.c("mark p4_gate 19 15 N"); m.c("mark p4_crowd 19 13 N"); m.c("mark p4_lever 34 3 N"); m.c("mark p4_in 19 9 S")
    m.c("mark p4_yuk 19 11 S"); m.c("mark p4_pa 24 10 S"); m.c("mark p4_out 3 11 W")
    for i, (x, y) in enumerate(((12, 10), (14, 11), (16, 10), (22, 10), (26, 11), (28, 10))):
        m.c(f"mark p4_bj{i + 1} {x} {y} S")
    m.c(f'npc C-001 17 12 S cond="{y77}"'); m.c(f'npc C-022 21 12 S cond="{y77}"')
    m.c(f'npc N-R01-019 35 3 N cond="{y77}"')
    m.c(f'npc C-002 20 15 N cond="{y77}" bark="맨 앞자리 맞지?"')
    # 2277 탈출(MQ-P4 S4 ①): 데크를 지키는 계엄군 6(제자리 경계, 생포 사격) · 파워 아머 1(정문 옆, 못 이기는 적) · 육지환 · 검역실 최보미(권총 위협 사격)
    for x, y, d in ((13, 10, "S"), (16, 11, "S"), (23, 11, "S"), (26, 10, "S"), (11, 15, "E"), (28, 15, "W")):
        m.c(f'enemy CR-401 {x} {y} dir={d} stance=hold cond="MQP4_STAGE >= 30 and MQP4_STAGE < 60 and MQP4_DECOY == 0"')
    m.c('enemy CR-405 22 9 dir=S stance=hold cond="MQP4_STAGE >= 30 and MQP4_STAGE < 60 and MQP4_DECOY == 0"')
    m.c('npc C-004 15 9 S cond="year() == 2277 and MQP4_STAGE >= 30 and MQP4_STAGE < 60 and MQP4_DECOY == 0" bark="후보는 다치게 하지 마라."')
    m.c('enemy CR-473 12 19 arm=pistol who=N-R01-019 dir=E route=12,19,4;27,19,4 cond="MQP4_STAGE >= 30 and MQP4_STAGE < 60 and MQP4_DECOY == 0"')    # 데크 남쪽 순찰
    m.c('trigger 17 9 w=4 h=1 scene=MQ-P4_GATE cond="MQP4_STAGE >= 30 and MQP4_STAGE < 60 and V_ESCAPE >= 1" once')
    # 탈출 출구는 방폭문 하나(0-9 정합): 제어실 레버 · 서쪽 통로의 오버시어 비상 개방 단말 · 검역실 바닥 배수구(배수 갱도) · 정비 통로
    m.c('text 34 3 "정문 레버." w=2 scene=MQ-P4_LEVER cond="MQP4_STAGE >= 30 and MQP4_STAGE < 60 and V_ESCAPE == 0"')
    m.p("wall_terminal", 2, 1)
    m.c('text 2 3 "오버시어 비상 개방 단말. 열쇠 구멍 하나 — 오버시어 열쇠로만 돈다."')
    for nid, x, y in (("N-R01-023", 12, 14), ("N-R01-007", 14, 15), ("N-R01-008", 16, 14), ("N-R01-010", 23, 14),
                      ("N-R01-009", 25, 15), ("N-R01-020", 27, 14), ("N-R01-012", 13, 17), ("C-023", 16, 17),
                      ("C-026", 22, 17), ("C-025", 25, 17), ("N-R01-013", 19, 18), ("N-R01-021", 28, 17)):
        m.c(f'npc {nid} {x} {y} N cond="{y77}"')
    return m


# ---------------------------------------------------------------- V-02 관리동 (50×40)
def v02():
    m = M("V-02", "관리동", 50, 40, "행정실(등록 창구·방금례 책상)·오버시어실(결재 책상·단말·금고)·평가 위원회 회의실·화장실(덕트)·비상 계단")
    m.room(1, 3, 22, 12, ".").room(24, 3, 48, 12, "c")                                    # 행정실·오버시어실
    m.room(1, 16, 48, 19, ".").hguide(18, 1, 48)                                           # 복도
    m.room(1, 23, 22, 32, "c").room(24, 23, 34, 32, "o").room(36, 23, 48, 32, "~")         # 회의실·화장실·비상 계단
    m.door(12, 12, label="행정실"); m.door(36, 12, label="오버시어")
    m.door(10, 19, label="회의실"); m.door(29, 19, label="화장실"); m.door(42, 19, kind="hatch", label="비상")
    m.exit_w(17, 1, "V-01")
    m.exit_n(8, 3, "V-05", label="등록 단말실")
    m.exit_at(46, 31, "V-00", (44, 31), "W")
    m.exit_at(33, 23, "V-11", (32, 24), "S")
    # 행정실
    m.p("counter", 3, 7); m.p("desk", 14, 5); m.p("file_cabinet", 20, 3); m.p("file_cabinet", 21, 3); m.p("file_cabinet", 22, 3)
    m.p("bookshelf", 16, 3); m.p("terminal_desk", 18, 7); m.p("chair_n", 15, 6); m.p("reg_window", 3, 1); m.p("wall_clock", 11, 1)
    m.c('text 14 5 "방금례의 책상. 출생신고서 양식이 열 장씩 묶여 있다." w=2')
    # 오버시어실
    m.p("overseer_desk", 33, 5); m.p("safe", 47, 3); m.p("bookshelf", 25, 3); m.p("file_cabinet", 27, 3); m.p("chair_s", 34, 4)
    m.p("planter", 44, 10); m.p("emblem", 39, 1); m.p("slogan_crt2", 30, 1); m.p("wall_terminal", 43, 1)
    m.c('text 33 5 "결재 책상. 단말에 인구 조사 2277: 192명. 관리 후보 1순위 — 처우 반영 금지." w=3')
    m.c('text 47 3 "오버시어 금고. 열쇠 구멍이 둘이다."')
    # 복도
    m.p("bench", 3, 16); m.p("water_cooler", 47, 16); m.p("planter", 20, 16)
    m.c('sign 13 14 "행정실"'); m.c('sign 37 14 "오버시어실"')
    # 회의실
    m.p("meeting_table", 8, 26); m.p("chair_s", 9, 25); m.p("chair_s", 10, 25); m.p("chair_n", 9, 28); m.p("chair_n", 10, 28)
    m.p("blackboard", 3, 21); m.p("file_cabinet", 20, 23); m.p("slogan_crt", 14, 21)
    m.c('text 8 26 "평가 위원회 회의 탁자. 관리 후보 순위표는 이 탁자에 오르지 않는다." w=3 h=2')
    # 화장실
    m.p("sink", 25, 23); m.p("sink", 26, 23); m.p("sink", 27, 23); m.p("duct_grille", 33, 21)
    m.c('text 33 21 "천장 환기 덕트 덮개. 나사 두 개가 빠져 있다."')
    # 비상 계단
    m.p("crate", 37, 23); m.p("quarantine_sign", 38, 21)
    m.c('text 46 31 "오버시어 전용 비상 계단. 아래는 정문 구역이다."')
    m.c('npc C-024 15 7 S route=책상:15,7,10;창구:5,9,8;서류장:21,5,4 bark="서류는 줄 맞춰서 내요."')
    # 2268 첫 배정(MQ-P2 S3): 방금례(54세)가 창구에서 통지서를 준다. 하도윤도 줄을 섰다
    m.c('npc C-024 4 6 S look=F2-S2-HR08-H4-T11-2-PF11-HD00-EY02 cond="year() == 2268" bark="배정 통지서는 한 사람에 한 장이에요."')
    m.c('npc C-002 7 9 W look=K1-S3-HR08-H2-T01-1-PF11-HD00-EY00 cond="year() == 2268 and MQP2_STAGE == 30" bark="나 아직 내 거 안 열어 봤어."')
    m.c("mark p2_window 4 8 N")
    m.c('trigger 2 8 w=5 h=2 scene=MQ-P2_S03 cond="MQP2_STAGE == 30" once')
    m.c('npc C-001 36 8 S route=책상:36,8,14;창:44,9,5;복도:37,17,4 cond="year() == 2277 and MQP4_STAGE >= 100" bark="일 끝나면 들를게. 밥은 꼭 먹고."')
    # 2277 거래 뒤(MQ-P4 S3~S4): 결재 책상 뒤의 윤정인(설득 경로 ③). 덕트 엿듣기 컷은 육지환을 연출로 세운다
    m.c("mark p4_ovs 34 8 N"); m.c("mark p4_ovs_yuk 34 7 N")
    m.c('npc C-001 37 7 W cond="year() == 2277 and MQP4_STAGE >= 30 and MQP4_STAGE < 100" bark="…왔구나."')
    m.c('enemy CR-473 6 17 arm=baton dir=E route=6,17,3;46,17,4 cond="MQP4_STAGE >= 30 and MQP4_STAGE < 60"')                      # 탈출: 관리동 복도 순찰(순찰 2)
    m.c('text 33 5 "결재 책상. 오버시어 단말이 켜져 있다." w=3 scene=MQ-P4_S05 cond="MQP4_STAGE >= 30 and MQP4_STAGE < 60 and K_RALLY == 0"')
    # 2274 같은 날 오버시어실(MQ-P3 S4, 주인공은 보지 못한다): 단말 앞의 윤정인(39세)
    m.c("mark p3_ovs 34 6 N")
    m.c('npc C-001 34 4 S cond="year() == 2274 and MQP3_STAGE >= 100"')
    return m


# ---------------------------------------------------------------- V-03 교무 구역 (56×40)
def v03():
    m = M("V-03", "교무 구역", 56, 40, "교실 3·적성 평가 교실(판독 카드 책상 24, 멈추지 않은 벽시계)·평가관실·사물함 복도·도서실·체육관·체육 창고")
    m.room(1, 3, 12, 11, ",").room(14, 3, 25, 11, ",").room(27, 3, 38, 11, ",")           # 교실 3
    m.room(40, 3, 54, 11, ".")                                                             # 평가관실
    m.room(1, 15, 54, 18, ".").hguide(17, 1, 54)                                            # 사물함 복도
    m.room(1, 22, 22, 36, ",")                                                             # 적성 평가 교실
    m.room(24, 22, 33, 36, "w")                                                            # 도서실(마루)
    m.room(35, 22, 54, 32, "w").room(35, 36, 54, 38, "~")                                  # 체육관·창고
    m.arch(44, 45, 32, "w")
    for x, lb in ((6, "1반"), (19, "2반"), (32, "3반"), (46, "평가관실")):
        m.door(x, 11, label=lb)
    m.door(11, 18, label="평가"); m.door(28, 18, label="도서실"); m.arch(43, 46, 18, "w")
    m.exit_e(16, 54, "V-01")
    m.exit_at(2, 35, "V-07", (3, 35), "E")
    # 교실
    for x0 in (1, 14, 27):
        m.p("blackboard", x0 + 4, 1); m.p("teacher_desk", x0 + 5, 4)
        for yy in (7, 9):
            for xx in range(x0 + 2, x0 + 11, 3):
                m.p("exam_desk", xx, yy)
    # 평가관실
    m.p("teacher_desk", 44, 5); m.p("mimeograph", 41, 3); m.p("file_cabinet", 52, 3); m.p("file_cabinet", 53, 3)
    m.p("terminal_desk", 49, 4); m.p("bookshelf", 47, 3); m.p("chair_n", 45, 6); m.p("record_locker", 50, 9)
    m.c('text 49 4 "평가관실 단말: 10번 문항 원본에 메모 — 변경 금지, 설계실 지시 2076."')
    m.c('text 41 3 "등사기. 잉크가 손가락에 묻는다."')
    # 복도 사물함
    for x in (1, 9, 13, 22, 25, 35, 38, 49):
        m.p("locker_row3", x, 15)
    m.p("water_cooler", 53, 15)
    m.c('text 22 15 "하도윤의 사물함. 이름표가 반쯤 떨어져 있다." w=3')
    # 적성 평가 교실
    m.p("blackboard", 3, 20); m.p("wall_clock", 14, 20); m.p("teacher_desk", 10, 23)
    for yy in (26, 28, 30, 32):
        for xx in range(3, 21, 3):
            m.p("exam_desk", xx, yy)
    m.c('text 14 21 "벽시계가 10시 12분을 가리키며 간다. S-07의 시계는 멈추지 않았다."')
    # 도서실
    for x in (24, 26, 30, 32):
        m.p("bookshelf", x, 22)
    m.p("bookshelf", 24, 28); m.p("bookshelf", 30, 28); m.p("desk", 27, 32); m.p("chair_n", 28, 33)
    m.c('text 24 22 "도서실. 『주간 만화 쇠파이프 반장』 전권이 맨 아래 칸에 꽂혀 있다." w=8')
    # 체육관·창고
    m.p("gym_mat", 38, 26); m.p("gym_mat", 41, 26); m.p("gym_mat", 38, 28); m.p("target", 52, 23)
    m.p("bench", 36, 22); m.p("bench", 52, 31)
    m.p("bat_rack", 36, 36); m.p("crate", 50, 36); m.p("crate", 51, 36); m.p("crate_metal", 53, 36)
    m.c('text 36 36 "방망이 꽂이. 붉은 테이프를 감은 방망이에 \'9회말\'이라고 쓰여 있다."')
    m.c('npc C-023 9 24 S route=교탁:10,25,12;평가관실:44,7,10;복도:30,16,3 bark="질문은 손 들고."')
    # 2268 학년 말 생활기록부(MQ-P2 S1): 1반 교실, 담임 차명수(43세). 주인공 자리(가운데 줄), 옆자리 하도윤
    m.c("mark p2_seat 6 8 N"); m.c("mark p2_desk 6 6 S")
    m.c('npc C-023 7 3 S look=M1-S3-HR05-H1-T11-1-PF11-HD00-EY03 cond="year() == 2268" bark="질문은 손 들고."')
    m.c('npc C-002 9 8 N look=K1-S3-HR08-H2-T01-1-PF11-HD00-EY00 cond="year() == 2268 and MQP2_STAGE < 20" bark="야, 너 뭐라고 나왔어?"')
    # 2274 적성 평가(MQ-P3): 사물함 복도 소동 → 적성 평가 교실 → 평가관실 결과지. 사건 결과(MQP3_RESULT)에 따라 교실 자리가 바뀐다
    #   (1~3 나채윤 적발 · 4 둘 다 응시 · 5·6 하도윤 응시 자격 박탈). 도경철은 장면이 세운다(show).
    y74 = 'year() == 2274'
    m.c("mark p3_locker 24 17 N"); m.c("mark p3_kc_in 2 17 E"); m.c("mark p3_kc_stop 20 17 E")
    m.c("mark p3_seat 9 29 N"); m.c("mark p3_cha_out 11 22 N"); m.c("mark p3_office 45 8 N")
    m.c(f'npc C-026 22 16 E cond="{y74} and MQP3_STAGE <= 20" bark="부장님 오시면 다 말할 거야."')
    m.c(f'npc C-002 25 16 W cond="{y74} and MQP3_STAGE <= 20" bark="그거 내 거 아니라니까!"')
    m.c(f'trigger 30 16 scene=MQ-P3_S01 h=3 cond="{y74} and MQP3_STAGE == 10" once')
    m.c(f'npc C-023 10 25 S cond="{y74} and MQP3_STAGE <= 30" bark="앉아라. 문항은 내가 읽는다."')
    m.c(f'npc C-002 12 29 N cond="{y74} and MQP3_STAGE >= 30 and MQP3_RESULT >= 1 and MQP3_RESULT <= 4" bark="시험 끝나고 밥 살게."')
    m.c(f'npc C-026 6 29 N cond="{y74} and MQP3_STAGE >= 30 and MQP3_RESULT >= 4" bark="…점수가 전부인 데서 사는 거, 너도 알잖아."')
    m.c(f'npc C-023 45 7 S cond="{y74} and MQP3_STAGE >= 40" bark="결과지는 판독기가 뱉은 그대로다."')
    m.c(f'text 50 9 "출입 기록 서랍. 어젯밤 줄은 이미 누가 들여다봤다." cond="{y74} and MQP3_RESULT == 2"')
    m.c('npc N-R01-017 28 25 S route=서가:28,25,10;책상:29,31,8 bark="책은 제자리에. 200년째 같은 부탁이야."')
    m.c('npc N-R01-016 44 28 W route=체육관:44,28,6;창고:47,37,5 bark="9회말은 아직이야."')
    return m


# ---------------------------------------------------------------- V-04 거주동 (64×48)
def v04():
    m = M("V-04", "거주동", 64, 48, "A 행정동(2인실, 주인공 가족 방 A-07)·B 기술동·C 생산동·D 정비동·격리 폐쇄 복도. 빈방 절반 이상")
    m.room(1, 9, 62, 12, ".").hguide(11, 1, 62)                                            # 가로 중앙 복도
    m.room(1, 25, 62, 28, ".").hguide(27, 1, 62)
    m.room(1, 41, 62, 44, "=")                                                             # 격리 폐쇄 복도(격자)
    m.room(30, 3, 33, 46, ".").vguide(31, 3, 46)                                           # 세로 복도
    for i, x0 in enumerate(range(1, 29, 7)):                                               # A동(북서) 2인실
        m.room(x0, 3, x0 + 5, 5, ".")
        m.door(x0 + 2, 5, label=f"A-0{i + 5}")
    for i, x0 in enumerate(range(35, 62, 7)):                                              # B동(북동) 4인실
        m.room(x0, 3, x0 + 5, 5, ".")
        m.door(x0 + 2, 5, label=f"B-0{i + 1}")
    for i, x0 in enumerate(range(1, 29, 7)):                                               # C동(가운데)
        m.room(x0, 16, x0 + 5, 21, ".")
        m.door(x0 + 2, 12, label=f"C-1{i}")
        m.door(x0 + 3, 21, label="")
    for i, x0 in enumerate(range(35, 62, 7)):                                              # D동(가운데 동쪽)
        m.room(x0, 16, x0 + 5, 21, "~")
        m.door(x0 + 2, 12, label=f"D-0{i + 1}")
    for i, x0 in enumerate(range(1, 29, 7)):                                               # 남쪽 빈방(출생 허가 대기)
        m.room(x0, 32, x0 + 5, 37, ".")
        m.door(x0 + 2, 28, label="")
    for i, x0 in enumerate(range(35, 62, 7)):
        m.room(x0, 32, x0 + 5, 37, ".")
        m.door(x0 + 2, 28, label="")
    m.exit_n(31, 3, "V-01", label="아트리움")
    m.exit_w(10, 1, "V-09"); m.exit_e(26, 62, "V-10")
    m.c("mark home_bed 9 4 S"); m.c("mark home_door 9 5 N")
    m.c("mark p4_room 16 4 E"); m.c("mark p4_dy_in 17 5 N"); m.c("mark p4_dy 18 4 W"); m.c("mark p4_dy_out 17 9 S")   # A-07(MQ-P4 S3)
    # A동: 침대·사물함, A-07 = 주인공 가족 방(x0=15)
    for x0 in range(1, 29, 7):
        m.p("bunk", x0, 3); m.p("bunk", x0 + 4, 3)
    m.c('text 16 3 "A-07. 엄마와 내 방. 벽에 돌잡이 때 잡은 물건이 걸려 있다." w=3')
    for x0 in range(35, 62, 7):
        m.p("bunk", x0, 3); m.p("bunk", x0 + 1, 3); m.p("bunk", x0 + 4, 3); m.p("bunk", x0 + 5, 3)
    for i, x0 in enumerate(range(1, 29, 7)):
        m.p("bunk", x0, 17); m.p("bunk", x0 + 5, 17); m.p("crate", x0 + 1, 20)
    for x0 in range(35, 62, 7):
        m.p("bunk", x0, 16); m.p("bunk", x0 + 1, 16); m.p("bunk", x0 + 4, 16); m.p("bunk", x0 + 5, 16)
        m.p("crate_metal", x0 + 2, 20)
    for i, x0 in enumerate(list(range(1, 29, 7)) + list(range(35, 62, 7))):
        if i % 3 == 0:
            m.p("bunk", x0, 32)
        m.c(f'text {x0 + 2} 32 "빈방. 문패에 쪽지 — 출생 허가 대기 22{50 + i}-0{1 + i % 9}."')
    # 격리 폐쇄 복도
    m.p("quarantine_sign", 12, 39); m.p("quarantine_sign", 40, 39)
    for x in (34, 35):
        m.p("cell_bars", x, 41)
    m.c('text 2 41 "2196년 회색 열병 격리 표지가 아직 붙어 있다. 복도 끝은 용접으로 막혀 있다." w=2')
    m.p("water_cooler", 33, 13)
    m.c('npc N-R01-024 20 10 E route=복도:20,10,6;C동:23,19,8 bark="…아무한테도 말하지 마."')
    m.c('npc N-R01-022 40 26 W route=복도:40,26,5;세로:31,20,4;빨래:5,26,6 bark="첫 배정이 세탁이래. 하루 종일 비누 냄새야."')
    m.c('npc N-R01-015 52 20 N route=D동:52,19,8;복도:55,10,5 bark="D등급 방은 문이 안 잠겨. 원래 그래."')
    return m


# ---------------------------------------------------------------- V-05 등록 단말실 (24×18)
def v05():
    m = M("V-05", "등록 단말실", 24, 18, "출생 등록 단말기(진공관 랙 2×3)·계보 대장 테이프 보관함·서명대")
    m.room(1, 3, 22, 15, "c")
    m.vguide(11, 6, 15)
    m.exit_s(11, 15, "V-02")
    for x in (3, 7, 15, 19):
        m.p("tube_rack", x, 3)
    m.p("tube_rack", 3, 8); m.p("tube_rack", 19, 8)
    m.p("tape_cabinet", 2, 9); m.p("tape_cabinet", 2, 10); m.p("terminal_desk", 10, 6); m.p("desk", 15, 11)
    m.p("memorial_plaque", 10, 1)
    m.c('text 10 1 "동판: 제15조 — 훼손 시 D등급 영구 고정." w=3')
    m.c('text 10 6 "등록 단말: 출생 기록 검산합 — 사슬 길이 41,207건, 단절 0."')
    m.c('text 2 9 "계보 대장 테이프 보관함. 오버시어 열쇠로만 열린다." h=2')
    m.c('text 15 11 "서명대. 펜이 줄에 매여 있다." w=2')
    return m


# ---------------------------------------------------------------- V-06 수경 농장 (60×40)
def v06():
    m = M("V-06", "수경 농장", 60, 40, "1·2·3동 재배 선반(쌀·콩·버섯·상추)·양액 탱크·농장 배수로(은신 경로)·2·3동 곰팡이병 구역")
    m.room(1, 3, 18, 31, "=").room(21, 3, 38, 31, "=").room(41, 3, 58, 31, "=")            # 1·2·3동
    m.room(1, 35, 58, 37, "~")                                                             # 배수로(콘크리트)
    for x in (19, 20, 39, 40):
        for y in (16, 17):
            m.hole(x, y, "=")
    for x0 in (1, 21, 41):
        m.vguide(x0 + 8, 4, 31)
    m.fill_if(23, 20, 36, 30, "M", "="); m.fill_if(43, 8, 56, 30, "M", "=")
    for x in (5, 25, 45):
        m.arch(x, x, 31, "~")
    m.exit_s(30, 37, "V-01")
    m.exit_at(58, 36, "V-11", (56, 36), "W")
    m.exit_at(1, 36, "V-00", (2, 36), "E")                                                   # 배수 갱도 → 정문 구역 검역실 바닥 배수구
    crops = {1: ("shelf_lettuce", "shelf_bean"), 21: ("shelf_rice", "shelf_mold"), 41: ("shelf_mushroom", "shelf_mold2")}
    for x0, (a, b) in crops.items():
        for i, y in enumerate(range(6, 30, 3)):
            m.p(a if i < 4 or x0 == 1 else b, x0 + 2, y)
            m.p(a if i % 2 or x0 == 1 else b, x0 + 11, y)
        m.p("tank_water" if x0 == 21 else "tank_nutrient", x0 + 7, 3)
        m.p("wall_terminal", x0 + 3, 1); m.p("notice_board", x0 + 13, 1)
    m.c('text 24 1 "수경 농장 단말: 2276 곰팡이병 보고 — 2동·3동 수확량 41% 감소."')
    m.c('text 13 35 "농장 배수로. 허리를 숙이면 지나갈 수 있다. 서쪽 끝은 배수 갱도 — 정문 구역 검역실 밑으로 이어진다." w=4')
    m.c('npc N-R01-010 10 15 S route=1동:10,15,8;2동:30,12,8;탱크:9,6,4 bark="잎 만지지 마. 곰팡이는 손으로 옮아."')
    m.c('npc N-R01-008 49 20 W route=3동:49,20,8;배수로:40,36,5 cond="year() == 2277 and (MQP4_STAGE < 30 or MQP4_STAGE >= 60)" bark="2동은 이번 주에 갈아엎어야 해."')
    m.c('enemy CR-473 40 36 arm=baton dir=W route=40,36,5;18,36,5 cond="MQP4_STAGE >= 30 and MQP4_STAGE < 60"')                     # 탈출: 배수로 순찰(순찰 3)
    return m


# ---------------------------------------------------------------- V-07 지하 판정실 (30×24)
def v07():
    m = M("V-07", "지하 판정실", 30, 24, "세진 적성 판정기(카드 투입구·출력 프린터)·평가 기록 보관장·'수정 금지' 봉인")
    m.room(1, 3, 28, 21, "~")
    m.room(8, 8, 21, 17, ".")
    m.vguide(14, 12, 21)
    m.exit_at(2, 20, "V-03", (3, 20), "E")
    m.p("judge_machine", 13, 8)
    for x in (2, 4, 21, 23, 25):
        m.p("record_locker", x, 3)
    m.p("crate_metal", 26, 18); m.p("crate_metal", 27, 18); m.p("wall_terminal", 8, 1); m.p("wall_pipes", 12, 1)
    m.c('text 13 8 "세진 적성 판정기 SJ-AP7. 옆에 붙은 봉인: 관리 후보 순위 출력 — 수정 금지." w=3 h=2')
    m.c('text 2 3 "평가 기록 보관장. 200년 치 판독 카드가 연도별로 묶여 있다." w=4')
    m.c('text 2 20 "교무 구역으로 올라가는 계단."')
    return m


# ---------------------------------------------------------------- V-09 보안과 (44×32)
def v09():
    m = M("V-09", "보안과", 44, 32, "보안부 사무실(도경철)·무기고(자물쇠 25)·사격장(표적 10 + 은신 표적 2)·구금실 2칸")
    m.room(1, 3, 16, 11, ".").room(18, 3, 26, 11, "~")                                     # 사무실·무기고
    m.room(28, 3, 42, 28, "~")                                                             # 사격장(긴 방)
    m.room(1, 15, 26, 18, ".").hguide(17, 1, 26)                                           # 복도
    m.room(1, 22, 8, 28, "=").room(10, 22, 17, 28, "=").room(19, 22, 26, 28, ".")          # 구금실 2·대기
    m.door(8, 11, label="보안부"); m.door(22, 11, label="무기고", locked=True)
    m.door(4, 18, label="구금 1"); m.door(13, 18, label="구금 2"); m.arch(21, 24, 18)
    for y in (16, 17):
        m.hole(27, y, ".")
    m.exit_w(16, 1, "V-01"); m.exit_s(22, 28, "V-04")
    m.p("desk_metal", 4, 6); m.p("chair_n", 5, 7); m.p("file_cabinet", 1, 3); m.p("file_cabinet", 2, 3); m.p("gun_rack", 12, 3)
    m.p("terminal_desk", 14, 7); m.p("emblem", 7, 1); m.p("slogan_crt2", 9, 1)
    m.c('text 14 7 "보안과 단말: 2160 개방파 사건 기록 — 41명. 처분란이 비어 있다."')
    m.c('text 12 3 "총기 거치대. 공기총 네 정과 진압봉." w=2')
    m.p("gun_rack", 18, 3); m.p("gun_rack", 22, 3); m.p("crate_metal", 25, 8); m.p("crate_metal", 26, 8); m.p("safe", 18, 9)
    for i, y in enumerate(range(5, 26, 2)):
        if i < 10:
            m.p("target", 40 if i % 2 else 38, y)
    m.p("target_low", 35, 12); m.p("target_low", 36, 20)
    m.p("bench", 29, 26); m.p("desk_metal", 29, 3)
    m.c('text 29 3 "사격장 기록판: 표적 10, 은신 표적 2. 엎드려 다가가면 들키지 않는다." w=2')
    m.p("cell_bars", 1, 22); m.p("cell_bars", 8, 22); m.p("bench", 3, 27); m.p("cell_bars", 10, 22); m.p("cell_bars", 17, 22)
    m.p("bench", 12, 27); m.p("bench", 20, 24)
    m.c('npc C-022 6 8 S route=사무실:6,8,10;사격장:32,15,10;복도:12,16,4 cond="year() == 2277 and MQP4_STAGE >= 30" bark="보안부는 명령대로 쏜다. 명령 없이는 안 쏜다."')
    # 2268 사격 교습(MQ-P2 S5): 도경철(45세). 사대 = 입구 쪽 x 29~30. 은신 표적 앞 모래주머니 두 무더기(낮은 엄폐 — 웅크리면 표적이 못 본다)
    for y in (11, 12, 13, 19, 20, 21):
        m.p("sandbag", 31, y)
    m.c("mark p2_range 29 16 E"); m.c("mark range_line 30 16 E"); m.c("mark sneak_1 30 12 E"); m.c("mark sneak_2 30 20 E")
    m.c('npc C-022 29 14 S look=M2-S4-HR02-H1-T02-1-PF11-HD03-EY00 cond="year() == 2268" bark="보안부는 명령대로 쏜다. 명령 없이는 안 쏜다. 그뿐이다."')
    m.c('npc C-002 29 24 N look=K1-S3-HR08-H2-T01-1-PF11-HD00-EY00 cond="year() == 2268 and MQP2_STAGE >= 50" bark="다 맞혔어? 나 기다리는 중."')
    m.c('trigger 27 15 w=2 h=4 scene=MQ-P2_S05 cond="MQP2_STAGE == 40" once')
    m.c('npc N-R01-018 21 15 S route=무기고앞:22,15,10;복도:3,16,5 cond="year() == 2277 and MQP4_STAGE < 30" bark="무기고는 부장님 열쇠로만 열려."')
    # 2277 탈출(MQ-P4 S4 ① 전투): 무기고 앞을 도는 권서준(보안요원, 진압봉). 무기고 문 = [자물쇠 따기 25] · 열쇠
    m.c('enemy CR-473 22 15 arm=baton who=N-R01-018 dir=N route=22,15,4;12,16,2;24,16,3 cond="MQP4_STAGE >= 30 and MQP4_STAGE < 60"')
    m.c('text 22 14 "무기고 철문." scene=MQ-P4_ARMORY cond="MQP4_STAGE >= 30 and MQP4_STAGE < 60 and MQP4_ARMORY == 0"')
    m.c('text 22 3 "총기 거치대." scene=MQ-P4_GUNS cond="MQP4_ARMORY == 1"')
    return m


# ---------------------------------------------------------------- V-10 설비 구역 (56×44)
def v10():
    m = M("V-10", "설비 구역", 56, 44, "원자로실(소형 원자로 1기, 2261 사고 추모 명판)·공기 정화기실(2131 추모 벽)·정수실·예비 축전지실")
    m.room(1, 3, 30, 22, "~").room(32, 3, 54, 22, "~")                                     # 원자로실·공기 정화기실
    m.room(1, 26, 54, 29, "=").hguide(28, 1, 54)                                           # 설비 복도
    m.room(1, 33, 24, 41, "~").room(26, 33, 54, 41, "~")                                   # 정수실·축전지실
    m.door(15, 22, label="원자로"); m.door(43, 22, label="공기")
    m.door(12, 29, label="정수"); m.door(40, 29, label="축전지")
    m.exit_w(27, 1, "V-04"); m.exit_e(27, 54, "V-11")
    m.fill_if(10, 7, 21, 18, ".", "~")
    m.p("reactor", 13, 8)
    m.p("memorial_plaque", 3, 1); m.p("wall_terminal", 24, 1); m.p("lever_panel", 26, 1); m.p("wall_pipes", 8, 1)
    m.p("crate_metal", 2, 19); m.p("crate_metal", 3, 19); m.p("battery_rack", 27, 3)
    m.c('text 3 1 "추모 명판: 2261. 04. 17. 원자로실 사고 순직자 — 이름의 성이 내 성과 같다." w=3')
    m.c('text 13 8 "S-07 원자로 1호기. 바닥이 미세하게 떨린다." w=4 h=4')
    m.p("air_purifier", 36, 5); m.p("air_purifier", 45, 5); m.p("wall_pipes", 33, 1); m.p("notice_board", 50, 1)
    m.p("memorial_plaque", 40, 1)
    m.c('text 40 1 "추모 벽: 2131년 공기 정화기 사고. 열두 명의 이름." w=3')
    m.p("tank_water", 3, 34); m.p("tank_water", 7, 34); m.p("tank_water", 11, 34); m.p("wall_terminal", 18, 31); m.p("sink", 22, 33)
    for x in (27, 30, 33, 36):
        m.p("battery_rack", x, 33)
    m.p("crate_metal", 50, 38); m.p("crate_metal", 51, 38)
    m.c('npc N-R01-009 20 12 W route=원자로:20,12,10;계기:25,4,5;복도:16,27,3 bark="원자로는 오늘도 잘 돈다."')
    m.c('npc N-R01-014 41 13 N route=정화기:41,13,10;복도:44,27,4 bark="필터 갈 때가 지났어. 부품이 없어."')
    return m


# ---------------------------------------------------------------- V-11 하층 배관·덕트망 (70×30)
def v11():
    m = M("V-11", "하층 배관·덕트망", 70, 30, "배관실(MQ-P2 변이 바퀴 6)·환기 덕트(은신 동선)·농장 배수로 합류부·비상 배수 갱도 철문")
    m.room(1, 3, 24, 14, "=")                                                              # 배관실
    m.room(1, 18, 68, 20, "~")                                                             # 아래 큰 관로
    m.room(27, 3, 28, 14, "=").room(27, 3, 50, 4, "=").room(49, 3, 50, 14, "=")             # 덕트(좁은 고리)
    m.room(53, 3, 68, 14, "~")                                                             # 배수로 합류부
    m.room(1, 24, 68, 27, "=")                                                             # 맨 아래 덕트
    for y in (8, 9):
        m.hole(25, y, "="); m.hole(26, y, "="); m.hole(51, y, "~"); m.hole(52, y, "~")
    m.arch(10, 12, 14, "="); m.arch(60, 62, 14, "~"); m.arch(30, 32, 20, "=")
    for y in range(15, 18):
        m.hole(28, y, "="); m.hole(49, y, "=")
    m.exit_w(19, 1, "V-10"); m.exit_e(19, 68, "V-06")
    m.exit_at(27, 3, "V-02", (28, 5), "S")
    m.p("wall_pipes", 2, 1); m.p("wall_pipes", 5, 1); m.p("wall_pipes", 8, 1); m.p("wall_pipes", 12, 1); m.p("wall_pipes", 17, 1)
    m.p("crate", 3, 10); m.p("crate", 4, 10); m.p("crate_metal", 22, 4); m.p("tank_water", 20, 10)
    m.c("mark roach_1 8 6 S"); m.c("mark roach_2 14 9 S"); m.c("mark roach_3 19 6 S"); m.c("mark roach_4 6 12 S")
    m.c("mark roach_5 16 12 S"); m.c("mark roach_6 22 8 S"); m.c("mark doyun 4 7 E")
    m.c('text 10 6 "배관 틈으로 바깥 공기 냄새가 들어온다." w=4')
    # 2268 해충 구제(MQ-P2 S6): 큰바퀴 6(볼트 판본, SD-14 §3.1), 하도윤 일시 동행. 통로 입구에서 장면, 증기 분출 = 스팀팩 튜토리얼
    for k, (x, y) in enumerate(((8, 6), (14, 9), (19, 6), (6, 12), (16, 12), (22, 8))):
        m.c(f'enemy CR-002 {x} {y} cond="MQP2_STAGE == 60"')
    m.c("mark p2_pipe 11 15 N"); m.c("mark doyun_wait 13 19 W")
    m.c('npc C-002 13 19 W look=K1-S3-HR08-H2-T01-1-PF11-HD00-EY00 cond="year() == 2268 and MQP2_STAGE == 60" bark="바퀴는 대가리를 쳐!"')
    m.c('trigger 10 15 w=3 h=2 scene=MQ-P2_S06 cond="MQP2_STAGE == 60" once')
    m.p("wall_pipes", 54, 1); m.p("wall_pipes", 58, 1); m.p("crate", 66, 12)
    m.p("duct_grille", 61, 1); m.p("drain_hatch", 63, 1)
    m.c('text 64 3 "비상 배수 갱도 철문(원형). 녹이 슬어 바퀴가 꿈쩍하지 않는다." w=3')
    m.c("mark p4_gate11 64 4 N")
    m.c('npc C-002 62 5 E cond="year() == 2277 and MQP4_STAGE >= 30 and MQP4_STAGE < 60 and MQP4_FOLLOW == 0" bark="왔네."')         # 탈출 ④: 혼자 왔을 때 기다리는 하도윤
    m.c('trigger 62 4 w=5 h=3 scene=MQ-P4_DOYUN cond="MQP4_STAGE >= 30 and MQP4_STAGE < 60 and MQP4_FOLLOW == 1" once')
    m.c('text 27 3 "환기 덕트. 위로 올라가면 관리동 화장실이다."')
    m.p("wall_pipes", 3, 22); m.p("wall_pipes", 34, 22); m.p("wall_pipes", 50, 22)
    return m


ALL = [v00, v01, v02, v03, v04, v05, v06, v07, v08, v09, v10, v11]


# ---------------------------------------------------------------- 용기(0-9, SD-12 §7.3·§9.2): 가구 위에 겹쳐 놓는다(가구 칸 = 조사 칸)
# box x y 종류 w= h= owner=(""·PC·S7·인물 ID) lock=(자물쇠 따기 판정) name="이름". 주인 있는 용기에서 꺼내면 절도(카르마 −5).
# 장면이 달린 조사 글(무기고 총기 거치대·제어실 레버·오버시어 책상)과는 겹치지 않는다(map_compile이 막는다).
BOX_PROPS = {                                                                     # 용기를 위해 새로 놓는 가구
    "V-04": [("crate_metal", 6, 3), ("crate_metal", 13, 3), ("crate_metal", 20, 3), ("crate_metal", 27, 3), ("crate", 12, 35)],
}
BOXES = {
    "V-00": ['box 7 24 locker w=3 owner=S7 name="경비대 사물함"', 'box 33 24 locker w=2 owner=S7 name="검역실 사물함"',
             'box 28 11 crate w=2 owner=S7 name="반입 화물 상자"', 'box 38 4 cabinet owner=S7 name="제어실 서류함"'],
    "V-01": ['box 46 31 crate owner=S7', 'box 45 33 pantry w=2 owner=S7 name="배급 창고 상자"', 'box 49 31 desk w=2 owner=S7 name="배급 사무 책상"',
             'box 49 38 cabinet w=2 owner=S7 name="기록 보관함"'],
    "V-02": ['box 20 3 cabinet w=3 owner=S7 name="행정 서류함"', 'box 27 3 cabinet owner=S7 name="행정 서류함"',
             'box 47 3 safe owner=C-001 lock=50 name="오버시어 금고"', 'box 20 23 cabinet owner=S7', 'box 37 23 crate owner=S7'],
    "V-03": ['box 1 15 school_locker w=3 owner=C-026', 'box 9 15 school_locker w=3 name="주인 없는 사물함"',
             'box 13 15 school_locker w=3 owner=PC name="내 사물함"', 'box 25 15 school_locker w=3 owner=N-R01-016',
             'box 35 15 school_locker w=3 owner=S7 name="분실물 사물함"', 'box 44 5 desk w=2 owner=C-023 name="교사 책상"',
             'box 52 3 cabinet w=2 owner=S7 name="교무 서류함"', 'box 50 36 crate w=2 owner=S7 name="체육 창고 상자"'],
    "V-04": ['box 6 3 locker owner=N-R01-024 name="A-05 사물함"', 'box 13 3 locker owner=N-R01-022 name="A-06 사물함"',
             'box 20 3 locker owner=PC name="A-07 내 사물함"', 'box 27 3 locker owner=N-R01-015 name="A-08 사물함"',
             'box 2 20 crate owner=S7 name="C동 설비 상자"', 'box 16 20 pantry owner=S7 name="C동 배급 상자"',
             'box 44 20 locker owner=N-R01-015 name="D동 공용 사물함"', 'box 51 20 crate name="버려진 상자"',
             'box 12 35 crate name="빈방에 남은 상자"'],
    "V-05": ['box 2 10 cabinet owner=S7 name="테이프 보관함"'],
    "V-06": ['box 23 6 pantry w=3 owner=S7 name="수확물 선반"', 'box 43 6 pantry w=3 owner=N-R01-010 name="버섯 선반"'],
    "V-07": ['box 21 3 cabinet w=2 owner=S7 name="판정 기록함"', 'box 26 18 crate w=2 name="먼지 쌓인 상자"'],
    "V-08": ['box 24 3 aid w=2 owner=S7 name="의무과 약품장"', 'box 33 3 aid w=2 owner=S7 lock=25 name="약품장(잠김)"',
             'box 27 6 crate w=2 owner=S7 name="의무과 물품 상자"', 'box 2 7 desk w=2 owner=C-025 name="의무관 책상"',
             'box 12 3 cabinet owner=S7 name="진료 기록함"'],
    "V-09": ['box 25 8 ammo w=2 owner=S7 lock=25 name="보안과 탄약 상자"', 'box 18 9 safe owner=C-022 lock=75 name="보안부장 금고"',
             'box 4 6 desk w=2 owner=C-022 name="보안부장 책상"', 'box 1 3 cabinet w=2 owner=S7 name="보안 서류함"'],
    "V-10": ['box 2 19 crate w=2 owner=S7 name="설비 부품 상자"', 'box 50 38 crate w=2 name="굴러다니는 상자"'],
    "V-11": ['box 3 10 crate w=2 name="배관공 상자"', 'box 66 12 crate name="녹슨 상자"', 'box 22 4 aid name="민방위 비상용품함"'],
}


def main():
    os.makedirs(OUT, exist_ok=True)
    force = "--force" in sys.argv
    for f in ALL:
        m = f()
        for name, x, y in BOX_PROPS.get(m.id, []):
            m.p(name, x, y)
        for b in BOXES.get(m.id, []):
            m.c(b)
        p = os.path.join(OUT, m.id + ".map")
        if os.path.exists(p) and not force:
            print("건너뜀(이미 있음):", p)
            continue
        open(p, "w", encoding="utf-8").write(m.text())
        print("씀:", p)


if __name__ == "__main__":
    main()
