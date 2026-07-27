# _archive

Git 저장소가 아니라서 삭제 전 사본을 남긴 파일들입니다.

## Main.tscn  (2026-07-26 제거)

2D 프로토타입 시절의 구 메인 씬. 제거 근거:

1. 실행 씬은 `res://scenes/Main3D.tscn` (project.godot 확인)
2. 프로젝트 전체에서 `Main.tscn` 참조 **0건**
3. 이 씬이 참조하는 `res://scripts/World.gd` 가 **존재하지 않음**
   → Godot 임포트마다 오류 3건을 발생시키고 있었음

되돌리려면 이 폴더의 `Main.tscn` 을 `scenes/` 로 복사하세요.
(단, `scripts/World.gd` 가 없으므로 여전히 오류가 납니다)

## LandmarkCatalog.gd  (2026-07-27 제거)

랜드마크 10종이 하드코딩된 카탈로그. 제거 근거:

1. 캠페인 JSON(`data/campaigns/campaign_main.json`)이 유일한 데이터 소스가 됨
2. `CampaignManager` 가 JSON 을 읽어 랜드마크를 생성하므로 카탈로그를 호출하는 곳이 **0건**
3. 두 곳에 같은 데이터가 있으면 어느 쪽이 맞는지 알 수 없게 됨

이 카탈로그의 내용은 AI Asset Factory 의 `tools_seed_campaign.py` 로
캠페인 데이터에 이관되었습니다.
