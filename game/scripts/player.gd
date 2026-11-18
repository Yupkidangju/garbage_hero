extends CharacterBody3D

signal died
signal health_changed(current: int, maximum: int)
signal cue(kind: String)

const MoveBook = preload("res://data/combat_moves.gd")
const CombatFX = preload("res://scripts/combat_fx.gd")
const CharacterInk = preload("res://scripts/character_ink.gd")
const HERO_PATH := "res://assets/models/hero.glb"
const MAX_HP := 100
const SPEED := 5.0
const SCREEN_RIGHT := Vector3(0.70710678, 0.0, -0.70710678)
const SCREEN_DOWN := Vector3(0.70710678, 0.0, 0.70710678)

var hp := MAX_HP
var max_hp := MAX_HP
var facing := Vector3(0.2, 0.0, 0.98).normalized()
var _power := 10
var _critical := 3
var _grade := 0
var _spin_unlocked := false
var _slam_unlocked := false
var _timers := {"dodge":0.0, "hook":0.0, "spin":0.0, "slam":0.0}

var _move := ""
var _spec: Dictionary = {}
var _frame := 0
var _chain := false
var _hit_ids := {}
var _dodge_safe := false
var _hurt_lock := 0.0
var _hurt_grace := 0.0
var _death_time := 0.0
var _pointer_aim := false
var _wait_for_release := false
var _keyboard_aim := false
var _rng := RandomNumberGenerator.new()

var _pivot := Node3D.new()
var _camera := Camera3D.new()
var _fx := CombatFX.new()
var _skeleton: Skeleton3D
var _base_bone := -1
var _tip_bone := -1
var _grade_nodes: Array[Node3D] = []
var _tree: AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var _clips := {}
var _clip_speed := 1.0
var _hitstop := 0
var _hold_impact_pose := false
var _shake := 0.0
var _shake_age := 0.0
var _shake_enabled := true


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.35
	var body_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.52
	capsule.radius = 0.34
	body_shape.shape = capsule
	body_shape.position.y = capsule.height * 0.5
	add_child(body_shape)
	_pivot.name = "Facing"
	add_child(_pivot)
	_turn_to(facing)
	var shadow := MeshInstance3D.new()
	var shadow_plane := PlaneMesh.new()
	shadow_plane.size = Vector2(0.88, 0.60)
	shadow.mesh = shadow_plane
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = preload("res://assets/models/foot_shadow.gdshader")
	shadow_material.render_priority = -6
	shadow.material_override = shadow_material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position.y = 0.053
	_pivot.add_child(shadow)
	_install_art()
	_camera.name = "FieldCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 15.0
	_camera.near = 0.12
	_camera.far = 100.0
	add_child(_camera)
	var axis := SCREEN_DOWN*cos(deg_to_rad(38.0)) + Vector3.UP*sin(deg_to_rad(38.0))
	_camera.position = Vector3.UP*0.65 + axis*24.0
	_camera.basis = Basis.looking_at(-axis)
	_camera.current = true
	_fx.name = "AttackEffects"
	_fx.top_level = true
	add_child(_fx)
	_fx.global_transform = Transform3D.IDENTITY
	health_changed.emit(hp, MAX_HP)


func configure(gear: Dictionary, first_merge: bool, forest_clear: bool) -> void:
	_power = maxi(1, int(gear.get("atk", 4)))
	_critical = clampi(int(gear.get("crit", 0)), 0, 100)
	var next_grade := int(gear.get("grade", -1))
	if next_grade != _grade:
		_grade = next_grade
		_update_gear_mesh()
		if _grade < 5:
			_fx.enchanted_blade(_grade, Vector3.ZERO, Vector3.ZERO)
	_spin_unlocked = first_merge
	_slam_unlocked = forest_clear


func set_feedback(shake_enabled: bool, reduced_flash: bool) -> void:
	_shake_enabled = shake_enabled
	_fx.reduced_flash = reduced_flash


func cooldowns() -> Dictionary:
	return _timers.duplicate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_UNPAUSED:
		_wait_for_release = Input.is_action_pressed("attack")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.relative.length_squared() > 0.1:
			_pointer_aim = true
			_keyboard_aim = false
	elif event.is_action_pressed("attack"):
		_pointer_aim = event is InputEventMouseButton
		_keyboard_aim = not _pointer_aim


