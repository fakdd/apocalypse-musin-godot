extends Node
## 재질 공유 캐시.
##
## 문제였던 것:
##   적 1기가 생성될 때마다 flash_mat(StandardMaterial3D)을 새로 만들었다.
##   재질은 리소스이고 셰이더 파라미터 세트를 들고 있어서, 같은 값의 재질이 N개면
##   메모리도 낭비되고 렌더러가 배칭할 수 없어 드로우콜 상태 전환도 늘어난다.
##   VFX(검기·기탄·데미지 폭발)도 매번 새 재질을 만들고 있었다.
##
## 여기서 만든 재질은 **공유되므로 절대 런타임에 값을 바꾸면 안 된다.**
## 알파 페이드처럼 개별 애니메이션이 필요한 재질은 `unshaded_fade()` 로 사본을 받아 쓴다.

var _cache := {}

## 적 피격 1단계 — 순백 플래시
func enemy_flash() -> StandardMaterial3D:
	return _cached("enemy_flash", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(4, 4, 4)
		m.emission_enabled = true
		m.emission = Color(1, 1, 1)
		m.emission_energy_multiplier = 4.0
		return m)

## 적 피격 2단계 — 붉은 잔상
func enemy_hurt() -> StandardMaterial3D:
	return _cached("enemy_hurt", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.6, 0.25, 0.2)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.12, 0.08)
		m.emission_energy_multiplier = 2.2
		return m)

## 플레이어 피격 플래시
func player_flash() -> StandardMaterial3D:
	return _cached("player_flash", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.35, 0.35)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.2, 0.2)
		m.emission_energy_multiplier = 1.5
		return m)

## 발광 눈알 — 모든 적이 같은 재질을 쓴다
func glow_eye() -> StandardMaterial3D:
	return _cached("glow_eye", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.15, 0.1)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.1, 0.06)
		m.emission_energy_multiplier = 9.0
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return m)

## 적 기탄 — 모든 기탄이 공유한다
func projectile() -> StandardMaterial3D:
	return _cached("projectile", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.28, 0.2)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = Color(1.0, 0.2, 0.12)
		m.emission_energy_multiplier = 6.0
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return m)

## 알파가 애니메이션되는 VFX용 — 매번 **새 사본**을 반환한다.
## (공유 재질의 알파를 트윈하면 화면의 모든 같은 VFX가 함께 사라져 버린다)
func unshaded_fade(color: Color, glow: float, cull_disabled: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = glow
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if cull_disabled:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## 이름으로 캐시된 재질을 얻는다. 없으면 factory 로 만들어 저장한다.
func _cached(key: String, factory: Callable) -> StandardMaterial3D:
	if not _cache.has(key):
		_cache[key] = factory.call()
	return _cache[key]

## 캐시된 재질 개수 (성능 보고용)
func cached_count() -> int:
	return _cache.size()
