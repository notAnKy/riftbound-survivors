class_name GameController
extends Node2D

# States: title, armory, settings, playing, level_up, shop, paused,
# settings_pause, game_over. Anything other than "playing" pauses the tree.

# Screens whose rows can be clicked.
const MOUSE_STATES := ["title", "armory", "shop", "settings", "settings_pause",
	"paused", "level_up"]
# Settings rows that hold a value rather than a yes/no, so left and right
# adjust them instead of activating them.
const SLIDER_ROWS := ["sfx", "music"]
const SLIDER_STEP := 0.1

# Screens that are a vertical list: up and down walk the rows, left and right
# adjust whichever row is focused.
const LIST_STATES := ["title", "settings", "settings_pause", "paused"]
# Screens laid out across the display instead. Left and right walk the row, and
# up and down step between the groups the layout is already drawn in.
const ROW_STATES := ["shop", "level_up"]

@onready var session: GameSession = $GameSession
@onready var audio: AudioSfx = $AudioSfx
@onready var ui: GameUI = $GameUI

var selected_gun := 0
var selected_character := 0
var danger := 0
var last_reward := 0
var rift_effects_enabled := true
var profile := ProfileManager.new()
var menu_hover := ""
# Which device the player last used, so every on-screen prompt names the thing
# actually in their hands instead of always naming a key.
var input_device := "keyboard"
# Stick menu navigation, latched so one flick moves one row while a held stick
# scrolls at a steady rate.
var stick_held := Vector2.ZERO
var stick_repeat := 0.0
# Which row the keyboard is on. Declared before `state` because the setter
# below resets it, and member initialisers run in declaration order.
var menu_index := 0

var state := "title":
	set(value):
		if state == value: return
		state = value
		# Landing on a new screen should always start at its first row rather
		# than wherever the last screen happened to be pointing.
		menu_index = 0
		# The shop is the exception: it opens on NEXT WAVE. Enter and Space
		# have always meant "leave the shop", and starting the cursor on an
		# offer would turn that muscle memory into an accidental purchase.
		if value == "shop": menu_index = maxi(0, menu_items().find("go"))

func _ready() -> void:
	# The actors drive themselves from _physics_process now, so pausing the
	# tree is what stops the game. These three have to keep running to draw
	# the menus, read input and feed the audio generator while it is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	audio.process_mode = Node.PROCESS_MODE_ALWAYS
	# Children default to INHERIT, which means they take the parent effective
	# mode -- so marking the controller ALWAYS silently made the whole game
	# tree unpausable, and enemies kept moving through the pause and level-up
	# menus. The session has to opt back in explicitly.
	session.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Hangs the stick and the d-pad off the movement actions the keys already
	# use, so nothing downstream has to know a controller exists.
	Gamepad.bind_movement()
	profile.load_profile()
	# Settings live in the profile now, so they survive a quit.
	rift_effects_enabled = profile.setting("rift_effects")
	audio.set_volume(profile.level("sfx_volume"))
	audio.set_music_volume(profile.level("music_volume"))
	danger = profile.max_danger()
	if profile.setting("fullscreen"): toggle_fullscreen()
	session.level_up_requested.connect(func() -> void: state = "level_up")
	session.wave_cleared.connect(func() -> void: state = "shop")
	session.run_ended.connect(on_run_ended)
	session.run_won.connect(on_run_won)
	session.rift_effects_enabled = rift_effects_enabled

# Combat and the menus get their own track; the shop counts as a menu, which
# is what makes leaving it feel like going back in.
func music_for_state() -> String:
	return "combat" if state in ["playing", "level_up", "paused"] else "menu"

func _process(delta: float) -> void:
	audio.play_music(music_for_state())
	# Restored here rather than in the session, because this node keeps
	# running while the tree is paused: pausing mid hit-stop would otherwise
	# leave the whole game at 6% speed with nothing left to undo it.
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() >= session.hitstop_until:
		Engine.time_scale = 1.0
	get_tree().paused = state != "playing"
	if state == "playing":
		session.tick(delta)
	if state in MOUSE_STATES:
		sync_hover(get_viewport().get_mouse_position())
	poll_stick(delta)
	ui.queue_redraw()

