# 복합 랜드마크(구역) 리팩터링 보고서

노드 하나가 여러 진입 영역을 갖도록 스키마를 확장했습니다.
병원은 이제 노드 **1개**에 구역 **4개**(정문 / 3층 병동 / 중환자실 / 지하 영안실)입니다.

```
이전                            이후
─────────────────────────────   ─────────────────────────────
hospital          (노드)         hospital            (노드)
hospital_ward     (노드)          ├ gate       → hospital
hospital_morgue   (노드)          ├ ward       → hospital_ward
                                  ├ icu        → hospital_icu
노드 15개 = 진입 영역 15개        └ morgue     → hospital_morgue

                                노드 7개 = 진입 영역 16개
```

파이프라인은 그대로입니다.

```
Campaign Builder → campaign_main.json → CampaignData → CampaignManager → 게임
```

새 에디터도, 새 데이터 시스템도, 새 월드 시스템도 만들지 않았습니다.
기존 4개 구성요소를 확장만 했습니다.

---

## 1. 변경된 JSON 스키마

### 1-1. 최상위 — 메타데이터 추가

```jsonc
{
  "version":  2,                          // ← 신규
  "schema":   2,                          // ← 신규 (로더 분기 기준)
  "name":     "메인 캠페인",               // ← 신규
  "author":   "AI Asset Factory",         // ← 신규
  "modified": "2026-07-27T08:31:37",      // ← 신규
  "id":       "main",
  "description": "",
  "arena":    { "w": 80.0, "h": 80.0 },
  "start":    "convenience",
  "nodes":    [ ... ],
  "routes":   [ ... ],
  "events":   [ ... ]
}
```

`modified` 는 내보낼 때마다 갱신됩니다. 누가 언제 만든 데이터인지 게임 로그에 찍힙니다.

### 1-2. 노드 — `stages[]` 추가

노드는 이제 **껍데기**입니다. 위치·이름·잠금·노드 전역 이벤트만 갖고,
난이도·웨이브·NPC·퀘스트는 전부 구역으로 내려갔습니다.

```jsonc
{
  "id":       "hospital",
  "order":    1,
  "pos":      { "x": 60.0, "z": 21.0 },   // 구역 오프셋의 기준점
  "zone":     1,
  "name":     "성모 종합병원",
  "locked_until": "q_convenience",         // 랜드마크 전체 잠금
  "events":   [],                          // 노드 전역 이벤트
  "stages":   [ ... ]                      // ← 신규. 비어 있으면 예전 노드와 동일
}
```

### 1-3. 구역(stage) — 신규

```jsonc
{
  "id":       "ward",                      // 노드 안에서만 유일하면 된다
  "area_id":  "hospital_ward",             // ← 게임이 쓰는 실제 키 (아래 4장)
  "name":     "3층 병동",
  "subtitle": "링거대가 복도를 막고 있다",
  "desc":     "…",
  "offset":   { "x":  6.5, "z": -6.5 },    // 노드 기준 상대 좌표 (편집 단위)
  "pos":      { "x": 66.5, "z": 14.5 },    // 절대 좌표 (내보낼 때 계산)
  "zone":     1,
  "radius":   5.5,
  "danger":   3,
  "level":    8,
  "bgm":      "battle",
  "locked_until": "q_hospital",            // 앞 구역 퀘스트
  "waves":    [ ... ],
  "npcs":     [ ... ],
  "events":   [ ... ],
  "quest":    { ... },
  "story":    "",
  "ambient":  { "hound": 2 },
  "items":    3,  "luck": 0.1,  "guaranteed": 2
}
```

`offset` 과 `pos` 를 **둘 다** 씁니다. 편집기는 `offset` 으로 다루고(노드를 옮기면
구역이 따라옵니다), 게임은 `pos` 만 읽습니다(런타임 덧셈 없음).

### 1-4. NPC — `state` 추가

