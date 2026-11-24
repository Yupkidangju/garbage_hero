extends RefCounted

const Loot = preload("res://data/loot_rules.gd")
const SLOTS = ["weapon", "armor", "shield", "boots", "helmet", "ring", "necklace"]
const TOWN_PRICES = [8, 10, 12, 10, 10, 12, 10, 8, 9, 13, 12]
const REGIONAL_PRICES = [18, 24, 20]

static func _worn(data: Dictionary, slot: String) -> Dictionary:
	if slot == "weapon":
		return data.equipped
	return data.get("gear_slots", {}).get(slot, {})

static func slots(data: Dictionary) -> Dictionary:
	var result := {}
	for slot: String in SLOTS:
		result[slot] = Loot.describe(_worn(data, slot))
	return result

static func _add_stats(total: Dictionary, item: Dictionary, factor: int = 1) -> void:
	for stat in Loot.STATS:
		total[stat] += item.get(stat, 0) * factor

static func bonuses(data: Dictionary) -> Dictionary:
	var total := {"atk":4 if data.equipped.is_empty() else 0, "crit":0, "defense":0, "max_hp":0, "speed":0.0,
		"effects":{"pierce":0, "lifesteal":0.0, "area":0.0}}
	for slot: String in SLOTS:
		var item := _worn(data, slot)
		_add_stats(total, item)
		var passive := Loot.effects(int(item.get("design", -1)))
		for effect: String in passive:
			total.effects[effect] += passive[effect]
	for effect: String in Loot.EFFECT_CAPS:
		total.effects[effect] = minf(total.effects[effect], Loot.EFFECT_CAPS[effect])
	total.effects.pierce = int(total.effects.pierce)
	return total

static func compare_text(item: Dictionary, equipment: Dictionary) -> String:
	var slot := Loot.slot(item.design)
	var weapon: Dictionary = equipment.get("weapon", {})
	if slot == "shield" and Loot.kind(weapon.get("design", -1)) in Loot.TWO_HANDED:
		return Loot.caption("TWO_HANDS_BUSY")
	var delta := {"atk":0, "crit":0, "defense":0, "max_hp":0, "speed":0.0}
	_add_stats(delta, item)
	_add_stats(delta, equipment.get(slot, {}), -1)
	if slot == "weapon" and weapon.is_empty():
		delta.atk -= 4
	if Loot.kind(item.design) in Loot.TWO_HANDED:
		_add_stats(delta, equipment.get("shield", {}), -1)
	return Loot.stat_delta_text(delta)

static func equipped_item(data: Dictionary, id: int) -> Dictionary:
	for slot: String in SLOTS:
		var item := _worn(data, slot)
		if item.get("id", -2) == id and not item.is_empty():
			return item
	return {}

static func valid_slots(data: Dictionary) -> bool:
	if not data.get("equipped") is Dictionary or not data.get("gear_slots", {}) is Dictionary:
		return false
	var gear: Dictionary = data.get("gear_slots", {})
	for slot in gear:
		if slot == "weapon" or slot not in SLOTS or not gear[slot] is Dictionary:
			return false
	var seen := {}
	for slot: String in SLOTS:
		var item := _worn(data, slot)
		if item.is_empty():
			continue
		if not item.get("id") is int or item.id <= 0 or seen.has(item.id):
			return false
		if not item.get("design") is int or Loot.slot(item.design) != slot:
			return false
		if not item.get("grade") is int or item.grade < 0 or item.grade > 6:
			return false
		if not item.get("order") is int or not item.get("locked") is bool:
			return false
		if not item.get("atk") is int or not item.get("crit") is int:
			return false
		for stat in ["max_hp", "defense"]:
			if not item.get(stat, 0) is int:
				return false
		if typeof(item.get("speed", 0)) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(item.get("speed", 0))):
			return false
		seen[item.id] = true
	return _worn(data, "shield").is_empty() or Loot.kind(data.equipped.get("design", -1)) not in Loot.TWO_HANDED

static func _stow(data: Dictionary, slot: String) -> void:
	var item := _worn(data, slot)
	if item.is_empty():
		return
	data.bag.append(item)
	if slot == "weapon":
		data.equipped = {}
	else:
		data.gear_slots.erase(slot)