# --- menu navigation ---------------------------------------------------------

# Keep the keyboard cursor under the mouse, so the two never disagree about
# which row is about to be activated.
func sync_hover(point: Vector2) -> void:
	menu_hover = ui.menu_action_at(point)
	var hovered := menu_items().find(menu_hover)
	if hovered >= 0: menu_index = hovered

# The one definition of every list screen. The drawing, the hit-testing, the
# keyboard cursor and the controller all read this -- menu_action_at once kept
# its own copy of the settings rows, and adding a row sent every click to the
# wrong setting.
func menu_items() -> Array[String]:
	var items: Array[String] = []
	match state:
		"title": items.assign(["play", "armory", "settings", "quit"])
		"settings", "settings_pause": items.assign(["sfx", "music", "rift", "fullscreen", "back"])
		"paused": items.assign(["resume", "settings", "menu"])
		"level_up":
			if session == null: return items
			for i in range(session.upgrades.size()): items.append("upgrade_%d" % i)
		"shop":
			if session == null: return items
			# In drawing order, which is what makes left and right feel like
			# they move across the screen rather than through a list.
			for i in range(GameUI.SHOP_CARDS): items.append("buy_%d" % i)
			items.append("reroll")
			items.append("go")
			for i in range(session.weapons.size()): items.append("sell_%d" % i)
	return items

# The shop is drawn as three bands -- the offers, the two buttons, then the
# weapon slots -- so up and down move between them rather than crawling the
# whole list one card at a time.
func menu_groups() -> Array:
	if state != "shop": return []
	var offers: Array[int] = []
	var buttons: Array[int] = []
	var slots: Array[int] = []
	var items := menu_items()
	for i in range(items.size()):
		if items[i].begins_with("buy_"): offers.append(i)
		elif items[i].begins_with("sell_"): slots.append(i)
		else: buttons.append(i)
	var groups: Array = []
	for group in [offers, buttons, slots]:
		if not group.is_empty(): groups.append(group)
	return groups

func move_menu(step: int) -> void:
	var items := menu_items()
	if items.is_empty(): return
	audio.play("ui_move", -5.0)
	menu_index = wrapi(menu_index + step, 0, items.size())

func focused_action() -> String:
	var items := menu_items()
	return items[menu_index] if menu_index >= 0 and menu_index < items.size() else ""

# Up and down on a screen laid out across the display. Keeps the column, so
# stepping from the third offer down to the slots lands near where the eye
# already is rather than back at the start of the band.
func jump_group(step: int) -> void:
	var groups := menu_groups()
	if groups.is_empty():
		move_menu(step)
		return
	var here := 0
	var column := 0
	for g in range(groups.size()):
		var found: int = (groups[g] as Array).find(menu_index)
		if found >= 0:
			here = g
			column = found
	var target: Array = groups[wrapi(here + step, 0, groups.size())]
	audio.play("ui_move", -5.0)
	menu_index = int(target[mini(column, target.size() - 1)])

# One directional press, resolved against the way this screen is laid out.
# `vertical` is the axis the press came from, not the axis it ends up moving on.
func move_focus(step: int, vertical: bool) -> void:
	if state in LIST_STATES:
		if vertical:
			move_menu(step)
			return
		# Sideways on a vertical list adjusts the focused row instead: a volume
		# bar slides, and anything else simply activates.
		var row := focused_action()
		if row in SLIDER_ROWS: nudge_slider(row, SLIDER_STEP * float(step))
		else: activate_menu()
		return
	if vertical: jump_group(step)
	else: move_menu(step)

func activate_menu() -> void:
	audio.play("ui_click", -2.0)
	var items := menu_items()
	if menu_index >= 0 and menu_index < items.size():
		handle_menu_action(items[menu_index])

