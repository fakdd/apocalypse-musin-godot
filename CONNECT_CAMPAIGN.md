# CONNECT_CAMPAIGN — 캠페인 데이터 주도 연결

> Campaign Builder 에서 `campaign.json` **하나만 고치면 게임 맵이 바뀝니다.**
> 랜드마크 위치·이름·스폰·NPC·이벤트는 게임 코드에 **한 줄도 없습니다.**

---

## 1. 전체 흐름

```
 AI Asset Factory — Campaign Builder (외부 도구)
        │  맵에 배치 · 경로 자동 생성 · 웨이브/NPC/보스/BGM/이벤트 편집
        ▼
 res://data/campaigns/campaign_main.json      ← 유일한 데이터 소스
        │
        ▼
 CampaignData.gd          JSON 로더 (스키마만 안다)
        │
        ▼
 CampaignManager.gd       ★ 랜드마크의 유일한 생성자
        │
        ├─ 랜드마크 데이터 (LandmarkData) → LandmarkRegistry 등록
        ├─ 진입 영역        (LandmarkZone)
        ├─ 시각 표식        (링 · 광주 · 이름 · 조명)
        ├─ NPC             (CampaignNPC)
        ├─ 배회 몹          (ambient)
        ├─ 웨이브           (LandmarkZone 이 진입 시 실행)
        ├─ BGM             (LandmarkRegistry.notify_enter)
        ├─ 이벤트           (CampaignEvents 디스패처)
        └─ 퀘스트 잠금       (LandmarkRegistry.set_lock)
```

### 게임 시작 순서 (`World3D._ready`)

```gdscript
environment_manager.setup_environment()
landmark_manager.build_all()      # 지형만 — 랜드마크를 만들지 않는다
prop_manager.build_scatter_and_detail()
landmark_manager.build_base()
portal_manager.build_rifts()
prop_manager.build_atmosphere()
spawn_manager.spawn_player()
PetManager.spawn_into_world()

hud = load("res://scripts3d/HUD3D.gd").new()
add_child(hud)

campaign_manager.build()          # ★ 여기서 맵의 모든 랜드마크가 태어난다
```

HUD 다음에 캠페인을 만드는 이유: 진입 배너·토스트를 이벤트가 **즉시** 쓸 수 있어야 합니다.

---

## 2. 무엇이 어디서 오는가

| 게임 요소 | 출처 | 코드에 하드코딩? |
|---|---|---|
| 랜드마크 위치 | `nodes[].pos` | ✘ |
| 랜드마크 이름 | `nodes[].name` | ✘ |
| 진입 반경 | `nodes[].radius` | ✘ |
| 위험도 · 추천 레벨 | `nodes[].danger` / `level` | ✘ |
| 수호 몬스터 구성 | `nodes[].waves[].composition` | ✘ |
| 웨이브 수 · 대기 · HP 배율 | `nodes[].waves[]` | ✘ |
| 보스 · 보스 HP | `nodes[].boss` / `boss_hp_mult` | ✘ |
| NPC 이름 · 대사 · 보상 | `nodes[].npcs[]` | ✘ |
| BGM 트랙 | `nodes[].bgm` | ✘ |
| 이벤트 (시점·동작·값) | `nodes[].events[]` | ✘ |
| 퀘스트 · 잠금 | `nodes[].quest` / `locked_until` / `routes[].locked_until` | ✘ |
| 미니맵 색 | 위험도에서 유도 | (규칙만 코드에) |
| **동작을 실행하는 방법** | `CampaignEvents._run()` | ✔ (당연히 코드) |

마지막 줄이 핵심입니다. JSON 은 **"언제 무엇을"** 만 담고,
**"어떻게"** 는 게임이 압니다. 이 경계가 데이터 주도의 정의입니다.

---

## 3. 바뀐 파일

### 새로 만든 것

| 파일 | 역할 |
|---|---|
| `scripts3d/campaign/CampaignData.gd` | JSON 로더 (AI Asset Factory 가 생성) |
| `scripts3d/campaign/CampaignManager.gd` | 랜드마크의 **유일한 생성자** |
| `scripts3d/campaign/CampaignEvents.gd` | 이벤트 디스패처 (동작 8종) |
| `scripts3d/campaign/CampaignNPC.gd` | NPC 노드 (대화 · 보상) |
| `data/campaigns/campaign_main.json` | **캠페인 데이터** |

### 고친 것

