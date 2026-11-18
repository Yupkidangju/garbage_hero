extends Control

const S = preload("res://scripts/hud_style.gd")
const Text = preload("res://data/map_ko.tres")
const Height = preload("res://scripts/world/height.gd")
const PALETTES := ["7b9177","729377","ab915e","83918b","6f958b","94a9b0","977b6a"]
const PAPER := Color("#e7d5a8")
const ROAD := Color("#f1deb3")
const INK := Color("#273d3c")
const WATER := Color("#749ea2")
static var _charts: Dictionary = {}

var map_data: Dictionary = {}
var text_scale := 1.0
var _map_texture: Texture2D
var _font: Font


static func snapshot(world, player, director) -> Dictionary:
	if not is_instance_valid(world) or not is_instance_valid(player):
		return {}
	var data: Dictionary = world.map_data().duplicate()
	if data.is_empty():
		return {}
	var inverse: Transform3D = data.transform.affine_inverse()
	data["region"] = world.region
	data["footprints"] = _footprints(world, data, inverse)
	data["player"] = _flat(inverse * player.global_position)
	data["facing"] = _flat(inverse.basis * player.facing).normalized()
	var points := {}
	var services: Dictionary = world.service_points()
	for key in services:
		if key == "traveler" and not world.traveler_visible:
			continue
		points[key] = _flat(inverse * services[key])
	data["points"] = points
	if is_instance_valid(director) and not str(director.boss_key).is_empty():
		var alive := is_instance_valid(director.boss)
		var pos: Vector3 = director.boss.global_position if alive else world.boss_point()
		var phase: String = director.state.get("phase","boss")
		data["guardian"] = {"pos":_flat(inverse*pos), "phase":phase, "pending":not alive,
			"title":S.t(phase+str(world.region)) if phase in ["mini","boss"] else ""}
	return data


static func _flat(pos: Vector3) -> Vector2:
	return Vector2(pos.x, pos.z)


static func _footprints(world, data: Dictionary, inverse: Transform3D) -> Array:
	var key := Vector2i(data.roads.get_instance_id() & 0x7fffffff, int(world.traveler_visible))
	if world.get_meta("map_footprint_key",Vector2i(-1,-1)) == key:
		return world.get_meta("map_footprints")
	var shapes := []
	var bounds: Rect2 = data.bounds
	var border := PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),
		bounds.end,Vector2(bounds.position.x,bounds.end.y)])
	for node in world.axes.find_children("*","CollisionShape3D",true,false):
		var box := node.shape as BoxShape3D
		if box==null or node.disabled or not node.is_visible_in_tree():
			continue
		if box.size.y<0.4 or maxf(box.size.x,box.size.z)>10:
			continue
		var half := Vector2(box.size.x,box.size.z)*0.5
		var xform: Transform3D = inverse*node.global_transform
		var polygon := PackedVector2Array()
		for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			var p: Vector2 = corner*half
			polygon.append(_flat(xform*Vector3(p.x,0,p.y)))
		for part in Geometry2D.intersect_polygons(polygon,border):
			shapes.append({"polygon":part,"small":maxf(box.size.x,box.size.z)<0.72})
	world.set_meta("map_footprint_key",key)
	world.set_meta("map_footprints",shapes)
	return shapes


func _ready() -> void:
	name = "AreaMap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_font = S.font_weight(get_theme_default_font(), 550)
	if not map_data.is_empty():
		_map_texture = _chart(map_data)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	var narrow := size.x > 0 and size.x < 490.0
	custom_minimum_size.y = 490.0*text_scale if narrow else maxf(390.0,320.0*text_scale)
	queue_redraw()


