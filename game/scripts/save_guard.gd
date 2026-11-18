extends RefCounted

# 루프백 수신 소켓 하나를 저장 폴더에 대응시킨다. 운영체제가 소유 프로세스 종료 시 소켓을 회수한다.
var _listener: TCPServer
var _key := ""
var directory := ""

func acquire(folder: String) -> Error:
	var path := _resolve_links(_absolute(folder))
	if path.is_empty():
		return ERR_FILE_BAD_PATH
	var key:=path
	if OS.get_name()=="Windows":
		key=key.to_lower()
	if _listener and key==_key:
		return OK
	var digest := ("GarbageHero/save-writer/"+key).sha256_buffer()
	var address := "127.0.0.1"
	if OS.get_name() in ["Windows","Linux"]:
		address="127.%d.%d.%d" % [1+int(digest[0])%254,digest[1],1+int(digest[2])%254]
	var port := 23000 + ((int(digest[3])<<8)|int(digest[4]))%22000
	var candidate := TCPServer.new()
	var result := candidate.listen(port,address)
	if result==OK:
		_listener=candidate
		directory=path
		_key=key
	return result

static func _absolute(path: String) -> String:
	var full := ProjectSettings.globalize_path(path.replace("\\","/"))
	if full.begins_with("//?/UNC/"):
		full="//"+full.substr(8)
	elif full.begins_with("//?/"):
		full=full.substr(4)
	if not full.is_absolute_path():
		full=DirAccess.open(".").get_current_dir().path_join(full)
	return full.simplify_path().trim_suffix("/") if full.length()>3 else full

static func _resolve_links(path: String) -> String:
	# 상위 폴더의 정션을 거친 경로도 원본 저장 폴더와 같은 키로 정규화한다.
	var current:=path
	for _hop in 32:
		var cursor:=current
		var changed:=false
		while not cursor.is_empty():
			var parent:=cursor.get_base_dir()
			if parent==cursor or parent.is_empty(): break
			var dir:=DirAccess.open(parent)
			if dir and dir.is_link(cursor):
				var target:=dir.read_link(cursor).replace("\\","/")
				if target.is_empty(): return ""
				if not target.is_absolute_path(): target=parent.path_join(target)
				current=_absolute(target+current.substr(cursor.length()))
				changed=true
				break
			cursor=parent
		if not changed: return current
	return ""
