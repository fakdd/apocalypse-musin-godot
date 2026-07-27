# 병원 콘텐츠 — 복합 랜드마크 템플릿

> 새 시스템 없이 **기존 캠페인 파이프라인만으로** 제작했습니다.
> 게임 코드 변경은 버그 수정 1줄뿐입니다.

---

## 1. 복합 랜드마크 패턴

게임에는 씬 전환이 없습니다. 그래서 "내부 맵"을 **인접한 세 구역 + 퀘스트 잠금**으로 표현했습니다.

```
   ┌─ hospital          외부 · 정문      ★☆☆☆☆ Lv2   웨이브1  NPC 간호사 윤
   │      ↓ q_hospital 완료해야 열림
   ├─ hospital_ward     내부 · 3층 병동   ★★★☆☆ Lv8   웨이브2  미니보스 destroyer
   │      ↓ q_hospital_ward 완료해야 열림
   └─ hospital_morgue   심부 · 지하 영안실 ★★★★★ Lv16  웨이브3  보스 overlord
```

세 노드는 한 변 **13m 정삼각형**으로 붙여 한 장소로 읽히게 하되,
반경(7 / 5.5 / 5.5)이 겹치지 않도록 띄웠습니다 — 겹치면 진입 판정이 애매해집니다.

---

## 2. 완성 기준 대응

| 기준 | 구현 | 데이터 위치 |
|---|---|---|
| 외부 랜드마크 | `hospital` (정문, 구급차가 막고 있음) | `nodes[].pos` `radius` |
| 내부 맵 | `hospital_ward` → `hospital_morgue` 2단 | 인접 노드 + `locked_until` |
| NPC | 간호사 윤(생존자·회복), 서 과장(정보원·아이템) | `nodes[].npcs[]` |
| 일반 몬스터 | hound · stalker · ravager · screecher · juggernaut | `waves[].composition` |
| 미니보스 | **destroyer** (병동 최종 웨이브) | `waves[1].boss` |
| 보스 | **overlord** (영안실 최종 웨이브) | `waves[2].boss` |
| 이벤트 | 10건 (배너·대사·BGM·해금·보상·봉인·스팅어) | `nodes[].events[]` |
| 웨이브 | 1단 → 2단 → 3단 (총 20마리) | `waves[]` |
| BGM | explore → tense → boss | `nodes[].bgm` |
| 탐험 보상 | 아이템 1/3/5개 + E/C/S급 확정 + 마석 25/75/200 | 위험도·퀘스트 등급에서 유도 |
| 대사 | NPC 2명 + 진입 대사 | `npcs[].dialogue`, `events[].value.text` |
| 연출 | 스토리 비트 6개 + 배너 3회 + 스팅어 | `story[]`, `events[]` |
| Quest | q_hospital → q_hospital_ward → q_hospital_morgue | `nodes[].quest` |
| JSON | `data/campaigns/campaign_main.json` (25 KB) | — |
| Campaign Builder | 랜드마크 15종 + 캠페인 1개 | `_content_ws/` |

---

## 3. 플레이 흐름

```
편의점 클리어 (q_convenience)
   ↓  병원 정문 해금
정문 진입 → 배너 "성모 종합병원 — 마지막 진료는 끝나지 않았다"
   → 간호사 윤: "안쪽에 아직 사람이 있어요. 3층 병동…"  [E] 대화 → 체력 회복
   → hound×3 처치 → 아이템 1 + E급 확정 + 마석 25
   ↓  병동 해금 (on_clear → unlock)
병동 진입 → BGM tense, 대사 "심전도 모니터가 아직 신호를 그린다"
   → 웨이브1 hound×3 stalker×1 (HP×1.15)
   → 10초 뒤 웨이브2 ravager×2 stalker×2 + **미니보스 destroyer**
   → 서 과장: "지하로 내려가지 마. 거기서 처음 올라왔어."  → 아이템
   → 클리어 → 마석 60 + 아이템 3 + C급 확정
   ↓  영안실 해금
영안실 진입 → 배너 "여기서 처음 열렸다", BGM boss
   → 웨이브1 ravager×2 screecher×1 (HP×1.30)
   → 웨이브2 juggernaut×2 ravager×2 (HP×1.50)
   → 웨이브3 screecher×2 + **보스 overlord** (HP×1.70)
   → 보스 처치 → 균열 봉인 +1 · 마석 200 · S급 확정 · 아이템 5
```

**연출 장치**: 스토리 비트가 "사라진 사람들"을 가리킵니다.
간호사 윤이 3층을 가리키고 → 서 과장이 지하를 경고하고 →
영안실 냉동고에 **간호사 윤의 이름만 남아 있습니다.**

---

## 4. 같은 구조 재사용

`tools_build_content.py` 의 `build_complex()` 에 텍스트만 바꿔 넘기면 됩니다.
실제로 세 곳을 같은 함수로 만들었습니다.

| 장소 | 외부 | 내부 (미니보스) | 심부 (보스) |
|---|---|---|---|
| **병원** | 정문 | 3층 병동 · destroyer | 지하 영안실 · overlord |
| **경찰서** | 정문 | 지하 무기고 · destroyer | 유치장 · overlord |
| **학교** | 운동장 | 본관 복도 · destroyer | 체육관 · overlord |
| **발전소** | 검문소 | 터빈실 · destroyer | 노심 격납고 · overlord |

