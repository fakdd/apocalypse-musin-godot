@tool
extends EditorScript


## 실제 프로젝트 경로(res://data/campaigns/campaign_main.json) 검증 스크립트
## 실행 방법: Godot 에디터 FileSystem에서 이 스크립트 우클릭 -> [스크립트 실행]

func _run() -> void:
	var file_path := "res://data/campaigns/campaign_main.json"
	
	if not FileAccess.file_exists(file_path):
		print("❌ [오류] %s 파일을 찾을 수 없습니다!" % file_path)
		return

	var file := FileAccess.open(file_path, FileAccess.READ)
	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_text)
	if err != OK:
		print("❌ [오류] JSON 구문 분석 실패: %s (줄 %d)" % [json.get_error_message(), json.get_error_line()])
		return

	var data: Dictionary = json.data
	var nodes: Array = data.get("nodes", [])

	print("\n========================================")
	print("✅ [성공] campaign_main.json 정상 로드 완료!")
	print(" - 캠페인 명칭: %s" % data.get("name", "이름 없음"))
	print(" - 스키마 버전: v%s" % data.get("version", 1))
	print(" - 메인 노드 개수: %d개 (목표: 7개)" % nodes.size())
	print("----------------------------------------")

	var total_sub_areas := 0
	for node in nodes:
		var node_id: String = node.get("id", "unknown")
		var stages: Array = node.get("stages", [])
		
		if stages.size() > 0:
			total_sub_areas += stages.size()
			print(" 📍 [복합 랜드마크] %s -> 하위 구역 %d개" % [node_id, stages.size()])
			for stage in stages:
				print("    └─ %s (%s)" % [stage.get("area_id", stage.get("id", "")), stage.get("name", "")])
		else:
			total_sub_areas += 1
			print(" 📍 [단독 랜드마크] %s -> 1개 구역" % node_id)

	print("----------------------------------------")
	print("🎯 총 플레이 구역(Sub-areas): %d개 (목표: 16개)" % total_sub_areas)
	
	if nodes.size() == 7 and total_sub_areas == 16:
		print("🎉 검증 완료: 7개 메인 노드 / 16개 플레이 구역이 정상 구조를 갖추고 있습니다!")
	else:
		print("⚠️ 주의: 노드 또는 구역 개수가 다릅니다.")
	print("========================================\n")
	
