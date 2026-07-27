extends WorldSystem
class_name CampaignManager
## 캠페인을 읽어 맵을 구성한다 — **랜드마크의 유일한 생성자**.
##
## ══════════════════════════════════════════════════════════
##  데이터 주도 구조
## ══════════════════════════════════════════════════════════
##
##     Campaign Builder (외부 도구)
##            ↓
##     res://data/campaigns/campaign_<id>.json     ← 유일한 데이터 소스
##            ↓
##     CampaignData (로더)
##            ↓
##     CampaignManager (이 파일)
##            ↓
##     노드 → 구역(stage) → 랜드마크 → NPC → 웨이브 → BGM → 이벤트 → 퀘스트 잠금
##
## 복합 랜드마크(병원 등)는 노드 하나 안에 구역이 여러 개입니다.
## 구역이 없는 노드는 자기 자신이 구역 하나입니다 —
## `MapNode.areas()` 가 둘을 같은 모양으로 돌려주므로 여기서는 구분하지 않습니다.
##
## **랜드마크 위치·이름·난이도·스폰·드랍은 코드에 없습니다.** 전부 JSON 에서 옵니다.
## 노드를 추가/삭제/이동하려면 Campaign Builder 에서 고치고 다시 내보내면 됩니다 —
## 게임 코드는 건드리지 않습니다.
##
## LandmarkManager 는 지형(도로·건물·경계)만 만들고, 랜드마크는 만들지 않습니다.

## 불러올 캠페인 id. 프로젝트 설정으로 바꿀 수 있게 해 두었다
## (`campaign/active` — 없으면 "main")
const DEFAULT_CAMPAIGN := "main"

var campaign: CampaignData = null
var events: CampaignEvents = null

## 노드 id → CampaignData.MapNode (이벤트/웨이브 조회용)
var _nodes := {}

## 배회 몹을 둘 구역 목록. 낮에는 비워 두고 밤이 될 때마다 다시 채운다
## (DayNightManager 가 아침에 모든 적을 정리하므로 매일 밤 새로 소환해야 한다)
var _ambient_specs: Array = []

func build() -> void:
	var id: String = _active_campaign_id()
	campaign = CampaignData.load_campaign(id)
	if campaign == null:
		_report_missing(id)
		return

	events = CampaignEvents.new()
	events.name = "CampaignEvents"
	events.setup(world)
	add_child(events)

	LandmarkRegistry.clear_placements()
	LandmarkRegistry.bind_campaign(self)
	# 씬을 다시 만들면 build() 가 또 불린다 — 중복 연결을 막는다
	if not GameManager.phase_changed.is_connected(_on_phase_changed):
		GameManager.phase_changed.connect(_on_phase_changed)
	_ambient_specs.clear()

	print("[Campaign] '%s' 불러옴 — 노드 %d · 경로 %d"
		% [campaign.display_name, campaign.nodes.size(), campaign.routes.size()])

	var made := 0
	for site in campaign.nodes:
		for area in site.areas():
			_build_area(area, site)
			made += 1
	print("[Campaign] 진입 영역 %d개 생성 (노드 %d개)" % [made, campaign.nodes.size()])

	_apply_quest_locks()
	events.fire_global(campaign, "on_enter")

## 구역 하나를 실제 게임 오브젝트로 만든다.
##   area: CampaignData.Stage  (구역이 없는 노드면 자기 자신을 감싼 Stage)
##   owner: CampaignData.MapNode
func _build_area(area, owner) -> void:
	if owner.missing_landmark:
		push_warning("[Campaign] 랜드마크 정의가 없는 노드: %s (배치만 적용됨)" % owner.id)

	# 이벤트/웨이브 조회는 area_id 로 한다 (예전 노드 id 와 같은 값)
	_nodes[area.area_id] = area

	# ── 1) 랜드마크 데이터 ──
	var data: LandmarkData = _make_landmark_data(area)
	LandmarkRegistry.register(data)

	# ── 2) 진입 감지 영역 ──
	var zone := LandmarkZone.new()
	zone.name = "Landmark_" + area.area_id
	world.add_child(zone)
	zone.setup(data, area)

	# ── 3) 시각 표식 (Zone 의 자식으로 붙인다 — 랜드마크와 함께 움직이고 함께 사라진다) ──
	_spawn_marker(data, zone)

	# ── 4) NPC ──
	_spawn_npcs(area, data)

	# ── 5) 배회 몹 — 밤에만. 낮에는 예약만 해 둔다 ──
	_ambient_specs.append(area)
	if GameManager.phase == GameManager.Phase.NIGHT:
		_spawn_ambient(area)

