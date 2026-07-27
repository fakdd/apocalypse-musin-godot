# 프로젝트 구조 분석 — 《SSS급 무신》

> 분석일: 2026-07-26 · Godot 4.7.1 · 총 용량 **2.3 GB** · GDScript **6,527줄** / 27개 파일

---

## 1. 현재 폴더 구조

```
apocalypse-musin-godot/
├── project.godot                 오토로드 8개 + 렌더 설정
├── CITY_DESIGN.md                도시 아트 디렉션 문서
│
├── scenes/                       2 KB
│   ├── Main3D.tscn               ★ 메인 씬 (World3D.gd 만 붙은 빈 Node3D)
│   └── Main.tscn                 ⛔ 죽은 파일 (삭제된 scripts/World.gd 참조)
│
├── scripts/                      82 KB — 엔진 비의존 게임 로직
│   ├── ItemData.gd               class_name ItemData (Resource)
│   ├── ItemSkins.gd              class_name ItemSkins (static 유틸)
│   └── autoload/                 싱글톤 8개
│       ├── RarityEnums.gd        등급 정의 · 가중치 롤
│       ├── TraitManager.gd       특성 46종 · 리롤 · 운명시험
│       ├── GameManager.gd        낮/밤 · 웨이브 · 봉인 진행도
│       ├── PlayerStats.gd        스탯 합산 · 장비 관리
│       ├── LootManager.gd        아이템 생성 · 드랍
│       ├── CraftManager.gd       합성 · 강화 · 마석
│       ├── PetManager.gd         펫 보유/교체
│       └── SoundManager.gd       SFX 풀 · 마스터 볼륨
│
├── scripts3d/                    241 KB — 3D 씬 노드
│   ├── World3D.gd                ⚠️ 1,252줄 / 함수 56개 (God Object)
│   ├── HUD3D.gd                  707줄
│   ├── Player3D.gd               698줄
│   ├── Enemy3D.gd                639줄
│   ├── InventoryUI · ItemSlotUI · StatsWindow · TraitScreen
│   ├── BaseCore3D · Altar3D · Rift3D · Atmosphere3D · MiniMap3D
│   ├── ItemDrop · Projectile3D · Pet3D
│   └── SurvivorNPC3D.gd          ⛔ 고아 (아무도 참조 안 함)
│
├── assets/                       348 KB
│   ├── audio/                    ✅ 19개 전부 사용 중
│   ├── characters/ tiles/        ⛔ 2D 시절 PNG (전부 미사용)
│   └── KENNEY_LICENSE.txt
│
├── assets3d/                     957 MB  ⚠️
│   ├── monsters/   345 MB        ⚠️ .tscn 4.6MB + 원본 FBX/PNG 340MB
│   ├── buildings/  214 MB        ⚠️ wartorn_block.obj 단일 207MB
│   ├── chars/      213 MB        ⚠️ hero.tscn 30MB + 원본 FBX 146MB
│   ├── station/    179 MB        ⚠️ central_station.obj 172MB
│   ├── textures/   5.8 MB        ✅ PBR 세트
│   ├── npc/ models/ icons/       ✅ 정상
│
├── assets_src/                   653 MB — 원본 보관 (.gdignore 있음, 빌드 제외됨)
└── .godot/                       675 MB — 임포트 캐시 (Git 제외 대상)
```

---

## 2. 발견된 문제 — 심각도 순

### 🔴 심각 1: 게임 에셋 폴더에 원본 파일이 섞여 있다

`assets3d/`가 **957MB**인데, 게임이 실제로 로드하는 리소스는 78개뿐입니다.
**코드에서 `.fbx` 참조는 0건** — 즉 원본 FBX가 전부 죽은 무게입니다.

| 경로 | 크기 | 게임에서 쓰나? |
|---|---|---|
| `chars/Idle.fbx`, `Walking.fbx`, `Running.fbx`, `Dying.fbx`, `Sword And Shield *.fbx` | 146 MB | ❌ (`hero.tscn`으로 구움) |
| `monsters/Mutant.fbx`, `Walking.fbx`, `Zombie Attack*.fbx` 외 7개 + PNG | 340 MB | ❌ (`mutant.tscn` 등으로 구움) |

**영향**: Godot이 매 임포트마다 이것들을 다시 처리해 시간이 낭비되고, 빌드에도 포함될 위험이 있습니다.

