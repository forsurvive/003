## 영등포(R02) 사이드 퀘스트 SQ-S10 「오늘의 4번 인력」 진행기(단계 1-11i, SD-04a §5.3). 원고: script/act1/SQ-S10.txt · MQ-105.txt(황두칠 매입 300/520) ·
##   world/radio.txt(남산 방송 반응 뉴스). 맵: GD-01 그라운드 · GD-02 위층(VIP · 중계석 · 매점 · 캣워크) · GD-03 지하 대기실 · H-03 22번 칸 · K-06 우도하 ·
##   X-BC · 노들 남문(정착). 설계안 docs/seoul-fallout/_plans/SQ-S10_plan.md(§8 계획 단계 재미 검수 반영).
## 기라희의 자리는 SQ_S10_KIRA 하나(P1): 0 우리 · 1 고척 지하 · 2 경매 무대 · 3 고척 정문 앞 · 4 정착 · 5 세이프빌 식당 · 6 세이프빌 노역 · 7 주인공 소유 · 8 탱크마을.
## 단계는 이 진행기 한 곳에서만, 오르기만 한다(SD-20). 시계는 하나: 그녀의 경매일(AUCTION) 06시 이송 → 10시 경매(그라운드에 있으면 장면) → 10:30 주인공 없이 낙찰.
class_name SideS10
extends Node

const KIRA_ID := "N-R02-040"                ## 기라희(88번)
const SEO_ID := "N-R02-044"                 ## 기서윤(세이프빌 대리인)
const HOST_ID := "N-R02-043"                ## 견적(사회자)
const CAP_SEO := 750                        ## 기서윤 상한
const CAP_BUDGET := 600                     ## 예산을 털어놓으면([물물교환 50])
const FORE_CAP := 450                       ## 탱크마을 십장 상한(탁현수 · 연석규가 말한 값) — 기서윤이 있으면 450에 한 번 끼고 빠진다
const OVR_CAP := 550                        ## 기서윤이 없을 때 감독관 반경모가 한 번 따라오는 상한
const FORE_ID := "N-R02-508"                ## 연석규(탱크마을 십장)
const OVR_ID := "N-R02-509"                 ## 반경모(비상정부 지상 노역 감독관)
const BOARD := Vector2i(13, 13)             ## GD-01 칠판
const GLASS := {"GD-01": Vector2i(19, 1), "GD-02": Vector2i(26, 1)}
const LBOX := Vector2i(22, 12)              ## GD-01 장부함
const ROLE := {"CR-435": "CR-435", "CR-436": "CR-436", "CR-438": "CR-438", "N-R02-043": "CR-438"}   # 습격 때 적이 되는 사람(견적은 반장 판본)
const EXTRA := ["CR-435", "CR-435", "CR-435", "CR-438", "CR-436", "CR-107", "CR-107", "CR-107"]     # 그라운드 증원(모집원 6 · 반장 2 · 추심원 2 · 경비견 3 맞춤)

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var _gd: Array = []                         ## 이 맵에서 깨운 습격 적
var _staging := false                       ## 경매 연출(어둡게 → 입찰 자리) 중


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["s10"] = _cmd
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)


func v(k: String) -> int:
	return int(st.vars.get_v(k))


func q(k: String) -> int:
	return int(st.vars.get_v("SQ_S10_" + k))


func _sq(k: String, n: int) -> void:
	st.vars.set_v("SQ_S10_" + k, n)


func _log(s: String) -> void:
	if log_on:
		print("[4번] " + s)


func day() -> int:
	return maxi(1, v("GAME_DAY"))


func stage() -> int:
	return st.quests.stage("SQ-S10")


func _up(n: int) -> void:
	if stage() < n:
		st.quests.set_stage("SQ-S10", n)
		_log("단계 %d" % n)


func _zone() -> String:
	return host.map.id if host.map != null else ""


func _now() -> int:
	var t := Clock.parse(host.date_text)
	return int(t[3]) * 60 + int(t[4]) if not t.is_empty() else 0


## GAME_DAY d의 달 · 날(지금 날짜에서 날 수만큼 더한다)
func _md(d: int) -> Array:
	var t := Clock.parse(Clock.add_minutes(host.date_text, (d - day()) * 1440))
	return [int(t[1]), int(t[2])] if not t.is_empty() else [0, 0]


func _box() -> bool:
	return host.box != null and host.box.active