# 이 함수들은 세션의 거래 사본만 수정한다. 합성 후 최종 가방 용량과 저장은 세션에서 확인한다.
static func equip(data: Dictionary, item: Dictionary) -> String:
	var index: int = data.bag.find(item)
	if index < 0:
		return "UNAVAILABLE"
	var actual: Dictionary = data.bag[index]
	var slot := Loot.slot(actual.design)
	if slot.is_empty():
		return "UNAVAILABLE"
	if slot == "shield" and Loot.kind(data.equipped.get("design", -1)) in Loot.TWO_HANDED:
		return "TWO_HANDS_BUSY"
	data.bag.remove_at(index)
	_stow(data, slot)
	if slot == "weapon":
		if Loot.kind(actual.design) in Loot.TWO_HANDED:
			_stow(data, "shield")
		data.equipped = actual
	else:
		if not data.has("gear_slots"):
			data.gear_slots = {}
		data.gear_slots[slot] = actual
	return ""

static func unequip(data: Dictionary, id: int = -1) -> String:
	if id == -1:
		id = data.equipped.get("id", -1)
	var item := equipped_item(data, id)
	if item.is_empty():
		return "UNAVAILABLE"
	_stow(data, Loot.slot(item.design))
	return ""

static func town_designs(data: Dictionary) -> Array:
	var designs := Loot.TOWN_DESIGNS.duplicate()
	var cleared_regions := {}
	var routes: Array = data.get("routes", [])
	for index in routes.size():
		if routes[index].get("cleared", false):
			cleared_regions[index % 6] = true
	for region in 6:
		if cleared_regions.has(region):
			designs.append_array(Loot.regional_pool(region))
	return designs

static func _offer_price(design: int, regional: bool, index: int) -> int:
	if regional and index < REGIONAL_PRICES.size():
		return REGIONAL_PRICES[index]
	var base_index := Loot.TOWN_DESIGNS.find(design)
	if not regional and base_index >= 0:
		return TOWN_PRICES[base_index]
	var profile := Loot.catalog(design)
	var price := 34 if profile.artifact else 18 + int(profile.region) * 2
	if Loot.kind(design) in ["staff", "armor", "necklace"]:
		price += 4
	return price + (4 if regional else 0)

static func offers(vendor: String, traveler: Dictionary, data: Dictionary = {}) -> Array[Dictionary]:
	var products: Array[Dictionary] = []
	var regional := vendor == "traveler"
	var region := int(traveler.get("region", -1))
	if regional and (not traveler.get("available", false) or region < 0 or region >= Loot.REGIONAL_DESIGNS.size()):
		return products
	if vendor not in ["shop", "traveler"]:
		return products
	var designs: Array = Loot.REGIONAL_DESIGNS[region].duplicate() if regional else town_designs(data)
	if regional:
		var artifacts: Array = Loot.ARTIFACT_DESIGNS[region]
		designs.append(artifacts[posmod(int(traveler.get("visit", 0)), artifacts.size())])
	var grade := 1 if regional else 0
	for index in designs.size():
		var design: int = designs[index]
		var product := Loot.design_view(design, grade)
		product.price = _offer_price(design, regional, index)
		product.sold = regional and (design in traveler.get("sold_designs", []) or (index == 0 and traveler.get("sold", false)))
		product.stock = (0 if product.sold else 1) if regional else -1
		product.source = "traveler" if regional else ("basic" if design in Loot.TOWN_DESIGNS else "commission")
		product.rotation = int(traveler.get("visit", 0)) if regional else 0
		product.stat_text = Loot.range_text(design, grade)
		products.append(product)
	return products

static func buy(data: Dictionary, vendor: String, design: int = -1) -> String:
	var products := offers(vendor, data.traveler, data)
	var offer: Dictionary = {}
	for product in products:
		if design == -1 or product.design == design:
			offer = product
			break
	if offer.is_empty():
		return "UNAVAILABLE"
	if offer.sold:
		return "SOLD_OUT"
	if data.coins < offer.price:
		return "LOW_COINS"
	var rng := RandomNumberGenerator.new()
	rng.state = data.rng.shop
	data.bag.append(Loot.weapon(data.next_id, offer.design, offer.grade, rng))
	data.rng.shop = rng.state
	data.next_id += 1
	data.coins -= offer.price
	if vendor == "traveler":
		if not data.traveler.has("sold_designs"):
			data.traveler.sold_designs = []
		data.traveler.sold_designs.append(offer.design)
		if offer.design == products[0].design:
			data.traveler.sold = true
	return ""
