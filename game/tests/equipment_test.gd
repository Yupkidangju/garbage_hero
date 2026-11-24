extends SceneTree

const Loot = preload("res://data/loot_rules.gd")
const Equipment = preload("res://scripts/equipment.gd")
const Session = preload("res://scripts/session.gd")
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
	return condition

func _initialize() -> void:
	_catalog()
	_shop_and_swap()
	_wearable_fusion()
	print("Equipment tests: %d checks, %d failures." % [checks, failures])
	quit(1 if failures > 0 else 0)

func _catalog() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 318997
	var sentinel := {"id":1, "order":1, "design":0, "grade":0, "atk":10, "crit":3, "locked":false}
	var described := Loot.describe(sentinel)
	check(described.slot == "weapon" and described.weapon_type == "sword" and described.atk == 10 and described.crit == 3,
		"schema-1 equipped item retains sword and original stats")
	check(described.next_min_atk == 11 and described.next_max_atk == 16 and described.next_min_crit == 2 and described.next_max_crit == 6,
		"legacy next-grade ranges")
	for region in 6:
		var found := {}
		var local_count := 0
		var local := Loot.regional_pool(region)
		for i in 3000:
			var design := Loot.draw_design(region, rng)
			found[design] = true
			if design in local:
				local_count += 1
		check(found.size() == 11 + local.size() and found.has_all(Loot.TOWN_DESIGNS) and found.has_all(local),
			"region %d drops every common, regional design and regional artifact" % region)
		check(local_count > 1650 and local_count < 1950, "region %d samples expected 40/60 common/regional split" % region)
	for design in Loot.BLUEPRINTS.size():
		for grade in 7:
			var generated := Loot.describe(Loot.weapon(1, design, grade, rng))
			check(not generated.name.is_empty() and not generated.type_name.is_empty() and not generated.stat_text.is_empty()
				and not generated.next_stat_text.is_empty(), "localized item %d grade %d" % [design,grade])
	var legacy_traveler := {"available":true,"region":4,"sold":true,"price":18}
	var legacy_stock := Equipment.offers("traveler", legacy_traveler)
	check(legacy_stock.size() == 12 and legacy_stock[0].sold and not legacy_stock[1].sold and not legacy_stock[2].sold,
		"schema-1 traveler preserves previously sold regional sword")

