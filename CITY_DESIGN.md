# 《SSS급 무신》 도시 환경 아트 디렉션

> 목표 톤: **디아블로4의 중압감 + 퍼스트 디센던트의 SF 질감 + 솔로레벨링의 붉은 게이트 + 다크소울의 수직 밀도**
> 무대: 차원의 균열로 멸망한 현대 대한민국 광역시.

---

## 0. 공통 디자인 언어 (모든 건물이 반드시 공유)

이 규칙을 모든 프롬프트에 동일하게 넣어야 도시가 하나로 이어져 보입니다.

| 요소 | 규칙 |
|---|---|
| **건축 양식** | 1990~2020년대 한국 도시. 화강암 저층부 + 유리 커튼월 상층부, 옥상 물탱크·실외기·간판 프레임 |
| **파괴 방향** | 붕괴는 항상 **북동쪽(균열 방향)에서 남서쪽으로** 찢겨나간 형태 |
| **차원 수정** | 붉은 결정이 **건물을 뚫고 자란다**. 창문·균열·환기구에서 돋아남 |
| **오염 진행도** | 지면 가까울수록 검게 탄 콘크리트, 위로 갈수록 붉은 결정 밀도 증가 |
| **색 팔레트** | 콘크리트 `#3A3733` · 녹슨 철 `#5C3A2E` · 차원 붉은빛 `#C81428` · 오염 자주 `#6B1A4A` |
| **발광** | 붉은 에너지만 발광. 인공 조명은 전부 꺼져 있음 |
| **모듈 접합** | 건물 하단부를 **평평한 직육면체 기단**으로 마감 → 격자에 붙여 배치 가능 |

### 프롬프트 공통 접미사 (모든 건물에 그대로 붙일 것)

```
isolated building, centered composition, neutral gray background, front perspective,
realistic PBR, AAA game environment, highly detailed, cinematic lighting,
Unreal Engine 5 quality, no people, no vehicles, no text, Image-to-3D optimized,
korean urban architecture, red dimensional crystals growing through structure,
collapsed concrete, exposed rebar, shattered glass, dark fantasy apocalypse
```

---

## 1. 오피스 빌딩 (테헤란로 타워)

1. **컨셉** — 20층 유리 커튼월 오피스. 상층부 1/3이 대각선으로 절단되어 무너졌고, 절단면에서 붉은 결정이 자라 하늘을 향해 뻗음.
2. **역할** — 일반 파밍 구역. B~A급 장비 드랍.
3. **탐험** — 1층 로비 진입 → 무너진 계단으로 3층 → 옥상 헬기장에서 광역 조망(주변 균열 위치 표시 해금).
4. **환경 스토리텔링** — 로비에 쌓인 바리케이드와 탄피. 사람들이 여기서 버티다 실패했다.
5. **프롬프트**
```
A ruined 20-story Korean office tower, glass curtain wall facade, upper third
sheared diagonally and collapsed, massive red crystal shards erupting from the
severed floors, granite podium base, rooftop water tanks and HVAC units,
[공통 접미사]
```

---

## 2. 대형 쇼핑몰 (센트럴 몰)

1. **컨셉** — 낮고 넓은 박스형 몰. 유리 아트리움 천장이 완전히 붕괴해 내부가 노출됨.
2. **역할** — **중형 보스 아레나**. 넓은 실내 전투 공간.
3. **탐험** — 무너진 천장 구멍으로 낙하 진입 → 에스컬레이터 층간 이동 → 푸드코트에서 보스전.
4. **환경 스토리텔링** — 세일 현수막이 그을린 채 걸려 있고, 카트가 바리케이드로 쌓여 있다.
5. **프롬프트**
```
A collapsed Korean shopping mall, wide low box structure, glass atrium roof
caved in exposing interior escalators, red crystal formations bursting through
the floor plates, burnt signage frames, rubble piles,
[공통 접미사]
```

---

## 3. 병원 (성심 의료원)