func _physics_process(delta: float) -> void:
	for key in _timers:
		_timers[key] = maxf(0.0, float(_timers[key])-delta)
	_hurt_grace = maxf(0.0, _hurt_grace-delta)
	_dodge_safe = false
	if _wait_for_release and not Input.is_action_pressed("attack"):
		_wait_for_release = false
	var motion := Vector3.ZERO
	if hp <= 0:
		_death_time -= delta
		if _death_time <= 0:
			set_physics_process(false)
			died.emit()
			return
	elif _hurt_lock > 0.0:
		_hurt_lock -= delta
		if _hurt_lock <= 0.0:
			_play("Locomotion")
	else:
		var stick := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var walk := SCREEN_RIGHT*stick.x + SCREEN_DOWN*stick.y
		var pressed := Input.is_action_just_pressed("attack") and not _wait_for_release
		_handle_controls(walk, pressed)
		if _move.is_empty():
			motion = walk * SPEED
			var aim := _aim(walk)
			if not aim.is_zero_approx():
				_turn_to(facing.slerp(aim, 1.0-exp(-22.0*delta)) if facing.dot(aim)>-0.98 else aim)
		else:
			motion = _tick_move(delta)
		if _tree != null:
			_tree.set("parameters/Locomotion/blend_position", minf(1.0, motion.length()/SPEED))
	velocity.x = motion.x
	velocity.z = motion.z
	velocity.y = minf(0.0, velocity.y) if is_on_floor() else maxf(-30.0, velocity.y-22.0*delta)
	move_and_slide()
	_animate(delta)
	if (_fx.ribbon_live or _grade >= 5) and _base_bone >= 0 and _tip_bone >= 0:
		var base := _bone_world(_base_bone)
		var tip := _bone_world(_tip_bone)
		_fx.blade_sample(base, tip)
		_fx.enchanted_blade(_grade, base, tip)
	if not _move.is_empty():
		_frame += 1
		if _frame >= int(_spec.windup)+int(_spec.active)+int(_spec.recovery):
			_finish_move()


func _handle_controls(walk: Vector3, attack_pressed: bool) -> void:
	var dodge_pressed: bool = Input.is_action_just_pressed("dodge") and _timers.dodge <= 0.0
	if _move.is_empty():
		if dodge_pressed:
			_start_move("dodge", walk.normalized() if not walk.is_zero_approx() else facing)
			return
		for skill in ["hook", "spin", "slam"]:
			if skill == "spin" and not _spin_unlocked or skill == "slam" and not _slam_unlocked:
				continue
			if Input.is_action_just_pressed(skill) and _timers[skill] <= 0.0:
				_start_move(skill, _aim(facing))
				return
		if attack_pressed:
			_start_move("attack1", _aim(facing))
	elif _move.begins_with("attack"):
		var remaining := int(_spec.windup)+int(_spec.active)+int(_spec.recovery)-_frame
		if remaining <= 6 and dodge_pressed:
			_fx.interrupt()
			_start_move("dodge", walk.normalized() if not walk.is_zero_approx() else facing)
		elif remaining <= 8 and attack_pressed and _move != "attack3":
			_chain = true


func _aim(fallback: Vector3) -> Vector3:
	if not _pointer_aim or _keyboard_aim:
		return fallback
	var mouse := get_viewport().get_mouse_position()
	var start := _camera.project_ray_origin(mouse)
	var ray := _camera.project_ray_normal(mouse)
	var query := PhysicsRayQueryParameters3D.create(start, start+ray*80.0, 4)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var ground: Variant = Plane(Vector3.UP, global_position.y).intersects_ray(start, ray)
	if not hit.is_empty() and hit.collider is Node3D and hit.collider.is_in_group("enemies"):
		ground = hit.collider.global_position
	if ground is Vector3:
		var toward: Vector3 = ground-global_position
		toward.y = 0.0
		if toward.length_squared() > 0.02:
			return toward.normalized()
	return fallback


func _turn_to(direction: Vector3) -> void:
	if direction.is_zero_approx():
		return
	facing = direction.normalized()
	_pivot.rotation.y = atan2(-facing.x, -facing.z)


func _start_move(action: String, direction: Vector3) -> void:
	_move = action
	_spec = MoveBook.MOVES[action]
	_frame = 0
	_chain = false
	_hit_ids.clear()
	_turn_to(direction)
	if _spec.has("cooldown"):
		_timers[action] = _spec.cooldown
	_play(_spec.clip, (float(_spec.windup)+float(_spec.active)+float(_spec.recovery))/60.0)
	if action == "dodge":
		cue.emit("dodge")