static func _chart(data: Dictionary) -> Texture2D:
	var region := int(data.region)
	var roads: Texture2D = data.roads
	if _charts.has(region) and _charts[region].source == roads.get_instance_id():
		return _charts[region].texture
	var mask: Image = data.get("road_image")
	if mask == null:
		mask = roads.get_image()
	if mask == null:
		return null
	var mask_size := mask.get_size()
	var bounds: Rect2 = data.bounds
	var extent: Rect2 = data.texture_bounds
	var dimensions := Vector2i((bounds.size*9.0).round())
	var sheet := Image.create_empty(dimensions.x,dimensions.y,false,Image.FORMAT_RGB8)
	var land := Color(PALETTES[region+1])
	var slope_ink := land.darkened(0.27)
	var track_border := land.lerp(Color("#a89a72"),0.72)
	for y in dimensions.y:
		for x in dimensions.x:
			var p := bounds.position+(Vector2(x+0.5,y+0.5)/Vector2(dimensions))*bounds.size
			var uv := (p-extent.position)/extent.size
			var mask_xy := Vector2i(uv*Vector2(mask_size)).clamp(Vector2i.ZERO,mask_size-Vector2i.ONE)
			var road := mask.get_pixelv(mask_xy).r
			var h := Height.sample_height(p,region) if region>=0 else 0.0
			var paper_noise := 0.014*sin(x*2.567+y*13.73)+0.012*cos(x*0.23+y*0.82)
			var tint := land.lightened(clampf(h*0.26+paper_noise,0,1))
			if h>0.055:
				var contour := absf(fposmod(h+0.065,0.13)-0.065)
				tint = tint.lerp(slope_ink,(1.0-smoothstep(0.002,0.012,contour))*0.6)
			tint = tint.lerp(track_border,smoothstep(0.08,0.28,road))
			tint = tint.lerp(ROAD,smoothstep(0.27,0.50,road))
			sheet.set_pixel(x,y,tint)
	var chart := ImageTexture.create_from_image(sheet)
	_charts[region] = {"texture":chart,"source":roads.get_instance_id()}
	return chart


func _draw() -> void:
	if _map_texture == null or map_data.is_empty() or size.x < 1.0:
		return
	var region := int(map_data.region)
	var narrow := size.x < 490.0
	var inset := 8.0
	var legend_width := minf(size.x*0.34, 210.0*text_scale)
	var bounds: Rect2 = map_data.bounds
	var available := Vector2(size.x-2*inset, size.y-2*inset)
	if narrow:
		available.y = size.y*0.5
	else:
		available.x -= legend_width+22.0
	var ratio := minf(available.x/bounds.size.x, available.y/bounds.size.y)
	var chart := Rect2(Vector2(inset,inset)+(available-bounds.size*ratio)*0.5, bounds.size*ratio)
	draw_rect(chart.grow(3), Color("#243536"))
	draw_rect(chart.grow(1), S.BRASS)
	draw_texture_rect(_map_texture,chart,false)
	_draw_terrain(chart)
	_draw_footprints(chart)
	_draw_grid(chart)
	for key in map_data.points:
		_mark(_at(map_data.points[key],chart),key,11.5)
	if map_data.has("guardian"):
		_mark(_at(map_data.guardian.pos,chart), "guardian", 13.5)
	_mark(_at(map_data.player,chart),"you",9.0)
	var right := Vector2(inset,chart.end.y+15) if narrow else Vector2(available.x+23,inset+4)
	_legend(right,region)


func _at(local: Vector2, chart: Rect2) -> Vector2:
	var bounds: Rect2 = map_data.bounds
	return chart.position + (local-bounds.position)/bounds.size*chart.size


func _draw_terrain(chart: Rect2) -> void:
	var stream: PackedVector2Array = map_data.get("stream",PackedVector2Array())
	var bounds: Rect2 = map_data.bounds
	if stream.size()>1:
		# 흐르는 물길은 원 지형과 같은 Catmull–Rom 구간을 따른다.
		var ink := WATER if int(map_data.region) in Height.BRIDGE_REGIONS else Color("#ab9c7c")
		var coords := PackedVector2Array()
		for i in stream.size()-1:
			for k in 12:
				var p := stream[i].cubic_interpolate(stream[i+1],stream[maxi(0,i-1)],stream[mini(stream.size()-1,i+2)],k/12.0)
				if bounds.grow(-1.0).has_point(p):
					coords.append(_at(p,chart))
		if coords.size()>1:
			var width := 1.75*chart.size.x/bounds.size.x
			draw_polyline(coords,ink.darkened(0.22),width+2.1,true)
			draw_polyline(coords,ink,width,true)
	if int(map_data.region) in Height.BRIDGE_REGIONS:
		var mid := _at(_flat(Height.BRIDGE_ORIGIN),chart)
		var arm := Vector2.RIGHT.rotated(-Height.BRIDGE_YAW)*Height.BRIDGE_HALF_LENGTH*chart.size.x/bounds.size.x
		draw_line(mid-arm,mid+arm,INK,7.0,true)
		draw_line(mid-arm,mid+arm,PAPER,4.0,true)


