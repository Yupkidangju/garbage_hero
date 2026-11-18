extends Node3D

signal cue(kind: String)
signal announcement(message: String)
signal save_failed(retry: Callable)

const SPECIES := [5, 6, 5, 6, 5, 6]
const POPULATION := [10, 14, 18, 24]
# 지역마다 앞줄의 방어·근접형과 뒤에서 지원하는 원거리·회복형을 짝짓는다.
const PARTNERS := [Vector2i(3, 1), Vector2i(3, 1), Vector2i(2, 3), Vector2i(4, 1), Vector2i(2, 4), Vector2i(2, 3)]
const QUALITY_COLORS := ["beb4a1", "fae7b6", "99dd92", "86dce5", "b59ef3", "ffc06a", "ff92b0"]

var session
var world
var hero
var region: int
var difficulty: int
var enemies: Array = []
var vacant_at: Array[float] = []
var spawn_counter := 0
var field_id := ""
var elapsed := 0.0
var spawn_clock := 0.0
var rest_clock := 0.0
var candidates: Array[Vector3] = []
var marker: Node3D
var boss
var boss_key := ""
var boss_due := 0.0
var loot_nodes := {}
var loot_retry_at := {}
var state := {}
var halted := false
var pending_kills: Array[Dictionary] = []
var loot_mesh := PrismMesh.new()
var loot_materials: Array[StandardMaterial3D] = []
var enemy_script: Script

func initialize(store, landscape, player, theme: int, rank: int) -> void:
	session = store
	world = landscape
	hero = player
	region = theme
	difficulty = rank
	field_id = Crypto.new().generate_random_bytes(12).hex_encode()
	candidates = world.spawn_points()
	enemy_script = load("res://scripts/enemy.gd")
	loot_mesh.size = Vector3(0.22, 0.42, 0.14)
	for color in QUALITY_COLORS:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(color)
		material.emission_enabled = true
		material.emission = Color(color)
		material.emission_energy_multiplier = 0.45
		loot_materials.append(material)
	enemies.resize(POPULATION[rank])
	vacant_at.resize(enemies.size())
	session.changed.connect(sync)
	sync()
	_fill_slots()

func sync() -> void:
	state = session.world_state(region, difficulty)
	var key := str(state.get("spawn_id", ""))
	if key != boss_key:
		boss_key = key
		if is_instance_valid(marker):
			marker.queue_free()
			marker = null
		if not key.is_empty():
			boss_due = elapsed + 2.0
			marker = _summon_marker()
			announcement.emit(tr("FIELD_MINI") if state.phase == "mini" else tr("FIELD_BOSS"))
			cue.emit("warning")
	_sync_loot()

func _physics_process(delta: float) -> void:
	if halted or state.is_empty() or not is_instance_valid(hero):
		return
	elapsed += delta
	spawn_clock -= delta
	if spawn_clock <= 0.0:
		spawn_clock = 0.25
		_fill_slots()
		_collect_nearby()
	if is_instance_valid(marker):
		marker.rotate_y(delta * 1.5)
		if elapsed >= boss_due:
			marker.queue_free()
			marker = null
			boss = _spawn(str(state.phase), 0, boss_key, world.boss_point(), -1)
	if state.phase == "rest":
		rest_clock += delta
		if rest_clock >= 1.0:
			rest_clock -= 1.0
			if not session.tick_rest(region, difficulty, 1):
				halted = true
				save_failed.emit(_retry_rest)
	else:
		rest_clock = 0

func _retry_rest() -> bool:
	halted = not session.tick_rest(region, difficulty, 1)
	return not halted and _drain_kills()