새 복합 랜드마크를 만들려면:

```python
MUSEUM = Complex(
    prefix="museum", display="시립 박물관", color="#c9a0ff",
    base=(40.0, 30.0),                    # 클러스터 중심
    stages=[
        Stage(key="gate", name="…", danger=1, level=3, bgm="explore",
              waves=[...], npcs=[...], story=[...], events=[...]),
        Stage(key="hall", ...),           # 미니보스
        Stage(key="vault", ...),          # 보스
    ],
)
```

`main()` 의 `clusters` 목록에 추가하고 실행하면 끝입니다.

---

## 5. 전체 맵 구성 (15노드)

```
 0. ★     convenience        (40,14)  편의점
 1. ★     hospital           (54,17)  🔒q_convenience
 2. ★★★   hospital_ward      (67,17)  🔒q_hospital        미니보스
 3. ★★★★★ hospital_morgue    (60,28)  🔒q_hospital_ward   보스
 4. ★     police             (14,17)  🔒q_hospital_morgue
 5. ★★★   police_armory      (27,17)  🔒q_police          미니보스
 6. ★★★★★ police_holding     (20,28)  🔒q_police_armory   보스
 7. ★     school             (14,55)  🔒q_police_holding
 8. ★★★   school_hall        (27,55)  🔒q_school          미니보스
 9. ★★★★★ school_gym         (20,66)  🔒q_school_hall     보스
10. ★★★   subway             (40,66)  🔒q_school_gym
11. ★★    power              (54,55)  🔒q_subway
12. ★★★★  power_turbine      (67,55)  🔒q_power           미니보스
13. ★★★★★ power_core         (60,66)  🔒q_power_turbine   보스
14. ★★★★★ rift_core          (72,40)  🔒q_power_core      최종
```

- 4개 복합 랜드마크가 맵 네 모서리를 차지하고, 중앙 안전지대를 비웁니다
- 단독 3곳(편의점·지하철·심장부)이 클러스터 사이를 잇습니다
- **반경 겹침 0건** (제작 스크립트가 검사합니다)
- 봉인 4회(각 심부 보스) + 최종 심장부 = 엔딩 조건 충족

---

## 6. 제작 중 잡은 문제

### 웨이브가 조용히 건너뛰어지던 버그 (게임 코드 1줄 수정)

`delay = 0` 인 웨이브는 다음 프레임에 "타이머 만료 + 남은 적 없음" 으로 읽혀
**그 웨이브를 통째로 건너뛰었습니다.** 미니보스 웨이브가 사라질 수 있는 문제였습니다.

```gdscript
# LandmarkZone._queue_next_wave()
_wave_timer = maxf(float(site.waves[_wave_index].delay), 0.05)
```

### 배치 검증이 잡은 3건

처음엔 방향 각도로 클러스터를 배치했더니:

| 문제 | 증상 |
|---|---|
| `police_holding` 이 x=1.7 | 맵 밖으로 절반이 튀어나감 |
| `power_core` 가 안전지대 | 시작 지점에 보스 |
| `power_turbine` ↔ `subway` 3.2m | 두 랜드마크 진입 판정이 겹침 |

고정 오프셋(정삼각형)으로 바꾸고 제작 스크립트에 **반경 겹침 검사**를 넣었습니다.
지금은 0건입니다.

### 도구와 게임의 보상 값 불일치

콘텐츠에서 `item_count = 2 + danger` 로 넣었지만 게임은
`max(1, danger)` 로 자체 유도해 무시했습니다. 도구 표시와 실제가 어긋나므로
**같은 규칙**을 쓰도록 맞췄습니다.

---

## 7. 편집 방법

### 수치·대사 고치기

`ai-asset-factory/tools_build_content.py` 에서 해당 `Stage` 를 고치고:

```bash
python tools_build_content.py _content_ws
```

게임 재실행 — Godot 재임포트도 필요 없습니다 (JSON 은 코드가 아님).

### GUI 로 고치기

AI Asset Factory → **🗺 캠페인 빌더** 탭에서 노드를 옮기거나
이벤트·NPC 를 편집하고 **JSON 내보내기**.

### 주의

- 웨이브 `delay` 는 첫 웨이브만 0, 나머지는 **1 이상**으로 두세요
- 노드 반경이 겹치지 않게 13m 이상 띄우세요 (제작 스크립트가 검사합니다)
- 랜드마크 id 는 ASCII 만 (세이브 키·리소스 경로에 쓰입니다)

---

## 8. 남은 작업

| 순위 | 항목 | 이유 |
|---|---|---|
| 1 | **미니맵에 잠금 표시** | 잠긴 랜드마크도 똑같이 보여 헛걸음합니다 |
| 2 | **퀘스트 HUD 연동** | 지금 퀘스트 패널은 봉인 진행도만 보여줍니다 |
| 3 | 내부 구역 시각 차별화 | 세 노드가 같은 링/광주라 "안으로 들어왔다"는 느낌이 약합니다 |
| 4 | NPC 모델 | 지금은 캡슐 + 링입니다 (`CampaignNPC._build_visual` 한 곳만 바꾸면 됩니다) |
| 5 | 발전소 BGM | `power` 계열에 전용 트랙이 없어 explore/tense/boss 를 재사용합니다 |
