extends Node
## 저장/불러오기 왕복 검증 — 오토로드가 필요하므로 씬과 함께 돈다.
##   godot --quit-after 200 -- --savetest
##
## 보는 것:
##   1) 값을 바꾸고 저장 → 초기화 → 불러오기 하면 값이 돌아오는가
##   2) 아이템(인벤토리·장착)이 그대로 오는가
##   3) 세이브 파일에 없는 키가 있어도 기본값으로 넘어가는가 (하위 호환)
##   4) wipe() 가 실제로 지우는가

var _f := 0

func _ready() -> void:
	var want := false
	for a in OS.get_cmdline_user_args():
		if String(a) == "--savetest":
			want = true
	if not want:
		queue_free()
		return
	# 타이틀 메뉴가 트리를 멈춰도 검증은 돌아야 한다
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func _process(_d: float) -> void:
	_f += 1
	if _f < 30:            ## 월드가 다 서길 기다린다
		return
	set_process(false)
	_run()
	get_tree().quit()

func _run() -> void:
	var bad := 0
	print("SV| ══ 저장/불러오기 왕복 ══")

	# ── 1) 값을 심는다 ──
	GameManager.chapter = 4
	GameManager.day_count = 9
	GameManager.player_level = 12
	GameManager.player_exp = 77
	GameManager.seals_done = 2
	CraftManager.essence = 1234
	TraitManager.current_trait = {"name": "시험 특성", "rarity": 5, "atk_pct": 7.0}
	PetManager.owned = ["wolf_pup", "raven"]
	PetManager.active = "raven"

	var it := ItemData.new()
	it.name = "시험용 검"
	it.rarity = 6
	it.atk_bonus = 42.5
	it.slot = "weapon"
	it.skin = "sword"
	it.enhance_level = 3
	PlayerStats.inventory.clear()
	PlayerStats.inventory.append(it)
	PlayerStats.equipped = {"weapon": it}

	SaveGame.achievements = {"first_blood": true}
	SaveGame.upgrades = {"atk": 3, "hp": 1}
	SaveGame.affinity = {"hunter_old": 5}
	SaveGame.puzzles = {"forest_levers": true}
	SaveGame.ng_plus = 1

	if not SaveGame.save():
		print("SV| ✘ 저장 실패")
		return
	print("SV|  저장 완료 → %s"
		% ProjectSettings.globalize_path(SaveGame.PATH))

	# ── 2) 전부 지운다 ──
	GameManager.chapter = 1
	GameManager.day_count = 1
	GameManager.player_level = 1
	GameManager.player_exp = 0
	GameManager.seals_done = 0
	CraftManager.essence = 0
	TraitManager.current_trait = {}
	PetManager.owned = []
	PetManager.active = ""
	PlayerStats.inventory.clear()
	PlayerStats.equipped = {}
	SaveGame.achievements = {}
	SaveGame.upgrades = {}
	SaveGame.affinity = {}
	SaveGame.puzzles = {}
	SaveGame.ng_plus = 0

	# ── 3) 다시 읽는다 ──
	if not SaveGame.load_game():
		print("SV| ✘ 불러오기 실패")
		return

	bad += _eq("챕터", GameManager.chapter, 4)
	bad += _eq("일차", GameManager.day_count, 9)
	bad += _eq("레벨", GameManager.player_level, 12)
	bad += _eq("경험치", GameManager.player_exp, 77)
	bad += _eq("봉인", GameManager.seals_done, 2)
	bad += _eq("마석", CraftManager.essence, 1234)
	bad += _eq("특성명", String(TraitManager.current_trait.get("name", "")), "시험 특성")
	bad += _eq("펫 수", PetManager.owned.size(), 2)
	bad += _eq("활성 펫", PetManager.active, "raven")
	bad += _eq("업적", SaveGame.has_achievement("first_blood"), true)
	bad += _eq("강화 atk", SaveGame.upgrade_level("atk"), 3)
	bad += _eq("호감도", int(SaveGame.affinity.get("hunter_old", 0)), 5)
	bad += _eq("퍼즐", SaveGame.is_puzzle_solved("forest_levers"), true)
	bad += _eq("NG+", SaveGame.ng_plus, 1)

	# 아이템 왕복
	bad += _eq("인벤 수", PlayerStats.inventory.size(), 1)
	if PlayerStats.inventory.size() > 0:
		var got = PlayerStats.inventory[0]
		bad += _eq("아이템명", got.name, "시험용 검")
		bad += _eq("아이템 등급", got.rarity, 6)
		bad += _eq("아이템 공격", got.atk_bonus, 42.5)
		bad += _eq("아이템 강화", got.enhance_level, 3)
	bad += _eq("장착 무기", PlayerStats.equipped.has("weapon"), true)

	# ── 4) 없는 키 하위 호환 ──
	var f := FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
	f.store_string('{"version": 99, "progress": {"chapter": 6}}')
	f.close()
	if SaveGame.load_game():
		bad += _eq("빈 세이브 챕터", GameManager.chapter, 6)
		bad += _eq("빈 세이브 레벨(기본)", GameManager.player_level, 1)
		print("SV|  ✔ 키가 없어도 기본값으로 넘어감 (하위 호환)")
	else:
		print("SV|  ✘ 최소 세이브를 읽지 못함")
		bad += 1

	# ── 5) wipe ──
	SaveGame.wipe()
	if SaveGame.exists():
		print("SV|  ✘ wipe() 후에도 파일이 남아 있다")
		bad += 1
	else:
		print("SV|  ✔ wipe() 로 세이브 삭제됨")

	print("SV| " + ("✔ 전부 통과" if bad == 0 else "✘ 실패 %d건" % bad))
	print("SV| DONE")

func _eq(label: String, got, want) -> int:
	if typeof(got) == TYPE_FLOAT or typeof(want) == TYPE_FLOAT:
		if absf(float(got) - float(want)) < 0.001:
			return 0
	elif got == want:
		return 0
	print("SV|  ✘ %s: %s (기대 %s)" % [label, str(got), str(want)])
	return 1