func _tick_move(delta: float) -> Vector3:
	var tick := _frame - int(_spec.windup)
	if tick < 0:
		return Vector3.ZERO
	if tick >= int(_spec.active):
		_fx.end_ribbon()
		if _move == "dodge" and tick == int(_spec.active):
			_fx.dust(global_position, -facing)
		return Vector3.ZERO
	match _move:
		"dodge":
			_dodge_safe = true
			if tick == 0:
				_fx.dust(global_position, -facing)
			return facing * float(_spec.distance)/(float(_spec.active)*delta)
		"hook":
			if tick == 0:
				_hook()
		"spin":
			if tick == 0 or tick == 9:
				_hit_ids.clear()
				_fx.begin_ribbon()
				_fx.spin(global_position, facing, tick/9)
				cue.emit("spin")
				_sector_hits()
		_:
			if tick == 0:
				_fx.begin_ribbon()
				if _move == "slam":
					_fx.slam(global_position, facing)
					cue.emit("slam")
				else:
					var step := _move.right(1).to_int()
					_fx.strike(global_position, facing, step, _spec.range)
					cue.emit("swing%d" % step)
			_sector_hits()
	return Vector3.ZERO


func _finish_move() -> void:
	var next := ""
	if _chain:
		next = "attack2" if _move == "attack1" else "attack3"
	_move = ""
	_chain = false
	_fx.end_ribbon()
	if next.is_empty():
		_play("Locomotion")
	else:
		_start_move(next, _aim(facing))


func _target_radius(enemy: Node3D) -> float:
	return maxf(0.0, float(enemy.get("hit_radius")))


func _sector_hits() -> void:
	var radius := float(_spec.range)
	var half_angle := deg_to_rad(float(_spec.angle)*0.5)
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as Node3D
		if enemy == null or enemy.is_queued_for_deletion() or _hit_ids.has(enemy.get_instance_id()):
			continue
		var offset := enemy.global_position-global_position
		if absf(offset.y)>1.8:
			continue
		offset.y = 0.0
		var body_radius := _target_radius(enemy)
		if offset.length() > radius+body_radius:
			continue
		if half_angle < PI-0.001 and not offset.is_zero_approx():
			var angle := facing.signed_angle_to(offset.normalized(), Vector3.UP)
			if absf(angle) > half_angle:
				var boundary := facing.rotated(Vector3.UP, signf(angle)*half_angle)
				var nearest := boundary*clampf(offset.dot(boundary), 0.0, radius)
				if nearest.distance_squared_to(offset)>body_radius*body_radius:
					continue
		if not _has_clear_path(enemy):
			continue
		_hit(enemy, Vector3.ZERO)


