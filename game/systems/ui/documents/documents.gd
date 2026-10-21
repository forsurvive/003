## 서류 UI 5종의 입구 (단계 0-4). 이벤트 실행기의 `doc 이름` 연출 명령(doc_requested)을 받아 서류를 열고, 닫히면 연출을 잇는다.
##   birth    출생신고서(MQ-P1)              record   학교생활기록부(MQ-P2)
##   aptitude 적성 평가 판독 카드(MQ-P3)      result   결과 통지서 + 태그 선택(MQ-P3)
##   exit     출구 점검표·전출 신고서(MQ-P4)
class_name Documents
extends RefCounted

const NAMES := ["birth", "record", "aptitude", "result", "exit"]


static func make(doc_name: String, st: StoryState) -> DocScreen:
	match doc_name:
		"birth":
			return RegisterTerminal.new().setup(st, "birth")
		"exit":
			return RegisterTerminal.new().setup(st, "exit")
		"record":
			return RecordBook.new().setup(st)
		"aptitude":
			return AptitudeCard.new().setup(st)
		"result":
			return ResultSheet.new().setup(st)
		"ledger":
			return LedgerCopy.new().setup(st)                                 # FQ-SB-01 출근부 2쪽(1-12f)
	push_error("서류 이름을 모른다: " + doc_name)
	return null


## 서류를 host 아래에 연다. done은 닫힐 때 부른다(확정 여부).
static func open(doc_name: String, st: StoryState, host: Node, done: Callable = Callable()) -> DocScreen:
	var d := make(doc_name, st)
	if d == null:
		if done.is_valid():
			done.call(false)
		return null
	if done.is_valid():
		d.closed.connect(func(ok: bool) -> void: done.call(ok))
	host.add_child(d)
	return d


## 이벤트 실행기에 붙인다: 원고의 `@cmd doc birth` → 출생신고서를 열고, 닫히면 다음 연출로.
static func attach(ev: EventRunner, st: StoryState, host: Node) -> void:
	ev.doc_requested.connect(func(doc_name: String, done: Callable) -> void:
		open(doc_name, st, host, func(_ok: bool) -> void: done.call()))
