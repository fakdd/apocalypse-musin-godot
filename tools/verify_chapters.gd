extends SceneTree
## 챕터 테이블 검증 — headless 로 ChapterConfig 를 직접 읽는다.
##   godot --headless --script tools/verify_chapters.gd --quit-after 2
##
## 보는 것:
##   1) 1~7 챕터가 전부 정의되어 있는가
##   2) 테마 키가 빠진 곳은 없는가 (빠지면 그 챕터만 이전 색으로 보인다)
##   3) 캠페인 JSON 이 실제로 있는가 (없으면 main 으로 폴백된다)
##   4) 난이도 배율이 챕터 순으로 증가하는가

const P := "CH| "

const THEME_KEYS := [
	"day_sky_top", "day_sky_horizon", "night_sky_top", "night_sky_horizon",
	"day_fog", "night_fog", "fog_color", "ground", "sun",
]

func _init() -> void:
	var problems := 0
	var prev_hp := 0.0
	var prev_dmg := 0.0

	print(P + "══ 챕터 %d~%d ══" % [ChapterConfig.FIRST, ChapterConfig.LAST])

	for n in range(ChapterConfig.FIRST, ChapterConfig.LAST + 1):
		var c: Dictionary = ChapterConfig.get_chapter(n)
		var camp: String = ChapterConfig.campaign_of(n)
		var has_json := FileAccess.file_exists(
			"res://data/campaigns/campaign_%s.json" % camp)

		print(P + "%d. %-12s 캠페인=%-18s %s  보스=%-12s 몹%d종  HP×%.2f 공×%.2f"
			% [n, ChapterConfig.name_of(n), camp,
			"있음" if has_json else "없음→main",
			ChapterConfig.boss_of(n), ChapterConfig.monsters_of(n).size(),
			float(c.get("hp_mult", 1.0)), float(c.get("dmg_mult", 1.0))])

		# 테마 키 누락
		var theme: Dictionary = ChapterConfig.theme_of(n)
		var missing := []
		for k in THEME_KEYS:
			if not theme.has(k):
				missing.append(k)
		if not missing.is_empty():
			print(P + "   ✘ 테마 키 누락: " + str(missing))
			problems += 1

		# 몬스터/보스 비어 있음
		if ChapterConfig.monsters_of(n).is_empty():
			print(P + "   ✘ 몬스터 목록이 비었다")
			problems += 1
		if ChapterConfig.boss_of(n) == "":
			print(P + "   ✘ 보스가 없다")
			problems += 1

		# 난이도는 챕터 순으로 올라가야 한다
		var hp: float = float(c.get("hp_mult", 1.0))
		var dmg: float = float(c.get("dmg_mult", 1.0))
		if hp < prev_hp or dmg < prev_dmg:
			print(P + "   ✘ 난이도가 앞 챕터보다 낮다 (HP×%.2f 공×%.2f)" % [hp, dmg])
			problems += 1
		prev_hp = hp
		prev_dmg = dmg

	# ── 몬스터·보스가 EnemyConfig 에 실제로 있는가 ──
	# 없으면 게임이 조용히 hound / overlord 로 갈아치워, 지역색이 사라진다.
	print(P + "── 몬스터 정의 대조 ──")
	for n in range(ChapterConfig.FIRST, ChapterConfig.LAST + 1):
		var miss := []
		for m in ChapterConfig.monsters_of(n):
			if not EnemyConfig.TYPES.has(String(m)):
				miss.append(String(m))
		var b: String = ChapterConfig.boss_of(n)
		var bok: bool = EnemyConfig.TYPES.has(b)
		var bboss: bool = EnemyConfig.BOSS_TYPES.has(b)
		if miss.is_empty() and bok and bboss:
			print(P + "  ✔ %d장 %s — 몹 %d종 정의됨, 보스 %s (모델 %s)"
				% [n, ChapterConfig.name_of(n),
				ChapterConfig.monsters_of(n).size(), b,
				String(EnemyConfig.TYPES[b]["model"]).get_file()])
		else:
			if not miss.is_empty():
				print(P + "  ✘ %d장: EnemyConfig 에 없는 몬스터 %s" % [n, str(miss)])
				problems += 1
			if not bok:
				print(P + "  ✘ %d장: 보스 '%s' 가 EnemyConfig 에 없다" % [n, b])
				problems += 1
			elif not bboss:
				print(P + "  ✘ %d장: 보스 '%s' 가 BOSS_TYPES 에 없다 (포탈이 안 열린다)" % [n, b])
				problems += 1

	# 모델 파일이 실제로 있는가
	var bad_model := []
	for t in EnemyConfig.TYPES:
		var path: String = String(EnemyConfig.TYPES[t]["model"])
		if not ResourceLoader.exists(path):
			bad_model.append("%s→%s" % [t, path.get_file()])
	if bad_model.is_empty():
		print(P + "  ✔ 몬스터 모델 %d개 전부 존재" % EnemyConfig.TYPES.size())
	else:
		print(P + "  ✘ 없는 모델: " + str(bad_model))
		problems += 1

	# 범위 밖 접근이 안전한가 (0, 99 를 넣어도 죽으면 안 된다)
	var lo: Dictionary = ChapterConfig.get_chapter(0)
	var hi: Dictionary = ChapterConfig.get_chapter(99)
	if lo.is_empty() or hi.is_empty():
		print(P + "✘ 범위 밖 챕터 접근이 빈 값을 돌려준다")
		problems += 1
	else:
		print(P + "✔ 범위 밖 접근 안전 (0→%s, 99→%s)"
			% [String(lo.get("name", "?")), String(hi.get("name", "?"))])

	print(P + ("✔ 문제 없음" if problems == 0 else "✘ 문제 %d건" % problems))
	print(P + "DONE")
	quit(0 if problems == 0 else 1)