**조치**
```bash
mkdir -p assets_src/mixamo_raw
mv assets3d/chars/*.fbx  assets3d/chars/*.fbx.import  assets_src/mixamo_raw/
mv assets3d/monsters/*.fbx assets3d/monsters/*.fbx.import assets_src/mixamo_raw/
mv assets3d/monsters/*_[0-9].png assets3d/monsters/*_[0-9].png.import assets_src/mixamo_raw/
```
→ **약 486 MB 절감**, 게임 동작에는 영향 없음.

---

### 🔴 심각 2: OBJ 두 개가 379MB — 폴리곤 과다

| 파일 | 크기 |
|---|---|
| `buildings/wartorn_block.obj` | **207 MB** |
| `station/central_station.obj` | **172 MB** |

Meshy 원본 그대로라 폴리곤이 수백만 단위입니다. 게다가 `wartorn_block`은 **건물 22동에 반복 인스턴싱**되고 있어 드로우콜·메모리 부담이 큽니다.

**조치** (권장 순):
1. Blender에서 **Decimate 모디파이어**로 폴리곤 90~95% 감축 → 각 10~20MB
2. `.obj` → `.glb`로 재저장 (바이너리라 훨씬 작고 로딩도 빠름)
3. 원거리용 저폴리 LOD 별도 생성

이 두 파일이 프로젝트 용량의 **16%**이자, 가장 큰 성능 리스크입니다.

---

### 🟠 중대 3: `World3D.gd`가 God Object

**1,252줄 / 함수 56개**로 프로젝트 전체 코드의 19%입니다. 한 파일이 다음을 전부 담당합니다.

- 환경/조명 설정 · 지형 생성 · 도시 생성 · 스카이라인 · 보도 · 소품 배치
- 파티클 · 균열 · 방주 · 아이템 배치 · 플레이어 스폰
- 낮/밤 상태 머신 · 웨이브 진행 · 적 스폰 · 보스 · 입력 처리

**영향**: 한 곳을 고치면 다른 곳이 깨질 위험이 크고, 실제로 이번 작업 중 여러 번 발생했습니다.

**조치**: 최소 3개로 분리
```
World3D.gd        → 조립과 상태 머신만 (200줄 목표)
CityBuilder.gd    → 지형/도시/스카이라인/소품/보도 생성
WaveDirector.gd   → 웨이브·적 스폰·보스·봉인 진행
```

---

### 🟠 중대 4: 죽은 코드가 남아 있다

| 대상 | 상태 |
|---|---|
| `scenes/Main.tscn` | 삭제된 `scripts/World.gd` 참조 → **열면 에러**. 삭제해도 지웠다가 에디터가 되살림 |
| `scripts3d/SurvivorNPC3D.gd` | 생존자 시스템 제거 후 **아무도 참조 안 함** |
| `GameManager` 자원 시스템 | `resources` / `add_resource` / `can_afford` / `spend` — 호출처 0 |
| `GameManager.survivors_rescued` | 생존자 제거 후 항상 0. `PlayerStats.get_final_max_hp()`가 아직 이걸 더함 |
| `assets/characters/`, `assets/tiles/` | 2D 시절 PNG, 전부 미사용 |
| 루트의 `*.gd.uid` 7개 | 삭제한 임시 스크립트의 잔재 |

**주의**: `Main.tscn`은 제가 삭제했는데도 다시 생겼습니다. **Godot 에디터에서 해당 씬 탭을 닫고** 삭제해야 합니다.

---

### 🟡 보통 5: 매 프레임 전역 그룹 조회

`MiniMap3D.gd`는 `_draw()`에서 `get_nodes_in_group()`을 **7번** 호출하고, `_process()`마다 `queue_redraw()`합니다. 즉 **초당 60회 × 7회 트리 전체 순회**입니다.

적이 수십 마리인 밤에는 부담이 됩니다.

**조치**: 갱신 주기를 0.1초로 낮추거나(레이더는 10fps여도 충분), 결과를 캐싱.

---

### 🟡 보통 6: UI 좌표가 1280×720에 하드코딩

`HUD3D.gd`에 `Vector2(1150, 556)` 같은 절대 좌표가 **12곳** 있습니다. 창 크기를 바꾸면 스킬 버튼과 미니맵이 화면 밖으로 나갑니다.

**조치**: `anchors_preset`(우하단/우상단 고정)으로 전환.

---