func start_run() -> void:
	if not profile.is_gun_unlocked(selected_gun):
		if not profile.unlock_gun(selected_gun, int(GunCatalog.get_gun(selected_gun).cost)): return
	if not profile.is_character_unlocked(selected_character):
		if not profile.unlock_character(selected_character, int(CharacterCatalog.get_character(selected_character).cost)): return
	session.selected_gun = selected_gun
	session.selected_character = selected_character
	session.danger = danger
	session.reset_run()
	session.apply_character(selected_character)
	state = "playing"

func on_run_ended() -> void:
	last_reward = session.round_number * 4 + int(session.kills / 4) + danger * 6
	profile.add_coins(last_reward)
	state = "game_over"

func on_run_won() -> void:
	# Winning pays far better than dying deep, and opens the next rung of the
	# danger ladder.
	last_reward = 120 + danger * 45 + int(session.kills / 4)
	profile.add_coins(last_reward)
	profile.record_victory(danger)
	state = "victory"

func set_danger(value: int) -> void:
	danger = clampi(value, 0, profile.max_danger())

func open_settings() -> void:
	state = "settings_pause" if state == "paused" else "settings"

func leave_settings() -> void:
	state = "paused" if state == "settings_pause" else "title"

func leave_shop() -> void:
	session.begin_round()
	state = "playing"

func handle_menu_action(action: String) -> void:
	if action.begins_with("buy_"):
		session.buy(int(action.trim_prefix("buy_")))
		return
	if action.begins_with("sell_"):
		session.sell_weapon(int(action.trim_prefix("sell_")))
		return
	if action.begins_with("danger_"):
		set_danger(int(action.trim_prefix("danger_")))
		return
	if action.begins_with("upgrade_"):
		choose_upgrade(int(action.trim_prefix("upgrade_")))
		return
	match action:
		"play": start_run()
		"armory": state = "armory"
		"settings": open_settings()
		"sfx", "music": set_slider(action, 0.0 if slider_value(action) > 0.0 else 0.7)
		"rift": toggle_rift_effects()
		"fullscreen": toggle_fullscreen()
		"resume": state = "playing"
		"menu": state = "title"
		"back": leave_back()
		"reroll": session.reroll_shop()
		"go": leave_shop()
		"quit": get_tree().quit()

# Taking a level-up reward. A level can be gained during the shop, and dropping
# straight back to "playing" from there would resume the wave with the shop
# skipped, so where this lands depends on what the session was doing.
func choose_upgrade(index: int) -> void:
	if index < 0 or index >= session.upgrades.size(): return
	session.choose_upgrade(index)
	state = "shop" if session.round_phase == "shop" else "playing"

func cycle_character(step: int) -> void:
	selected_character = wrapi(selected_character + step, 0, CharacterCatalog.all().size())
	audio.play("ui_move", -5.0)

func cycle_gun(step: int) -> void:
	selected_gun = wrapi(selected_gun + step, 0, GunCatalog.all().size())
	audio.play("ui_move", -5.0)

func leave_back() -> void:
	if state == "settings" or state == "settings_pause": leave_settings()
	else: state = "title"

func is_fullscreen() -> bool:
	var mode := get_window().mode
	return mode == Window.MODE_FULLSCREEN or mode == Window.MODE_EXCLUSIVE_FULLSCREEN

func toggle_fullscreen() -> void:
	# Borderless rather than exclusive fullscreen, so alt-tab stays instant.
	get_window().mode = Window.MODE_WINDOWED if is_fullscreen() else Window.MODE_FULLSCREEN
	profile.set_setting("fullscreen", is_fullscreen())

func slider_value(action: String) -> float:
	return audio.volume if action == "sfx" else audio.music_volume

func set_slider(action: String, value: float) -> void:
	var level := clampf(value, 0.0, 1.0)
	if action == "sfx":
		audio.set_volume(level)
		audio.play("ui_move", -4.0)
		profile.set_level("sfx_volume", level)
	else:
		audio.set_music_volume(level)
		profile.set_level("music_volume", level)

