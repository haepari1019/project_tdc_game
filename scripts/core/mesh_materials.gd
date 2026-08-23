extends RefCounted
## **메시의 인스턴스 전용 머티리얼 해석** — 절차 생성 메시와 임포트(glTF/.blend) 메시가
## 머티리얼을 다른 자리에 두기 때문에 필요한 어댑터.
##
## 절차 메시는 코드가 `material_override`에 직접 꽂는다. 임포트 메시는 그 자리가 **비어 있고**
## 머티리얼이 mesh 리소스의 surface에 붙어 있다(그리고 `.tres`/씬 사이에서 **공유**된다).
## 그래서 `material_override is StandardMaterial3D`만 보던 코드는 임포트 메시를 통째로
## 건너뛴다 — 경고 한 줄 없이. F-011 안개(`next_pass`)와 벽 X-ray(알파 페이드)가 둘 다
## 그 조건을 쓰고 있었다.
##
## 여기서는 **인스턴스 전용**으로 만들어 돌려준다: surface 머티리얼은 공유 리소스이므로
## 그대로 건드리면 같은 머티리얼을 쓰는 다른 벽까지 같이 투명해진다 → `duplicate()` 후
## `set_surface_override_material()`로 이 인스턴스에만 묶는다(한 번만 — 이미 있으면 재사용).
##
## ref: docs/design/map_upgrade_plan.html §Phase 0 「조용히 깨지는 4곳」 ①③

## 이 메시에 안전하게 쓰기 가능한 `BaseMaterial3D` 목록.
## `material_override`가 있으면 그것 하나(절차 경로), 없으면 surface별 인스턴스 오버라이드.
## 빈 배열 = 손댈 수 있는 머티리얼이 없다(셰이더 전용 머티리얼 등).
static func editable_materials(mi: MeshInstance3D) -> Array:
	var out: Array = []
	if mi == null:
		return out
	if mi.material_override is BaseMaterial3D:
		out.append(mi.material_override as BaseMaterial3D)
		return out
	if mi.mesh == null:
		return out
	for i in mi.mesh.get_surface_count():
		var cur: Material = mi.get_surface_override_material(i)
		if cur == null:
			var active: Material = mi.get_active_material(i)
			if active is BaseMaterial3D:
				cur = (active as BaseMaterial3D).duplicate()   # 공유 리소스를 인스턴스 전용으로
				mi.set_surface_override_material(i, cur)
		if cur is BaseMaterial3D:
			out.append(cur as BaseMaterial3D)
	return out


## 콜라이더에서 짝이 되는 메시 찾기 — **계층이 구현마다 뒤집힌다.**
## 절차: StaticBody3D(부모) → MeshInstance3D(자식).
## 임포트(Godot `-col` 힌트): MeshInstance3D(부모) → StaticBody3D(자식).
## 둘 다 보지 않으면 X-ray가 임포트 맵에서 **영구히 아무것도 안 한다**(에러도 안 난다).
static func mesh_of_collider(collider: Object) -> MeshInstance3D:
	if collider == null or not (collider is Node):
		return null
	var n := collider as Node
	for c in n.get_children():
		if c is MeshInstance3D:
			return c as MeshInstance3D
	var p := n.get_parent()
	if p is MeshInstance3D:
		return p as MeshInstance3D
	return null
