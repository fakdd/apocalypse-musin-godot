extends Node
## 랜드마크 등록소 — 모든 랜드마크의 정의와 탐험 진행도를 보유한다.
##
## 왜 Autoload 인가:
##   · 미니맵(UI), HUD(배너/퀘스트), SpawnManager(스폰 테이블), LootManager(아이템 테이블),
##     SoundManager(BGM)가 모두 같은 정보를 봐야 한다. 씬 트리를 타고 서로를 찾게 하면
##     결합이 얽히므로, 한 곳에 두고 시그널로 알린다.
##   · 탐험 진행도는 세이브 대상이라 씬 재생성과 무관하게 살아 있어야 한다.

signal landmark_registered(data: LandmarkData)
signal landmark_entered(data: LandmarkData)
signal landmark_exited(data: LandmarkData)
signal landmark_explored(data: LandmarkData)   ## 최초 진입 순간 1회
signal explore_reward(data: LandmarkData, exp_gain: int, essence: int)  ## 최초 발견 보상
signal landmark_cleared(data: LandmarkData)    ## 소환된 적을 모두 처치
signal progress_changed(explored: int, total: int)
signal quest_completed(quest_id: String)
signal landmark_unlocked(id: String)
signal landmark_blocked(id: String, need_quest: String)  ## 잠긴 곳에 들어가려 함

## ── 탐험/클리어 경험치 ──
## 캠페인의 "추천 레벨"은 마지막 지역이 Lv20 이다. 16개 구역을 전부 깨면
## 그 근처에 닿도록 잡은 값이다. 낮추면 모든 랜드마크가 영구 언더레벨이 된다.
const EXP_EXPLORE_BASE := 40
const EXP_EXPLORE_PER_SPAWN := 15
const EXP_CLEAR_BASE := 90
const EXP_CLEAR_PER_SPAWN := 30

var landmarks: Array[LandmarkData] = []
var by_id := {}
var current: LandmarkData = null            ## 플레이어가 지금 들어가 있는 랜드마크 (없으면 null)

## 랜드마크별로 소환된 적을 추적한다 (클리어 판정용)
var _pending_kills := {}                    ## id -> 남은 적 수
## 아직 남은 웨이브 수. 이게 없으면 1웨이브만 잡아도 클리어가 나서
## 2·3웨이브와 보스가 영원히 소환되지 않는다.
var _waves_left := {}                       ## id -> 남은 웨이브 수

## ── 캠페인 연동 (v2.2) ──
## 캠페인이 데이터 소스가 되면서 잠금/퀘스트가 여기로 들어왔다.
var campaign_manager = null                 ## CampaignManager (없으면 캠페인 미사용)
var _locks := {}                            ## landmark_id -> 필요한 quest_id
var _done_quests := {}                      ## quest_id -> true
var _talked := {}                           ## "landmark|npc" -> true

func bind_campaign(manager) -> void:
	campaign_manager = manager

## ── 잠금 ──
func set_lock(landmark_id: String, need_quest: String) -> void:
	if need_quest == "":
		_locks.erase(landmark_id)
	else:
		_locks[landmark_id] = need_quest

func unlock(landmark_id: String) -> void:
	if _locks.erase(landmark_id):
		landmark_unlocked.emit(landmark_id)

func is_locked(landmark_id: String) -> bool:
	var need: String = _locks.get(landmark_id, "")
	return need != "" and not _done_quests.has(need)

func lock_reason(landmark_id: String) -> String:
	return _locks.get(landmark_id, "")

func done_quests() -> PackedStringArray:
	var out := PackedStringArray()
	for q in _done_quests:
		out.append(String(q))
	return out

## ── 퀘스트 ──
func complete_quest(quest_id: String) -> void:
	if quest_id == "" or _done_quests.has(quest_id):
		return
	_done_quests[quest_id] = true
	quest_completed.emit(quest_id)
	# 이 퀘스트로 잠겨 있던 곳들을 연다
	for lid in _locks.keys():
		if _locks[lid] == quest_id:
			_locks.erase(lid)
			landmark_unlocked.emit(lid)

func is_quest_done(quest_id: String) -> bool:
	return _done_quests.has(quest_id)