# ---------------------------------------------------------------- 발동 · 따라 올림(P2)
func _start(why: String) -> void:
	if v("V_ACT") < 1 or q("KIRA") != 0 or st.is_dead(KIRA_ID) or v("SB_BOUGHT") == 1 or v("SB_DEBT") == 1:
		return
	_up(10)
	if q("START") == 0:
		_sq("START", day())
		var a := day() + 1                                                # 발동 다음 날부터 처음 오는 경매일(재미 검수 3 — 적어도 하루는 준다)
		while a % 3 != 0:
			a += 1
		_sq("AUCTION", a)
		var md := _md(a)
		_sq("AM", md[0])
		_sq("AD", md[1])
		host.hint("88번 기라희 — %d월 %d일 10:00 고척 돔 경매(오늘의 4번)." % [md[0], md[1]], 6.0)
		_log("발동(%s) · 경매일 %d (%d/%d)" % [why, a, md[0], md[1]])
	_catch_up()


func _catch_up() -> void:
	if stage() < 10:
		return
	if q("SEEN") == 1:
		_up(20)
	if q("SEO") == 1 and _zone().begins_with("GD-") and day() == q("AUCTION"):
		_up(30)
	if q("DONE") == 1:
		_up(40)


func _process(dt: float) -> void:
	_t += dt
	if _t < 0.5:
		return
	_t = 0.0
	if host.map == null or host.player == null or v("V_ACT") < 1:
		return
	tick()


func tick() -> void:
	_flags()
	_released()
	_move()
	_clock()
	_raid_watch()
	_catch_up()
	if stage() > 0 and stage() < 100 and st.is_dead(KIRA_ID):
		_close(12, "기라희가 죽었다")


## 경매일 깃발: OPEN(06~11시) · HOST(견적) · SEO(기서윤 09~11시) · 다음 경기 날짜
func _flags() -> void:
	var d := day()
	var now := _now()
	var aday := d % 3 == 0
	var nf := {"OPEN": 1 if aday and now >= 360 and now < 660 else 0,
		"HOST": 1 if not st.is_dead(HOST_ID) and q("RAID") == 0 and now >= 360 and now < 1320 else 0,   # 견적은 06~22시 단상 곁(밤엔 숙소 — 장부함이 빈다)
		"SEO": 1 if aday and now >= 540 and now < 660 and not st.is_dead(SEO_ID) and q("STOP") == 0 else 0}
	var changed := false
	for k in nf:
		if q(k) != nf[k]:
			_sq(k, nf[k])
			changed = true
	var nx := d if aday and now < 630 else d + (3 - d % 3)
	var md := _md(nx)
	if q("NM") != md[0] or q("ND") != md[1]:
		_sq("NM", md[0])
		_sq("ND", md[1])
	if changed and _zone().begins_with("GD-"):
		host.refresh_npcs()
		_props()


## 본소 쪽에서 풀려났다(우리 열기 · 매입 — 경매 전): 노들로(기존 대사 '세이프빌 대신 노들로')
func _released() -> void:
	var k := q("KIRA")
	if (k == 0 or k == 7) and st.boxes.has("sbcage:22") and not st.is_dead(KIRA_ID):
		_settle_now(2)
		if k == 0:
			_sq("SOL", 6)
			_close(6, "본소 우리가 열림")


func _settle_now(place: int) -> void:
	_sq("KIRA", 4)
	_sq("PLACE", place)
	_sq("SAID", 1)


## 06시 이송: 그녀의 경매일 아침 H-03 22번 칸이 빈다(주인공이 H-03을 보고 있으면 미룸)
func _move() -> void:
	var a := q("AUCTION")
	if q("KIRA") != 0 or a == 0 or st.is_dead(KIRA_ID) or v("SB_BOUGHT") == 1 or v("SB_DEBT") == 1:
		return
	if (day() > a or (day() == a and _now() >= 360)) and _zone() != "H-03":
		_sq("KIRA", 1)
		_log("고척 지하로 이송")
		if _zone().begins_with("GD-"):
			host.refresh_npcs()