```jsonc
{
  "id":    "nurse_yoon",
  "name":  "간호사 윤",
  "role":  "생존자",
  "dialogue": "안쪽에 아직 사람이 있어요. 3층 병동… 제발 확인해 주세요.",
  "reward": "heal",
  "state":  "quest",                       // ← 신규: idle | quest | completed
  "dialogue_completed": "정문은… 이제 괜찮은 거죠?"   // ← 신규
}
```

기존 NPC JSON 을 그대로 두면 `state` 는 `idle` 로 읽힙니다. 새 NPC 시스템이 아니라
`CampaignNPC.gd` 가 어떤 대사를 고를지 판단하는 근거가 하나 늘어난 것입니다.

### 1-5. 이벤트 — `conditions` 추가

```jsonc
{
  "trigger": "on_clear",
  "action":  "banner",
  "value":   { "text": "서 과장이 말한 그 아래로 가는 길이 열렸다" },
  "once":    true,
  "conditions": [                          // ← 신규. 전부 만족해야 실행
    { "kind": "quest_completed", "value": "q_hospital_ward" }
  ]
}
```

지원하는 `kind`: `quest_completed` · `quest_pending` · `stage_cleared` ·
`item_owned` · `level` · `time`. `conditions` 가 없거나 비면 예전처럼 항상 실행됩니다.

`trigger` / `action` / `value` 는 하나도 바꾸지 않았습니다.

---

## 2. Campaign Builder UI 변경 사항

### 2-1. 트리 편집기 (신규)

맵 아래에 `랜드마크 · 구역` 트리를 넣었습니다.

```
이름                         위험도    웨이브    잠금
─────────────────────────────────────────────────────────
24시 편의점 (convenience)    ★☆☆☆☆    단독
▼ 성모 종합병원 (hospital)             구역 4    q_convenience
    성모 종합병원 — 정문      ★☆☆☆☆    웨이브 1
    3층 병동      [ward]     ★★★☆☆    웨이브 2   q_hospital
    중환자실      [icu]      ★★★★☆    웨이브 2   q_hospital_ward
    지하 영안실   [morgue]   ★★★★★    웨이브 3   q_hospital_icu
▼ 중앙 경찰서 (police)                 구역 3    q_hospital_morgue
    …
```

- **구역 추가 / 구역 삭제 / ▲ / ▼** 버튼. 순서가 곧 진행 순서입니다.
- 보스가 있는 구역은 위험도 칸이 강조됩니다.
- 노드 행을 고르면 노드 폼, 구역 행을 고르면 **구역 설정** 패널이 함께 열립니다
  (이름 · 노드 기준 오프셋 dX/dZ · 반경 · 위험도 · 추천 Lv · BGM · 진입 잠금).
- 웨이브 · 몬스터 · NPC · 이벤트 탭은 **선택 대상을 따라갑니다.**
  노드를 고르면 노드 것을, 구역을 고르면 그 구역 것을 편집합니다
  (`_target_npcs()` / `_target_events()` 한 군데서 갈라집니다).

새 창도 새 탭도 만들지 않았습니다. 캠페인 빌더 탭 안에서 끝납니다.

### 2-2. 맵 캔버스

노드 주위에 구역을 **점선 원**으로 그립니다. 위험도별 색이고 `1.gate`, `2.ward`
같은 라벨이 붙습니다. 복합 랜드마크가 한 덩어리로 보입니다.
좌표·반경을 고치면 맵에 즉시 반영되고, 노드를 끌면 구역이 따라옵니다.

### 2-3. NPC · 이벤트 폼

- NPC 폼에 **상태** 콤보(`idle` / `quest` / `completed`)와 완료 후 대사 칸 추가
- 이벤트 폼에 **조건** 칸 추가 — `quest_completed=q_hospital_ward` 형태로 입력

### 2-4. 내보내기 전 검사 (강화)

`JSON 내보내기` 를 누르면 먼저 `preflight()` 가 돕니다. 8가지를 봅니다.