1. **컨셉** — H자 평면의 종합병원. 창문마다 커튼이 찢겨 나부끼고, 응급실 입구가 검붉게 오염됨.
2. **역할** — **회복 아이템 특화 파밍**. 오염도가 높아 지속 피해 구역.
3. **탐험** — 응급실 → 수술동 → 지하 영안실(고등급 드랍, 고위험).
4. **환경 스토리텔링** — 이동식 침대가 복도에 뒤엉켜 있다. 대피가 실패한 흔적.
5. **프롬프트**
```
A ruined Korean general hospital, H-shaped concrete building, emergency entrance
canopy collapsed, torn curtains hanging from broken windows, dark red corruption
spreading from the ground floor, red crystals in the upper wards,
[공통 접미사]
```

---

## 4. 경찰서 (강북 경찰서)

1. **컨셉** — 5층 관공서. 정문에 방벽과 철조망, 하지만 안쪽에서부터 뚫렸다.
2. **역할** — **무기류 드랍 우대**. 무기고 금고 해금 요소.
3. **탐험** — 정문 방벽 넘기 → 유치장 → 지하 무기고(열쇠 필요).
4. **환경 스토리텔링** — 방벽은 바깥이 아니라 **안쪽으로 무너져 있다**. 균열은 건물 안에서 열렸다.
5. **프롬프트**
```
A ruined Korean police station, 5-story government concrete building, riot
barricades and razor wire at the entrance blown outward from inside, shattered
ground floor, red crystals emerging from the interior,
[공통 접미사]
```

---

## 5. 소방서

1. **컨셉** — 3층 차고형. 셔터가 뜯겨 나가고 내부 소방차 자리는 비어 있다.
2. **역할** — 소형 안전 거점. 화톳불 리스폰 지점.
3. **탐험** — 차고 → 훈련탑 상단(저격/조망 포인트).
4. **환경 스토리텔링** — 출동한 소방차는 돌아오지 못했다. 벽에 걸린 이름표가 그대로다.
5. **프롬프트**
```
A ruined Korean fire station, 3-story building with large garage bays, torn
metal shutters, attached concrete training tower, red crystal growth on the
tower top, scorched walls,
[공통 접미사]
```

---

## 6. 학교 (제일고등학교)

1. **컨셉** — ㄱ자 4층 교사 + 운동장. 운동장 한가운데가 함몰되어 균열이 열림.
2. **역할** — **균열 구역 입구**. 몬스터 스폰 밀집.
3. **탐험** — 운동장 우회 → 교실동 3층 → 옥상 연결통로.
4. **환경 스토리텔링** — 운동장에 그려진 대피 유도선이 함몰지 쪽으로 향해 있다.
5. **프롬프트**
```
A ruined Korean high school building, L-shaped 4-story concrete structure with
rows of identical classroom windows, adjacent sunken playground with a glowing
red fissure, crystals radiating from the crater,
[공통 접미사]
```

---

## 7. 아파트 (행복 아파트 3단지)

1. **컨셉** — 25층 판상형 아파트 3개 동. 한 동은 중간이 꺾여 옆 동에 기대어 있음.
2. **역할** — **맵 외곽 스카이라인**. 배경 전용(진입 불가).
3. **탐험** — 진입 불가. 원경 실루엣으로 도시 규모를 체감시킴.
4. **환경 스토리텔링** — 베란다마다 널린 빨래가 그대로 타 있다.
5. **프롬프트**
```
A ruined Korean apartment tower complex, 25-story flat slab residential
buildings with repeating balconies, one tower snapped mid-height and leaning
onto the next, red crystals in the fracture, burnt laundry on balconies,
[공통 접미사]
```

---

## 8. 지하철역 (센트럴 스테이션) ★ 이미 제작됨

1. **컨셉** — 돔형 유리 지붕 + 시계탑. 현재 게임의 **방주 거점**.
2. **역할** — **안전지대**. 특성 재주사 제단, 정비 공간.
3. **탐험** — 광장 → 대합실 → 승강장(하강 던전 입구).
4. **환경 스토리텔링** — 생존자들의 붉은 깃발이 걸려 있다. 인류가 마지막으로 지킨 곳.
5. **프롬프트** — *(이미 보유. 확장 시 승강장 내부용으로 추가 생성 권장)*
```
Underground subway platform interior, Korean metro station, collapsed ceiling
sections, stalled train carriage, red crystals growing along the rails,
emergency lighting off, water pooling on the floor,
[공통 접미사]
```

