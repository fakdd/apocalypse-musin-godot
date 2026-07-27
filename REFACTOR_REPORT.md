# REFACTOR_REPORT — 《아포칼립스 무신》 구조 리팩토링 보고서

> 작업 원칙: **동작 100% 동일 유지 · 기능 추가/삭제 없음 · 구조만 개선**
> 검증 방법: `randomize()`를 고정 시드로 임시 교체한 뒤, 리팩토링 **전/후 빌드를 각각 헤드리스로 240프레임 실행**하여
> 월드 지문(노드 수·그룹 수·몹 스탯 7종·존 판정·플레이어 상태·상수·페이즈 전이·봉인 수)을 diff로 비교했다.
> World3D / Player3D / Enemy3D / HUD3D 네 파일 모두 **지문 완전 일치** (유일한 차이였던 `phase/waves` 라인은
> 같은 빌드를 두 번 실행해도 흔들리는 프레임 타이밍 노이즈임을 확인). 검증 후 `randomize()` 복원 완료.
> 리팩토링 전 원본은 `tools/_work/*.orig` 에 보관되어 있다.

---

## 1. 현재 구조 평가 (리팩토링 전)

| 파일 | 줄 수 | 문제 |
|---|---|---|
| World3D.gd | 1,252 | God Object. 환경·랜드마크·소품·포탈·스폰·낮밤·웨이브 7가지 책임이 한 파일에 |
| HUD3D.gd | 707 | 11개 UI 위젯의 구축+갱신+입력이 하나의 `_ready`/`_process`에 |
| Player3D.gd | 698 | 이동·전투·스킬·애니메이션·입력이 한 `_physics_process`에 |
| Enemy3D.gd | 639 | 타입 데이터(58줄 딕셔너리)+AI+이동+공격+연출 혼재 |

- 매직 넘버 다수 (돌진 배율 4.2, 쿨다운 0.7 등이 코드 곳곳에 반복)
- `_physics_process` 하나가 130줄 이상 (규칙 8 위반)
- 다행히 Autoload 계층(GameManager/PlayerStats/LootManager…)은 이미 책임이 분리되어 있었고,
  씬은 코드 생성 방식이라 Inspector/NodePath 파손 위험은 원래 낮았다.

## 2. 개선한 이유

1. **기능 추가 비용** — 예: "새 보스 패턴 추가"가 이전에는 1,252줄 파일에서 웨이브·스폰·연출 코드를 헤집어야 했다. 이제 `EnemyBrain._try_pattern` 한 곳.
2. **책임 충돌** — HUD의 `_process` 안에서 튜토리얼 입력, 체력 바, 퀘스트 텍스트, 무기 아이콘 회전이 한 함수에 섞여 있어 한 곳을 고치면 다른 곳이 깨지기 쉬웠다.
3. **매직 넘버** — 동일한 4.2(돌진 배율)가 Enemy3D의 세 곳에 흩어져 있어 밸런스 수정 시 누락 위험. `EnemyConfig.CHARGE_SPEED_MULT` 한 곳으로 통일.
4. **팀/미래의 나** — 400줄 이하 파일은 전체를 한 화면에서 파악할 수 있다. 현재 최대 파일이 301줄(Player3D).

## 3. 변경된 파일 목록

### 새 파일 (19)
```
scripts3d/world/   WorldConfig.gd      — 맵 격자·존·운(luck) 상수와 정적 좌표 수학
                   WorldSystem.gd      — 모든 월드 매니저의 공통 베이스(배치 헬퍼·프록시)
                   EnvironmentManager.gd  LandmarkManager.gd  PropScatterManager.gd
                   PortalManager.gd       SpawnManager.gd     DayNightManager.gd
                   WaveManager3D.gd
scripts3d/player/  PlayerConfig.gd     — 플레이어 튜닝 상수
                   PlayerMovement.gd   PlayerCombat.gd   PlayerAnimation.gd
scripts3d/enemy/   EnemyConfig.gd      — 적 8종 TYPES 딕셔너리 + 전투 상수
                   EnemyBrain.gd       EnemyMovement.gd  EnemyAttack.gd  EnemyAnimation.gd
scripts3d/hud/     HealthUI.gd  SkillUI.gd  MiniMapUI.gd  QuestUI.gd  DamageUI.gd  PopupUI.gd
```

