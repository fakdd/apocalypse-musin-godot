## ⚠ AI Asset Factory 가 자동 생성한 **조각**입니다. 직접 편집하지 마세요.
## 아래 항목을 게임 코드의 해당 위치에 **복사해 붙여넣으세요.**
## (통째로 덮어쓰지 않는 이유: 손으로 조정한 밸런스 값을 조용히 날릴 위험이 있습니다)

## 붙여넣을 위치: scripts3d/world/LandmarkCatalog.gd → all() 안

# 위험도 순으로 정렬되어 있습니다 (난이도 곡선을 눈으로 확인하기 쉽게).

	# ★☆☆☆☆  추천 Lv2
	out.append(_mk({
		"id": "clinic", "name": "무너진 보건소",
		"subtitle": "",
		"desc": "응급 침상이 복도까지 밀려나 있다.",
		"color": Color(0.851, 0.749, 0.451), "bgm": "explore",
		"spawn": {"hound": 3}, "budget": 2,
		"items": 2, "luck": 10.2, "guaranteed": RarityEnums.Rarity.E, "radius": 8.0,
	}))

	# ★★★☆☆  추천 Lv8
	out.append(_mk({
		"id": "police", "name": "중앙 경찰서",
		"subtitle": "",
		"desc": "바리케이드가 건물 안쪽을 향해 세워져 있다.",
		"color": Color(0.851, 0.749, 0.451), "bgm": "tense",
		"spawn": {"hound": 2, "ravager": 2, "destroyer": 1}, "budget": 7,
		"items": 3, "luck": 34.2, "guaranteed": RarityEnums.Rarity.C, "radius": 11.0,
	}))

	# ★★★★★  추천 Lv20  · 보스 overlord
	out.append(_mk({
		"id": "rift_core", "name": "균열의 심장부",
		"subtitle": "",
		"desc": "중력이 어긋나 잔해가 공중에 떠 있다.",
		"color": Color(0.851, 0.749, 0.451), "bgm": "boss",
		"spawn": {"ravager": 3, "juggernaut": 2, "screecher": 2, "destroyer": 1}, "budget": 11,
		"items": 5, "luck": 96.6, "guaranteed": RarityEnums.Rarity.S, "radius": 14.0,
	}))