| 검사 | 등급 | 예시 메시지 |
|---|---|---|
| 반경 겹침 | 경고 | `반경 겹침: hospital ↔ hospital_area5 (거리 9.2 < 12.5) — 진입 판정이 애매해집니다` |
| 맵 밖 좌표 | 오류 | `hospital_icu: 맵 밖에 있습니다 (460.0, 25.7)` |
| 안전지대 안 | 오류 | `power_core: 안전지대 안에 있습니다 — 방주/제단과 겹칩니다` |
| 안전지대 침범 | 경고 | `hospital_area5: 반경이 안전지대를 침범합니다 (중심에서 15.9m, r=5.5)` |
| 고립 노드 | 오류 | `연결된 경로가 없습니다(고립): subway` |
| 시작 노드 없음 | 오류 | `시작 노드가 없습니다.` |
| 끊어진 경로 | 오류 | `경로가 없는 노드를 가리킵니다: school → mall` |
| 도달 불가 노드 | 오류 | `시작 지점에서 갈 수 없습니다: rift_core` |
| 잠금 순환 | 오류 | `잠금이 순환합니다(진행 불가): hospital_ward → hospital_morgue → hospital_icu → hospital_ward` |

오류가 있으면 확인 대화상자가 막고, 경고는 알린 뒤 진행할 수 있습니다.
`대기 시간 0` 웨이브도 여기서 잡습니다 — 게임이 그 웨이브를 통째로 건너뛰기 때문입니다.

---

## 3. CampaignManager 변경 사항

핵심은 **한 곳**입니다. 노드를 도는 대신 영역을 돕니다.

```gdscript
# 이전
for site in campaign.nodes:
    _build_node(site)

# 이후
var made := 0
for site in campaign.nodes:
    for area in site.areas():        # 구역이 없으면 자기 자신 1개
        _build_area(area, site)
        made += 1
```

`MapNode.areas()` 가 구역 유무를 흡수합니다. 구역이 없는 노드는 자기 자신을 감싼
`Stage` 하나를 돌려줍니다. **매니저에는 v1/v2 분기가 없습니다.**

그 외:

- `_build_node(site)` → `_build_area(area, owner)` 로 이름과 인자가 바뀜.
  `_nodes[area.area_id] = area` 로 등록하므로 이벤트·웨이브 조회 키가 예전과 같습니다.
- LandmarkData 를 만들 때 `site.area_id`, `site.enter_stinger` 를 씁니다.
- 탐험 보상은 JSON 이 지정하면 그대로 쓰고, 없으면 예전 규칙으로 유도합니다.

```gdscript
if site.item_count >= 0:
    data.item_count = site.item_count
elif site.quest != null:
    data.item_count = maxi(1, int(site.danger))
```

`CampaignManager` 는 여전히 **랜드마크의 유일한 생성자**이고,
`LandmarkManager` 는 지형만 만듭니다. 역할 분담은 바뀌지 않았습니다.

### 함께 손본 곳

| 파일 | 내용 |
|---|---|
| `CampaignData.gd` (443줄) | `class Stage` 추가, `MapNode.areas()`, `all_areas()`, `area_by_id()`, 메타데이터, NPC `state`, Event `conditions` |
| `CampaignEvents.gd` (166줄) | `_conditions_met()` / `_check_condition()` — 6가지 조건 |
| `CampaignNPC.gd` (176줄) | 클리어 상태에 따라 `dialogue_completed` 를 고름 |
| `LandmarkZone.gd` (186줄) | 대기 0 웨이브가 건너뛰어지던 버그 수정 (`maxf(delay, 0.05)`) |
| `LandmarkRegistry.gd` | 잠금·퀘스트·NPC 대화 기록 API 추가 |

---

## 4. 기존 프로젝트와의 호환성

요청하신 7가지 유지 조건 기준입니다.