## 10시 경매: 그라운드에 있으면 장면(10:15 뒤면 450에서 낀다), 10:30이 지나면 주인공 없이
func _clock() -> void:
	var a := q("AUCTION")
	if a == 0:
		return
	if q("KIRA") == 2:                                                    # 장면이 끊겼다(불러오기 등): 반쯤 된 상태 없이 그 자리부터(P10)
		if not _box() and not _staging and _zone() == "GD-01":
			host.play_scene("SQS10_AUCTION", "CONTRACT" if q("DONE") == 1 else "BEAT")
		return
	if q("KIRA") != 1 or q("DONE") == 1 or st.is_dead(HOST_ID) or st.is_dead(KIRA_ID) or q("RAID") == 1:
		return                                                            # 견적이 없거나 습격 판이면 경매가 열리지 않는다 — 기라희는 지하에 남는다
	var d := day()
	var now := _now()
	if d < a or (d == a and now < 600):
		return
	if d == a and now < 630:
		if (_zone() == "GD-02" or _zone() == "GD-03") and not st.boxes.has("s10bell"):
			st.boxes["s10bell"] = {"open": true}
			host.hint("%s 망치 소리 — \"오늘의 1번!\" 그라운드로 가면 4번에 낄 수 있다(10:30까지)." % ("위에서" if _zone() == "GD-03" else "아래에서"), 6.0)
		if _zone() == "GD-01" and not _box() and not _staging:
			_sq("KIRA", 2)
			if now >= 615:
				_sq("LATE", 1)
				_lot4()
			_stage_auction()
		return
	_offstage()


## 경매 연출(RPG 메이커식): 화면을 어둡게 → 단상 앞 입찰 자리(표지 bid)에 세움 → 밝게 → 장면
func _stage_auction() -> void:
	_staging = true
	host.ev.run("fade_out", ["black", "4"], func() -> void:
		host.enter("GD-01", "bid")
		host.refresh_npcs()
		_props()
		host.ev.run("fade_in", ["black", "4"], func() -> void:
			_staging = false
			host.play_scene("SQS10_AUCTION")))


## 주인공 없이 끝난 경매(10:30)
func _offstage() -> void:
	_sq("DONE", 1)
	_up(40)
	if q("KIN") == 1:
		_kin_end()
	elif q("SWAP") == 1:
		_swap_end()
	elif _seo_in():
		_sq("LEAD", 1)
		_sq("KIRA", 6)
		_sold_close()
	elif not st.is_dead(OVR_ID) or not st.is_dead(FORE_ID):
		_sq("LEAD", 3 if not st.is_dead(OVR_ID) else 2)                   # 기서윤이 없으면 감독관이 가져간다(죽었으면 십장)
		_sq("KIRA", 8)
		_sold_close()
	else:
		_log("유찰 — 살 사람이 없다")                                     # 기라희는 지하 대기실에 남는다(칸 문 · 습격으로 빼낸다)
	_log("주인공 없이 경매 끝 → %d" % q("KIRA"))
	if _zone().begins_with("GD-"):
		host.refresh_npcs()
		_props()


func _seo_in() -> bool:
	return q("SEO") == 1 and q("KIN") != 1 and q("THREAT") == 0 and q("SWAP") == 0


func _sold_close() -> void:
	_refund()
	var sol := 4 if q("CAST") >= 1 or q("THREAT") == 1 else 9                   # D만(장부는 남산으로 — 사람은 못 구함) · 그냥 팔림
	_sq("SOL", sol)
	_close(sol, "팔림(%d)" % q("KIRA"))


func _refund() -> void:
	if st.boxes.has("s10depo"):
		st.boxes.erase("s10depo")
		st.call_fn("caps", [100])
		host.hint("보증금 100캡을 돌려받았다.", 3.0)


# ---------------------------------------------------------------- 경매 박자(재미 검수 2)
func _lot4() -> void:
	var seo := _seo_in()
	var fore := not st.is_dead(FORE_ID)
	var ovr := not st.is_dead(OVR_ID)
	_sq("SEOIN", 1 if seo else 0)
	_sq("CAPV", (CAP_BUDGET if q("BUDGET") == 1 else CAP_SEO) if seo else (OVR_CAP if ovr else (FORE_CAP if fore else 0)))
	_sq("PRICE", 300)
	_sq("LEAD", 1 if seo else (2 if fore else (3 if ovr else 9)))
	_sq("WATCH", 0)
	if q("LATE") == 1 and fore:                                           # 늦게 왔다: 십장이 이미 450을 들었다
		_sq("PRICE", FORE_CAP)
		_sq("LEAD", 2)
		_sq("FORE", 1)
	_props()


