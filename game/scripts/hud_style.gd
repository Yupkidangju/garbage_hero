extends RefCounted

const TRANSLATION = preload("res://data/hud_ko.tres")
const INK = Color("#13232c")
const DEEP = Color("#0d1922")
const PANEL = Color("#1d3039")
const RAISED = Color("#293e45")
const LINE = Color("#4b615e")
const PAPER = Color("#fcf4da")
const MUTED = Color("#bdc9bd")
const GOLD = Color("#f2c475")
const BRASS = Color("#a88552")
const MINT = Color("#83dec0")
const HOT = Color("#ff9164")
const GRADE = [Color("#c2c8b6"), Color("#dbe5cc"), Color("#84ddac"), Color("#80c5e3"), Color("#d3a3eb"), Color("#ffc272"), Color("#ff9499")]
const GEO = [Color("#96d39d"), Color("#f1c274"), Color("#bfaccd"), Color("#7ed2bf"), Color("#aad8ed"), Color("#f59b79")]
const REGION_ART = ["forest","desert","graveyard","swamp","snow","volcano"]
static var _textures: Dictionary = {}

static func texture(path: String) -> Texture2D:
	if path.is_empty(): return null
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]

static func item_art(item: Dictionary) -> Texture2D:
	return texture(str(item.get("icon","res://assets/ui/items/item_%03d.png"%int(item.get("design",0)))))

static func skill_art(id: String) -> Texture2D:
	return texture("res://assets/ui/skills/%s.png"%id)

static func region_art(region: int) -> Texture2D:
	return texture("res://assets/ui/regions/%s.png"%REGION_ART[clampi(region,0,5)])

static func t(key: String) -> String:
	return String(TRANSLATION.get_message(key))

static func font_weight(base: Font, weight: int) -> FontVariation:
	var result := FontVariation.new()
	result.base_font = base
	result.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):weight}
	return result

static func box(bg: Color, border: Color, width := 1, radius := 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

static func key_name(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		var index: int = event.button_index
		return t("key_mouse%d" % index) if index <= 3 else t("key_mousex") % index
	if event is InputEventKey:
		var code: Key = event.physical_keycode if event.physical_keycode else event.keycode
		return OS.get_keycode_string(code)
	return t("no_key")

static func binding(action: String) -> String:
	if InputMap.has_action(action):
		var events := InputMap.action_get_events(action)
		if not events.is_empty():
			return key_name(events[0])
	return t("no_key")

static func icon(c: CanvasItem, id: String, at: Vector2, size: float, color: Color) -> void:
	# 한 칸에 맞춘 24단위의 금속 각인 문양.
	var paths: Array = []
	var width := 1.8
	match id:
		"attack", "inventory_weapon":
			paths = [[5,20,8.5,16.5],[5,12.5,11.5,19],[8,14.5,15.5,5.5,21,3,19,9,10,17]]
		"hook":
			paths = [[4,20,13,11,11,8,14.5,4,20,4,18,6,15,6,14,8,16,10,18.5,9,21,6,20,12,17,14,14,14],[5,17,7,19]]
		"spin":
			paths = [[3,14,4,10,9,6,16,5,20,7,21,10,17,13,12,14,9,13,10,11,14,10],[5,16,9,18,15,17,19,15],[2,11,3,15,7,14]]
		"slam":
			paths = [[6,15,11,9,9,7,14,3,20,9,15,14,13,12,8,18],[3,19,7,21,12,20,17,22,21,20],[4,13,2,11],[17,16,21,15]]
		"volley":
			paths = [[3,17,10,10,12,12,5,19],[8,19,16,11,17,13,10,20],[5,11,13,4,15,4,14,7,6,14],[16,8,21,3,20,7,17,9]]
		"nova":
			paths = [[12,3,14,8,19,5,17,10,22,12,17,14,19,19,14,17,12,22,10,17,5,19,7,14,2,12,7,10,5,5,10,8,12,3],[10,12,12,10,14,12,12,14,10,12]]
		"rush":
			paths = [[8,8,15,8,13,4,22,12,11,20,14,15,5,15],[2,8,5,8],[3,11,10,11],[2,18,7,18]]
		"skills":
			paths = [[10,17,14,17,14,21,10,21,10,17],[12,17,12,12,5,12,5,7],[12,12,19,12,19,7],[3,3,7,3,7,7,3,7,3,3],[17,3,21,3,21,7,17,7,17,3]]
		"dodge":
			paths = [[7,4,14,11,10,12,16,18,10,18],[15,4,22,11,18,12,21,15],[2,9,7,9],[2,14,7,14],[4,18,7,18]]
		"inventory", "chest":
			paths = [[5,9,6,5,10,5,11,3,14,3,15,5,18,5,19,9],[4,10,20,10,20,20,4,20,4,10],[4,14,10,14],[14,14,20,14],[10,12,14,12,14,16,10,16,10,12]]
		"town", "return":
			paths = [[2,11,12,3,22,11],[5,10,5,20,19,20,19,10],[10,20,10,14,14,14,14,20]]
		"coach":
			paths = [[2,7,18,7,18,15,4,15,2,7],[5,7,7,4,15,4,17,7],[18,14,22,12]]
			c.draw_arc(at + Vector2(6,18)*size/24.0,size*0.105,0,TAU,14,color,1.6,true)
			c.draw_arc(at + Vector2(16,18)*size/24.0,size*0.105,0,TAU,14,color,1.6,true)
		"elder", "track":
			paths = [[4,4,18,4,18,16,12,20,6,16,6,5],[9,8,15,8],[9,11,14,11]]
		"shop", "traveler":
			paths = [[3,9,6,4,18,4,21,9,19,11,16,10,13,11,10,10,7,11,3,9],[5,12,5,20,19,20,19,12],[8,15,12,15,12,20]]
		"map":
			paths = [[3,6,9,3,15,6,21,3,21,18,15,21,9,18,3,21,3,6],[9,3,9,18],[15,6,15,21]]
		"pin":
			paths = [[6,11,6,8,8,5,12,3,16,5,18,8,18,11,12,20,6,11],[10,9,12,7,14,9,12,11,10,9]]
		"pause": paths = [[8,5,8,19],[16,5,16,19]]
		"lock":
			paths = [[6,11,18,11,18,20,6,20,6,11],[8,11,8,7,10,4,14,4,16,7,16,11],[12,14,12,17]]
		"settings":
			paths = [[3,6,9,6],[13,6,21,6],[9,3,13,3,13,9,9,9,9,3],[3,17,14,17],[18,17,21,17],[14,14,18,14,18,20,14,20,14,14]]
		"coin":
			paths = [[8,3,16,3,21,8,21,16,16,21,8,21,3,16,3,8,8,3],[9,7,15,7,17,9,17,15,15,17,9,17,7,15,7,9,9,7]]
			width = 1.4
		"forest": paths = [[12,2,5,11,9,11,3,17,10,17,10,21,14,21,14,17,21,17,15,11,19,11,12,2]]
		_: paths = [[12,2,22,12,12,22,2,12,12,2],[12,7,17,12,12,17,7,12,12,7]]
	for path in paths:
		var points := PackedVector2Array()
		for i in range(0, path.size(), 2):
			points.append(at + Vector2(path[i], path[i+1]) * size / 24.0)
		c.draw_polyline(points,color,maxf(1.2, width*size/24.0),true)