func _shop_and_swap() -> void:
	var temp := DirAccess.create_temp("garbagehero-equipment")
	var game := Session.new()
	if not check(temp != null and game.start_slot(temp.get_current_dir()), "fresh session"):
		game.free()
		return
	game._data.coins = 2000
	check(game.act("auto", {"enabled":false}), "manual inventory")
	var ui := game.ui_state()
	check(ui.offers.shop.size() == 11 and ui.offers.traveler.is_empty(), "11 available permanent offers")
	var ids := {}
	for product in ui.offers.shop:
		var before: int = game._data.coins
		if not check(game.act("buy", {"vendor":"shop", "design":product.design}), "buy %s" % product.name):
			continue
		var bought: Dictionary = game._data.bag.back()
		ids[product.design] = bought.id
		check(game._data.coins == before - product.price and bought.design == product.design and bought.grade == product.grade,
			"offer price and actual item agree %s" % product.name)
	for design in [11,12,13,14,15,16]:
		check(game.act("equip", {"id":ids[design]}), "wear slot %s" % Loot.kind(design))
	ui = game.ui_state()
	for slot in Equipment.SLOTS:
		check(not ui.equipment[slot].is_empty() and ui.equipment[slot].slot == slot, "visible independent slot " + slot)
	var totals := Equipment.bonuses(game._data)
	check(totals.atk > 10 and totals.crit > 3 and totals.defense > 0 and totals.max_hp > 0 and totals.speed > 0,
		"wearables contribute combat and movement stats")
	check(game.act("lock", {"id":ids[12]}), "lock equipped shield")
	for design in [7,8,9]:
		check(game.act("equip", {"id":ids[design]}), "equip two-handed %s" % Loot.kind(design))
		ui = game.ui_state()
		check(ui.equipment.shield.is_empty() and ui.equipped.weapon_type == Loot.kind(design), "two-handed weapon stows shield")
		var before := game._data.duplicate(true)
		check(not game.act("equip", {"id":ids[12]}) and game._data == before and game.last_error == Loot.caption("TWO_HANDS_BUSY"),
			"reject shield without spending inventory or changing equipment")
		check(game.act("equip", {"id":ids[10]}) and game.act("equip", {"id":ids[12]}), "mace and shield coexist")
	check(game.ui_state().equipment.shield.locked, "shield identity and lock survived retirement")
	check(game.act("unequip"), "old unequip command removes weapon")
	check(Equipment.bonuses(game._data).atk == 4 + int(game.ui_state().equipment.ring.atk), "unarmed four plus ring")
	check(game.act("equip", {"id":ids[10]}), "restore one-handed weapon")
	while game._data.bag.size() < Session.BAG_SIZE:
		if not check(game.act("buy", {"vendor":"shop", "design":16}), "fill bag"):
			break
	var full := game._data.duplicate(true)
	check(not game.act("equip", {"id":ids[7]}) and game.last_error == Loot.caption("BAG_FULL") and game._data == full,
		"full bag rejects two-handed swap atomically")
	check(game.act("store", {"id":game._data.bag.back().id}) and game.act("equip", {"id":ids[7]}),
		"one free slot permits both shield and mace to return")
	check(game._data.bag.size() == 30 and game.ui_state().equipment.shield.is_empty(), "two retired items account for final slot count")
	for i in 3:
		check(game.act("store", {"id":game._data.bag.back().id}), "make room for regional offers")
	game._data.traveler = {"available":true,"sold":false,"region":2,"price":18}
	ui = game.ui_state()
	var goods: Array = ui.offers.traveler
	check(goods.size() == 12 and goods[0].design == 3 and goods[0].price == 18, "legacy regional sword keeps price")
	var custom: Dictionary = goods[1]
	var money: int = game._data.coins
	check(game.act("buy", {"vendor":"traveler","design":custom.design}) and game._data.coins == money-custom.price,
		"buy middle regional offer")
	check(not game.act("buy", {"vendor":"traveler","design":custom.design}) and game.last_error == Loot.caption("SOLD_OUT"),
		"same regional offer sold out")
	var saved := game._data.duplicate(true)
	game.free()
	game = Session.new()
	check(game.start_slot(temp.get_current_dir()) and game._data == saved, "regional stock and equipment survive reload")
	goods = game.ui_state().offers.traveler
	check(goods[0].stock == 1 and goods[1].stock == 0 and goods[2].stock == 1, "other regional offers remain")
	check(game.act("buy", {"vendor":"traveler"}) and game.act("buy", {"vendor":"traveler","design":goods[2].design}),
		"last two available independently")
	var sold := game._data.duplicate(true)
	check(not game.act("buy", {"vendor":"traveler","design":0}) and sold == game._data, "reject absent design without mutation")
	game.free()

func _wearable_fusion() -> void:
	var temp := DirAccess.create_temp("garbagehero-wearable-fusion")
	var game := Session.new()
	if not check(temp != null and game.start_slot(temp.get_current_dir()), "fresh fusion session"):
		game.free()
		return
	game._data.coins = 80
	check(game.act("auto", {"enabled":false}), "disable automatic fusion to compare candidates")
	for index in 4:
		check(game.act("buy", {"vendor":"shop","design":13}), "buy boot ingredient %d" % index)
	var bag: Array = game._data.bag
	bag[1].speed = 0.30
	for i in [0,2,3]:
		bag[i].speed = 0.21
	var faster_id: int = bag[1].id
	check(game.act("auto", {"enabled":true}), "automatically fuse lowest three pairs")
	var state := game.ui_state()
	check(state.bag.size() == 2 and state.bag[0].id == faster_id and state.bag[0].grade == 0, "stronger boots survive")
	var fused: Dictionary = state.last_merge.item
	check(fused.grade == 1 and fused.slot == "boots" and fused.speed > 0 and fused.stat_text.contains("m/s"),
		"fusion retains wearable design with next-grade stat and unit")
	check(game.act("equip", {"id":fused.id}) and game.ui_state().stats.speed > 5.0, "fused item affects player movement")
	check(not game.act("sell", {"id":fused.id}), "equipped boots protected from sale")
	game.free()