func nudge_slider(action: String, step: float) -> void:
	set_slider(action, slider_value(action) + step)

func toggle_rift_effects() -> void:
	rift_effects_enabled = not rift_effects_enabled
	session.rift_effects_enabled = rift_effects_enabled
	profile.set_setting("rift_effects", rift_effects_enabled)

# --- input -------------------------------------------------------------------

# A key and a pad button collapse to the same verb here, so every screen below
# is written once and answers to either. Adding a binding is a line in one of
# these two tables rather than a second copy of the state machine.
func key_verb(keycode: int) -> String:
	match keycode:
		KEY_UP: return "nav_up"
		KEY_DOWN: return "nav_down"
		KEY_LEFT: return "nav_left"
		KEY_RIGHT: return "nav_right"
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: return "confirm"
		KEY_ESCAPE: return "back"
	return ""

func pad_verb(button: int) -> String:
	if button == Gamepad.CROSS: return "confirm"
	if button == Gamepad.CIRCLE: return "back"
	if button == Gamepad.OPTIONS: return "pause"
	if button == Gamepad.SQUARE: return "alt"
	if button == Gamepad.TRIANGLE: return "special"
	if button == JOY_BUTTON_DPAD_UP: return "nav_up"
	if button == JOY_BUTTON_DPAD_DOWN: return "nav_down"
	if button == JOY_BUTTON_DPAD_LEFT: return "nav_left"
	if button == JOY_BUTTON_DPAD_RIGHT: return "nav_right"
	return ""

# Which device the prompts should name. Tracked in _input rather than
# _unhandled_input, because a click a menu consumes still says the player has a
# hand on the mouse.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		input_device = "pad"
	elif event is InputEventJoypadMotion:
		# A resting stick emits motion constantly, so only a real push counts.
		if absf((event as InputEventJoypadMotion).axis_value) >= Gamepad.MENU_DEADZONE:
			input_device = "pad"
	elif event is InputEventKey or event is InputEventMouse:
		input_device = "keyboard"

# The left stick walks a menu as well as the d-pad does. Latched, or a single
# push would scroll the whole list inside one frame, and clamped to one axis at
# a time, or a diagonal would move the cursor twice.
func poll_stick(delta: float) -> void:
	if not Gamepad.connected(): return
	if not (state in LIST_STATES or state in ROW_STATES or state == "armory"):
		stick_held = Vector2.ZERO
		return
	var axis := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	var pushed := Vector2.ZERO
	if absf(axis.x) >= Gamepad.MENU_DEADZONE and absf(axis.x) >= absf(axis.y): pushed.x = signf(axis.x)
	elif absf(axis.y) >= Gamepad.MENU_DEADZONE: pushed.y = signf(axis.y)
	if pushed == Vector2.ZERO:
		stick_held = Vector2.ZERO
		return
	stick_repeat -= delta
	if pushed != stick_held:
		stick_held = pushed
		stick_repeat = Gamepad.REPEAT_FIRST
	elif stick_repeat > 0.0:
		return
	else:
		stick_repeat = Gamepad.REPEAT_NEXT
	input_device = "pad"
	if pushed.y < 0.0: handle_verb("nav_up")
	elif pushed.y > 0.0: handle_verb("nav_down")
	elif pushed.x < 0.0: handle_verb("nav_left")
	else: handle_verb("nav_right")