| # | 조건 | 상태 | 근거 |
|---|---|---|---|
| 1 | JSON Export 시스템 유지 | ✅ | 같은 `write_json()` · 같은 경로 · 같은 파일명 |
| 2 | Campaign Builder GUI 유지 | ✅ | 같은 탭 안에서 확장. 새 창/새 탭 없음 |
| 3 | CampaignManager 유지 | ✅ | 클래스·진입점(`build()`) 동일. 루프 한 줄만 바뀜 |
| 4 | CampaignData 유지 | ✅ | 같은 `class_name`, 기존 API 전부 살아 있음 |
| 5 | 새 월드 시스템 안 만듦 | ✅ | `WorldSystem` 목록 변화 없음 |
| 6 | 세이브 포맷 보존 | ✅ | 아래 4-1 |
| 7 | 기존 테스트 유지 | ✅ | 109개 전부 통과 (+7개 추가 = 116개) |

### 4-1. 세이브 키가 그대로인 이유

구역의 `area_id` 는 이렇게 정합니다.

```python
def area_id(self, node_id: str, index: int) -> str:
    return node_id if index == 0 else f"{node_id}_{self.id}"
```

**첫 구역은 랜드마크 id 를 그대로 씁니다.** 그래서 예전 세이브의
`hospital`, `hospital_ward`, `hospital_morgue`, `police`, `police_armory` 가
전부 같은 키로 다시 붙습니다. 헤드리스 검증 결과:

```
V2|  ✔ 세이브 키 호환 — 예전 키 8개 전부 존재
```

### 4-2. v1 JSON 하위 호환

`stages` 가 없는 예전 JSON 을 **고치지 않고** 넣어도 그대로 열립니다.

```
V2|  ✔ v1 JSON 그대로 열림 — 노드 1 → 영역 1 (clinic), 웨이브 1, NPC state=idle
```

`schema` 값을 보지 않고 `stages` 유무만 봅니다. 없으면 노드 자신이 구역 하나입니다.

---

## 5. 기존 캠페인 JSON 마이그레이션 방법

### 5-1. 원칙 — 마이그레이션은 **필수가 아닙니다**

v1 JSON 은 그대로 동작합니다(4-2). 아래는 "복합 랜드마크로 묶고 싶을 때"의 절차입니다.

### 5-2. 방법 A — Campaign Builder에서 손으로 (권장, 노드 수가 적을 때)

1. 캠페인을 엽니다. v1 노드는 `단독` 으로 표시됩니다.
2. 대표 노드(예: `hospital`)를 고르고 **구역 추가** 를 누릅니다.
   - 첫 구역은 자동으로 `area_id = hospital` 이 됩니다 → 세이브 키 유지
3. 흡수할 노드(`hospital_ward`)의 값을 새 구역에 옮겨 적습니다.
   - 구역 `id` 를 `ward` 로 하면 `area_id` 가 `hospital_ward` 로 맞아떨어집니다.
   - **이 규칙만 지키면 세이브·퀘스트 id 가 그대로입니다.**
4. `offset` 은 원래 절대 좌표에서 노드 좌표를 뺀 값입니다.
   `(66.5, 14.5) - (60.0, 21.0) = (+6.5, -6.5)`
5. 흡수된 노드를 **맵에서 빼기** 로 제거합니다.
6. 그 노드를 가리키던 경로는 자동으로 정리됩니다. `경로 자동 생성` 으로 다시 이어도 됩니다.
7. **JSON 내보내기** — preflight 가 겹침·잠금 순환·고립을 잡아 줍니다.

### 5-3. 방법 B — 콘텐츠 스크립트로 (권장, 대량일 때)

`tools_build_content.py` 의 `build_complex()` 가 표준 형태입니다.

```python
build_complex(
    spec, landmarks,
    node_id="hospital", name="성모 종합병원", base=(60.0, 21.0),
    stages=[
        ("gate",   "성모 종합병원 — 정문", 1,  2),
        ("ward",   "3층 병동",             3,  8),
        ("icu",    "중환자실",             4, 12),
        ("morgue", "지하 영안실",          5, 16),
    ],
)
```

