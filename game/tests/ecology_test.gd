extends SceneTree

const Book=preload("res://data/monsters.gd")
var failed:=0
var checks:=0
var main
var slot:DirAccess

func _initialize() -> void:
	_run.call_deferred()

func check(condition:bool,label:String) -> void:
	checks+=1
	if not condition:
		failed+=1
		push_error(label)

func freeze() -> void:
	for actor in get_nodes_in_group("enemies"):
		actor.set_physics_process(false)
	main.player.set_physics_process(false)
	main.director.set_physics_process(false)

func living(hunt) -> int:
	var n:=0
	for actor in hunt.enemies:
		if is_instance_valid(actor): n+=1
	return n

func _run() -> void:
	slot=DirAccess.create_temp("garbagehero-ecology")
	OS.set_environment("GARBAGEHERO_SAVE_DIR",slot.get_current_dir())
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for rank in 4:
		main._enter(0,rank)
		freeze()
		var hunt=main.director
		check(hunt.enemies.size()==[16,24,32,40][rank],"Difficulty allocates the documented normal population")
		check(living(hunt)==hunt.enemies.size(),"Every normal slot can be populated near the entrance")
		for i in 20: hunt._fill_slots()
		check(living(hunt)==hunt.enemies.size(),"Repeated fill cannot exceed the normal cap")
	for region in 6:
		main._enter(region,1)
		freeze()
		var hunt=main.director
		var seen:={}
		var before:Dictionary=main.session.ui_state()
		for district in main.world.district_points():
			main.player.position=district.pos
			hunt._fill_slots()
			freeze()
			var local_seen:={}
			for actor in hunt.enemies:
				if not is_instance_valid(actor): continue
				var key:String=actor.get_meta("district_id","")
				check(not key.is_empty(),"Every encounter records its source district")
				if not key.is_empty():
					var niche:=int(key.get_slice("_",1))
					check(Book.population(region,niche).has(actor.index),"Spawn respects the district population")
				seen[actor.index]=true
				local_seen[actor.index]=true
			check(local_seen.size()>=4,"A nearby encounter offers several silhouettes and roles")
		check(seen.size()==10,"Roaming all five districts encounters all ten regional species")
		var after:Dictionary=main.session.ui_state()
		check(before.coins==after.coins and before.progression==after.progression and hunt.state.trace==0,"Retiring distant groups grants no kill, XP, coin or trace")
		var elite
		for actor in hunt.enemies:
			if is_instance_valid(actor) and actor.is_elite:
				elite=actor
				break
		check(is_instance_valid(elite),"An elite is present inside the normal cap")
		if is_instance_valid(elite):
			main.session._data.active_route=region+6
			check(elite.visual.get_node_or_null("EliteCrest")!=null,"Elite has a visible crown and banner")
			var coins:int=after.coins
			var drops:int=hunt.state.drops.size()
			elite.take_hit(100000)
			elite.take_hit(100000)
			check(main.session.ui_state().coins==coins+3 and hunt.state.drops.size()==drops+1,"One elite receipt persists triple coins and a guaranteed item exactly once")
		await process_frame
	main._enter(0,0)
	freeze()
	var hunt=main.director
	for variant in 2:
		main.session._data.routes[0].phase="mini"
		main.session._data.routes[0].minis=variant
		hunt.sync()
		hunt._physics_process(2.01)
		check(is_instance_valid(hunt.boss) and hunt.boss.species==["deer","badger_captain"][variant],"The saved mini count chooses the first then different second guardian")
		if is_instance_valid(hunt.boss):
			hunt.boss.free()
			hunt.boss=null
	await main.prepare_shutdown()
	main.free()
	print("ECOLOGY_TEST checks=",checks," failures=",failed)
	quit(1 if failed else 0)
