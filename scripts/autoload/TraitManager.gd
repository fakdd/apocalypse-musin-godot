extends Node
## 스타트 특성 시스템 (Autoload 싱글톤)
## 게임 시작 시 roll_random_trait() 로 F~SSS급 특성 1개를 무작위 부여한다.

signal trait_changed(trait_data: Dictionary)

## 현재 보유 특성. 비어 있으면 아직 안 뽑은 상태.
var current_trait: Dictionary = {}
var reroll_count: int = 0

## 특성 데이터 구조
##   name        : 특성 이름
##   rarity      : RarityEnums.Rarity
##   atk_pct     : 공격력 증가율 (%)
##   speed_pct   : 이동속도 증가율 (%)
##   drop_pct    : 아이템 드랍률 증가율 (%)
##   desc        : 설명 텍스트
const TRAIT_POOL := {
	# ── 역피라미드: 낮은 등급에 예시가 많고, 위로 갈수록 급격히 줄어든다 ──
	RarityEnums.Rarity.F: [   # 10종
		{"name": "둔한 감각", "atk_pct": -5.0, "speed_pct": -5.0, "drop_pct": 0.0,
		 "desc": "이계의 기운을 느끼지 못한다. 모든 것이 한 박자 느리다."},
		{"name": "빈 손", "atk_pct": 0.0, "speed_pct": 0.0, "drop_pct": 0.0,
		 "desc": "가진 것이 없다. 그래서 잃을 것도 없다."},
		{"name": "굶주린 위장", "atk_pct": -8.0, "speed_pct": 8.0, "drop_pct": 3.0,
		 "desc": "배고픔이 발을 재촉하지만 팔에는 힘이 없다."},
		{"name": "겁먹은 눈", "atk_pct": -10.0, "speed_pct": 15.0, "drop_pct": 0.0,
		 "desc": "싸우기보다 달아나는 데 익숙하다."},
		{"name": "낡은 무릎", "atk_pct": 4.0, "speed_pct": -12.0, "drop_pct": 5.0,
		 "desc": "오래 걸었다. 이제는 무릎이 비명을 지른다."},
		{"name": "떨리는 손", "atk_pct": -6.0, "speed_pct": 2.0, "drop_pct": 2.0,
		 "desc": "검을 쥐어도 칼끝이 흔들린다."},
		{"name": "얕은 숨", "atk_pct": -3.0, "speed_pct": -8.0, "drop_pct": 6.0,
		 "desc": "몇 걸음 만에 숨이 차오른다."},
		{"name": "무딘 칼", "atk_pct": -12.0, "speed_pct": 5.0, "drop_pct": 8.0,
		 "desc": "베는 게 아니라 두드리는 수준이다."},
		{"name": "길 잃은 자", "atk_pct": 0.0, "speed_pct": -5.0, "drop_pct": 12.0,
		 "desc": "헤매다 보니 남들이 못 본 것을 본다."},
		{"name": "평범함", "atk_pct": 2.0, "speed_pct": 2.0, "drop_pct": 2.0,
		 "desc": "특별한 것이 없다는 것이 그의 특별함이다."},
	],
	RarityEnums.Rarity.E: [   # 8종
		{"name": "생존 본능", "atk_pct": 3.0, "speed_pct": 5.0, "drop_pct": 2.0,
		 "desc": "도망치는 법만은 몸이 기억한다."},
		{"name": "굳은 살", "atk_pct": 5.0, "speed_pct": 0.0, "drop_pct": 0.0,
		 "desc": "맨손으로 버텨온 세월이 주먹을 단단하게 했다."},
		{"name": "고물 수집벽", "atk_pct": 0.0, "speed_pct": 0.0, "drop_pct": 18.0,
		 "desc": "쓸모없어 보이는 것에도 값이 있다는 걸 안다."},
		{"name": "잔걸음", "atk_pct": 2.0, "speed_pct": 12.0, "drop_pct": 0.0,
		 "desc": "폐허의 잔해 사이를 요령 있게 빠져나간다."},
		{"name": "악력", "atk_pct": 9.0, "speed_pct": -2.0, "drop_pct": 0.0,
		 "desc": "한 번 쥐면 놓지 않는다."},
		{"name": "밤눈", "atk_pct": 4.0, "speed_pct": 6.0, "drop_pct": 8.0,
		 "desc": "어둠 속에서도 괴수의 윤곽이 보인다."},
		{"name": "질긴 가죽", "atk_pct": 7.0, "speed_pct": -4.0, "drop_pct": 4.0,
		 "desc": "긁히고 찢겨도 다음 날엔 아물어 있다."},
		{"name": "도둑 걸음", "atk_pct": 1.0, "speed_pct": 14.0, "drop_pct": 6.0,
		 "desc": "발소리를 죽이는 법을 스스로 익혔다."},
	],
	RarityEnums.Rarity.D: [   # 7종
		{"name": "폐허의 눈", "atk_pct": 5.0, "speed_pct": 5.0, "drop_pct": 12.0,
		 "desc": "무너진 건물 속 쓸 만한 것을 알아본다."},
		{"name": "기초 검술", "atk_pct": 12.0, "speed_pct": 0.0, "drop_pct": 0.0,
		 "desc": "검을 쥐는 법을 안다. 그것만으로도 충분한 시대다."},
		{"name": "호흡법", "atk_pct": 8.0, "speed_pct": 10.0, "drop_pct": 4.0,
		 "desc": "숨을 고르는 법을 배웠다. 지치지 않는다."},
		{"name": "사냥꾼의 발", "atk_pct": 4.0, "speed_pct": 18.0, "drop_pct": 6.0,
		 "desc": "소리 없이 다가가 먼저 벤다."},
		{"name": "고철 감별", "atk_pct": 6.0, "speed_pct": 0.0, "drop_pct": 25.0,
		 "desc": "이계 금속의 냄새를 구분한다."},
		{"name": "반보 회피", "atk_pct": 7.0, "speed_pct": 15.0, "drop_pct": 2.0,
		 "desc": "반 걸음만 물러나 발톱을 흘려보낸다."},
		{"name": "굳센 심지", "atk_pct": 15.0, "speed_pct": -3.0, "drop_pct": 3.0,
		 "desc": "괴수의 포효에도 손이 떨리지 않는다."},
	],
	RarityEnums.Rarity.C: [   # 6종
		{"name": "경공 초식", "atk_pct": 8.0, "speed_pct": 20.0, "drop_pct": 5.0,
		 "desc": "발끝이 땅을 가볍게 스친다."},
		{"name": "내공 입문", "atk_pct": 22.0, "speed_pct": 5.0, "drop_pct": 0.0,
		 "desc": "단전에 희미한 온기가 돌기 시작했다."},
		{"name": "쌍수 검법", "atk_pct": 28.0, "speed_pct": 8.0, "drop_pct": 0.0,
		 "desc": "두 자루를 쥔 손이 서로를 방해하지 않는다."},
		{"name": "균열 후각", "atk_pct": 10.0, "speed_pct": 10.0, "drop_pct": 35.0,
		 "desc": "차원의 틈에서 흘러나온 기운을 코로 짚는다."},
		{"name": "철갑 의지", "atk_pct": 18.0, "speed_pct": -5.0, "drop_pct": 10.0,
		 "desc": "물러서지 않기로 마음먹은 자의 걸음은 무겁다."},
		{"name": "연격", "atk_pct": 25.0, "speed_pct": 12.0, "drop_pct": -5.0,
		 "desc": "한 번 시작한 베기는 멈추지 않는다."},
	],
	RarityEnums.Rarity.B: [   # 5종
		{"name": "약탈자의 직감", "atk_pct": 15.0, "speed_pct": 10.0, "drop_pct": 40.0,
		 "desc": "괴수의 사체에서 값진 것을 골라낸다."},
		{"name": "검기 발현", "atk_pct": 40.0, "speed_pct": 8.0, "drop_pct": 5.0,
		 "desc": "검을 휘두르면 공기가 갈라진다."},
		{"name": "질풍 보법", "atk_pct": 18.0, "speed_pct": 35.0, "drop_pct": 8.0,
		 "desc": "바람보다 먼저 도착한다."},
		{"name": "일점 관통", "atk_pct": 48.0, "speed_pct": -5.0, "drop_pct": 0.0,
		 "desc": "한 점만을 노린다. 그 점은 반드시 뚫린다."},
		{"name": "이계 친화", "atk_pct": 25.0, "speed_pct": 15.0, "drop_pct": 55.0,
		 "desc": "괴수의 기운이 그를 적으로 보지 않는다."},
	],
	RarityEnums.Rarity.A: [   # 4종
		{"name": "신법 대성", "atk_pct": 25.0, "speed_pct": 45.0, "drop_pct": 15.0,
		 "desc": "잔상만이 남는다. 눈으로는 쫓을 수 없다."},
		{"name": "파쇄의 일격", "atk_pct": 70.0, "speed_pct": 10.0, "drop_pct": 10.0,
		 "desc": "한 번의 베기로 콘크리트가 두 동이 난다."},
		{"name": "혈기 폭주", "atk_pct": 95.0, "speed_pct": 25.0, "drop_pct": -10.0,
		 "desc": "피 냄새가 짙어질수록 검이 빨라진다."},
		{"name": "약탈 대가", "atk_pct": 35.0, "speed_pct": 20.0, "drop_pct": 110.0,
		 "desc": "그가 지나간 자리엔 사체도 남지 않는다."},
	],
	RarityEnums.Rarity.S: [   # 3종
		{"name": "차원 간파", "atk_pct": 60.0, "speed_pct": 35.0, "drop_pct": 90.0,
		 "desc": "균열의 흐름을 읽는다. 괴수가 무엇을 품었는지 보인다."},
		{"name": "검강 개화", "atk_pct": 120.0, "speed_pct": 20.0, "drop_pct": 20.0,
		 "desc": "검이 아니라 의지가 적을 베어낸다."},
		{"name": "뇌전 신법", "atk_pct": 75.0, "speed_pct": 80.0, "drop_pct": 30.0,
		 "desc": "번개가 그의 발자국을 따라 그린다."},
	],
	RarityEnums.Rarity.SS: [  # 2종
		{"name": "만천화우", "atk_pct": 180.0, "speed_pct": 50.0, "drop_pct": 80.0,
		 "desc": "하늘을 뒤덮은 검의 환영이 비처럼 쏟아진다."},
		{"name": "공간 절단", "atk_pct": 230.0, "speed_pct": 35.0, "drop_pct": 40.0,
		 "desc": "적이 아니라 적이 서 있는 공간을 벤다."},
	],
	RarityEnums.Rarity.SSS: [ # 1종 — 유일무이
		{"name": "무신(武神)", "atk_pct": 400.0, "speed_pct": 120.0, "drop_pct": 200.0,
		 "desc": "인간의 영역을 넘어섰다. 이 세계에 그를 막을 것은 없다."},
	],
}

