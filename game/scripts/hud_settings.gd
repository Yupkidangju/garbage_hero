extends RefCounted

const DEFAULT_PATH = "user://interface.cfg"
const ACTIONS = ["move_up","move_left","move_down","move_right","attack","dodge","hook","spin","slam","interact","inventory","skills","map"]
const S = preload("res://scripts/hud_style.gd")
var prefs := {"text_scale":1.0,"screen_shake":true,"reduced_flash":false}
var settings_path := DEFAULT_PATH
var bindings: Dictionary = {}
var defaults: Dictionary = {}

func start() -> void:
	var override := OS.get_environment("GARBAGEHERO_SETTINGS_PATH")
	if override != "": settings_path = override
	for action in ACTIONS:
		if InputMap.has_action(action):
			defaults[action] = InputMap.action_get_events(action)
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK: return
	var scale_value = cfg.get_value("display","text_scale",1.0)
	if scale_value in [1.0,1.25,1.5]:
		prefs.text_scale = float(scale_value)
	for option in ["screen_shake","reduced_flash"]:
		var saved = cfg.get_value("display",option,prefs[option])
		if saved is bool: prefs[option] = saved
	for action in ACTIONS:
		var saved = cfg.get_value("input",action,[])
		if not saved is Array or saved.size()!=2 or not defaults.has(action): continue
		if typeof(saved[0])!=TYPE_STRING or typeof(saved[1])!=TYPE_INT or saved[1]<=0: continue
		var event: InputEvent
		if saved[0]=="key":
			event = InputEventKey.new()
			event.physical_keycode = saved[1]
		elif saved[0]=="mouse" and saved[1] in [1,2,3,8,9]:
			event = InputEventMouseButton.new()
			event.button_index = saved[1]
		else: continue
		_apply(action,event)
	_keep_growth_shortcut_free()

func _key_in_use(event: InputEvent, except_action: String) -> bool:
	for action in ACTIONS:
		if action==except_action or not InputMap.has_action(action): continue
		for existing in InputMap.action_get_events(action):
			if S.key_name(existing)==S.key_name(event): return true
	return false

func _keep_growth_shortcut_free() -> void:
	if not InputMap.has_action("skills"): return
	var current := InputMap.action_get_events("skills")
	if not current.is_empty() and not _key_in_use(current[0],"skills"): return
	# 구버전에서 이미 사용하던 K는 원래 동작에 남기고 성장 화면에 빈 키를 배정한다.
	for code in [KEY_J,KEY_G,KEY_H,KEY_U,KEY_Y,KEY_T,KEY_B,KEY_N,KEY_V,KEY_C,KEY_Z,KEY_X,KEY_P,KEY_O,KEY_L,KEY_1]:
		var fallback := InputEventKey.new()
		fallback.physical_keycode = code
		if not _key_in_use(fallback,"skills"):
			_apply("skills",fallback)
			return
	InputMap.action_erase_events("skills")
	bindings.erase("skills")

func _apply(action: String, event: InputEvent) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action,event)
	bindings[action] = ["key",event.physical_keycode] if event is InputEventKey else ["mouse",event.button_index]

func remap(action: String, input: InputEvent) -> String:
	var event: InputEvent
	if input is InputEventKey:
		if not input.pressed or input.echo: return ""
		if input.keycode in [KEY_TAB,KEY_ENTER,KEY_KP_ENTER,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_ESCAPE,KEY_SHIFT,KEY_ALT,KEY_CTRL,KEY_META] or input.alt_pressed or input.ctrl_pressed or input.meta_pressed:
			return "key_reserved"
		event = InputEventKey.new()
		event.physical_keycode = input.physical_keycode if input.physical_keycode else input.keycode
	elif input is InputEventMouseButton:
		if not input.pressed or input.button_index not in [1,2,3,8,9]: return ""
		event = InputEventMouseButton.new()
		event.button_index = input.button_index
	else: return ""
	if _key_in_use(event,action): return "key_used"
	_apply(action,event)
	return "ok"

func reset() -> void:
	for action in defaults:
		InputMap.action_erase_events(action)
		for event in defaults[action]:
			InputMap.action_add_event(action,event)
	bindings.clear()

func save() -> Error:
	var cfg := ConfigFile.new()
	for key in prefs: cfg.set_value("display",key,prefs[key])
	for key in bindings: cfg.set_value("input",key,bindings[key])
	return cfg.save(settings_path)
