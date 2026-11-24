extends SceneTree

const Growth = preload("res://data/progression.gd")

var failures := 0
var checks := 0


func _initialize() -> void:
	_levels_and_stats()
	_tree_and_loadout()
	_legacy_and_validation()
	_rank_gate_and_resume()
	print("Progression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func _levels_and_stats() -> void:
	var p := Growth.fresh()
	var snapshot := p.duplicate(true)
	check(Growth.valid(p), "fresh state passes slot validation")
	check(Growth.gain(p, 1, "unknown") == 0 and Growth.gain(p, 0, "boss") == 0 and p == snapshot, "invalid kill has no effect")
	check(not Growth.allocate(p, "strength") and p == snapshot, "no free stat increase")
	for i in 4:
		check(Growth.gain(p, 1, "normal") == 0, "first four forest normals accumulate XP")
	check(p.xp == 24 and Growth.describe(p).xp_next == 30, "first XP threshold")
	check(Growth.gain(p, 1, "normal") == 1 and p.xp == 0 and p.level == 2, "exact threshold")
	check(p.stat_points == 3 and p.skill_points == 1, "both point pools awarded")
	var before_invalid := p.duplicate(true)
	check(not Growth.allocate(p, "luck") and p == before_invalid, "unknown attribute preserves points")
	check(Growth.allocate(p, "strength") and Growth.allocate(p, "vitality") and Growth.allocate(p, "agility"), "spend earned attributes")
	var base := Growth.stats(p, {})
	check(base == {"atk":6, "defense":0, "crit":1, "max_hp":110, "speed":5.0, "effects":{}}, "unarmed hero with three allocated stats")
	var geared := Growth.stats(p, {"atk":13, "crit":100, "defense":2, "max_hp":20, "speed":0.35})
	check(geared.atk == 15 and geared.crit == 100 and geared.defense == 2 and geared.max_hp == 130 and is_equal_approx(geared.speed, 5.35), "equipment totals and critical cap")
	var overlapped := Growth.fresh()
	check(Growth.gain(overlapped, 4, "boss") == 3, "one kill gains three levels")
	check(overlapped.level == 4 and overlapped.xp == 9 and overlapped.stat_points == 9 and overlapped.skill_points == 3, "multi-level reward and remainder")
	check(Growth.gain(overlapped, 4, "mini") == 0 and overlapped.xp == 69, "mini XP multiplier")
	check(Growth.valid(overlapped) and Growth.valid(p), "earned and spent points validate")


func _tree_and_loadout() -> void:
	var p := Growth.fresh()
	var start := p.duplicate(true)
	check(not Growth.equip(p, 1, "volley") and not Growth.learn(p, "volley") and p == start, "reject unlearned skill and unearned upgrade")
	Growth.gain(p, 70, "boss")
	check(not Growth.learn(p, "nova"), "level alone does not satisfy volley branch")
	check(Growth.learn(p, "volley") and Growth.learn(p, "nova"), "learning a prerequisite opens its branch")
	check(Growth.equip(p, 1, "volley") and Growth.equip(p, 0, "nova"), "equip learned skills")
	check(Growth.equip(p, 0, "volley") and p.loadout == ["volley", "nova", ""], "slot swap retains both equipped skills")
	check(Growth.equip(p, 1, "") and p.loadout == ["volley", "", ""], "clear selected slot only")
	var before := p.duplicate(true)
	check(not Growth.equip(p, -1, "hook") and not Growth.equip(p, 3, "hook") and not Growth.equip(p, 2, "bad") and p == before, "bad slot or skill does not alter loadout")
	for rank in range(2, 6):
		check(Growth.learn(p, "volley") and p.ranks.volley == rank, "rank increase to %d" % rank)
	check(is_equal_approx(Growth.damage_multiplier(5), 1.8), "rank five combat damage coefficient")
	var remaining: int = p.skill_points
	check(not Growth.learn(p, "volley") and p.skill_points == remaining, "no point lost at max rank")
	var view := Growth.describe(p)
	check(view.catalog.size() == 6, "all skills in UI")
	for row: Dictionary in view.catalog:
		check(not row.name.is_empty() and not row.description.is_empty() and row.rank == p.ranks[row.id], "skill details for %s" % row.id)
		if row.id == "volley":
			check(not row.can_learn and row.next_damage_percent == 0 and row.damage_percent == 180, "UI max rank agrees with rules")
	view.loadout[0] = ""
	view.attributes.strength = 99
	check(p.loadout[0] == "volley" and p.attributes.strength == 0, "HUD state does not alias save data")
	check(Growth.valid(p), "max rank and customized loadout validate")


func _legacy_and_validation() -> void:
	var former := Growth.from_legacy(true, true)
	check(former.level == 1 and former.xp == 0 and former.skill_points == 0, "existing player begins XP from level one")
	check(former.loadout == ["hook", "spin", "slam"] and Growth.valid(former), "both earned legacy skills stay on their historical keys")
	check(Growth.from_legacy(false, true).loadout == ["hook", "", "slam"], "forest victory before first merge")
	check(Growth.equip(former, 0, "spin") and Growth.equip(former, 2, ""), "custom legacy layout")
	var customized := former.duplicate(true)
	Growth.grant_legacy(former, "slam")
	check(former == customized, "duplicate milestone cannot re-equip intentionally removed skill")
	var filled := Growth.fresh()
	Growth.gain(filled, 70, "boss")
	Growth.learn(filled, "volley")
	Growth.learn(filled, "nova")
	Growth.equip(filled, 1, "volley")
	Growth.equip(filled, 2, "nova")
	Growth.grant_legacy(filled, "spin")
	check(filled.loadout == ["hook", "volley", "nova"] and filled.ranks.spin == 1 and Growth.valid(filled), "milestone preserves full custom bar")
	for invalid in [null, [], {}, {"level":1}]:
		check(not Growth.valid(invalid), "malformed progression is rejected")
	var corrupt := former.duplicate(true)
	corrupt.loadout = ["hook", "hook", ""]
	check(not Growth.valid(corrupt), "one skill cannot appear in two slots")
	corrupt = former.duplicate(true)
	corrupt.loadout[1] = "nova"
	check(not Growth.valid(corrupt), "unlearned skill cannot be equipped")
	corrupt = former.duplicate(true)
	corrupt.stat_points += 1
	check(not Growth.valid(corrupt), "inflated stat balance")
	corrupt = former.duplicate(true)
	corrupt.ranks.volley = 1
	check(not Growth.valid(corrupt), "unearned skill rank")
	corrupt = former.duplicate(true)
	corrupt.xp = Growth.describe(corrupt).xp_next
	check(not Growth.valid(corrupt), "XP equal to threshold requires a level gain")
	check(Growth.from_legacy(false, false) == Growth.fresh(), "legacy slot without milestones has fresh progression")


func _rank_gate_and_resume() -> void:
	var p := Growth.from_legacy(true, false)
	Growth.gain(p, 1, "mini")
	var lvl_two := p.duplicate(true)
	check(p.level == 2 and not Growth.learn(p, "spin") and p == lvl_two, "one point cannot bypass the rank-two level gate")
	for entry: Dictionary in Growth.describe(p).catalog:
		if entry.id == "spin":
			check(entry.level_required == 3 and not entry.can_learn and entry.cost == 1 and entry.next_damage_percent == 120, "UI predicts next rank at level three")
	Growth.gain(p, 1, "boss")
	check(Growth.learn(p, "spin") and Growth.allocate(p, "strength") and Growth.equip(p, 2, "spin"), "qualifying level buys second legacy rank")
	check(Growth.valid(p) and p.loadout == ["hook", "", "spin"], "strengthened legacy skill keeps free first rank")
	check(Growth.level_notice(p, 1).contains("레벨 3") and Growth.level_notice(p, 1).contains("+3"), "Korean level notice gives attained level and reward")
	var temp := DirAccess.create_temp("garbagehero-growth-roundtrip")
	check(temp != null, "isolated save directory")
	if temp == null:
		return
	var path := temp.get_current_dir().path_join("progression.sav")
	var save := FileAccess.open(path, FileAccess.WRITE)
	check(save != null, "isolated save writer")
	if save == null:
		return
	save.store_var(p)
	save.close()
	save = FileAccess.open(path, FileAccess.READ)
	check(save != null, "isolated save reader")
	if save == null:
		return
	var restored: Variant = save.get_var()
	check(Growth.valid(restored) and restored == p, "native Variant save round-trip preserves actual XP, budgets, grants and swapped loadout")
	save.close()
