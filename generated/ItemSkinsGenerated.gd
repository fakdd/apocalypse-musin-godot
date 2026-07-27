## ⚠ AI Asset Factory 가 자동 생성한 파일입니다. 직접 편집하지 마세요.
## 아래 항목을 게임 코드의 해당 위치에 **복사해 붙여넣으세요.**
## (자동 병합을 하지 않는 이유: 손으로 조정한 밸런스 값을 조용히 덮어쓸 위험이 있습니다)

## 붙여넣을 위치 1: scripts/ItemData.gd → const SKINS
## 붙여넣을 위치 2: scripts/ItemSkins.gd → build_mesh() 의 match 분기

# ── 1) SKINS 목록에 추가할 키 ──
#   "weapon": [ … , "blade_steel_longsword"]

# ── 2) build_mesh() 에 추가할 분기 ──
		"blade_steel_longsword":
			return _blade(0.14, 1.25, 0.05)          # 흑철 장검 (B급)

# ── 3) 아이콘 파일 배치 확인 ──
#   ItemSkins.icon_path() 는 res://assets3d/icons/{skin}.svg 를 찾습니다.
#   PNG 를 쓰려면 icon_path() 의 확장자를 png 로 바꾸거나 아래처럼 두 개를 다 시도하세요:
#     for ext in ["svg", "png"]:
#         var p := "res://assets3d/icons/%s.%s" % [skin, ext]
#         if ResourceLoader.exists(p): return p
#   blade_steel_longsword.png   ← 흑철 장검