| 파일 | 변경 |
|---|---|
| `World3D.gd` | `campaign_manager.build()` 호출 추가. 랜드마크 좌표 없음 |
| `LandmarkManager.gd` | **지형 전용화** — `_place_landmarks` / `_spawn_zone` / `_spawn_marker` 제거 (461 → 311줄) |
| `LandmarkZone.gd` | 캠페인 웨이브 실행 + 퀘스트 잠금 판정 |
| `LandmarkRegistry.gd` | 잠금 · 퀘스트 완료 · NPC 대화 추적 추가 |
| `LandmarkData.gd` | 주석 갱신 (카탈로그 → 캠페인) |

### 지운 것

| 파일 | 근거 |
|---|---|
| `scripts3d/world/LandmarkCatalog.gd` | 랜드마크 10종 하드코딩. 참조 **0건**이 되어 죽은 코드 → `tools/_archive/` 로 이동 |

> 같은 데이터가 두 곳에 있으면 어느 쪽이 맞는지 알 수 없게 됩니다.
> 그래서 카탈로그를 남겨두지 않고 캠페인으로 **이관**했습니다
> (`ai-asset-factory/tools_seed_campaign.py`).

---

## 4. 데이터 주도 검증

**게임 코드를 한 줄도 건드리지 않고** JSON 만 고쳐 세 가지를 실험했습니다.

| 실험 | JSON 조작 | 게임 결과 |
|---|---|---|
| 노드 **삭제** | `mall` 제거 | 랜드마크·존·표식 모두 사라짐 |
| 노드 **이동** | `clinic.pos` (61,40) → (20,20) | 그 위치에 생성됨 |
| 노드 **추가** | `harbor` 신규 (게임 코드에 없는 id) | 랜드마크·NPC·웨이브·이벤트 전부 생성 (NPC 3 → 4명) |

```
수정 전:  노드 10 · 경로 14 · NPC 3명
수정 후:  노드 10 · 경로 13 · NPC 4명
   clinic       ( 20.0, 20.0)   ← 이동됨
   harbor       ( 70.0, 70.0)   ← 새로 생김
   (mall 없음)                   ← 삭제됨
JSON↔게임 좌표 불일치: 0건
```

---

## 5. 게임에서 실제로 굴러가는 것

정상 실행 시 로그:

```
[Campaign] '메인 캠페인' 불러옴 — 노드 10 · 경로 14
```

등록 결과:

```
clinic       ( 61.0, 40.0) r= 8.0 spawn=3 explore
convenience  ( 19.0, 40.0) r= 7.5 spawn=2 explore  🔒q_clinic
school       ( 60.6, 54.1) r=10.0 spawn=4 explore  🔒q_convenience
police       ( 50.9, 68.0) r=11.0 spawn=5 tense    🔒q_school
…
rift_core    ( 10.5, 67.0) r=15.0 spawn=6 boss     🔒q_cathedral
LandmarkZone 10개 · NPC 3명
```

퀘스트 잠금이 **체인**으로 걸려 순서가 강제됩니다.

---

## 6. 이벤트 시스템

### 트리거 (게임이 발생시킴)

| 트리거 | 발생 위치 |
|---|---|
| `on_enter` | `LandmarkRegistry.notify_enter` |
| `on_first_visit` | 같은 곳, 최초 1회 |
| `on_clear` | 수호 몬스터 전멸 (`notify_kill`) |
| `on_wave_start` | `LandmarkZone._spawn_wave` |
| `on_boss_defeat` | 보스가 있는 랜드마크 클리어 시 |

### 동작 (`CampaignEvents._run`)

| 동작 | 값 | 실행 |
|---|---|---|
| `bgm` | `track=boss` | `SoundManager.set_bgm()` |
| `banner` | `text=…` | `hud.show_banner()` |
| `dialogue` | `text=…` | `hud.show_toast()` |
| `stinger` | `sound=night_start` | `SoundManager.play()` |
| `spawn` | `type=hound,count=3` | `world._make_enemy()` |
| `unlock` | `target=police` | `LandmarkRegistry.unlock()` |
| `reward` | `essence=100,rarity=S` | `CraftManager` / `LootManager` |
| `seal` | — | `GameManager.add_seal()` |

**새 동작을 추가하려면** `_run()` 에 분기 하나만 더하면 됩니다.
Campaign Builder 쪽 `EVENT_ACTIONS` 에도 같은 이름을 등록하세요.

---

## 7. 퀘스트 잠금

```
routes[].locked_until = "q_clinic"
        ↓  (진행 순서상 뒤쪽 노드를 잠근다)
LandmarkRegistry.set_lock("convenience", "q_clinic")
        ↓
LandmarkZone._on_body_entered  →  is_locked() 면 진입 차단 + 안내
        ↓
q_clinic 완료  →  complete_quest()  →  그 퀘스트로 잠긴 곳 전부 해제
```