## NPC 와 대화했음을 기록한다 (rescue 목표 판정에 쓴다)
func notify_npc_talked(landmark_id: String, npc_id: String) -> void:
	var key := "%s|%s" % [landmark_id, npc_id]
	if _talked.has(key):
		return
	_talked[key] = true
	if campaign_manager == null:
		return
	var site = campaign_manager.node_of(landmark_id)
	if site == null or site.quest == null:
		return
	# 구조 목표는 그 랜드마크의 NPC 를 모두 만나면 완료된다
	if site.quest.objective == "rescue":
		var talked := 0
		for npc in site.npcs:
			if _talked.has("%s|%s" % [landmark_id, npc.id]):
				talked += 1
		if talked >= site.quest.target:
			complete_quest(site.quest.id)

func register(data: LandmarkData) -> void:
	if data == null or data.id == "":
		return
	if by_id.has(data.id):
		# 같은 id 가 다시 등록되면 위치만 갱신한다 (씬 재생성 시)
		var old: LandmarkData = by_id[data.id]
		old.center = data.center
		old.radius = data.radius
		return
	landmarks.append(data)
	by_id[data.id] = data
	landmark_registered.emit(data)
	progress_changed.emit(explored_count(), landmarks.size())

## 씬이 다시 만들어질 때 위치 정보만 비운다. 탐험 진행도는 유지한다.
func clear_placements() -> void:
	current = null
	_pending_kills.clear()
	_waves_left.clear()

## 완전 초기화 (새 게임)
func reset() -> void:
	landmarks.clear()
	by_id.clear()
	current = null
	_pending_kills.clear()
	_waves_left.clear()
	_locks.clear()
	_done_quests.clear()
	_talked.clear()
	campaign_manager = null
	progress_changed.emit(0, 0)

func explored_count() -> int:
	var n := 0
	for l in landmarks:
		if l.explored:
			n += 1
	return n

func cleared_count() -> int:
	var n := 0
	for l in landmarks:
		if l.cleared:
			n += 1
	return n

func get_data(id: String) -> LandmarkData:
	return by_id.get(id, null)

## 위치가 어느 랜드마크 안인지 (없으면 null)
func at_position(pos: Vector3) -> LandmarkData:
	for l in landmarks:
		if l.is_inside(pos):
			return l
	return null

## ── 진입 / 이탈 ──

## LandmarkZone 이 플레이어 진입 시 호출한다.
func notify_enter(data: LandmarkData) -> void:
	if data == null or current == data:
		return
	if current != null:
		notify_exit(current)
	current = data
	data.visited_count += 1

	# 캠페인 이벤트 — 진입/최초 진입
	if campaign_manager != null:
		campaign_manager.fire_event(data.id, "on_enter")

	var first_time := not data.explored
	if first_time:
		data.explored = true
		_grant_explore_reward(data)      ## EXP → Essence
		landmark_explored.emit(data)     ## 미니맵이 이 시점부터 이 랜드마크를 채워 그린다
		progress_changed.emit(explored_count(), landmarks.size())
		if campaign_manager != null:
			campaign_manager.fire_event(data.id, "on_first_visit")
			# 진입만으로 끝나는 퀘스트는 여기서 완료된다
			var site = campaign_manager.node_of(data.id)
			if site != null and site.quest != null and site.quest.objective == "explore":
				complete_quest(site.quest.id)

	# BGM 전환 — 랜드마크마다 분위기가 바뀐다
	if data.bgm != "":
		SoundManager.set_bgm(data.bgm)
	if data.enter_stinger != "":
		SoundManager.play(data.enter_stinger, -8.0)

	landmark_entered.emit(data)

## 최초 발견 보상 — 위험한 곳일수록 후하다.
## 순서: EXP → Essence → (지도는 explored 플래그로 자동) → HUD 는 explore_reward 를 듣는다.
func _grant_explore_reward(data: LandmarkData) -> void:
	# 위험도는 미니맵 색이 아니라 스폰 예산으로 가늠한다 (데이터가 이미 갖고 있는 값)
	var weight: int = maxi(1, data.spawn_budget)
	var exp_gain: int = EXP_EXPLORE_BASE + weight * EXP_EXPLORE_PER_SPAWN
	var essence: int = 5 + weight * 2

	GameManager.add_exp(exp_gain)
	CraftManager.add_essence(essence)
	explore_reward.emit(data, exp_gain, essence)

func notify_exit(data: LandmarkData) -> void:
	if data == null:
		return
	if current == data:
		current = null
		# 랜드마크를 벗어나면 기본 BGM 으로 돌아간다
		SoundManager.set_bgm(SoundManager.default_bgm_for_phase())
	landmark_exited.emit(data)