`stage_offsets(count)` 가 2/3/4구역 배치를 고정 오프셋으로 돌려줍니다
(각도 계산으로 흩뿌리면 맵 밖·안전지대로 새어 나갑니다 — 실제로 겪었습니다).

### 5-4. 마이그레이션 후 반드시 확인할 것

```bash
godot --headless --script tools/verify_stages.gd --quit-after 2
```

세이브 키 · 잠금 사슬 · 웨이브 대기시간 · v1 호환을 한 번에 봅니다.

### 5-5. 되돌리기

구역을 최상위 노드로 되돌리는 것도 무손실입니다. 구역이 절대 좌표(`pos`)와
`area_id` 를 이미 갖고 있어서 그대로 끌어올리면 v1 형태가 됩니다.
`tools/bench_stages.gd` 의 `_flatten()` 이 실제로 그렇게 합니다.

---

## 6. 테스트 결과 및 성능 영향

### 6-1. 단위 테스트

```
116 passed in 3.19s
```

기존 109개 전부 통과. 이번에 7개를 추가했습니다.

| 추가 테스트 | 잡는 것 |
|---|---|
| `test_add_stage_keeps_new_areas_on_the_map` | 구역을 계속 추가해도 맵 밖으로 안 나감 |
| `test_add_stage_spreads_stages_apart` | 같은 좌표에 겹쳐 쌓이지 않음 |
| `test_select_node_keeps_selection_when_already_selected` | 같은 노드 재선택 시 편집 패널이 잠기지 않음 |
| `test_reload_preserves_selection` | 맵을 다시 그려도 선택 유지 |
| `test_refresh_stages_follows_edited_offsets` | 좌표를 고치면 맵에 반영 |
| `test_refresh_stages_does_not_leak_items` | 반복 렌더링에 도형이 쌓이지 않음 |
| `test_campaign_tab_imports_every_name_it_uses` | 임포트 누락 (실행돼야 터지는 종류) |

`pytest.ini` 를 추가했습니다. 이게 없으면 루트의 `tools_smoke_test.py` 가
이름 규칙(`*_test.py`)에 걸려 수집되고, 임포트만으로 GUI 를 띄운 뒤 `sys.exit()` 를
불러 pytest 를 통째로 끝내 버립니다.

### 6-2. GUI 실동작 검증

실제로 창을 띄워 확인했습니다 (`tools_smoke_stages.py`).

```
STG| 노드 7개 · 트리 최상위 7개
STG|   성모 종합병원  (hospital)  (구역 4)
STG| 선택: 성모 종합병원 › 중환자실 (hospital_icu)
STG|   위험도=4 Lv=12 r=5.5 오프셋=(13.0,4.7) 잠금=q_hospital_ward
STG|   NPC 1명 · 이벤트 3건
STG| 구역 추가 후: 노드 7개 (변화 없음: True) · 병원 구역 5개
STG| preflight: 오류 0 · 경고 2
STG| 고의 결함 주입 후: 오류 3건
STG|   ✘ hospital_icu: 맵 밖에 있습니다 (460.0, 25.7)
STG|   ✘ 잠금이 순환합니다(진행 불가): hospital_ward → hospital_morgue → hospital_icu → hospital_ward
STG|   ✘ hospital/morgue 웨이브 2: 대기 시간이 0 입니다 — 게임이 이 웨이브를 건너뜁니다
STG| 구역 삭제 후: 병원 구역 4개 · 오류 0 · 경고 0
STG| 노드 7개 → 진입 영역 16개
```

**GUI 를 띄워서만 드러난 버그가 4개 있었습니다.** 단위 테스트로는 전부 통과였습니다.

1. `QColor` 임포트 누락 — 트리를 그리는 순간 죽음
2. `select_node()` 의 `clearSelection()` 이 허위 "선택 해제" 신호를 쏨 →
   구역 행에서 노드 행으로 옮기면 편집 패널이 통째로 잠김
