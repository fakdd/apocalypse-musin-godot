extends SceneTree
## 구역(stage) 구조의 비용 측정 — 평평한 v1 과 같은 콘텐츠를 비교한다.
##   godot --headless --script tools/bench_stages.gd --quit-after 2
##
## 같은 16개 진입 영역을
##   A) v1 방식: 최상위 노드 16개
##   B) v2 방식: 노드 7개 + 구역 16개
## 로 만들어 파싱 시간·메모리·순회 비용을 잰다.

const P := "BM| "
const ROUNDS := 200

func _init() -> void:
	var raw := _read("res://data/campaigns/campaign_main.json")
	if raw.is_empty():
		print(P + "✘ 캠페인 JSON 을 읽지 못했다")
		quit(1)
		return

	var flat := _flatten(raw)

	print(P + "v2  노드 %d개 · JSON %d bytes"
		% [raw["nodes"].size(), JSON.stringify(raw).length()])
	print(P + "v1  노드 %d개 · JSON %d bytes"
		% [flat["nodes"].size(), JSON.stringify(flat).length()])

	var t2 := _bench(raw)
	var t1 := _bench(flat)
	print(P + "파싱 %d회 — v2 %.2f ms/회 · v1 %.2f ms/회 (차 %+.2f ms)"
		% [ROUNDS, t2, t1, t2 - t1])

	var c2 = CampaignData.from_dict(raw)
	var c1 = CampaignData.from_dict(flat)
	print(P + "진입 영역 — v2 %d개 · v1 %d개 (같아야 한다)"
		% [c2.all_areas().size(), c1.all_areas().size()])

	print(P + "순회 %d회 — v2 %.3f ms/회 · v1 %.3f ms/회"
		% [ROUNDS, _walk(c2), _walk(c1)])

	print(P + "DONE")
	quit(0)

func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	return d if d is Dictionary else {}

## v2 캠페인을 구역 없는 평평한 형태로 되돌린다 (예전 구조 재현).
func _flatten(src: Dictionary) -> Dictionary:
	var out := src.duplicate(true)
	var nodes := []
	for n in out["nodes"]:
		var stages: Array = n.get("stages", [])
		if stages.is_empty():
			nodes.append(n)
			continue
		# 구역은 이미 절대 좌표(pos)와 area_id 를 들고 있다 —
		# 그대로 최상위 노드로 끌어올리면 예전 구조가 된다.
		for st in stages:
			var flat: Dictionary = n.duplicate(true)
			flat.erase("stages")
			for k in st.keys():
				flat[k] = st[k]
			flat["id"] = st.get("area_id", st.get("id", n["id"]))
			nodes.append(flat)
	out["nodes"] = nodes
	out["schema"] = 1
	return out

func _bench(d: Dictionary) -> float:
	var t := Time.get_ticks_usec()
	for i in range(ROUNDS):
		var c = CampaignData.from_dict(d)
		if c == null:
			return -1.0
	return float(Time.get_ticks_usec() - t) / float(ROUNDS) / 1000.0

## CampaignManager 가 하는 일 — 모든 진입 영역을 훑는다.
func _walk(camp) -> float:
	var t := Time.get_ticks_usec()
	var n := 0
	for i in range(ROUNDS):
		for site in camp.nodes:
			for area in site.areas():
				n += area.waves.size() + area.npcs.size()
	return float(Time.get_ticks_usec() - t) / float(ROUNDS) / 1000.0