func _bid(step: int) -> void:
	_sq("PRICE", q("PRICE") + step)
	_sq("LEAD", 0)
	_sq("WATCH", 0)
	_respond()


## 상대 패: 기서윤이 있으면 십장이 450에 한 번 끼고 빠진다 · 기서윤은 상한까지 50씩 · 없으면 십장이 500까지
func _respond() -> void:
	var p := q("PRICE")
	var fore := not st.is_dead(FORE_ID)
	if q("SEOIN") == 1 and q("KIN") != 1:
		if q("FORE") == 0 and fore and p < FORE_CAP:
			_sq("PRICE", FORE_CAP)
			_sq("LEAD", 2)
			_sq("FORE", 1)
		elif p + 50 <= q("CAPV"):
			_sq("PRICE", p + 50)
			_sq("LEAD", 1)
	elif fore and p + 50 <= FORE_CAP:
		_sq("PRICE", p + 50)
		_sq("LEAD", 2)
		_sq("FORE", 1)
	elif not st.is_dead(OVR_ID) and p + 50 <= OVR_CAP and not st.boxes.has("s10ovr"):
		st.boxes["s10ovr"] = {"open": true}                               # 감독관은 한 번만(550까지)
		_sq("PRICE", p + 50)
		_sq("LEAD", 3)
	_ksay()
	_props()


## 단상의 기라희가 값이 오를 때마다 한 줄(450 · 600 · 750 — 한 번씩)
func _ksay() -> void:
	var p := q("PRICE")
	var said := int(st.boxes.get("s10ksay", {}).get("n", 0))
	var lv := 3 if p >= 750 else (2 if p >= 600 else (1 if p >= 450 else 0))
	if lv > said:
		st.boxes["s10ksay"] = {"n": lv}
		_sq("KSAY", lv)


func _won() -> void:
	var cost := q("PRICE") - (100 if st.boxes.has("s10depo") else 0)
	st.boxes.erase("s10depo")
	st.call_fn("caps", [-cost])
	_sq("DONE", 1)
	_up(40)
	_props()
	_log("낙찰 %d" % q("PRICE"))


func _lost() -> void:
	_sq("DONE", 1)
	_up(40)
	if q("LEAD") == 9:
		_refund()                                                         # 유찰 — 기라희는 지하로(칸 문 · 습격)
		host.refresh_npcs()
		_props()
		return
	_sq("KIRA", 6 if q("LEAD") == 1 else 8)
	_sold_close()
	host.refresh_npcs()
	_props()


func _kin_end() -> void:
	_sq("KIRA", 5)
	_sq("DONE", 1)
	_sq("SOL", 2)
	st.call_fn("karma", [75])
	st.call_fn("aff", ["SV", 3])
	st.call_fn("aff", ["SB", -3])
	_refund()
	_close(2, "친척")


func _swap_end() -> void:
	_sq("KIRA", 3)
	_sq("DONE", 1)
	_sq("SOL", 8)
	st.call_fn("karma", [50])
	st.call_fn("aff", ["SV", 3])
	_refund()
	_close(8, "장부와 계약서")


# ---------------------------------------------------------------- 습격(C)
func _raid() -> void:
	if q("RAID") == 1:
		return
	_sq("RAID", 1)
	st.call_fn("aff", ["SB", -12])
	if q("KIRA") == 1 or q("KIRA") == 2:
		_sq("KIRA", 3)                                                    # 소동 속에 정문 쪽 모래주머니 뒤로(습격 해방)
		_sq("DONE", 1)
		_sq("SOL", 3)
		st.call_fn("karma", [50])
		_refund()
		_close(3, "습격")
	host.hint("새벽인력이 몰려나온다!", 4.0)
	_raid_spawn(true)
	host.refresh_npcs()
	_props()