게임에는 "길"이라는 실체가 없고 랜드마크만 있으므로,
**경로 잠금을 목적지 노드의 잠금으로 환산**합니다. 같은 효과가 납니다.

퀘스트 완료 판정:

| 목표 | 완료 조건 |
|---|---|
| `explore` | 최초 진입 |
| `clear` / `boss` | 수호 몬스터 전멸 |
| `rescue` | 그 랜드마크의 NPC 를 `target` 명 만남 |

---

## 8. 캠페인 바꾸기 / 늘리기

### 편집 → 반영

1. AI Asset Factory 실행 → **🗺 캠페인 빌더** 탭
2. 노드를 옮기거나 추가/삭제, 이벤트·NPC 편집
3. **JSON 내보내기** 버튼
4. 게임 재실행 — 끝. Godot 재임포트도 필요 없습니다 (JSON 은 코드가 아님)

### 캠페인 여러 개

`data/campaigns/` 에 여러 JSON 을 두고 프로젝트 설정으로 고릅니다:

```
ProjectSettings: campaign/active = "hard_mode"
   → res://data/campaigns/campaign_hard_mode.json 을 읽는다
```

설정이 없으면 `main` 을 씁니다.

### 캠페인이 없을 때

빈 맵을 조용히 내놓지 않고 **분명히 알립니다**:

```
[Campaign] ✘ 캠페인을 불러오지 못했습니다: res://data/campaigns/campaign_main.json
[Campaign]   AI Asset Factory 의 캠페인 빌더에서 'JSON 내보내기' 를 실행하세요.
```

화면에도 배너가 뜹니다. "왜 아무것도 없지?" 로 헤매지 않게 하기 위해서입니다.

---

## 9. 설계 결정과 이유

**왜 JSON 이고 GDScript 가 아닌가**
캠페인은 자주 바뀝니다. 배치를 옮길 때마다 코드를 붙여넣으면 재임포트·재빌드가 필요합니다.
JSON 은 `res://` 에 두면 그대로 읽히고 런타임 교체도 가능합니다.

**왜 `LandmarkData` 를 계속 쓰는가**
미니맵·HUD·LootManager 가 이미 `LandmarkData` 를 봅니다. 캠페인 노드를 여기로 **한 번만 변환**하면
나머지 코드를 건드리지 않아도 됩니다. 변환 지점은 `CampaignManager._make_landmark_data()` 하나입니다.

**왜 배회 몹은 클리어 판정에서 뺐는가**
링 바깥을 어슬렁거리다 흩어지면 영원히 클리어가 안 됩니다.
`landmark_id = ""` 로 두어 판정에서 제외합니다.

**왜 웨이브가 없으면 예전 방식으로 폴백하는가**
캠페인에 웨이브를 안 넣은 노드도 동작해야 합니다.
`LandmarkZone._spawn_legacy_guards()` 가 단일 스폰 테이블로 처리합니다.

**왜 진행도는 남기고 정의만 갈아끼우는가**
`LandmarkRegistry._make_landmark_data` 는 같은 id 가 이미 등록되어 있으면 **그 객체를 재사용**합니다.
그래서 캠페인을 고쳐도 `explored` / `cleared` 같은 진행도가 유지됩니다.

---

## 10. 남은 작업

| 순위 | 항목 | 이유 |
|---|---|---|
| 1 | **미니맵에 잠금 표시** | 지금은 잠긴 랜드마크도 똑같이 보입니다. 자물쇠 아이콘이 있으면 헛걸음이 줄어듭니다 |
| 2 | **퀘스트 HUD 연동** | `QuestUI` 가 아직 캠페인 퀘스트를 표시하지 않습니다 (`LandmarkRegistry.quest_completed` 시그널만 있음) |
| 3 | **경로 시각화** | 캠페인의 `routes` 가 게임에서 그려지지 않습니다. 바닥 화살표나 미니맵 선이 있으면 다음 목적지가 읽힙니다 |
| 4 | 세이브 연동 | `LandmarkRegistry.to_save()` 에 퀘스트·대화 기록을 넣었지만, 실제 세이브 시스템에 연결되어 있지 않습니다 |
| 5 | 노드 겹침 경고 | 두 랜드마크 반경이 겹치면 진입 판정이 애매해집니다 (Campaign Builder 쪽에서 잡는 것이 좋습니다) |
