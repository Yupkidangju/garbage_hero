extends RefCounted

const CharacterInk = preload("res://scripts/character_ink.gd")
static var _models: Dictionary = {}
var _skeleton: Skeleton3D
var _sockets: Dictionary = {}
var _signatures: Dictionary = {}
var weapon_length := 1.04


func install(skeleton: Skeleton3D) -> void:
	_skeleton = skeleton


func refresh(weapon: Dictionary, equipment: Dictionary, has_shield: bool) -> Dictionary:
	if not is_instance_valid(_skeleton):
		return {}
	var active := {}
	active.weapon = _attach("weapon",weapon,"WeaponGrip",Transform3D.IDENTITY,true)
	active.armor = _attach("armor",equipment.get("armor",{}),"Chest",Transform3D(Basis.IDENTITY,Vector3(0,1.065,0.0)))
	active.helmet = _attach("helmet",equipment.get("helmet",{}),"Head",Transform3D(Basis.IDENTITY,Vector3(0,1.595,0.015)))
	active.shield = _attach("shield",equipment.get("shield",{}) if has_shield else {},"Hand.L",Transform3D(Basis(Vector3.UP,-PI*0.5),Vector3(0.39,0.86,0.07)))
	var boots: Dictionary = equipment.get("boots",{})
	active.boots = _attach("boots_left",boots,"Foot.L",Transform3D(Basis.IDENTITY,Vector3(0.124,0.13,-0.055)))
	_attach("boots_right",boots,"Foot.R",Transform3D(Basis.IDENTITY,Vector3(-0.124,0.13,-0.055)))
	active.ring = _attach("ring",equipment.get("ring",{}),"Hand.R",Transform3D(Basis.IDENTITY,Vector3(-0.34,0.765,0.075)))
	active.necklace = _attach("necklace",equipment.get("necklace",{}),"Chest",Transform3D(Basis.IDENTITY,Vector3(0,1.155,-0.165)))
	return active


func _clear(slot: String) -> void:
	if _sockets.has(slot):
		var socket: Node3D = _sockets[slot]
		_skeleton.remove_child(socket)
		socket.queue_free()
		_sockets.erase(slot)
	_signatures.erase(slot)


func _attach(slot: String, item: Dictionary, bone: String, rest: Transform3D, weapon := false) -> bool:
	var design := int(item.get("design",-1))
	if design < 0 or _skeleton.find_bone(bone) < 0:
		_clear(slot)
		return false
	var signature := Vector2i(design,int(item.get("grade",0)))
	if _signatures.get(slot,Vector2i(-1,-1)) == signature:
		return true
	_clear(slot)
	var path := "res://assets/models/items/item_%03d.glb" % design
	if not ResourceLoader.exists(path):
		return false
	if not _models.has(design):
		_models[design] = load(path) as PackedScene
	var packed := _models[design] as PackedScene
	if packed == null:
		return false
	var model := packed.instantiate() as Node3D
	if model == null:
		return false
	var socket := BoneAttachment3D.new()
	socket.name = "ItemSlot_"+slot
	socket.bone_name = bone
	socket.set_meta("design",design)
	_skeleton.add_child(socket)
	socket.add_child(model)
	model.name = "Item_%03d" % design
	var bone_rest := _skeleton.get_bone_global_rest(_skeleton.find_bone(bone))
	if weapon:
		var axis := (_skeleton.get_bone_global_rest(_skeleton.find_bone("SwordTip")).origin-bone_rest.origin).normalized()
		var width := (Vector3.UP-axis*axis.dot(Vector3.UP)).normalized()
		var orientation := Basis(width,axis,width.cross(axis)).orthonormalized()
		if str(item.get("weapon_type","")) == "bow":
			orientation = Basis(Vector3.UP,PI*0.5)
		model.transform = Transform3D(bone_rest.basis.inverse()*orientation,Vector3.ZERO)
	else:
		model.transform = bone_rest.affine_inverse()*rest
	var bounds := _bounds(model,Transform3D.IDENTITY)
	if slot == "ring" or slot == "necklace":
		var wanted := 0.052 if slot == "ring" else 0.22
		var extent := maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
		if extent > 0.001:
			model.scale *= wanted/extent
	if weapon:
		# 원본 GLB의 실제 끝을 VFX 소켓 길이로 사용한다.
		var native := _bounds(model,model.transform.affine_inverse())
		weapon_length = maxf(0.25,native.end.y)
	CharacterInk.apply(model)
	_sockets[slot] = socket
	_signatures[slot] = signature
	return true


func _bounds(node: Node3D, parent: Transform3D) -> AABB:
	var transform := parent*node.transform
	var result := AABB()
	var populated := false
	if node is MeshInstance3D and node.mesh != null:
		result = transform*node.mesh.get_aabb()
		populated = true
	for child in node.get_children():
		if child is Node3D:
			var bounds := _bounds(child,transform)
			if bounds.size.length_squared() > 0.000001:
				result = result.merge(bounds) if populated else bounds
				populated = true
	return result
