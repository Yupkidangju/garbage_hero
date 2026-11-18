extends SceneTree

const MAIN = preload("res://scenes/main.tscn")
var sandbox: DirAccess
var children: Array[int]=[]
var failures:=0

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==3:
		worker.call_deferred(args[0],args[1],args[2])
	else:
		run.call_deferred()

func write_message(path:String,value:String) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(value)
	file.close()

func worker(slot:String,channel:String,label:String) -> void:
	OS.set_environment("GARBAGEHERO_SAVE_DIR",slot)
	var game=MAIN.instantiate()
	root.add_child(game)
	var status:="active" if is_instance_valid(game.player) else "blocked:"+str(game.session.last_error)
	write_message(channel.path_join(label+".ready"),status)
	var until:=Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<until:
		for cmd:String in ["retry","write","quit"]:
			var request:=channel.path_join(label+"."+cmd)
			if not FileAccess.file_exists(request): continue
			DirAccess.remove_absolute(request)
			if cmd=="quit":
				quit()
				return
			var outcome:="failed"
			if cmd=="write" and game.session.act("auto",{"enabled":false}):
				outcome="saved"
			elif cmd=="retry":
				game._retry_saves()
				if is_instance_valid(game.player) and not game.session.ui_state().auto:
					outcome="restored"
			write_message(request+".result",outcome)
		await create_timer(.05,true).timeout
	quit(1)

func launch(slot:String,label:String) -> int:
	var tmp:=sandbox.get_current_dir()
	var args:=["--headless","--path",ProjectSettings.globalize_path("res://"),"--log-file",tmp.path_join(label+".log"),
		"--script","res://tests/save_guard_test.gd","--",slot,tmp,label]
	var pid:=OS.create_process(OS.get_executable_path(),args)
	if pid>0: children.append(pid)
	return pid

func receive(name:String) -> String:
	var path:=sandbox.get_current_dir().path_join(name)
	var until:=Time.get_ticks_msec()+18000
	while Time.get_ticks_msec()<until:
		if FileAccess.file_exists(path):
			var data:=FileAccess.get_file_as_string(path)
			if not data.is_empty(): return data
		await create_timer(.05,true).timeout
	return ""

func send(cmd:String) -> void:
	write_message(sandbox.get_current_dir().path_join(cmd),"go")

func banks(path:String) -> String:
	var sum:=""
	for i in 2:
		var bank:=path.path_join("slot-v2-%d.sav"%i)
		if FileAccess.file_exists(bank): sum+=FileAccess.get_sha256(bank)
	return sum

func expect(ok:bool,detail:String) -> bool:
	if not ok:
		push_error(detail)
		failures+=1
	return ok

func stopped(pid:int) -> bool:
	var until:=Time.get_ticks_msec()+8000
	while OS.is_process_running(pid) and Time.get_ticks_msec()<until:
		await create_timer(.05,true).timeout
	return not OS.is_process_running(pid)

func run() -> void:
	sandbox=DirAccess.create_temp("garbagehero-writer-")
	var tmp:=sandbox.get_current_dir()
	var slot:=tmp.path_join("one")
	var alias:=slot.path_join("unused/../.")
	if OS.get_name()=="Windows": alias=alias.to_upper().replace("/","\\")
	var owner:=launch(slot,"owner")
	if expect(await receive("owner.ready")=="active","첫 창이 슬롯을 열지 못했다"):
		var original:=banks(slot)
		var second:=launch(alias,"second")
		launch(tmp.path_join("separate"),"other")
		expect((await receive("second.ready")).begins_with("blocked:"),"같은 저장의 두 번째 창을 차단해야 한다")
		expect(await receive("other.ready")=="active","별도 저장은 동시에 열려야 한다")
		expect(not original.is_empty() and banks(slot)==original,"대기 창이 기존 저장을 변경했다")
		send("owner.write")
		expect(await receive("owner.write.result")=="saved" and banks(slot)!=original,"첫 창이 계속 저장해야 한다")
		send("owner.quit")
		expect(await stopped(owner),"첫 창 정상 종료")
		send("second.retry")
		expect(await receive("second.retry.result")=="restored","정상 종료 후 대기 창에서 이전 저장을 재개해야 한다")
		if second>0 and OS.is_process_running(second):
			OS.kill(second)
			expect(await stopped(second),"시험용 두 번째 창 강제 종료")
		launch(slot,"restart")
		expect(await receive("restart.ready")=="active","강제 종료 뒤 같은 저장이 열려야 한다")
		send("restart.quit")
		send("other.quit")
	for child:int in children:
		if OS.is_process_running(child) and not await stopped(child):
			OS.kill(child)
	print("save guard: cross-process ownership, separate slot, first writer, normal exit, force-stop and retry: %s failures"%failures)
	quit(1 if failures else 0)
