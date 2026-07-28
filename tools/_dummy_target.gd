extends CharacterBody3D
## 검증용 가짜 적. Enemy3D 를 통째로 띄우지 않고
## 화살이 보는 최소 조건(dead 플래그 · take_damage · contact_damage)만 갖춘다.
## verify_content.gd 에서만 쓴다.

var dead := false
var hits := 0
var total := 0.0
var contact_damage := 10.0
var enemy_type := "ice_wisp"   ## 장판 정의를 가진 몹으로 위장한다
var hp := 999.0
var max_hp := 999.0

func take_damage(amount: float, _knockback = null) -> bool:
	hits += 1
	total += amount
	return false