---

## 9. 백화점

1. **컨셉** — 곡면 파사드 + 금속 패널. 외벽 패널이 비늘처럼 벗겨져 철골 노출.
2. **역할** — 고급 장비 파밍. **엘리트 몬스터 서식**.
3. **탐험** — 외부 비상계단 → 최상층 명품관.
4. **환경 스토리텔링** — 진열장은 이미 털렸다. 우리보다 먼저 온 헌터가 있었다.
5. **프롬프트**
```
A ruined Korean department store, curved facade with metal cladding panels
peeling off like scales exposing steel frame, luxury storefront ground floor
smashed, red crystals along the exposed structure,
[공통 접미사]
```

---

## 10. 발전소

1. **컨셉** — 냉각탑 2기 + 터빈동. 냉각탑 하나는 균열에 관통당해 구멍이 뚫림.
2. **역할** — **마석(에너지) 대량 획득 구역**.
3. **탐험** — 터빈동 → 냉각탑 내부(원형 아레나 전투).
4. **환경 스토리텔링** — 계기판이 전부 최대치에서 멈춰 있다. 균열이 에너지를 빨아들였다.
5. **프롬프트**
```
A ruined Korean power plant, two concrete cooling towers one pierced by a
massive red crystal spire, turbine hall with collapsed roof trusses, industrial
pipework, transformer yard,
[공통 접미사]
```

---

## 11. 방송국

1. **컨셉** — 사각 본관 + 거대 송신탑. 송신탑이 기울어 본관을 관통.
2. **역할** — **맵 전역 정보 해금**(균열 위치 전체 공개).
3. **탐험** — 스튜디오 → 송신탑 등반(수직 구간).
4. **환경 스토리텔링** — 스튜디오 카메라가 켜진 채 멈춰 있다. 마지막 방송이 끝나지 않았다.
5. **프롬프트**
```
A ruined Korean broadcasting station, boxy studio building with a huge leaning
transmission tower piercing through its roof, satellite dishes torn off,
red crystals climbing the tower lattice,
[공통 접미사]
```

---

## 12. 시청

1. **컨셉** — 신고전 양식 석조 + 유리 증축부. 광장에 대형 균열.
2. **역할** — **2차 세이프존 후보**(스토리 진행 시 해금).
3. **탐험** — 광장 → 대회의실 → 지하 벙커.
4. **환경 스토리텔링** — 광장에 대피 안내 천막이 무너져 있다. 여기가 최초 집결지였다.
5. **프롬프트**
```
A ruined Korean city hall, neoclassical stone facade with modern glass annex,
grand entrance stairs cracked, plaza with a large glowing red fissure,
collapsed emergency tents, crystals around the fissure,
[공통 접미사]
```

---

## 13. 은행 (본점)

1. **컨셉** — 좁고 높은 석조. 1층 금고문이 **바깥으로** 터져 있다.
2. **역할** — **희귀 재료 집중 드랍**. 소형 고위험 구역.
3. **탐험** — 로비 → 지하 금고(밀실 전투).
4. **환경 스토리텔링** — 금고는 안에서 뚫렸다. 돈은 그대로 남아 있다. 이제 종이일 뿐이다.
5. **프롬프트**
```
A ruined Korean bank headquarters, narrow tall stone building with columns,
massive vault door blown outward at ground level, scattered debris, red crystal
growth from the basement level,
[공통 접미사]
```

---

## 14. 호텔

1. **컨셉** — 곡선형 고층. 상단 객실층이 통째로 붉은 결정에 감싸임.
2. **역할** — 중간 난이도 파밍 + **수직 탐험 튜토리얼**.
3. **탐험** — 로비 → 외벽 붕괴부를 발판 삼아 상층 → 옥상 수영장.
4. **환경 스토리텔링** — 로비 피아노 위에 먼지가 쌓였다. 체크인 명부가 펼쳐진 채다.
5. **프롬프트**
```
A ruined Korean luxury hotel, curved high-rise tower, upper guest floors
encased in a massive red crystal cluster, collapsed entrance canopy, balconies
sheared off, rooftop pool exposed,
[공통 접미사]
```

