extends SceneTree

const Loot = preload("res://data/loot_rules.gd")
const Equipment = preload("res://scripts/equipment.gd")
const Session = preload("res://scripts/session.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _initialize() -> void:
	_legacy_generation()
	_catalog()
	_regional_acquisition()
	_targeted_shop()
	_equipped_effects()
	_new_design_transactions()
	print("Item expansion tests: %d checks, %d failures." % [checks, failures])
	quit(1 if failures else 0)

func _legacy_generation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026112403
	var values := []
	for design in 29:
		for grade in 7:
			values.append(Loot.weapon(design * 7 + grade + 1, design, grade, rng))
	var fingerprint := var_to_bytes([values, rng.state]).hex_encode().sha256_text()
	check(fingerprint == "1d4d3a6064d608c41ce6f895825ca82813080f0a3e145f8a98f7ec5ef8adf8e0",
		"0.2 designs 0..28 keep generated stats and final RNG across seven grades")

func _catalog() -> void:
	check(Loot.BLUEPRINTS.size() == 88, "88 blueprints excluding grade variations")
	var kinds := {}
	var names := {}
	var shapes := {}
	var family_stats := {}
	for design in Loot.BLUEPRINTS.size():
		var view := Loot.design_view(design, 0)
		var kind := Loot.kind(design)
		kinds[kind] = kinds.get(kind, 0) + 1
		check(not names.has(view.name), "distinct translated item name %d" % design)
		names[view.name] = true
		check(not str(view.get("description", "")).is_empty(), "item lore %d" % design)
		check(not str(view.get("role", "")).is_empty(), "functional role %d" % design)
		check(view.get("icon", "") == "res://assets/ui/items/item_%03d.png" % design, "bound icon %d" % design)
		check(view.description != "DESC_%d" % design and view.role != "ROLE_%d" % design, "real Korean item text %d" % design)
		check(not shapes.has(view.archetype) and not str(view.visual.feature).is_empty(), "distinct readable silhouette %d" % design)
		shapes[view.archetype] = true
		check(Loot.catalog(design).id == design and Loot.catalog(design).kind == kind, "visual and gameplay identity %d" % design)
		if not family_stats.has(kind):
			family_stats[kind] = {}
		var stat_range: String = Loot.range_text(design, 6) + "|" + str(view.effect_text)
		check(not family_stats[kind].has(stat_range), "functional stat tradeoff for %s design %d" % [kind,design])
		family_stats[kind][stat_range] = true
		check(view.effect_id.is_empty() == view.effect_text.is_empty(), "passive and caption agree %d" % design)
	for kind in ["sword", "bow", "staff", "spear", "mace", "armor", "shield", "boots", "helmet", "ring", "necklace"]:
		check(kinds.get(kind, 0) == 8, "eight distinct %s blueprints" % kind)
	var saved := {"id":707, "order":3, "design":25, "grade":4, "atk":0, "crit":0,
		"defense":77, "max_hp":123, "locked":true}
	var original := saved.duplicate(true)
	var shown := Loot.describe(saved)
	check(saved == original and shown.defense == 77 and shown.max_hp == 123 and shown.locked,
		"describing stored older equipment never rerolls or rewrites its values")

func _regional_acquisition() -> void:
	var all_found := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 777312410
	for region in 6:
		var allowed := Loot.TOWN_DESIGNS + Loot.regional_pool(region)
		var local_found := {}
		for district in 5:
			var district_id := "%d:district_%d" % [region,district]
			for trial in 1200:
				var design := Loot.draw_design(region,rng,district_id)
				local_found[design] = true
				all_found[design] = true
			var weights := Loot.drop_weights(region,district_id)
			var common_weight := 0
			var regional_weight := 0
			for design: int in weights:
				if design in Loot.TOWN_DESIGNS:
					common_weight += int(weights[design])
				else:
					regional_weight += int(weights[design])
			check(common_weight * 3 == regional_weight * 2, "40/60 acquisition split %s" % district_id)
			for design: int in Loot.REGIONAL_DESIGNS[region]:
				if int(Loot.catalog(design).district) == district:
					var plain: Dictionary = Loot.drop_weights(region)
					var normal_share := float(plain[design]) / float(plain.values().reduce(func(a,b):return a+b,0))
					var focus_share := float(weights[design]) / float(weights.values().reduce(func(a,b):return a+b,0))
					check(focus_share > normal_share * 1.7, "district improves targeted collection %s design %d" % [district_id,design])
		check(local_found.has_all(allowed) and local_found.size() == allowed.size(),
			"natural regional samples reach all local designs and exclude foreign designs %d" % region)
	check(all_found.size() == 88, "all 88 blueprints are naturally obtainable across six fields")
	check(Loot.drop_weights(0,"1:district_0") == Loot.drop_weights(0), "foreign district cannot redirect a region's drops")
	var one := RandomNumberGenerator.new()
	one.seed = 176622
	var reference := RandomNumberGenerator.new()
	reference.state = one.state
	var weights := Loot.drop_weights(2,"2:district_4")
	var total: int = weights.values().reduce(func(a,b):return a+b,0)
	Loot.draw_design(2,one,"2:district_4")
	reference.randi_range(0,total-1)
	check(one.state == reference.state, "expanded design selection uses one draw from the saved stream")
	var longbow := Loot.design_view(30,0)
	var shortbow := Loot.design_view(31,0)
	check(longbow.combat_profile.windup > shortbow.combat_profile.windup
		and longbow.combat_profile.recovery > shortbow.combat_profile.recovery
		and longbow.combat_profile.range > shortbow.combat_profile.range,
		"heavy longbow and quick shortbow expose different real combat roles")
	check(longbow.combat_profile_text.contains("14.4") and shortbow.combat_profile_text.contains("10.2"),
		"visible weapon reach comes from actual combat profiles")
	check(longbow.source_text.contains("유리모래 사막") and longbow.source_text.contains("유리모래 언덕")
		and longbow.district_id == "1:district_1", "collection hint names its real map district")

func _targeted_shop() -> void:
	var data := {"routes":[], "equipped":{}, "gear_slots":{}, "bag":[], "coins":100000, "next_id":1,
		"traveler":{"available":false,"region":-1}, "rng":{"shop":1435666}}
	for index in 24:
		data.routes.append({"cleared":false})
	check(Equipment.offers("shop",data.traveler,data).size() == 11, "fresh town keeps eleven affordable base designs")
	check(Equipment.buy(data,"shop",29) == "UNAVAILABLE", "regional commissions require their source boss")
	for region in 6:
		data.routes[region].cleared = true
	var before := data.duplicate(true)
	var offers := Equipment.offers("shop",data.traveler,data)
	check(data == before and offers.size() == 88, "six source bosses unlock an explicit offer for every blueprint")
	var seen := {}
	for offer: Dictionary in offers:
		var money: int = data.coins
		check(not seen.has(offer.design) and Equipment.buy(data,"shop",offer.design).is_empty(), "select design %d directly" % offer.design)
		seen[offer.design] = true
		var bought: Dictionary = data.bag.back()
		check(bought.design == offer.design and bought.grade == offer.grade and data.coins == money-offer.price,
			"the selected offer is exactly the item paid for %d" % offer.design)
	data.coins = 0
	before = data.duplicate(true)
	check(Equipment.buy(data,"shop",87) == "LOW_COINS" and data == before,
		"failed explicit purchase leaves IDs, saved RNG, wallet and items unchanged")
	for region in 6:
		var traveler := {"available":true,"region":region,"sold":true,"visit":0,"sold_designs":[]}
		var inventory := Equipment.offers("traveler",traveler,data)
		check(inventory.size() == 12 and inventory[0].sold and inventory[0].price == 18
			and inventory[1].price == 24 and inventory[2].price == 20, "legacy prices and sold flag survive expanded traveler %d" % region)
		var stocked := {}
		for offer in inventory:
			stocked[offer.family] = true
		check(stocked.size() == 11, "regional traveler stocks every equipment family %d" % region)
		if region < 5:
			traveler.visit = 1
			var rotated := Equipment.offers("traveler",traveler,data)
			check(rotated.back().design != inventory.back().design, "visits rotate visible home-region artifact %d" % region)

func _equipped_effects() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 14372
	var data := {"equipped":Loot.weapon(1,51,1,rng), "gear_slots":{}}
	data.gear_slots.armor = Loot.weapon(2,57,1,rng)
	data.gear_slots.ring = Loot.weapon(3,81,1,rng)
	var total := Equipment.bonuses(data)
	check(is_equal_approx(total.effects.lifesteal,0.12), "stacked lifesteal caps actual damage recovery at twelve percent")
	check(total.atk > data.equipped.atk and total.max_hp > 0 and total.defense > 0,
		"passives coexist with ordinary seven-slot bonuses")
	data.equipped = Loot.weapon(4,40,1,rng)
	data.gear_slots = {"helmet":Loot.weapon(5,75,1,rng), "necklace":Loot.weapon(6,87,1,rng)}
	total = Equipment.bonuses(data)
	check(is_equal_approx(total.effects.area,0.35), "three area bonuses respect thirty-five percent radius cap")
	data.equipped = Loot.weapon(7,34,1,rng)
	data.gear_slots = {}
	total = Equipment.bonuses(data)
	check(total.effects.pierce is int and total.effects.pierce == 2, "orbit bow supplies two additional projectile targets")
	data.equipped = {"id":1,"order":1,"design":0,"grade":6,"atk":99,"crit":9,"locked":false,"effects":{"lifesteal":1}}
	check(Equipment.bonuses(data).effects.lifesteal == 0.0, "passives come from real equipped design rather than stale item fields")

func _new_design_transactions() -> void:
	var temp := DirAccess.create_temp("garbagehero-item030")
	var game := Session.new()
	if temp == null or not game.start_slot(temp.get_current_dir()):
		check(false,"open isolated 0.3 item session")
		game.free()
		return
	# 정직한 0.3 준비 상태: 첫 지역 보스 후 생기는 주문을 검사한다. 구버전 도안으로 위장하지 않는다.
	game._data.coins = 400
	game._data.routes[0].cleared = true
	check(game.act("auto",{"enabled":false}), "manual fusion for an unlocked new design")
	for index in 3:
		check(game.act("buy",{"vendor":"shop","design":29}), "buy exact new sword ingredient %d" % index)
	var materials := []
	for item in game._data.bag:
		materials.append(item.id)
	check(game.act("merge",{"ids":materials}), "three identical new blueprint copies fuse")
	var merged: Dictionary = game.ui_state().last_merge.item
	check(game._data.bag.size() == 1 and merged.design == 29 and merged.grade == 1 and not merged.effect_text.is_empty(),
		"new design fusion preserves blueprint and functional passive")
	check(game.act("equip",{"id":merged.id}) and is_equal_approx(game.ui_state().stats.effects.area,0.12),
		"new fused item reaches final player build effects")
	var persisted := game._data.duplicate(true)
	game.free()
	game = Session.new()
	check(game.start_slot(temp.get_current_dir()) and game._data == persisted,
		"new design, fused values and saved streams survive real disk reload")
	game.free()