## 캠페인 노드 → LandmarkData
## (게임의 나머지 부분은 계속 LandmarkData 를 보므로 여기서 한 번만 변환한다)
func _make_landmark_data(site) -> LandmarkData:
	# 이미 등록된 정의가 있으면 재사용한다 — 탐험 진행도를 유지하기 위해서다
	var existing: LandmarkData = LandmarkRegistry.get_data(site.area_id)
	var data: LandmarkData = existing if existing != null else LandmarkData.new()

	data.id = site.area_id
	data.display_name = site.display_name
	data.description = _story_text(site)
	data.subtitle = ""
	data.center = site.world_pos()
	data.radius = site.radius
	data.minimap_color = _color_for_danger(site.danger)
	data.bgm = site.bgm
	data.enter_stinger = site.enter_stinger

	# 웨이브 1단계를 기본 스폰 테이블로 쓴다 (진입 시 소환되는 수호 몬스터)
	if site.waves.size() > 0:
		data.spawn_table = site.waves[0].composition.duplicate()
		data.spawn_budget = site.waves[0].total_count()
	else:
		data.spawn_table = {}
		data.spawn_budget = 0
	data.spawn_radius = site.radius * 0.8

	# 탐험 보상 — JSON 이 명시하면 그 값을, 아니면 위험도에서 유도한다.
	# (기획자가 특정 구역만 후하게 주고 싶을 때 JSON 에서 덮어쓸 수 있다)
	if site.item_count >= 0:
		data.item_count = site.item_count
	elif site.quest != null:
		data.item_count = maxi(1, int(site.danger))
	else:
		data.item_count = 0

	if site.item_luck >= 0.0:
		data.item_luck_bonus = site.item_luck
	else:
		data.item_luck_bonus = float(site.danger) * 12.0

	if site.guaranteed != "":
		data.guaranteed_rarity = _rarity_index(site.guaranteed)
	elif site.quest != null:
		data.guaranteed_rarity = _rarity_index(site.quest.rarity)
	else:
		data.guaranteed_rarity = -1
	return data

func _story_text(site) -> String:
	var parts := PackedStringArray()
	for s in site.story:
		parts.append(s)
	return "\n".join(parts)

## 위험도 → 미니맵 색 (Campaign Builder 의 별 색과 맞춘다)
func _color_for_danger(danger: int) -> Color:
	match clampi(danger, 1, 5):
		1: return Color(0.85, 0.70, 0.35)
		2: return Color(0.85, 0.70, 0.35)
		3: return Color(0.88, 0.56, 0.17)
		4: return Color(0.88, 0.35, 0.17)
		_: return Color(0.78, 0.10, 0.13)

func _rarity_index(name: String) -> int:
	if name == "":
		return -1
	var order := ["F", "E", "D", "C", "B", "A", "S", "SS", "SSS"]
	return order.find(name.to_upper())

## ══════════════════════════════════════════════
##  시각 표식
## ══════════════════════════════════════════════
## 표식은 전부 LandmarkZone 의 자식이다. Zone 이 이미 data.center 에 서 있으므로
## 좌표는 전부 로컬(중심 기준)이고, Zone 이 사라지면 표식도 함께 사라진다.
func _spawn_marker(data: LandmarkData, zone: Node3D) -> void:
	var col: Color = data.minimap_color

	# 바닥 링 — 경계를 알려준다. 가까이 가야 보이게 해 화면이 지저분해지지 않게 한다
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = data.radius - 0.3
	torus.outer_radius = data.radius
	ring.mesh = torus
	ring.material_override = SharedMaterials.unshaded_fade(
		Color(col.r, col.g, col.b, 0.13), 0.8)
	ring.position = Vector3(0, 0.06, 0)
	ring.visibility_range_end = data.radius + 24.0
	ring.visibility_range_end_margin = 6.0
	zone.add_child(ring)

	# 수직 광주 — 멀리서 "저기 뭔가 있다"를 알리는 등대
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.28
	cyl.height = 20.0
	beam.mesh = cyl
	beam.material_override = SharedMaterials.unshaded_fade(
		Color(col.r, col.g, col.b, 0.10), 1.6)
	beam.position = Vector3(0, 10.0, 0)
	zone.add_child(beam)

	var label := Label3D.new()
	label.text = data.display_name
	label.font_size = 42
	label.pixel_size = 0.011
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = col
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.position = Vector3(0, 5.2, 0)
	label.visibility_range_end = 46.0
	zone.add_child(label)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 3.0, 0)
	light.light_color = col
	light.light_energy = 1.6
	light.omni_range = data.radius * 1.6
	zone.add_child(light)