---

## 15. 주차타워

1. **컨셉** — 개방형 콘크리트 슬래브 8층. 층마다 뻥 뚫려 있어 내부가 다 보임.
2. **역할** — **수직 전투 아레나**. 층간 낙하 유도.
3. **탐험** — 램프를 따라 나선형 상승. 층마다 웨이브.
4. **환경 스토리텔링** — 차들이 출구 쪽으로 몰려 뒤엉켜 있다. 아무도 빠져나가지 못했다.
5. **프롬프트**
```
A ruined Korean multi-story parking garage, 8 levels of open concrete slabs
with spiral ramps, partially collapsed corner, red crystals growing between
levels, exposed rebar, no cars,
[공통 접미사]
```

---

## 16. 연구소

1. **컨셉** — 저층 백색 패널 + 원형 실험동. 원형동 지붕이 열려 균열이 노출.
2. **역할** — **차원 균열 연구 로어**. 스토리 문서 수집처.
3. **탐험** — 클린룸 → 원형 실험동 중앙(균열 코어).
4. **환경 스토리텔링** — 여기서 균열을 **연구**한 게 아니라 **열었다**. 이 게임의 반전 지점.
5. **프롬프트**
```
A ruined Korean research facility, low-rise white panel building with a
cylindrical laboratory wing, domed roof split open exposing a red dimensional
rift inside, containment rings, scientific equipment debris,
[공통 접미사]
```

---

## 17. 물류센터

1. **컨셉** — 초대형 단층 창고. 지붕 절반이 내려앉음.
2. **역할** — **대량 소모품 파밍**. 넓은 개활 전투.
3. **탐험** — 하역장 → 랙 사이 미로 → 사무동.
4. **환경 스토리텔링** — 배송 대기 화물이 그대로다. 라벨의 주소는 이제 존재하지 않는 동네다.
5. **프롬프트**
```
A ruined Korean logistics warehouse, massive single-story steel structure,
half the corrugated roof collapsed inward, loading docks with torn shutters,
storage racks visible inside, red crystals piercing the roof,
[공통 접미사]
```

---

## 18. 공장

1. **컨셉** — 톱니형 지붕 + 굴뚝 3기. 굴뚝 하나가 꺾여 지붕을 관통.
2. **역할** — **장비 강화 재료** 특화.
3. **탐험** — 작업장 → 용광로(화염 기믹) → 굴뚝 내부.
4. **환경 스토리텔링** — 컨베이어가 아직 돌아간다. 전력은 균열에서 오고 있다.
5. **프롬프트**
```
A ruined Korean industrial factory, sawtooth roof profile, three smokestacks
with one snapped and fallen through the roof, rusted steel siding, exposed
machinery, red crystals and glowing energy inside,
[공통 접미사]
```

---

## 19. 방주 (안전지대) — 센트럴 스테이션 광장

1. **컨셉** — 역 앞 광장을 컨테이너·모래주머니·철조망으로 요새화. 중앙에 마도 제단.
2. **역할** — **유일한 안전지대**. 몬스터 스폰 금지, 특성 재주사, 정비.
3. **탐험** — 탐험 대상이 아님. **돌아오는 곳**.
4. **환경 스토리텔링** — 벽에 생존자 이름이 새겨져 있다. 지워진 이름이 더 많다.
5. **프롬프트**
```
A fortified survivor camp built in a ruined station plaza, shipping container
walls, sandbag barricades, razor wire, watchtowers made of scaffolding,
central stone altar with blue glowing crystal, braziers with fire,
[공통 접미사 — 단, red crystals 는 최소화하고 blue altar glow 를 강조]
```

---

## 20. 최종 보스 랜드마크 — **차원문 첨탑 (The Spire)**

