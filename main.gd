class_name GameController
extends Node2D

# States: title, armory, settings, playing, level_up, shop, paused,
# settings_pause, game_over. Anything other than "playing" pauses the tree.

# Screens whose rows can be clicked.
const MOUSE_STATES := ["title", "armory", "shop", "settings", "settings_pause", "paused"]
# Settings rows that hold a value rather than a yes/no, so left and right
# adjust them instead of activating them.
const SLIDER_ROWS := ["sfx", "music"]
const SLIDER_STEP := 0.1

# Screens that are a vertical list, driven with the arrow keys and Enter.
const MENU_STATES := ["title", "settings", "settings_pause", "paused"]

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
	ui.queue_redraw()

# --- menu navigation ---------------------------------------------------------

# Keep the keyboard cursor under the mouse, so the two never disagree about
# which row is about to be activated.
func sync_hover(point: Vector2) -> void:
	menu_hover = ui.menu_action_at(point)
	var hovered := menu_items().find(menu_hover)
	if hovered >= 0: menu_index = hovered

func menu_items() -> Array[String]:
	match state:
		"title": return ["play", "armory", "settings", "quit"]
		"settings", "settings_pause": return ["sfx", "music", "rift", "fullscreen", "back"]
		"paused": return ["resume", "settings", "menu"]
	return []

func move_menu(step: int) -> void:
	var items := menu_items()
	if items.is_empty(): return
	audio.play("ui_move", -5.0)
	menu_index = wrapi(menu_index + step, 0, items.size())

func focused_action() -> String:
	var items := menu_items()
	return items[menu_index] if menu_index >= 0 and menu_index < items.size() else ""

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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and state in MOUSE_STATES:
		var clicked := ui.menu_action_at(event.position)
		# A click on a slider sets it where you clicked, rather than toggling.
		if clicked in SLIDER_ROWS:
			set_slider(clicked, ui.slider_ratio_at(menu_items().find(clicked), event.position))
			return
		handle_menu_action(clicked)
		return
	if not (event is InputEventKey and event.pressed and not event.echo): return
	# Fullscreen is global: it has to work from every screen, so it is handled
	# before any per-state key mapping gets a look at the event. It is also
	# reachable as a settings row, since F11 is an Fn-layer key on many
	# laptops and never arrives.
	if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
		toggle_fullscreen()
		return
	# Arrow-key navigation for every screen that is a vertical list.
	if state in MENU_STATES:
		match event.keycode:
			KEY_UP:
				move_menu(-1)
				return
			KEY_DOWN:
				move_menu(1)
				return
			KEY_LEFT, KEY_RIGHT:
				var step: float = SLIDER_STEP if event.keycode == KEY_RIGHT else -SLIDER_STEP
				var row := focused_action()
				if row in SLIDER_ROWS: nudge_slider(row, step)
				else: activate_menu()
				return
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				activate_menu()
				return
	if state == "title":
		if event.keycode == KEY_P: handle_menu_action("play")
		elif event.keycode == KEY_A: handle_menu_action("armory")
		elif event.keycode == KEY_S: handle_menu_action("settings")
		elif event.keycode == KEY_Q: handle_menu_action("quit")
	elif state == "armory":
		if event.keycode >= KEY_1 and event.keycode <= KEY_3: selected_gun = event.keycode - KEY_1
		elif event.keycode == KEY_C: selected_character = (selected_character + 1) % CharacterCatalog.all().size()
		elif event.keycode == KEY_LEFT: set_danger(danger - 1)
		elif event.keycode == KEY_RIGHT: set_danger(danger + 1)
		elif event.keycode == KEY_ESCAPE or event.keycode == KEY_B: state = "title"
	elif state == "settings" or state == "settings_pause":
		if event.keycode == KEY_V: toggle_rift_effects()
		elif event.keycode == KEY_F: toggle_fullscreen()
		elif event.keycode == KEY_ESCAPE: leave_settings()
	elif state == "paused":
		if event.keycode == KEY_ESCAPE: state = "playing"
		elif event.keycode == KEY_S: open_settings()
		elif event.keycode == KEY_Q: state = "title"
	elif state == "shop":
		if event.keycode >= KEY_1 and event.keycode <= KEY_4: session.buy(event.keycode - KEY_1)
		elif event.keycode == KEY_R: session.reroll_shop()
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER: leave_shop()
	elif state == "level_up":
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			var choice: int = event.keycode - KEY_1
			if choice < session.upgrades.size():
				session.choose_upgrade(choice)
				# A level can be gained during the shop, and returning to
				# "playing" there would resume the wave with the shop skipped.
				state = "shop" if session.round_phase == "shop" else "playing"
	elif state == "game_over":
		if event.keycode == KEY_SPACE: start_run()
		elif event.keycode == KEY_ESCAPE: state = "title"
	elif state == "victory":
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE: state = "title"
	elif state == "playing":
		if event.keycode == KEY_ESCAPE: state = "paused"
		elif event.keycode == KEY_Q: session.dash()
		elif event.keycode == KEY_E: session.rift_nova()
