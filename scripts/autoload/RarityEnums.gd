extends Node
## 공통 등급 정의 (Autoload 싱글톤)
## 모든 등급 판정(특성/아이템)은 이 스크립트를 통해 이루어진다.

enum Rarity { F, E, D, C, B, A, S, SS, SSS }

## 등급별 기본 가중치 (합계 100.0)
## SSS = 0.0001% (100만분의 1). 합성으로도 도달할 수 있게 설계된 값이다.
const WEIGHTS := {
	Rarity.F:   58.0,
	Rarity.E:   25.0,
	Rarity.D:   11.0,
	Rarity.C:    4.0,
	Rarity.B:    1.5,
	Rarity.A:    0.4,
	Rarity.S:    0.09,
	Rarity.SS:   0.0099,
	Rarity.SSS:  0.0001,
}

const NAMES := {
	Rarity.F: "F", Rarity.E: "E", Rarity.D: "D", Rarity.C: "C",
	Rarity.B: "B", Rarity.A: "A", Rarity.S: "S",
	Rarity.SS: "SS", Rarity.SSS: "SSS",
}

const COLORS := {
	Rarity.F:   Color(0.62, 0.62, 0.62),
	Rarity.E:   Color(0.75, 0.78, 0.72),
	Rarity.D:   Color(0.45, 0.85, 0.45),
	Rarity.C:   Color(0.35, 0.70, 1.00),
	Rarity.B:   Color(0.60, 0.45, 1.00),
	Rarity.A:   Color(0.95, 0.55, 1.00),
	Rarity.S:   Color(1.00, 0.80, 0.20),
	Rarity.SS:  Color(1.00, 0.45, 0.10),
	Rarity.SSS: Color(1.00, 0.15, 0.20),
}

## 등급이 높을수록 강한 발광 (VFX 강도)
const GLOW := {
	Rarity.F: 0.5, Rarity.E: 0.8, Rarity.D: 1.2, Rarity.C: 1.8,
	Rarity.B: 2.5, Rarity.A: 3.5, Rarity.S: 5.0,
	Rarity.SS: 7.0, Rarity.SSS: 10.0,
}

var _cum_keys: Array = []
var _cum_vals: PackedFloat64Array = PackedFloat64Array()
var _cum_total: float = 0.0

func _ready() -> void:
	_build_cumulative()

func _build_cumulative() -> void:
	_cum_keys.clear()
	_cum_vals = PackedFloat64Array()
	var acc := 0.0
	for r in WEIGHTS.keys():
		acc += WEIGHTS[r]
		_cum_keys.append(r)
		_cum_vals.append(acc)
	_cum_total = acc

func get_rarity_name(r: int) -> String:
	return NAMES.get(r, "?")

func get_rarity_color(r: int) -> Color:
	return COLORS.get(r, Color.WHITE)

func get_rarity_glow(r: int) -> float:
	return GLOW.get(r, 1.0)

## 등급 표기용 (예: "[SSS]")
func get_rarity_tag(r: int) -> String:
	return "[%s]" % get_rarity_name(r)

## 가중치 기반 무작위 등급 뽑기.
## luck_bonus: 드랍률 증가율(%). 값이 클수록 고등급 가중치가 증폭된다.
func roll_rarity(luck_bonus: float = 0.0) -> int:
	# 운(luck)이 없으면 미리 계산된 누적 테이블로 즉시 판정 (백만 회 롤도 빠름)
	if luck_bonus <= 0.0:
		if _cum_total <= 0.0:
			_build_cumulative()
		var pick0 := randf() * _cum_total
		for i in range(_cum_vals.size()):
			if pick0 <= _cum_vals[i]:
				return _cum_keys[i]
		return Rarity.F

	var mult := 1.0 + maxf(0.0, luck_bonus) / 100.0
	var table := {}
	var total := 0.0
	for r in WEIGHTS.keys():
		# 낮은 등급(F=0)은 그대로, 높은 등급일수록 luck 배율을 크게 적용
		var tier_scale: float = pow(mult, float(r) * 0.5)
		var w: float = WEIGHTS[r] * tier_scale
		table[r] = w
		total += w

	var pick := randf() * total
	var acc := 0.0
	for r in table.keys():
		acc += table[r]
		if pick <= acc:
			return r
	return Rarity.F

## 확률 테이블 확인용 (디버그)
func debug_probabilities(luck_bonus: float = 0.0) -> Dictionary:
	var mult := 1.0 + maxf(0.0, luck_bonus) / 100.0
	var table := {}
	var total := 0.0
	for r in WEIGHTS.keys():
		var w: float = WEIGHTS[r] * pow(mult, float(r) * 0.5)
		table[r] = w
		total += w
	var out := {}
	for r in table.keys():
		out[get_rarity_name(r)] = table[r] / total * 100.0
	return out