3. `canvas.load()` 가 같은 방식으로 선택을 날림 → 구역 추가 직후 크래시
4. `add_stage()` 가 새 구역을 `dx = 개수 × 13m` 로 일렬로 밀어내
   네 번째 구역부터 맵 밖에 놓임

넷 다 고치고 회귀 테스트를 붙였습니다.

### 6-3. 게임 내 검증 (headless)

```
V2| ══ 스키마 v2 ══ '메인 캠페인' by AI Asset Factory (2026-07-27T08:31:37)
V2|  노드 7개 → 진입 영역 16개 · 경로 6개
V2|  hospital     구역4  hospital, hospital_ward, hospital_icu, hospital_morgue
V2|  police       구역3  police, police_armory, police_holding
V2|  school       구역3  school, school_hall, school_gym
V2|  power        구역3  power, power_turbine, power_core
V2|  ✔ 세이브 키 호환 — 예전 키 8개 전부 존재
V2|  NPC 8명 (state 지정 2) · 조건부 이벤트 1건
V2|    NPC 노 환자 state=quest → "…나는 여기 있어야 해요. 아직 순번이 안 됐어요."
V2|    EV on_clear → banner  조건=[{ "kind": "quest_completed", "value": "q_hospital_ward" }]
V2|  ✔ 잠금 사슬 정상 — 퀘스트 16개가 모든 잠금을 연다
V2|  ✔ v1 JSON 그대로 열림 — 노드 1 → 영역 1 (clinic), 웨이브 1, NPC state=idle
V2|  ✔ 웨이브 대기 시간 정상
```

실제 게임 부팅:

```
[Campaign] '메인 캠페인' 불러옴 — 노드 7 · 경로 6
[Campaign] 진입 영역 16개 생성 (노드 7개)
```

에러 0건.

### 6-4. 성능

같은 16개 진입 영역을 (A) 평평한 v1 16노드, (B) v2 7노드+16구역 으로 만들어
비교했습니다 (`tools/bench_stages.gd`, 200회 평균).

| 항목 | v1 (평평) | v2 (구역) | 차이 |
|---|---|---|---|
| JSON 크기 | 15,520 B | 15,833 B | **+313 B (+2.0%)** |
| 파싱 | 0.50 ms | 0.52 ms | +0.02 ms |
| 전체 순회 | 0.112 ms | **0.020 ms** | **−82%** |
| 생성된 진입 영역 | 16개 | 16개 | 동일 |
| 런타임 노드 수 | 동일 | 동일 | — |

- **JSON 은 2% 커집니다.** 구역마다 `area_id` 와 `offset` 을 함께 적기 때문입니다.
  대신 노드 이름·잠금·전역 이벤트를 중복해서 적지 않아 대부분 상쇄됩니다.
- **파싱은 사실상 동일**합니다(+0.02 ms, 게임 시작 시 1회).
- **순회는 오히려 5.6배 빠릅니다.** v1 은 노드마다 `areas()` 가 래퍼 `Stage` 를
  새로 할당하는데, v2 는 이미 있는 구역 배열을 그대로 돌려주기 때문입니다.
- 런타임에 만들어지는 `LandmarkZone` · `LandmarkData` 개수는 **완전히 같습니다.**
  구역은 편집·조직 단위이지 런타임 오브젝트가 아닙니다.

즉 **성능 비용은 없습니다.** 편집 편의를 얻는 대가로 JSON 2%를 냈습니다.

---

## 7. 향후 확장 시 장점과 제약 사항

### 7-1. 장점

**노드 폭발을 막습니다.** 이번 리팩터링만으로 15 → 7 노드가 됐습니다.
경찰서/학교/발전소/연구소/공항/군기지를 각 3~5구역으로 채워도:

| | 평평한 구조 | 구역 구조 |
|---|---|---|
| 랜드마크 10개 × 평균 4구역 | 노드 40개 | **노드 10개** |
| 맵에서 눈으로 파악 | 어려움 | 덩어리로 보임 |
| 경로 연결 | 40개를 일일이 | 10개만 |