func _has_clear_path(enemy: Node3D) -> bool:
	var height := Vector3.UP * 0.65
	var query := PhysicsRayQueryParameters3D.create(global_position+height, enemy.global_position+height, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _hook() -> void:
	var reach := float(_spec.range)
	var origin := global_position + Vector3.UP * 0.72
	var wall_query := PhysicsRayQueryParameters3D.create(origin, origin+facing*reach, 1)
	var wall := get_world_3d().direct_space_state.intersect_ray(wall_query)
	if not wall.is_empty():
		reach = origin.distance_to(wall.position)
	var closest: Node3D
	var travel := reach
	for body in get_tree().get_nodes_in_group("enemies"):
		var enemy := body as Node3D
		if enemy == null or enemy.is_queued_for_deletion():
			continue
		var offset := enemy.global_position-global_position
		if absf(offset.y)>1.8:
			continue
		offset.y = 0.0
		var along := offset.dot(facing)
		var radius := float(_spec.width)*0.5 + _target_radius(enemy)
		var lateral := (offset-facing*along).length_squared()
		if along < 0 or lateral>radius*radius:
			continue
		var contact := maxf(0.0, along-sqrt(maxf(0.0, radius*radius-lateral)))
		if contact <= travel and _has_clear_path(enemy):
			closest = enemy
			travel = contact
	cue.emit("hook")
	_fx.hook(origin, facing, minf(travel + (0.28 if closest != null else 0.0), reach))
	if closest != null:
		var pull := Vector3.ZERO
		if str(closest.get("kind")) == "normal":
			var offset := global_position-closest.global_position
			offset.y = 0.0
			pull = offset.normalized()*clampf(offset.length()-0.9,0.0,2.0)
		_hit(closest, pull)


func _hit(enemy: Node3D, pull: Vector3) -> void:
	_hit_ids[enemy.get_instance_id()] = true
	var critical := _rng.randf()*100.0 < _critical
	var damage := maxi(1, roundi(_power*float(_spec.power)*(1.5 if critical else 1.0)))
	var at := enemy.global_position + Vector3.UP*clampf(_target_radius(enemy)*1.4,0.55,1.55)
	var result: Variant = enemy.call("take_hit", damage, pull)
	if result is int:
		damage = result
	if damage <= 0:
		return
	cue.emit("hit")
	_fx.impact(at, facing, damage, critical)
	if _move in ["slam", "attack3"]:
		_hold_impact_pose = true
		_shake = maxf(_shake, 0.10 if _move == "slam" else 0.05)


func take_damage(amount: int) -> bool:
	if hp <= 0 or amount <= 0 or _dodge_safe or _hurt_grace > 0.0:
		return false
	hp = maxi(0, hp-amount)
	_move = ""
	_chain = false
	_hitstop = 0
	_hold_impact_pose = false
	_fx.interrupt()
	_fx.impact(global_position+Vector3.UP, -facing, amount, false, true)
	health_changed.emit(hp, MAX_HP)
	_shake = 0.08
	if hp <= 0:
		_death_time = 0.62
		_play("Death", _death_time)
		cue.emit("death")
	else:
		_hurt_grace = 0.48
		_hurt_lock = 0.17
		_play("Hit", _hurt_lock)
		cue.emit("hurt")
	return true


func apply_knockback(displacement: Vector3) -> void:
	if hp > 0 and not _dodge_safe:
		move_and_collide(Vector3(displacement.x, 0.0, displacement.z))


func _install_art() -> void:
	if not ResourceLoader.exists(HERO_PATH):
		push_warning("Hero model is missing: " + HERO_PATH)
		return
	var packed := load(HERO_PATH) as PackedScene
	if packed == null:
		return
	var model := packed.instantiate() as Node3D
	_pivot.add_child(model)
	CharacterInk.apply(model)
	for item in model.find_children("*", "Node3D", true, false):
		if str(item.name).begins_with("Grade") or str(item.name).begins_with("WeaponBase"):
			_grade_nodes.append(item)
	_update_gear_mesh()
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_skeleton = skeletons[0]
		_base_bone = _skeleton.find_bone("SwordBase")
		_tip_bone = _skeleton.find_bone("SwordTip")
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_install_animations(players[0])


func _update_gear_mesh() -> void:
	for item in _grade_nodes:
		var label := str(item.name)
		var rank := label.substr(5,1).to_int() if label.begins_with("Grade") else 0
		item.visible = _grade >= rank


func _install_animations(player: AnimationPlayer) -> void:
	var machine := AnimationNodeStateMachine.new()
	var locomotion := AnimationNodeBlendSpace1D.new()
	locomotion.min_space = 0.0
	locomotion.max_space = 1.0
	for name_key in player.get_animation_list():
		var clip := str(name_key).get_slice("|",str(name_key).count("|")).get_file()
		if clip not in ["Idle","Run","Dodge","Attack1","Attack2","Attack3","Hook","Spin","Slam","Hit","Death"]:
			continue
		var animation := player.get_animation(name_key)
		_clips[clip] = animation.length
		var node := AnimationNodeAnimation.new()
		node.animation = name_key
		if clip == "Idle" or clip == "Run":
			animation.loop_mode = Animation.LOOP_LINEAR
			locomotion.add_blend_point(node, 0.0 if clip == "Idle" else 1.0, -1, clip)
		else:
			machine.add_node(clip, node)
	machine.add_node("Locomotion", locomotion)
	_tree = AnimationTree.new()
	_tree.name = "HeroAnimationTree"
	_tree.tree_root = machine
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_pivot.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(player)
	_tree.root_node = _tree.get_path_to(player.get_node(player.root_node))
	_tree.active = true
	_playback = _tree.get("parameters/playback")
	_play("Locomotion")
	_tree.advance(0)


func _play(clip: String, duration := 0.0) -> void:
	if _playback == null or (clip != "Locomotion" and not _clips.has(clip)):
		return
	_playback.start(clip, true)
	_clip_speed = float(_clips.get(clip, 1.0))/duration if duration > 0.0 else 1.0


func _animate(delta: float) -> void:
	if _hold_impact_pose:
		if _tree != null:
			_tree.advance(delta*_clip_speed)
		_hitstop = 3
		_hold_impact_pose = false
	elif _hitstop > 0:
		_hitstop -= 1
	elif _tree != null:
		_tree.advance(delta*_clip_speed)
	_shake_age += delta
	_shake = maxf(0.0, _shake-delta*0.62)
	_camera.h_offset = sin(_shake_age*95.0)*_shake if _shake_enabled else 0.0
	_camera.v_offset = cos(_shake_age*77.0)*_shake*0.52 if _shake_enabled else 0.0


func _bone_world(index: int) -> Vector3:
	return _skeleton.to_global(_skeleton.get_bone_global_pose(index).origin)