### 축소된 기존 파일 (4)
| 파일 | 전 | 후 | 남은 역할 |
|---|---|---|---|
| World3D.gd | 1,252 | 178 | 매니저 생성·배선 + 외부 공개 API(zone_luck 등) 위임 |
| Player3D.gd | 698 | 301 | 상태 보유 + 모듈 생성 + `take_damage`/`shake` 등 공개 API |
| Enemy3D.gd | 639 | 212 | 상태 보유 + `setup`/`take_damage`/`stun`/`_die` |
| HUD3D.gd | 707 | 263 | 공유 위젯 팩토리 + 노드 참조 보유 + 공개 API 위임 |

### 삭제된 파일
**없음** (규칙: 기존 기능 삭제 금지)

## 4. 변경된 클래스 다이어그램

```
Main3D.tscn
└── World3D (오케스트레이터, 178줄)
    ├── EnvironmentManager ─┐
    ├── LandmarkManager     │ extends WorldSystem
    ├── PropScatterManager  │   └─ WorldConfig (상수·격자 수학, RefCounted)
    ├── PortalManager       │
    ├── SpawnManager  ──────┘──▶ Enemy3D / Player3D 생성
    ├── DayNightManager ◀──▶ WaveManager3D   (상호 참조는 느슨한 WorldSystem 타입)
    │
    ├── Player3D (컨트롤러, 301줄)
    │   ├── PlayerMovement   ─┐
    │   ├── PlayerCombat      │ owner_player 역참조 + PlayerConfig 상수
    │   └── PlayerAnimation  ─┘
    │
    ├── Enemy3D × N (컨트롤러, 212줄)
    │   ├── EnemyBrain      — 목표 선정·패턴 판단
    │   ├── EnemyMovement   — 물리 이동·접촉 피해
    │   ├── EnemyAttack     — 근접/기탄/예고선
    │   └── EnemyAnimation  — 모델·HP바·연출
    │       └─ EnemyConfig (TYPES 8종 + 전투 상수)
    │
    └── HUD3D (HUDRoot, 263줄 — 위젯 팩토리 + 공개 API)
        ├── HealthUI   ├── SkillUI    ├── MiniMapUI
        ├── QuestUI    ├── DamageUI   └── PopupUI

Autoload (변경 없음):
RarityEnums · TraitManager · GameManager · PlayerStats
LootManager · CraftManager · PetManager · SoundManager
```

- 하위 호환: `Enemy3D.TYPES`, `Player3D.DASH_SPEED` 등 기존 상수는 **별칭 const 로 유지**되어 외부 코드가 깨지지 않는다.
- Save 데이터: 저장 구조를 만지지 않았고 Autoload 상태 필드도 그대로 → **호환 유지**.
- Signal: 기존 시그널(`stats_changed`, `item_collected`, `died`, `victory` …) 전부 유지. 상호 참조가 필요한 곳(DayNight↔Wave)만 명시적 배선.

## 5. 앞으로 추가하기 쉬워진 기능

| 기능 | 이전 | 이제 |
|---|---|---|
| 새 몬스터 타입 | Enemy3D 639줄 수정 | `EnemyConfig.TYPES`에 딕셔너리 1개 추가 |
| 새 보스 패턴 | `_physics_process` 미로 수정 | `EnemyBrain._try_pattern`에 match 분기 추가 |
| 새 플레이어 스킬 | Player3D 곳곳 수정 | `PlayerCombat`에 함수 + `SkillUI`에 버튼 |
| 새 웨이브 규칙 | World3D 1,252줄에서 발굴 | `WaveManager3D` 96줄만 보면 됨 |
| 새 맵/존 | 상수가 코드 전역에 산재 | `WorldConfig` 한 파일 수정 |
| HUD 스킨 변경 | 707줄 중 색상 찾기 | 모듈별 build() + 루트의 RED/GOLD 상수 |
| 난이도 프리셋 | 매직 넘버 수정 불가 | Config 3종(World/Player/Enemy)만 스왑 |