## 습격 중 맵에 들어오거나 습격이 막 시작됐다: 그 맵 새벽인력을 적으로(맵마다 한 번 정리되면 끝)
func _raid_spawn(now: bool) -> void:
	var id := _zone()
	if q("RAID") != 1 or not id.begins_with("GD-") or st.boxes.has("gdclear:" + id):
		return
	_gd.clear()
	var lv := clampi(int(host.level()) + 2, 4, 22)
	if now:
		for n in host.npcs:
			var nid := str(n["id"])
			if ROLE.has(nid) and is_instance_valid(n["actor"]) and n["actor"].visible:
				_spawn(nid, n["actor"].loco.logical, lv)
	else:
		for n in host.map.data.get("npcs", []):
			var nid := str(n["id"])
			if ROLE.has(nid) and not st.is_dead(nid) and str(n.get("cond", "")).find("RAID") >= 0 or (nid == HOST_ID and not st.is_dead(HOST_ID)):
				_spawn(nid, Vector2(int(n["x"]) * 32 + 16, int(n["y"]) * 32 + 16), lv)
	if id == "GD-01":
		for i in EXTRA.size():
			var m := "raid_%d" % (i + 1)
			if host.map.data.get("marks", {}).has(m):
				_spawn(EXTRA[i], host.map.mark_pos(m), lv)


func _spawn(id: String, p: Vector2, lv: int) -> void:
	var cr: String = ROLE.get(id, id)
	var opts := {"lv": lv}
	if id.begins_with("N-"):
		opts["who"] = id
	var e := host.combat.spawn(cr, p, host.map, st, opts)
	e.brain.gauge = 100.0
	e.set_meta("capture", "SB")                                           # 새벽인력은 '생포만' — 지면 본소 우리에서 깬다
	_gd.append(e)


func _raid_watch() -> void:
	if _gd.is_empty():
		return
	for e in _gd:
		if is_instance_valid(e) and not e.cmb.dead:
			return
	st.boxes["gdclear:" + _zone()] = {"open": true}
	_gd.clear()
	host.hint("고척이 조용해졌다.", 4.0)


func _pen() -> void:
	if q("PEN") == 1:
		return
	_sq("PEN", 1)
	st.vars.set_v("SQS_S10", 1)                                           # MQ-504 '대기실 해방'을 먼저 이룸(순서 파괴, RECON_SPEC N-68)
	st.vars.set_v("PD_R02_GD", v("PD_R02_GD") - 15)
	st.call_fn("karma", [100])
	if q("KIRA") == 1:
		_sq("KIRA", 3)
		_sq("DONE", 1)
		_sq("SOL", 3)
		st.call_fn("karma", [50])
		_close(3, "대기실 해방")
	st.deeds.record(st, "side", "R02", 3, {"SB": -12}, Clock.abs_min(host.date_text), {"tag": "SQS10_PEN", "place": "R02",
		"what": "고척 돔 지하 대기실 문이 열려 번호표 단 사람들이 흩어졌다", "seen_by": [], "about": []})
	host.refresh_npcs()


# ---------------------------------------------------------------- 맵 · 하루 판정
func _on_map(_id: String) -> void:
	if host.map == null:
		return
	_gd.clear()
	if _zone() != "GD-01":
		_sq("CAT", 0)
	if _zone().begins_with("GD-"):
		_flags()
		_props()
		_raid_spawn(false)
	_barks()


func _props() -> void:
	if host.map == null:
		return
	var z := _zone()
	if GLASS.has(z):
		host.map.set_prop_state(GLASS[z], "sil" if q("SEO") == 1 and q("RAID") == 0 else "")
	if z != "GD-01":
		return
	var b := ""
	if q("STOP") == 1:
		b = "stop"
	elif q("RAID") == 1:
		b = "raid"
	elif q("KIRA") == 2 and q("PRICE") > 300:
		b = "p%d" % mini(q("PRICE"), 1000)
	elif q("DONE") == 1:
		b = {6: "sold_sv", 8: "sold_bj" if q("LEAD") == 3 else "sold_tank", 3: "free", 4: "free"}.get(q("KIRA"), "")
	host.map.set_prop_state(BOARD, b)
	if q("LEDGER") >= 1:
		host.map.set_prop_state(LBOX, "open")


## 세계가 경매일을 알린다(재미 검수 3) · 놓친 결과를 세계가 안다(재미 검수 4)
func _barks() -> void:
	var a := q("AUCTION")
	for n in host.npcs:
		var id := str(n["id"])
		if a > 0 and q("KIRA") <= 1 and (day() == a - 1 or (day() == a and _now() < 630)):
			var when := "내일" if day() == a - 1 else "오늘"
			if id in ["CR-435", "CR-437", "N-R02-037"]:
				n["bark"] = "%s 고척 4번 — 기씨네가 온대. 열 시 망치 소리 들리면 끝이야." % when
		if q("KIRA") == 6:
			if id == "N-R02-050":
				n["bark"] = "88번 아가씨, 세이프빌로 갔대요. 번호표 그대로."
			elif id == "N-R02-042":
				n["bark"] = "고척에서 또 하나 팔려 갔다더라. 노들 애라던데."
		elif q("KIRA") == 8 and id == "N-R02-042":
			n["bark"] = "88번은 탱크마을 트럭에 탔대. 탱크 청소…. 오래 못 버텨."


