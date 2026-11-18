extends RefCounted

const PAINT = preload("res://assets/models/character_paint.gdshader")
const OUTLINE = preload("res://assets/models/character_outline.gdshader")
static var _palette: Dictionary = {}
static var _ink: ShaderMaterial


static func apply(model: Node3D) -> void:
	if _ink == null:
		_ink = ShaderMaterial.new()
		_ink.shader = OUTLINE
	for item in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := item as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for i in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(i) as StandardMaterial3D
			if source == null:
				continue
			if not _palette.has(source):
				var material := ShaderMaterial.new()
				material.shader = PAINT
				material.set_shader_parameter("base_color", source.albedo_color)
				if source.albedo_texture != null:
					material.set_shader_parameter("grain", source.albedo_texture)
				material.next_pass = _ink
				_palette[source] = material
			mesh_instance.set_surface_override_material(i, _palette[source])