## ══════════════════════════════════════════════
##  NPC · 배회 몹
## ══════════════════════════════════════════════
func _spawn_npcs(site, data: LandmarkData) -> void:
	var n: int = site.npcs.size()
	if n == 0:
		return
	for i in range(n):
		# 랜드마크 링 안쪽에 고르게 세운다
		var a := TAU * float(i) / float(n) + 0.4
		var r: float = data.radius * 0.55
		var pos: Vector3 = data.center + Vector3(cos(a) * r, 0, sin(a) * r)
		var npc := CampaignNPC.new()
		world.add_child(npc)
		npc.setup(site.npcs[i], site.id, pos)

## 밤이 오면 배회 몹을 되살린다. 낮에는 한 마리도 두지 않는다.
func _on_phase_changed(p: int) -> void:
	if p != GameManager.Phase.NIGHT:
		return
	for area in _ambient_specs:
		_spawn_ambient(area)

func _spawn_ambient(site) -> void:
	if site.ambient.is_empty():
		return
	if GameManager.phase != GameManager.Phase.NIGHT:
		return
	if not world.has_method("_make_enemy"):
		return
	var i := 0
	for etype in site.ambient:
		var count: int = int(site.ambient[etype])
		for k in range(count):
			var a := randf_range(0.0, TAU)
			var r: float = site.radius * randf_range(1.0, 1.6)   ## 링 바깥을 어슬렁
			var pos: Vector3 = site.world_pos() + Vector3(cos(a) * r, 0, sin(a) * r)
			var enemy = world._make_enemy(String(etype), pos)
			if enemy != null:
				# 배회 몹은 클리어 판정에 넣지 않는다 —
				# 랜드마크를 벗어나 흩어질 수 있어 영원히 클리어가 안 될 수 있다
				enemy.landmark_id = ""
			i += 1

## ══════════════════════════════════════════════
##  퀘스트 잠금
## ══════════════════════════════════════════════
func _apply_quest_locks() -> void:
	for site in campaign.nodes:
		for area in site.areas():
			# 노드 잠금은 그 노드의 **첫 구역**에만 건다.
			# (안쪽 구역은 자기 잠금이나 앞 구역의 퀘스트로 이미 막힌다)
			var lock: String = area.locked_until
			if lock == "" and area.area_id == site.id:
				lock = site.locked_until
			if lock != "":
				LandmarkRegistry.set_lock(area.area_id, lock)
	# 경로 잠금도 목적지 노드의 잠금으로 환산한다.
	# (게임에는 "길"이라는 실체가 없고 랜드마크만 있으므로,
	#  들어가는 쪽을 잠그는 것이 같은 효과를 낸다)
	for r in campaign.routes:
		if r.locked_until == "":
			continue
		var target := campaign.node_by_id(r.to_id)
		var source := campaign.node_by_id(r.from_id)
		if target == null or source == null:
			continue
		# 진행 순서상 뒤쪽 노드를 잠근다 (그 노드의 첫 구역)
		var later: String = String(r.to_id) if target.order > source.order else String(r.from_id)
		LandmarkRegistry.set_lock(later, r.locked_until)

## ══════════════════════════════════════════════
##  조회 (LandmarkZone / 이벤트가 쓴다)
## ══════════════════════════════════════════════
## area_id 로 구역을 찾는다 (이벤트/퀘스트 판정이 쓴다)
func node_of(landmark_id: String):
	return _nodes.get(landmark_id, null)

## 구역이 속한 노드 id (복합 랜드마크의 묶음 이름)
func owner_of(area_id: String) -> String:
	for n in campaign.nodes:
		for a in n.areas():
			if a.area_id == area_id:
				return n.id
	return area_id

func fire_event(landmark_id: String, trigger: String) -> void:
	if events == null:
		return
	events.fire(_nodes.get(landmark_id, null), trigger)

func _active_campaign_id() -> String:
	if ProjectSettings.has_setting("campaign/active"):
		var v := String(ProjectSettings.get_setting("campaign/active"))
		if v != "":
			return v
	return DEFAULT_CAMPAIGN

## 캠페인을 못 읽었을 때 — 조용히 빈 맵을 내놓지 않고 분명히 알린다.
## (빈 맵은 "왜 아무것도 없지?" 로 한참 헤매게 만든다)
func _report_missing(id: String) -> void:
	var path: String = "res://data/campaigns/campaign_%s.json" % id
	var msg: String = "캠페인을 불러오지 못했습니다: %s" % path
	push_error("[Campaign] " + msg)
	print("[Campaign] ✘ " + msg)
	print("[Campaign]   AI Asset Factory 의 캠페인 빌더에서 'JSON 내보내기' 를 실행하세요.")
	if world and world.hud:
		world.hud.show_banner("캠페인 데이터 없음 — 콘솔을 확인하세요")