func _on_day(_d: int) -> void:
	# 고척 정문 앞에서 하룻밤 — 스스로 고른 곳에 선다(재미 검수 8: 정착 메뉴 없음)
	if q("KIRA") == 3:
		if q("SAID") == 0:
			_sq("PLACE", 1 if v("SB_127") == 6 and not st.is_dead("N-R02-039") else 2)
		_settle_now(q("PLACE"))
		_log("정착 %d" % q("PLACE"))
	# D 방송: 넘긴 다음 06시 남산이 읽는다 → 기서윤은 다음 경매부터 안 온다
	if q("CAST") == 1:
		_sq("CAST", 2)
		_sq("STOP", 1)
		_log("남산 방송 — 세이프빌 구매 중단")
	# 본소 장부(MQ-105 C · 소각): 경매 전이면 '석방 명단' — 노들로
	if q("KIRA") == 0 and (v("HO_LEDGER") == 8 or v("HO_LEDGER") == 99 or v("SB_DEBT") == 1) and not st.is_dead(KIRA_ID):
		_settle_now(2)
		if q("START") > 0:
			_sq("SOL", 6)
			_close(6, "석방 명단")


func _close(sqr: int, why: String) -> void:
	if stage() >= 100 or q("START") == 0:
		return
	st.vars.set_v("SQR_S10", sqr)
	_up(100)
	var xp: int = {4: 300, 9: 0, 12: 0}.get(sqr, 550)
	if xp > 0:
		st.call_fn("xp", [xp])
	var what: String = {1: "고척 경매에서 88번이 계약서를 손에 쥐고 걸어 나갔다", 2: "세이프빌 대리인이 먼 친척을 번호표 없이 데려갔다",
		3: "고척 경매장이 습격당하고 88번이 달아났다", 4: "고척 구매 장부가 남산 방송으로 갔지만 88번은 팔려 갔다",
		5: "고척 경매에서 산 88번이 본소 우리에 맡겨졌다", 6: "본소 우리에서 88번이 노들로 풀려났다",
		7: "고척 경매에서 산 88번이 세이프빌에 되팔렸다", 8: "구매 장부와 88번의 계약서가 맞바뀌었다",
		9: "고척 경매에서 88번이 팔려 갔다", 10: "고척 지하 대기실에서 88번이 몰래 빠져나갔다", 12: "88번 기라희가 죽었다"}.get(sqr, "")
	st.deeds.record(st, "side", "R02", 2, {"SB": 0}, Clock.abs_min(host.date_text), {"tag": "SQS10_%d" % sqr, "place": "R02",
		"what": what, "seen_by": [], "about": []})
	_log("닫힘 — " + why)