# Everything the two devices share. Returns whether the verb was consumed, so a
# screen's own letter shortcuts only ever see what is left over.
func handle_verb(verb: String) -> bool:
	if verb == "": return false
	# Options on a pad is a dedicated pause, so it works from inside the fight
	# without also being the button that backs out of menus.
	if verb == "pause":
		if state == "playing": state = "paused"
		elif state == "paused": state = "playing"
		return true
	if state == "playing":
		match verb:
			"back":
				state = "paused"
				return true
			"alt":
				session.dash()
				return true
			"special":
				session.rift_nova()
				return true
		return false
	if state == "armory":
		match verb:
			"nav_left":
				set_danger(danger - 1)
				return true
			"nav_right":
				set_danger(danger + 1)
				return true
			"nav_up":
				cycle_character(-1)
				return true
			"nav_down":
				cycle_character(1)
				return true
			"alt":
				cycle_gun(1)
				return true
			"confirm", "back":
				state = "title"
				return true
		return false
	if state in LIST_STATES or state in ROW_STATES:
		match verb:
			"nav_up":
				move_focus(-1, true)
				return true
			"nav_down":
				move_focus(1, true)
				return true
			"nav_left":
				move_focus(-1, false)
				return true
			"nav_right":
				move_focus(1, false)
				return true
			"confirm":
				activate_menu()
				return true
	if verb == "alt" and state == "shop":
		session.reroll_shop()
		return true
	if verb == "back":
		match state:
			"settings", "settings_pause":
				leave_settings()
				return true
			"paused":
				state = "playing"
				return true
			"game_over", "victory":
				state = "title"
				return true
			# The shop and the level-up screen are each a decision the player
			# has to actually make. There is nowhere to back out to.
			"shop", "level_up":
				return true
	if verb == "confirm":
		match state:
			"game_over":
				start_run()
				return true
			"victory":
				state = "title"
				return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and state in MOUSE_STATES:
		var clicked := ui.menu_action_at(event.position)
		# A click on a slider sets it where you clicked, rather than toggling.
		if clicked in SLIDER_ROWS:
			set_slider(clicked, ui.slider_ratio_at(menu_items().find(clicked), event.position))
			return
		handle_menu_action(clicked)
		return
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		handle_verb(pad_verb((event as InputEventJoypadButton).button_index))
		return
	if not (event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo): return
	var key := event as InputEventKey
	# Fullscreen is global: it has to work from every screen, so it is handled
	# before any per-state mapping gets a look at the event. It is also
	# reachable as a settings row, since F11 is an Fn-layer key on many laptops
	# and never arrives.
	if key.keycode == KEY_F11 or (key.keycode == KEY_ENTER and key.alt_pressed):
		toggle_fullscreen()
		return
	# Space has always meant "leave the shop", whatever the cursor happens to be
	# resting on, so it is answered before it can be read as a plain confirm.
	if state == "shop" and key.keycode == KEY_SPACE:
		leave_shop()
		return
	if handle_verb(key_verb(key.keycode)): return
	# What is left is each screen's own letter shortcuts. Arrows, Enter, Space
	# and Escape never reach here -- they are verbs, and work on a pad too.
	if state == "title":
		if key.keycode == KEY_P: handle_menu_action("play")
		elif key.keycode == KEY_A: handle_menu_action("armory")
		elif key.keycode == KEY_S: handle_menu_action("settings")
		elif key.keycode == KEY_Q: handle_menu_action("quit")
	elif state == "armory":
		if key.keycode >= KEY_1 and key.keycode <= KEY_3: selected_gun = key.keycode - KEY_1
		elif key.keycode == KEY_C: cycle_character(1)
		elif key.keycode == KEY_X: cycle_character(-1)
		elif key.keycode == KEY_B: state = "title"
	elif state == "settings" or state == "settings_pause":
		if key.keycode == KEY_V: toggle_rift_effects()
		elif key.keycode == KEY_F: toggle_fullscreen()
	elif state == "paused":
		if key.keycode == KEY_S: open_settings()
		elif key.keycode == KEY_Q: state = "title"
	elif state == "shop":
		if key.keycode >= KEY_1 and key.keycode <= KEY_4: session.buy(key.keycode - KEY_1)
		elif key.keycode == KEY_R: session.reroll_shop()
	elif state == "level_up":
		if key.keycode >= KEY_1 and key.keycode <= KEY_4: choose_upgrade(key.keycode - KEY_1)
	elif state == "playing":
		if key.keycode == KEY_Q: session.dash()
		elif key.keycode == KEY_E: session.rift_nova()