func _fill_slots() -> void:
	if candidates.is_empty():
		return
	for slot in enemies.size():
		if is_instance_valid(enemies[slot]) or elapsed < vacant_at[slot]:
			continue
		var chosen := Vector3.INF
		var distance := INF
		var partner
		var index := spawn_counter % int(SPECIES[region])
		if difficulty > 0 and slot % 7 <= 1:
			var first := slot % 7 == 0
			var mate := slot + 1 if first else slot - 1
			if mate < enemies.size():
				partner = enemies[mate]
				index = PARTNERS[region].x if first else PARTNERS[region].y
		for offset in candidates.size():
			var pos := candidates[(slot * 7 + spawn_counter * 3 + offset) % candidates.size()]
			if pos.distance_squared_to(hero.global_position) < 64 or pos.distance_squared_to(world.entry_point()) < 20:
				continue
			var clear := true
			for other in enemies:
				if is_instance_valid(other) and pos.distance_squared_to(other.position) < 2.25:
					clear = false
					break
			if clear:
				if not is_instance_valid(partner):
					chosen = pos
					break
				var score := pos.distance_squared_to(partner.position)
				if score < distance:
					distance = score
					chosen = pos
		if chosen.is_finite():
			spawn_counter += 1
			enemies[slot] = _spawn("normal", index, field_id + "-" + str(spawn_counter), chosen, slot)

func _spawn(kind: String, index: int, id: String, pos: Vector3, slot: int):
	var enemy = enemy_script.new()
	enemy.name = "Monster_" + str(spawn_counter) if slot >= 0 else "Guardian"
	enemy.position = pos
	enemy.set_meta("safe_point", world.entry_point())
	enemy.setup(region, difficulty, kind, index, id)
	enemy.defeated.connect(_defeated.bind(slot))
	enemy.cue.connect(func(sound: String): cue.emit(sound))
	add_child(enemy, true)
	return enemy

func _defeated(kind: String, id: String, pos: Vector3, slot: int) -> void:
	if slot >= 0:
		enemies[slot] = null
		vacant_at[slot] = elapsed + 10.0
	else:
		boss = null
	pending_kills.append({"kind": kind, "id": id, "pos": pos})
	if not halted and not _drain_kills():
		save_failed.emit(_drain_kills)

func _drain_kills() -> bool:
	while not pending_kills.is_empty():
		var event := pending_kills[0]
		if not session.record_kill(region, difficulty, event.kind, event.id, event.pos):
			halted = true
			return false
		pending_kills.pop_front()
	halted = false
	return true

func _summon_marker() -> Node3D:
	var ring := MeshInstance3D.new()
	var shape := TorusMesh.new()
	shape.inner_radius = 1.25
	shape.outer_radius = 1.55
	shape.rings = 40
	shape.ring_segments = 6
	ring.mesh = shape
	ring.scale.y = 0.15
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#ffb34c")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = material
	ring.position = world.boss_point() + Vector3.UP * 0.08
	add_child(ring)
	return ring

func _sync_loot() -> void:
	var live := {}
	for item in state.get("drops", []):
		var id := int(item.id)
		live[id] = true
		if loot_nodes.has(id):
			continue
		var grade := clampi(int(item.get("grade", 0)), 0, 6)
		var shard := MeshInstance3D.new()
		shard.mesh = loot_mesh
		shard.material_override = loot_materials[grade]
		shard.position = item.pos + Vector3.UP * 0.35
		shard.rotation.z = 0.3
		var label := Label3D.new()
		label.font = preload("res://assets/fonts/NotoSansKR.ttf")
		label.text = "%s · %s" % [item.grade_name, item.get("name", tr("FIELD_LOOT"))]
		label.font_size = 22
		label.pixel_size = 0.004
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(QUALITY_COLORS[grade])
		label.position.y = 0.37
		shard.add_child(label)
		add_child(shard)
		loot_nodes[id] = shard
	for id in loot_nodes.keys():
		if not live.has(id):
			loot_nodes[id].queue_free()
			loot_nodes.erase(id)
			loot_retry_at.erase(id)

func _collect_nearby() -> void:
	for id in loot_nodes.keys():
		var shard = loot_nodes[id]
		if elapsed < float(loot_retry_at.get(id, 0)):
			continue
		var gap: Vector3 = shard.position - hero.position
		if Vector2(gap.x, gap.z).length_squared() <= 2.25:
			if session.pickup(id):
				cue.emit("pickup")
			else:
				loot_retry_at[id] = elapsed + 3.0

func guardian_info() -> Dictionary:
	if is_instance_valid(boss):
		return {"name": boss.display_name, "hp": boss.hp, "max_hp": boss.max_hp}
	return {}