## 6. 앞으로 리팩토링이 필요한 부분

1. **`owner_player.` / `owner_enemy.` 역참조 패턴** — 모듈이 컨트롤러 내부 상태에 자유롭게 접근한다. 다음 단계는 상태를 모듈로 내리고 시그널/메서드 경계로 좁히는 것 (이번엔 "동작 100% 동일" 제약 때문에 보수적으로 접근).
2. **HUD 노드 참조가 루트에 집중** — `hp_bar` 등 30여 개 변수가 HUDRoot에 남아 있다. 각 모듈 소유로 내리면 더 깔끔해진다.
3. **`scripts/` vs `scripts3d/` 이원화** — ItemData/ItemSkins가 scripts/에, 나머지가 scripts3d/에. `scripts/{autoload,items,world,player,enemy,hud,props}` 로 통일 권장.
4. **SurvivorNPC3D.gd 죽은 코드** — 어디서도 생성되지 않는다(아래 분석 참조). 기능 삭제 금지 원칙 때문에 남겨두었으니, 생존자 구조 기능을 되살리든지 파일을 정리하든지 결정 필요.
5. **`_die()` 의 보상 로직** — 적 사망 시 마석/드랍 지급이 Enemy3D에 있다. `LootManager.on_enemy_died(enemy)` 로 옮기면 보상 정책이 한곳에 모인다.
6. **TraitScreen / StatsWindow / InventoryUI** — 각각 150~255줄로 아직 건강하지만, HUD 모듈 패턴과 통일하면 좋다.

## 7. 위험 요소

1. **버전 관리 부재 (최대 위험)** — 이 프로젝트는 git 저장소가 아니다. 이번 리팩토링 백업도 수동 복사(`tools/_work/`)에 의존했다. **`git init` 을 강력히 권장** (아래 TOP 10 1위).
2. **씬 재시작 시 Autoload 시그널 잔존** — `PopupUI.build_toast()` 가 `LootManager.item_collected` 에 람다를 연결하는데, R 재시작으로 HUD가 파괴되어도 Autoload 쪽 연결이 남아 무효 Callable 호출 경고가 누적될 수 있다 (기존 동작 그대로 보존한 것 — 버그 수정 최소화 원칙).
3. **모듈 생성 순서 의존** — Enemy/Player 모듈은 `_ready()` 에서 생성되므로, `add_child` 전에 `setup()` 을 부르는 코드가 새로 생기면 null 참조가 난다. (현재 SpawnManager는 올바른 순서 사용)
4. **class_name 전역 등록 의존** — 새 PC나 CI에서 첫 빌드 시 `--headless --import` 로 전역 클래스 캐시를 갱신해야 한다.
5. **동적 조명 폭증 가능성** — 적 1기당 OmniLight 1~2개(눈/오라). 웨이브가 커지면 Forward+ 클러스터 한계에 접근한다.

---

# 프로젝트 전체 분석 (13개 항목)