# ---------------------------------------------------------------- 원고 명령(@cmd s10 …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]):
		"start":
			_start("문" if str(a[1]) == "1" else "칠판")
		"board":
			_sq("SEEN", 1)
			_catch_up()
		"seen":
			_catch_up()
		"told":
			_sq("TOLD", 1)
		"carve":
			_sq("CARVE", 1)
		"pad":
			_sq("PADDLE", 1)
			if str(a[1]) == "1":
				st.boxes["s10depo"] = {"open": true}
		"old":
			_sq("OLD", 1)
			st.call_fn("karma", [10])
		"lot4":
			if q("LATE") == 0:
				_lot4()
		"bid":
			_bid(int(a[1]))
		"jump":
			_sq("JUMP", 1)
			_sq("PRICE", 600)
			_sq("LEAD", 0)
			if str(a[1]) != "1":
				_respond()                                                    # 믿지 않았다 — 상한이 남았으면 따라온다
			_ksay()
			_props()
		"ksaid":
			_sq("KSAY", 0)
		"glance":
			_sq("GLANCE", 1)
		"give":
			_sq("GAVE", 1)
			_sq("PADDLE", 0)
		"watch":
			_sq("WATCH", q("WATCH") + 1)
		"won":
			_won()
		"free":
			_sq("KIRA", 3)
			_sq("SOL", 1)
			st.call_fn("karma", [50])
			st.call_fn("aff", ["SB", 3])
			if q("SEOIN") == 1:
				st.call_fn("aff", ["SV", -3])
			_close(1, "낙찰 — 계약서를 건넴")
			host.refresh_npcs()
		"keep":
			st.boxes.erase("sbcage:22")                                       # 반장이 22번 칸에 새 자물쇠를 건다
			_sq("KIRA", 7)
			_sq("SOL", 5)
			st.call_fn("karma", [-50])
			st.call_fn("aff", ["SB", 5])
			_close(5, "소유")
			host.refresh_npcs()
		"resell":
			st.call_fn("caps", [int(q("CAPV") * 0.9)])                         # 회장단 선(상한)에서 견적 수수료 열에 하나
			_sq("KIRA", 6)
			_sq("SOL", 7)
			st.call_fn("karma", [-50])
			st.call_fn("aff", ["SB", 5])
			st.call_fn("aff", ["SV", 3])
			_close(7, "되팖")
			host.refresh_npcs()
			_props()
		"lost":
			_lost()
		"kin":
			_sq("KIN", 1)
			_log("친척(B)")                                                   # 경매 중이면 'kinend'가, 아니면 경매 시각(_offstage · 장면 KINDONE)이 마무리한다
		"kinend":
			_sq("DONE", 1)
			_up(40)
			_kin_end()
			host.refresh_npcs()
			_props()
		"kinfail":
			_sq("KIN", 9)
		"budget":
			_sq("BUDGET", 1)
		"threat":
			_sq("THREAT", 1)
			st.call_fn("aff", ["SV", -5])
		"swap":
			_sq("SWAP", 1)
			_sq("LEDGER", 3)
			st.call_fn("take", ["M-322", 1])
		"swapend":
			_sq("DONE", 1)
			_up(40)
			_swap_end()
			host.refresh_npcs()
			_props()
		"raid":
			_raid()
		"pen":
			_pen()
		"cell":
			_sq("KIRA", 3)
			_sq("SOL", 10)
			st.call_fn("karma", [50])
			st.call_fn("aff", ["SB", -5])
			_close(10, "대기실에서 빼냄")
			host.refresh_npcs()
		"ledger":
			_sq("LEDGER", 1)
			st.call_fn("give", ["M-322", 1])
			host.hint("고척 구매 장부를 챙겼다 — 세이프빌 · 비상정부 · 탱크마을.", 4.0)
			_props()
		"tak":
			_sq("TAK", 2)
			_sq("CODE", 1)
		"booth":
			_sq("BOOTH", 1)
		"cast":
			st.call_fn("take", ["M-322", 1])
			_sq("LEDGER", 2)
			_sq("CAST", 1)
			_sq("CAST_DAY", day() + 1)
			st.call_fn("karma", [50])
			st.call_fn("aff", ["SV", -8])
			st.call_fn("aff", ["JC", 3])
			st.call_fn("aff", ["SB", -1])                                     # 연동(JC +3 → SB −1)
			host.hint("내일 아침 남산 방송이 장부를 읽는다.", 4.0)
		"up":
			host.go("GD-02", "from_catwalk")
		"down":
			_sq("CAT", 1)                                                     # 견적 눈 밖으로 단상 뒤에 내려왔다(장부함)
			host.go("GD-01", "from_catwalk")
		"release":
			_sq("KIRA", 4)
			_sq("PLACE", 1 if v("SB_127") == 6 and not st.is_dead("N-R02-039") else 2)
			_sq("SAID", 1)
			st.call_fn("karma", [25])
			host.refresh_npcs()
		"bought":                                                          # 황두칠 매입(MQ-105 BUY88 · BUY88B)
			if q("KIRA") == 0:
				_settle_now(2)
				if q("START") > 0:
					_sq("SOL", 6)
					_close(6, "본소 매입")
		"say":
			_sq("PLACE", int(a[1]))
			_sq("SAID", 1)
		"reward":
			_sq("REWARD", 1)
			st.call_fn("give", ["M-321", 1])
		"refuse":
			_sq("REFUSED", 1)
			st.call_fn("karma", [25])                                         # 해방 보상 사양(SD-10)
	done.call()