## F~SSS급 특성 1개를 무작위로 부여한다.
func roll_random_trait() -> Dictionary:
	var rarity: int = RarityEnums.roll_rarity(0.0)
	var pool: Array = TRAIT_POOL.get(rarity, TRAIT_POOL[RarityEnums.Rarity.F])
	var picked: Dictionary = pool[randi() % pool.size()].duplicate(true)
	picked["rarity"] = rarity
	current_trait = picked
	trait_changed.emit(current_trait)
	return current_trait

## "새로 태어나기" — 특성을 다시 뽑는다.
func reroll_trait() -> Dictionary:
	reroll_count += 1
	return roll_random_trait()

## N번 굴려서 가장 높은 등급만 남긴다 (운명 시험).
## 같은 등급이 여러 번 나오면 그 중 하나를 무작위로 고른다.
## 반환값에 통계가 포함된다: rolls, best_rarity, counts
var last_trial: Dictionary = {}

func roll_best_of(times: int = 1000) -> Dictionary:
	times = maxi(1, times)
	var counts := {}
	var best_rarity := -1
	for i in range(times):
		var r: int = RarityEnums.roll_rarity(0.0)
		counts[r] = counts.get(r, 0) + 1
		if r > best_rarity:
			best_rarity = r

	var pool: Array = TRAIT_POOL.get(best_rarity, TRAIT_POOL[RarityEnums.Rarity.F])
	var picked: Dictionary = pool[randi() % pool.size()].duplicate(true)
	picked["rarity"] = best_rarity

	reroll_count += times
	current_trait = picked

	# 통계 정리 (등급명 -> 횟수)
	var named := {}
	for r in counts.keys():
		named[RarityEnums.get_rarity_name(r)] = counts[r]
	last_trial = {
		"rolls": times,
		"best_rarity": best_rarity,
		"counts": named,
		"best_count": counts.get(best_rarity, 0),
	}

	trait_changed.emit(current_trait)
	return current_trait

func has_trait() -> bool:
	return not current_trait.is_empty()

func get_atk_pct() -> float:
	return float(current_trait.get("atk_pct", 0.0))

func get_speed_pct() -> float:
	return float(current_trait.get("speed_pct", 0.0))

func get_drop_pct() -> float:
	return float(current_trait.get("drop_pct", 0.0))

func get_trait_rarity() -> int:
	return int(current_trait.get("rarity", RarityEnums.Rarity.F))

func get_trait_name() -> String:
	return String(current_trait.get("name", "무특성"))

func get_trait_desc() -> String:
	return String(current_trait.get("desc", ""))

## UI 표기용 요약 문자열
func get_summary() -> String:
	if not has_trait():
		return "특성 없음"
	return "%s %s  (공격 %+.0f%% · 속도 %+.0f%% · 드랍 %+.0f%%)" % [
		RarityEnums.get_rarity_tag(get_trait_rarity()),
		get_trait_name(), get_atk_pct(), get_speed_pct(), get_drop_pct()
	]

func reset() -> void:
	current_trait = {}
	reroll_count = 0
	last_trial = {}