| # | 항목 | 결과 |
|---|---|---|
| 1 | **사용되지 않는 Script** | `scripts3d/SurvivorNPC3D.gd` — 어떤 코드도 이 스크립트를 load/instantiate 하지 않음 (GameManager의 rescue_survivor API만 남아 있음). 죽은 코드지만 삭제 금지 원칙으로 보존 |
| 2 | **사용되지 않는 Scene** | `scenes/Main.tscn` — 존재하지 않는 `res://scripts/World.gd` 를 참조하는 구 2D 프로토타입. 메인 씬은 Main3D.tscn. 열면 스크립트 로드 에러가 나는 좀비 씬 |
| 3 | **사용되지 않는 Resource** | `assets/` 의 Kenney 2D 타일/캐릭터/vfx (audio만 19곳에서 사용 중). `assets3d/` 957MB 중 Mixamo FBX 원본(개당 24MB×6)은 임포트 후 게임에서 직접 쓰이지 않음 — 배포 시 export 제외 필터 필요 |
| 4 | **중복 코드** | 제거 완료: 월드 배치 헬퍼 7종 → WorldSystem, `_find_anim_player`/`_collect_meshes` 는 Player/Enemy 각자 모듈에 있으나 시그니처 동일(향후 공용 유틸 후보). SubViewport 환경 설정은 HUDRoot `_add_ui_env` 한곳으로 통일됨 |
| 5 | **순환 참조 가능성** | GDScript 는 `class_name` 상호 참조를 해석 못함 — WaveManager3D↔DayNightManager 는 느슨한 `WorldSystem` 타입으로 회피(주석 명시). Node 상호 참조(world↔manager, player↔module)는 수동 메모리라 누수 없음. RefCounted 순환은 발견 안 됨 |
| 6 | **메모리 낭비 요소** | ① 적마다 `flash_mat` StandardMaterial3D 새로 생성(공유 가능) ② 적마다 HP바 ImageTexture 2장 생성(48px/140px 4종이면 충분) ③ `ItemSlotUI._apply_style` 이 `set_item` 마다 StyleBoxFlat 새로 생성 |
| 7 | **성능 병목** | ① 적 1기당 매 프레임 `get_first_node_in_group` 3회(player/base_core) — 적 50기면 프레임당 150회 트리 검색 ② 적당 OmniLight 1~2개 ③ HUD `_process` 가 매 프레임 모든 라벨 텍스트 재조립 |
| 8 | **process() 남용** | 13개 스크립트가 `_process` 사용. HUD/미니맵은 매 프레임이 적절하나, `Atmosphere3D`(파티클 추적)와 `Rift3D`/`Altar3D`(장식 연출)는 0.1~0.2초 타이머로 충분 |
| 9 | **physics_process() 최적화** | Player/Enemy/Pet/Projectile 4종만 사용 — 적절. 다만 EnemyMovement 의 그룹 검색을 프레임당 1회 캐시(월드가 배포)로 바꾸면 대량 웨이브에서 이득 |
| 10 | **Draw Call 증가 가능성** | 소품(차량·상자·가로등)이 개별 MeshInstance3D — 동일 메시 반복은 MultiMeshInstance3D 로 묶으면 수백 콜 절감. 적 눈알/오라도 타입별 공유 가능. SubViewport 2개가 `UPDATE_ALWAYS` (초상화는 캐릭터가 안 바뀌면 `UPDATE_ONCE`로 충분) |
| 11 | **Instantiate 남용** | 데미지 숫자가 피격마다 Label3D+Tween 생성 — 광역기 연타 시 수십 개/초. 오브젝트 풀 권장. 기탄도 Area3D 런타임 조립 대신 PackedScene 풀 권장 |
| 12 | **QueueFree 누락** | 치명적 누락 없음. 데미지 숫자/기탄/예고선/사망 폭발 모두 tween 콜백 또는 수명으로 정리됨. 다만 게임오버 후 남은 적들은 씬 리로드까지 잔존(리로드가 정리하므로 실질 무해) |
| 13 | **Signal Disconnect 누락** | disconnect 호출 0회. 씬 노드→Autoload 연결(PopupUI→LootManager/PlayerStats, SpawnManager→GameManager 등)이 씬 리로드 시 무효 Callable 로 남는다. `tree_exiting` 에서 disconnect 하거나 `CONNECT_ONE_SHOT`/Callable 유효성 검사 필요 |

---

# 평가 점수 (10점 만점)

