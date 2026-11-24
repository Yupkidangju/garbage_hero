extends SceneTree

const Loot = preload("res://data/loot_rules.gd")
const Monsters = preload("res://data/monsters.gd")
const Layout = preload("res://scripts/world/field_layout.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	check(Layout.BOUNDS.size == Vector2(256,224), "field boundary is the approved size")
	check(Loot.BLUEPRINTS.size() == 88, "88 base blueprints independent of grade")
	var totals := {}
	for id in Loot.BLUEPRINTS.size():
		var family: String = Loot.kind(id)
		totals[family] = int(totals.get(family, 0)) + 1
		var view: Dictionary = Loot.design_view(id, 0)
		check(not view.name.is_empty(), "item localized name %d" % id)
		check(ResourceLoader.exists("res://assets/ui/items/item_%03d.png" % id), "dedicated icon %d" % id)
		check(ResourceLoader.exists("res://assets/models/items/item_%03d.glb" % id), "matching equipment model %d" % id)
	for kind in ["sword","bow","staff","spear","mace","armor","shield","boots","helmet","ring","necklace"]:
		check(totals.get(kind, 0) == 8, "eight designs in family " + kind)
	var species := {}
	for region in 6:
		for index in 10:
			species[Monsters.species(region, "normal", index)[0]] = true
		for index in 2:
			species[Monsters.species(region, "mini", index)[0]] = true
		species[Monsters.species(region, "boss", 0)[0]] = true
		check(Layout.new(region).districts.size() == 5, "five authored districts in region %d" % region)
	check(species.size() == 78, "78 different creature identities")
	for index in 4:
		check(Monsters.normal_cap(index) == [16,24,32,40][index], "difficulty population %d" % index)
	for id in ["hook","spin","slam","volley","nova","rush"]:
		check(ResourceLoader.exists("res://assets/ui/skills/%s.png" % id), "skill illustration " + id)
	for id in ["hero","shop","traveler","elder"]:
		check(ResourceLoader.exists("res://assets/ui/portraits/%s.png" % id), "portrait " + id)
	for id in ["forest","desert","graveyard","swamp","snow","volcano"]:
		check(ResourceLoader.exists("res://assets/ui/regions/%s.png" % id), "region painting " + id)
	check(ResourceLoader.exists("res://assets/ui/workshop_panel.png"), "workshop panel artwork")
	check(ResourceLoader.exists("res://assets/ui/workshop_frame.png"), "workshop frame artwork")
	print("0.3 content goal: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