1. **컨셉** — 도시 중심에서 **하늘로 솟은 거대 붉은 결정 구조물**. 원래 63빌딩급 마천루였으나 완전히 결정에 잠식되어 형태만 남음. 상공에 거대한 균열이 입을 벌리고 있다.
2. **역할** — **최종 보스전 무대**. 5개 균열 봉인 완료 시 개방.
3. **탐험** — 결정 계단을 나선으로 상승 → 정상 플랫폼에서 최후의 외계 군주와 1:1.
4. **환경 스토리텔링** — 첨탑 표면에 **삼켜진 건물들의 잔해가 박혀 있다**. 도시를 먹고 자란 것이다.
5. **프롬프트**
```
A colossal red crystal spire piercing the sky, formed from a consumed
skyscraper, fragments of absorbed buildings embedded in its surface, spiral
crystal platforms ascending, enormous glowing dimensional rift above the peak,
volumetric red energy, apocalyptic scale,
[공통 접미사]
```

---

## 21. 도시 배치도 & 탐험 동선

```
                    ▲ 북 (오염 진행 방향)
        ┌──────────────────────────────────────┐
        │  [아파트 단지] ← 진입불가 스카이라인   │
        │                                      │
   ┌────┼──[발전소]────[공장]────[물류센터]────┼────┐
   │    │      \          |          /         │    │
   │  [연구소]  \    ◆ 균열 구역 ◆   /   [주차타워] │
   │    │        \        |        /           │    │
   │  [학교]──────[  ★ 차원문 첨탑 ★  ]──[방송국]  │
   │    │        /        |        \           │    │
   │ [병원]     /   ● 폐허 도시 ●    \    [백화점]  │
   │    │      /          |          \         │    │
   ├────┼──[경찰서]──[■ 방주 ■]──[쇼핑몰]──────┼────┤
   │    │              (센트럴 스테이션)        │    │
   │  [소방서]     [시청]    [은행]    [호텔]   │    │
   │    │                                      │    │
   │    │  [오피스 빌딩군] ← 진입 가능 저층     │    │
   └────┴──────────────────────────────────────┴────┘
                    ▼ 남 (상대적 안전)
```

### 3단 동선 설계

| 단계 | 구역 | 난이도 | 목적 |
|---|---|---|---|
| **1** | 방주 남쪽 (소방서·시청·은행) | ★☆☆ | 초반 장비 확보, 조작 학습 |
| **2** | 중간 링 (병원·쇼핑몰·백화점·호텔·주차타워) | ★★☆ | 본격 파밍, 엘리트 조우 |
| **3** | 북쪽 균열 구역 (발전소·공장·연구소·학교) | ★★★ | 고등급 드랍, 균열 봉인 |
| **최종** | 중앙 첨탑 | ★★★★★ | 봉인 5개 완료 후 개방 |

**핵심 원칙**: 플레이어가 **북쪽으로 갈수록** 붉은 결정 밀도·안개 농도·몬스터 등급이 함께 올라갑니다. 별도의 안내 없이 **시각 정보만으로 난이도를 읽을 수 있게** 하는 것이 목표입니다.

---

## 22. 제작 우선순위 (실제 작업 순서 권장)

Meshy 크레딧과 시간이 한정적이므로 이 순서를 권합니다.

| 순위 | 건물 | 이유 |
|---|---|---|
| 1 | **차원문 첨탑** | 맵 어디서나 보이는 목표점. 방향감각의 축 |
| 2 | 오피스 빌딩 | 가장 많이 재사용됨 (도시 대부분을 채움) |
| 3 | 아파트 | 외곽 스카이라인 전체를 채움 |
| 4 | 쇼핑몰 | 보스 아레나 |
| 5 | 병원 · 학교 | 실루엣이 특징적이라 랜드마크 역할 |
| 6~ | 나머지 | 여유 있을 때 |

**팁**: 같은 모델을 **회전·스케일·색조만 바꿔 재사용**하면 5~6종만으로도 도시가 채워집니다. 지금 게임의 `wartorn_block`이 그 방식으로 쓰이고 있습니다.