| 항목 | 점수 | 근거 |
|---|---|---|
| Architecture | **8** | 컨트롤러+모듈+Config 계층 확립, Autoload 경계 명확. 역참조 패턴이 -2 |
| Maintainability | **8.5** | 최대 파일 301줄, 모든 파일이 단일 책임. 원본 대비 God Object 4개 해소 |
| Scalability | **7.5** | 새 몹/스킬/웨이브가 Config+한 모듈 수정으로 가능. 대량 적 성능 한계가 -1.5 |
| Performance | **6** | 60fps 동작하나 그룹 검색·개별 라이트·인스턴스 남발이 웨이브 확장 시 병목 |
| Readability | **8.5** | 한국어 주석 일관, 매직 넘버 상수화, 파일명=책임 |
| Folder Structure | **7** | world/player/enemy/hud 분리 완료. scripts/ vs scripts3d/ 이원화와 루트 잔여 파일이 -3 |
| Godot Best Practices | **7.5** | 시그널·그룹·Autoload·class_name 활용 양호. 씬 대신 코드 생성 UI, disconnect 부재가 감점 |
| Future Expansion | **8** | 2~3년 유지보수 관점에서 기능 추가 진입점이 전부 1파일로 좁혀짐 |

**종합: 7.6 / 10** (리팩토링 전 추정 4.5 → +3.1)

---

# 가장 위험한 문제 TOP 10 (우선순위순)

| 순위 | 문제 | 위험도 | 처방 |
|---|---|---|---|
| 1 | **git 저장소가 아님** — 957MB 프로젝트가 백업·이력 없이 존재. 실수 한 번이 복구 불가 | 🔴 치명 | `git init` + `.gitignore`(.godot/, *.fbx는 LFS) 즉시 |
| 2 | **씬 리로드마다 Autoload에 무효 시그널 연결 누적** — R 재시작 반복 시 경고 스팸·미세 누수 | 🔴 높음 | 연결 주체의 `tree_exiting` 에서 disconnect |
| 3 | **적 물리 프레임당 그룹 검색 3회** — 웨이브 확대(적 100+) 시 CPU 스파이크의 1순위 후보 | 🟠 높음 | World가 player/base_core 참조를 프레임당 1회 캐시해 배포 |
| 4 | **scenes/Main.tscn 좀비 씬** — 깨진 스크립트 경로 참조. 실수로 열거나 export 에 포함될 수 있음 | 🟠 중간 | 기능 아님이 확인되면 삭제 (사용자 결정 필요) |
| 5 | **SurvivorNPC3D 죽은 코드** — rescue 보상(최대HP+10)이 사실상 도달 불가 기능이 됨 | 🟠 중간 | 스폰 지점 복원 or 제거 결정 |
| 6 | **적당 동적 OmniLight 1~2개** — Forward+ 클러스터당 라이트 한계(기본 512) 접근 가능 | 🟠 중간 | 눈알은 emission만으로, 오라 라이트는 보스만 |
| 7 | **데미지 숫자 Label3D 무제한 생성** — 광역기+다수 적에서 인스턴스 폭발 | 🟡 중간 | 풀링 (재사용 12~24개면 충분) |
| 8 | **24MB×6 Mixamo FBX가 export 에 포함될 위험** — 배포본 크기 폭증 | 🟡 낮음 | Export Preset 에서 *.fbx 제외 필터 |
| 9 | **SubViewport 2개 UPDATE_ALWAYS** — 매 프레임 3D 씬 2개 추가 렌더 | 🟡 낮음 | 초상화 UPDATE_ONCE + 장비 변경 시 1회 갱신 |
| 10 | **소품 개별 드로우콜** — 도시 전역 차량/상자/가로등이 각각 1콜 | 🟡 낮음 | 동일 메시 MultiMesh 통합 |

*(4·5번은 "기능 삭제 금지" 원칙에 따라 이번 작업에서 손대지 않고 보고만 한다)*