## ── 클리어 추적 ──

## 랜드마크가 적 n마리를 소환했음을 알린다.
func register_spawns(id: String, count: int) -> void:
	if count <= 0:
		return
	_pending_kills[id] = _pending_kills.get(id, 0) + count

## 이 랜드마크가 소환한 적이 아직 살아 있는가 (웨이브 진행 판정)
func has_pending(id: String) -> bool:
	return _pending_kills.get(id, 0) > 0

## 소환된 적이 처치가 아니라 **삭제**로 사라졌을 때 카운터를 비운다.
## 아침이 오면 DayNightManager 가 모든 적을 queue_free 하는데, 그 경로는
## notify_kill 을 부르지 않는다. 그대로 두면 그 랜드마크는 "아직 적이 남았다"고
## 영원히 믿어 다시는 클리어되지 않는다.
func drop_pending(id: String) -> void:
	_pending_kills.erase(id)
	_waves_left.erase(id)

## 웨이브가 시작되었음을 알린다 (HUD/이벤트용)
func notify_wave(id: String, index: int, total: int) -> void:
	_waves_left[id] = maxi(0, total - index)
	if campaign_manager != null:
		campaign_manager.fire_event(id, "on_wave_start")

## 랜드마크 소속 적이 죽었음을 알린다 (Enemy3D._die 에서 호출)
## 비전투 영역(보물·쉼터·상인·퍼즐)은 싸울 적이 없다.
## 진입 즉시 클리어로 처리해 잠금 사슬이 막히지 않게 한다.
func force_clear(id: String) -> void:
	_pending_kills.erase(id)
	_waves_left[id] = 0
	var d: LandmarkData = by_id.get(id, null)
	if d == null or d.cleared:
		return
	_pending_kills[id] = 1
	notify_kill(id)

func notify_kill(id: String) -> void:
	if not _pending_kills.has(id):
		return
	_pending_kills[id] -= 1
	if _pending_kills[id] > 0:
		return
	_pending_kills.erase(id)
	# 아직 남은 웨이브가 있으면 클리어가 아니다 — LandmarkZone 이 다음 웨이브를 부른다
	if int(_waves_left.get(id, 0)) > 0:
		return
	var data: LandmarkData = by_id.get(id, null)
	if data == null or data.cleared:
		return
	data.cleared = true
	# 클리어는 발견보다 크게 준다 (밤에 싸워서 얻는 성장)
	GameManager.add_exp(EXP_CLEAR_BASE + maxi(1, data.spawn_budget) * EXP_CLEAR_PER_SPAWN)
	landmark_cleared.emit(data)
	progress_changed.emit(explored_count(), landmarks.size())

	# 캠페인 이벤트 + 퀘스트 완료
	if campaign_manager != null:
		campaign_manager.fire_event(id, "on_clear")
		var site = campaign_manager.node_of(id)
		if site != null and site.quest != null:
			if site.quest.objective in ["clear", "boss"]:
				complete_quest(site.quest.id)
			if site.boss != "":
				campaign_manager.fire_event(id, "on_boss_defeat")

## ── 세이브 호환 ──
## 정의(이름/테이블)는 코드에 있으므로 **진행 상태만** 저장한다.
## 그래서 나중에 랜드마크를 추가/수정해도 기존 세이브가 깨지지 않는다.
func to_save() -> Dictionary:
	var places := {}
	for l in landmarks:
		places[l.id] = l.to_save()
	return {
		"landmarks": places,
		"quests": _done_quests.keys(),
		"talked": _talked.keys(),
	}

func from_save(d: Dictionary) -> void:
	# 예전 세이브(랜드마크만 담긴 평평한 딕셔너리)도 읽는다
	var places: Dictionary = d.get("landmarks", d)
	for id in places:
		var l: LandmarkData = by_id.get(id, null)
		if l and typeof(places[id]) == TYPE_DICTIONARY:
			l.from_save(places[id])
	for q in d.get("quests", []):
		_done_quests[String(q)] = true
	for t in d.get("talked", []):
		_talked[String(t)] = true
	# 완료된 퀘스트로 잠긴 곳을 연다
	for lid in _locks.keys():
		if _done_quests.has(_locks[lid]):
			_locks.erase(lid)
	progress_changed.emit(explored_count(), landmarks.size())