**경로가 단순해집니다.** 경로는 노드끼리만 잇습니다. 구역 간 진행은
`locked_until` 퀘스트 사슬이 담당합니다. 병원 내부 순서를 바꿔도 맵 경로는 그대로입니다.

**새 랜드마크가 복붙 가능합니다.** 병원 구조가 그대로 틀입니다.

```
정문(★1)  →  본관(★3, 보스)  →  심층부(★5, 보스)
  NPC 안내      NPC 의뢰            보상 · 다음 랜드마크 해금
```

경찰서(정문/무기고/유치장), 학교(정문/본관/체육관), 발전소(정문/터빈/노심)가
전부 이 틀입니다. 연구소·공항·군기지도 `build_complex()` 에 구역 목록만 넘기면 됩니다.

**검증이 자동입니다.** 구역이 늘수록 겹침·잠금 순환이 나기 쉬운데,
preflight 가 내보내기 전에 막습니다. 실제로 이번에 `police_holding` 맵 밖,
`power_core` 안전지대 침범, `power_turbine`↔`subway` 3.2m 겹침을 잡았습니다.

**세이브가 안 깨집니다.** `area_id` 규칙 덕분에 구조를 바꿔도 진행도가 유지됩니다.

### 7-2. 제약 사항

**첫 구역 순서를 바꾸면 세이브 키가 바뀝니다.**
`area_id` 는 인덱스 0일 때만 노드 id 를 씁니다. ▲▼로 첫 구역을 교체하면
`hospital` 이 다른 구역에 붙습니다. 편집기가 경고를 띄우지만,
**이미 배포한 캠페인에서는 첫 구역을 옮기지 마세요.**

**구역은 중첩되지 않습니다.** 깊이가 딱 2단계(노드 → 구역)입니다.
"병원 → 3층 → 301호" 같은 3단계는 지금 구조로 안 됩니다.
필요해지면 `Stage.stages` 를 재귀로 넣어야 하는데, `area_id` 규칙과
preflight 를 다시 설계해야 합니다. 지금은 **일부러 막아 뒀습니다.**

**구역은 노드 반경 안에 있어야 자연스럽습니다.**
오프셋을 크게 주면 다른 랜드마크와 겹치거나 맵 밖으로 나갑니다.
경험상 12~14m 가 상한이고, 4구역이 한 노드의 실용적 한계입니다.
(5번째 구역을 넣어 보면 preflight 가 바로 겹침을 경고합니다.)

**구역마다 퀘스트가 하나입니다.** 한 구역에 병렬 퀘스트 2개는 안 됩니다.
필요하면 구역을 나누는 편이 데이터가 단순합니다.

**JSON 이 커집니다.** 구역당 `area_id`·`offset`·`pos` 가 중복입니다.
랜드마크 30개 × 4구역이면 60KB 정도가 예상되는데, 파싱은 1회뿐이라 문제되지 않습니다.

**맵 캔버스는 구역을 끌 수 없습니다.** 구역 위치는 dX/dZ 숫자 입력으로만 바꿉니다.
노드는 끌 수 있고 구역이 따라옵니다. 구역 드래그는 지금 없는 기능입니다.

---

## 검증 재현

```bash
cd C:\Users\User\ai-asset-factory && python -m pytest
```

```bash
cd C:\Users\User\ai-asset-factory && python tools_build_content.py
```

```bash
cd C:\Users\User\apocalypse-musin-godot && godot --headless --script tools/verify_stages.gd --quit-after 2
```

```bash
cd C:\Users\User\apocalypse-musin-godot && godot --headless --script tools/bench_stages.gd --quit-after 2
```

---

관련 문서: [CONNECT_CAMPAIGN.md](CONNECT_CAMPAIGN.md) · [HOSPITAL_CONTENT.md](HOSPITAL_CONTENT.md)