func _draw_grid(chart: Rect2) -> void:
	var bounds: Rect2 = map_data.bounds
	var grid := Color(INK,0.16)
	for x in range(ceili(bounds.position.x/5.0),ceili(bounds.end.x/5.0)):
		var px := _at(Vector2(x*5.0,0),chart).x
		draw_line(Vector2(px,chart.position.y),Vector2(px,chart.end.y),grid,1)
	for y in range(ceili(bounds.position.y/5.0),ceili(bounds.end.y/5.0)):
		var py := _at(Vector2(0,y*5.0),chart).y
		draw_line(Vector2(chart.position.x,py),Vector2(chart.end.x,py),grid,1)
	var px_per_meter := chart.size.x / bounds.size.x
	var start := chart.position + Vector2(9,chart.size.y-10)
	var end := start + Vector2(5*px_per_meter,0)
	draw_line(start,end,INK,2.3)
	draw_line(start,start-Vector2(0,4),INK,2)
	draw_line(end,end-Vector2(0,4),INK,2)
	draw_string(_font,start+Vector2(0,-6),Text.get_message("scale")%5,HORIZONTAL_ALIGNMENT_LEFT,-1,13,INK)


func _draw_footprints(chart: Rect2) -> void:
	for item in map_data.footprints:
		var points := PackedVector2Array()
		for p in item.polygon:
			points.append(_at(p,chart))
		if points.size()<3:
			continue
		var fill := Color("#516e60") if item.small else Color("#a68e69")
		draw_colored_polygon(points,fill)
		points.append(points[0])
		draw_polyline(points,Color(INK,0.65),1.3,true)


func _mark(at: Vector2, kind: String, radius: float) -> void:
	var tint := S.MINT if kind=="you" else (S.HOT if kind=="guardian" else S.GOLD)
	draw_circle(at,radius+2,S.DEEP,true,-1,true)
	draw_circle(at,radius,tint,true,-1,true)
	if kind=="you":
		var f: Vector2 = map_data.facing
		var side := f.orthogonal()
		draw_colored_polygon(PackedVector2Array([at+f*radius*.83,at-f*radius*.56+side*radius*.63,at-f*radius*.26,at-f*radius*.56-side*radius*.63]),S.DEEP)
	elif kind=="guardian":
		var s := radius*.68
		draw_polyline(PackedVector2Array([at+Vector2(-s,-s*.5),at+Vector2(-s*.55,s*.6),at+Vector2(s*.55,s*.6),at+Vector2(s,-s*.5),at+Vector2(s*.31,0),at+Vector2(0,-s*.78),at+Vector2(-s*.31,0),at+Vector2(-s,-s*.5)]),S.DEEP,1.8,true)
	else:
		S.icon(self,kind,at-Vector2.ONE*radius*.77,radius*1.54,S.DEEP)


func _legend(pos: Vector2, region: int) -> void:
	var title := S.t("town" if region<0 else "region%d"%region)
	var fs := roundi(16*text_scale)
	var row := maxf(29,fs+12)
	draw_string(_font,pos+Vector2(1,fs+4),title,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(fs*1.16),S.PAPER)
	pos.y += row+7
	draw_line(pos,pos+Vector2(minf(size.x-pos.x-8,182*text_scale),0),S.LINE,1)
	pos.y += row
	_legend_row(pos,"you",Text.get_message("you"),fs)
	for key in map_data.points:
		pos.y += row
		var local: Vector2 = map_data.points[key]
		var meters := roundi(local.distance_to(map_data.player))
		_legend_row(pos,key,"%s  ·  %s" % [S.t(key),Text.get_message("distance")%meters],fs)
	if map_data.has("guardian"):
		pos.y += row
		_legend_row(pos,"guardian",map_data.guardian.title,fs)
		if map_data.guardian.pending:
			pos.y += row*.85
			draw_string(_font,pos+Vector2(28,0),Text.get_message("pending"),HORIZONTAL_ALIGNMENT_LEFT,-1,fs,S.HOT)
	pos.y += row+6
	draw_line(pos+Vector2(1,-5),pos+Vector2(22,-5),ROAD,4,true)
	draw_string(_font,pos+Vector2(28,0),Text.get_message("way"),HORIZONTAL_ALIGNMENT_LEFT,-1,fs,S.MUTED)


func _legend_row(pos: Vector2, kind: String, label: String, fs: int) -> void:
	_mark(pos+Vector2(12,-fs*.34),kind,8.3*text_scale)
	draw_string(_font,pos+Vector2(28*text_scale,0),label,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,S.PAPER)