### 🟡 보통 7: `.gitignore`가 없다

Git을 쓰기 시작하면 `.godot/` **675MB**와 `assets_src/` **653MB**가 그대로 커밋됩니다.

**조치**: 루트에 `.gitignore` 생성
```gitignore
.godot/
assets_src/
*.tmp
export_presets.cfg
```

---

### 🟢 경미 8: 폴더 이름이 실제 내용과 어긋남

- `scripts/` vs `scripts3d/` — 실제 기준은 "2D/3D"가 아니라 **"엔진 비의존 로직" vs "씬 노드"** 입니다. 2D는 이미 없어졌습니다.
- `assets3d/npc/` — 생존자 NPC용이었으나 시스템 제거 후 미사용에 가까움

**조치**: `scripts/` → `core/`, `scripts3d/` → `game/` 정도가 의도를 더 잘 드러냅니다. (선택사항)

---

## 3. 잘 되어 있는 점

객관적으로 괜찮은 부분도 명확합니다.

- **오토로드 계층이 깔끔합니다.** `RarityEnums → TraitManager → PlayerStats → LootManager → CraftManager` 의존 순서가 올바르게 잡혀 있고 순환 참조가 없습니다.
- **시그널 기반 결합이 잘 되어 있습니다.** `stats_changed` 하나로 특성·장비·강화가 전부 플레이어에 반영됩니다. UI가 게임 로직을 직접 건드리지 않습니다.
- **`current_scene` 직접 참조가 단 2곳**뿐입니다 (`PetManager`, `Enemy3D`). 대부분 그룹으로 느슨하게 연결돼 있습니다.
- **오디오 19개가 전부 사용 중**입니다. 미사용 0건.
- **`assets_src/`에 `.gdignore`가 있어** 원본이 임포트 대상에서 제외됩니다.
- **라이선스 문서가 갖춰져 있습니다** (Kenney CC0, game-icons CC-BY 출처 표기).

---

## 4. 권장 조치 순서

| 순위 | 작업 | 효과 | 난이도 |
|---|---|---|---|
| 1 | 원본 FBX/PNG를 `assets_src/`로 이동 | **-486 MB** | 매우 쉬움 |
| 2 | `.gitignore` 생성 | Git 사용 시 필수 | 매우 쉬움 |
| 3 | 죽은 코드 삭제 (Main.tscn·SurvivorNPC3D·자원 시스템) | 혼란 제거 | 쉬움 |
| 4 | OBJ 2개 Decimate + GLB 변환 | **-350 MB**, 성능 개선 | 보통 (Blender 필요) |
| 5 | 미니맵 갱신 주기 제한 | 밤 프레임 개선 | 쉬움 |
| 6 | UI를 앵커 기반으로 전환 | 해상도 대응 | 보통 |
| 7 | `World3D.gd` 3분할 | 유지보수성 | 큼 |

**1~3번만 해도 프로젝트가 2.3GB → 1.8GB로 줄고 구조가 훨씬 명확해집니다.**

---

## 5. 목표 폴더 구조 (정리 후)

```
apocalypse-musin-godot/
├── project.godot
├── .gitignore                    ← 신규
├── docs/
│   ├── CITY_DESIGN.md
│   └── PROJECT_REVIEW.md
│
├── scenes/
│   └── Main3D.tscn               (Main.tscn 삭제)
│
├── core/                         ← scripts/ 개명
│   ├── ItemData.gd  ItemSkins.gd
│   └── autoload/                 싱글톤 8개
│
├── game/                         ← scripts3d/ 개명
│   ├── world/                    World3D · CityBuilder · WaveDirector
│   ├── actors/                   Player3D · Enemy3D · Pet3D · Projectile3D
│   ├── props/                    BaseCore3D · Altar3D · Rift3D · ItemDrop
│   └── ui/                       HUD3D · InventoryUI · StatsWindow · TraitScreen · MiniMap3D
│
├── assets/audio/                 (2D PNG 삭제)
├── assets3d/
│   ├── chars/hero.tscn           (FBX 제거)
│   ├── monsters/*.tscn *.gltf    (FBX/PNG 제거)
│   ├── buildings/ station/       (Decimate 된 .glb)
│   ├── models/ textures/ icons/
│
└── assets_src/                   원본 전부 (Git 제외)
```

**예상 용량**: 게임 폴더 **약 120 MB** (현재 957MB에서 87% 감소)
