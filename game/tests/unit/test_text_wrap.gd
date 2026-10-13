## SD-12 §14.2 줄바꿈: 어절 단위, 행두·행말 금칙, 긴 어절만 글자 단위, 줄바꿈 금지 공백, 강제 줄바꿈.
extends RefCounted


func test_words(t) -> void:
	var m := TextWrap.mono(6.0)                                    # 한글 12px, 영숫자 6px → 480px = 한글 40자
	t.eq(TextWrap.wrap("가나다 라마바 사아자", m, 96.0), ["가나다 라마바", "사아자"] as Array[String], "어절 단위")
	t.eq(TextWrap.wrap("가나다라마바사아자차카타", m, 60.0), ["가나다라마", "바사아자차", "카타"] as Array[String], "긴 어절은 글자 단위")
	t.eq(TextWrap.wrap("첫 줄\n둘째 줄", m, 480.0), ["첫 줄", "둘째 줄"] as Array[String], "강제 줄바꿈")
	var forty := "가".repeat(40)
	t.eq(TextWrap.wrap(forty, m, 480.0).size(), 1, "40자 한 줄")
	t.eq(TextWrap.wrap(forty + "가", m, 480.0).size(), 2, "41자 두 줄")


func test_kinsoku(t) -> void:
	var m := TextWrap.mono(6.0)
	var lines := TextWrap.wrap("가나다라 마바사아 …그래", m, 96.0)
	for l in lines:
		t.ok(not TextWrap.NO_START.contains(l[0]), "행두 금칙: " + l)
	t.eq(lines, ["가나다라", "마바사아 …그래"] as Array[String], "줄임표는 앞 어절에 붙는다")
	var h := TextWrap.wrap("가나다라마바.사아", m, 72.0)
	for l in h:
		t.ok(not TextWrap.NO_START.contains(l[0]), "글자 단위로 잘라도 행두 금칙: " + l)
	var nb := TextWrap.wrap("가나다 300" + TextFmt.NBSP + "캡을 냈다", m, 84.0)
	t.ok(nb.any(func(l): return l.contains("300" + TextFmt.NBSP + "캡을")), "숫자+단위는 줄바꿈 금지 공백으로 묶인다: " + str(nb))
