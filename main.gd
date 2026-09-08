class_name GameController
extends Node2D

# States: title, armory, settings, playing, level_up, shop, paused,
# settings_pause, game_over. Anything other than "playing" pauses the tree.

# Screens whose rows can be clicked.
const MOUSE_STATES := ["title", "armory", "shop", "settings", "settings_pause",
	"paused", "level_up", "confirm_quit", "lobby", "controls"]
# Settings rows that hold a value rather than a yes/no, so left and right
# adjust them instead of activating them.
const SLIDER_ROWS := ["sfx", "music"]
# Settings rows that step through a list. Left and right cycle them, the same
# way left and right slide a volume bar.
const CHOICE_ROWS := ["window", "resolution", "quality", "fps"]
# A single tap is a fine nudge; holding the direction sweeps at SLIDER_RATE of
# the full range per second. One step per press made a volume bar something you
# could only move in chunks, which is not what a slider is for.
const SLIDER_STEP := 0.05
const SLIDER_RATE := 0.8

# How far the mouse has to actually move to take control back from a pad. A
# mouse emits sub-pixel jitter on its own, and a nudged desk should not pop the
# cursor back over a menu somebody is steering with a stick.
const MOUSE_WAKE := 2.0

# Screens that are a vertical list: up and down walk the rows, left and right
# adjust whichever row is focused.
const LIST_STATES := ["title", "settings", "settings_pause", "paused", "confirm_quit"]
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
# Achievements the run that just ended earned, so the end screen can say so.
var last_earned: Array[String] = []
var rift_effects_enabled := true
var profile := ProfileManager.new()
var menu_hover := ""
# Whether the pointer currently owns the menu cursor. The shop and the level-up
# screen are wall-to-wall cards, so a mouse resting anywhere on them was re-read
# every frame and hauled the cursor straight back off whatever an arrow key had
# just selected -- the arrow keys looked dead. A directional press takes the
# cursor; the pointer takes it back only by genuinely moving, which is the same
# arbitration MOUSE_WAKE already runs between the mouse and a pad.
var mouse_leads := true
# Where the pointer was the last time it was the thing driving. The keys freeze
# it, so the distance measured against it is how far the mouse has moved since
# it lost the cursor rather than since the last frame.
var mouse_anchor := Vector2.ZERO
# Two players at one machine. The keyboard drives seat 0 and the pad seat 1;
# solo leaves this false and everything below collapses back to one seat.
var coop := false
# The co-op join screen. Held here rather than on the session because none of
# the survivors exist until what is decided here is handed to reset_run.
var lobby := Lobby.new()
# Which device the player last used, so every on-screen prompt names the thing
# actually in their hands instead of always naming a key.
var input_device := "keyboard":
	set(value):
		if input_device == value: return
		input_device = value
		# A cursor is meaningless while a pad is driving, and it sits on top of
		# a menu it is not steering. Moving the mouse brings it straight back --
		# MOUSE_MODE_HIDDEN still delivers motion events, unlike CAPTURED.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if mouse_active() else Input.MOUSE_MODE_HIDDEN
		# In co-op somebody is always on the keyboard, so the pad taking a turn
		# must not take the cursor away from them.
		# Hover must not outlive the switch. sync_hover stops running on a pad,
		# so a stale menu_hover would leave a row lit that nothing is on.
		if value == "pad": menu_hover = ""
# Stick menu navigation, latched so one flick moves one row while a held stick
# scrolls at a steady rate.
# Per pad, not per game. Polling only joypad 0 meant a second controller could
# not steer a menu at all, and a single pad that Windows enumerated as index 1
# could not either -- which is what "sometimes it works, sometimes it does not"
# was made of.
var stick_held: Dictionary = {}
var stick_repeat: Dictionary = {}
# The volume row currently being dragged with the mouse, so a bar can be swept
# rather than only clicked at a point.
var dragging := ""
# A slider moved but has not been written to the profile yet, and the level at
# which the last preview blip played.
var slider_dirty := false
var slider_tick := -1.0
# One menu cursor per seat: in co-op the two players steer separate lists on
# separate halves of the screen. Declared before `state` because the setter
# below resets them, and member initialisers run in declaration order.
var cursors: Array[int] = [0, 0]

# Seat 0's cursor under its old name, for every solo path and the whole suite.
var menu_index: int:
	get: return cursors[0]
	set(value): cursors[0] = value

func cursor(at_seat: int) -> int:
	return cursors[clampi(at_seat, 0, cursors.size() - 1)]

func set_cursor(at_seat: int, value: int) -> void:
	cursors[clampi(at_seat, 0, cursors.size() - 1)] = value

# Which player an input belongs to. Solo has one seat and everything lands on
# it; co-op splits by device, which is the whole reason Controls exists.
# Which player an input belongs to. Solo has one seat and everything lands on
# it; co-op looks up the device that actually claimed a seat in the lobby, so
# two pads work as readily as a pad and a keyboard.
func seat_for(device: String) -> int:
	if not coop: return 0
	# Once a run exists the session is the authority on who holds what; the
	# lobby only answers before there are any survivors to ask.
	for i in range(session.seats()):
		var who := session.seat(i)
		if who != null and who.device == device: return i
	var seat := lobby.seat_device.find(device)
	return seat if seat >= 0 else 0

func seat_count() -> int:
	return 2 if coop else 1

var state := "title":
	set(value):
		if state == value: return
		state = value
		# Landing on a new screen should always start at its first row rather
		# than wherever the last screen happened to be pointing.
		for i in range(cursors.size()): cursors[i] = 0
		# The shop is the exception: it opens on NEXT WAVE. Enter and Space
		# have always meant "leave the shop", and starting the cursor on an
		# offer would turn that muscle memory into an accidental purchase.
		if value == "shop":
			for i in range(cursors.size()): cursors[i] = maxi(0, menu_items(i).find("go"))
		# A confirmation opens on the harmless answer, so a reflexive Enter or
		# Cross keeps the run rather than throwing it away.
		if value == "confirm_quit": menu_index = maxi(0, menu_items().find("keep_playing"))

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
	# And registers the per-device sets co-op reads. Without this the kb_* and
	# pad_* actions simply do not exist, get_vector reads zero for both seats,
	# and neither player can move at all.
	Controls.bind_all()
	profile.load_profile()
	# Settings live in the profile now, so they survive a quit.
	rift_effects_enabled = profile.setting("rift_effects")
	audio.set_volume(profile.level("sfx_volume"))
	audio.set_music_volume(profile.level("music_volume"))
	danger = profile.max_danger()
	# One call for window mode, resolution and quality: boot and a settings
	# change take the same path, so they cannot disagree.
	apply_display()
	session.level_up_requested.connect(func() -> void: state = "level_up")
	session.wave_cleared.connect(func() -> void: state = "shop")
	session.run_ended.connect(on_run_ended)
	session.run_won.connect(on_run_won)
	session.rift_effects_enabled = rift_effects_enabled

# Combat and the menus get their own track; the shop counts as a menu, which
# is what makes leaving it feel like going back in.
func music_for_state() -> String:
	return "combat" if state in ["playing", "level_up", "paused", "confirm_quit"] else "menu"

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
	# Not while a pad is driving. The OS mouse stays parked wherever it was left,
	# so syncing from it would haul the menu cursor back onto that row every
	# frame and the d-pad would appear to do nothing at all.
	follow_pointer(get_viewport().get_mouse_position())
	# Buying, selling and combining all shorten the list under the cursor, so
	# clamp here rather than at each of the places that can shorten it.
	for seat in range(seat_count()):
		var rows := menu_items(seat).size()
		if rows > 0: set_cursor(seat, clampi(cursor(seat), 0, rows - 1))
	poll_stick(delta)
	poll_lobby(delta)
	# Both ways of sweeping a volume bar, and one disk write when the sweep
	# stops rather than sixty a second while it is happening.
	var swept := drag_slider()
	if poll_slider(delta): swept = true
	if slider_dirty and not swept:
		slider_dirty = false
		profile.save_profile()
	ui.queue_redraw()

# --- menu navigation ---------------------------------------------------------

# The pointer's claim on the menu cursor, settled once a frame. Takes the
# position rather than reading the viewport so a test can park a mouse on a
# card, which is the whole shape of the bug this arbitration exists for.
func follow_pointer(point: Vector2) -> void:
	if not (state in MOUSE_STATES and mouse_active()):
		mouse_anchor = point
		return
	if not mouse_leads and point.distance_to(mouse_anchor) >= MOUSE_WAKE:
		mouse_leads = true
	if not mouse_leads: return
	mouse_anchor = point
	sync_hover(point)

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
# Whether the mouse is currently the thing driving. Both the cursor and the
# hover sync hang off this, so they can never disagree about who is in control.
func mouse_active() -> bool:
	return coop or input_device != "pad"

func menu_items(at_seat: int = 0) -> Array[String]:
	var items: Array[String] = []
	match state:
		"title": items.assign(["play", "coop", "armory", "awards", "settings", "quit"])
		"settings", "settings_pause": items.assign(["sfx", "music", "window", "resolution", "quality", "fps", "showfps", "rift", "controls", "back"])
		"paused": items.assign(["resume", "settings", "menu"])
		"confirm_quit": items.assign(["quit_run", "keep_playing"])
		"level_up":
			if session == null: return items
			if session.seat(at_seat) == null: return items
			for i in range(session.seat(at_seat).upgrades.size()): items.append("upgrade_%d" % i)
		"shop":
			if session == null: return items
			# Checked before the loop, not after it. The loop below dereferences
			# the seat, so a null test underneath it never ran in time.
			var who := session.seat(at_seat)
			if who == null: return items
			# In drawing order, which is what makes left and right feel like
			# they move across the screen rather than through a list.
			for i in range(GameUI.SHOP_CARDS):
				# A sold card is not something the cursor can land on. It was,
				# so walking the shop with a pad hit dead stops on everything
				# already bought -- and the pin beside it was reachable too.
				if offer_empty(who.shop, i) and not who.shop.is_locked(i): continue
				items.append("buy_%d" % i)
				# The pin chip is deliberately *not* in this list. It is still
				# clickable -- menu_action_at hit-tests it directly -- but a pad
				# already pins with `alt` from anywhere on the card, so stopping
				# the cursor on a tiny chip on the way past buys nothing.
			items.append("reroll")
			items.append("go")
			for i in range(who.weapons.size()):
				items.append("sell_%d" % i)
				if session.can_combine(i, at_seat): items.append("combine_%d" % i)
	return items

# The shop is drawn as three bands -- the offers, the two buttons, then the
# weapon slots -- so up and down move between them rather than crawling the
# whole list one card at a time.
# A sold slot has nothing to pin.
func offer_empty(board: Shop, index: int) -> bool:
	return index >= board.offers.size() or board.offers[index].is_empty()

func menu_groups(at_seat: int = 0) -> Array:
	if state != "shop": return []
	var offers: Array[int] = []
	var buttons: Array[int] = []
	var slots: Array[int] = []
	var items := menu_items(at_seat)
	for i in range(items.size()):
		if items[i].begins_with("buy_") or items[i].begins_with("lock_"): offers.append(i)
		elif items[i].begins_with("sell_") or items[i].begins_with("combine_"): slots.append(i)
		else: buttons.append(i)
	var groups: Array = []
	for group in [offers, buttons, slots]:
		if not group.is_empty(): groups.append(group)
	return groups

func move_menu(step: int, at_seat: int = 0) -> void:
	var items := menu_items(at_seat)
	if items.is_empty(): return
	audio.play("ui_move")
	set_cursor(at_seat, wrapi(cursor(at_seat) + step, 0, items.size()))

func focused_action(at_seat: int = 0) -> String:
	var items := menu_items(at_seat)
	var index := cursor(at_seat)
	return items[index] if index >= 0 and index < items.size() else ""

# Up and down on a screen laid out across the display. Keeps the column, so
# stepping from the third offer down to the slots lands near where the eye
# already is rather than back at the start of the band.
func jump_group(step: int, at_seat: int = 0) -> void:
	var groups := menu_groups(at_seat)
	if groups.is_empty():
		move_menu(step, at_seat)
		return
	var here := 0
	var column := 0
	for g in range(groups.size()):
		var found: int = (groups[g] as Array).find(cursor(at_seat))
		if found >= 0:
			here = g
			column = found
	var target: Array = groups[wrapi(here + step, 0, groups.size())]
	audio.play("ui_move")
	set_cursor(at_seat, int(target[mini(column, target.size() - 1)]))

# A directional press takes the cursor off the pointer until the pointer moves
# again. Only seat 0 is ever steered by a mouse, so seat 1's pad must not clear
# the hover its team-mate is still using.
func take_cursor_from_pointer(at_seat: int) -> void:
	if at_seat != 0: return
	mouse_leads = false
	menu_hover = ""

# One directional press, resolved against the way this screen is laid out.
# `vertical` is the axis the press came from, not the axis it ends up moving on.
func move_focus(step: int, vertical: bool, at_seat: int = 0) -> void:
	take_cursor_from_pointer(at_seat)
	if state in LIST_STATES:
		if vertical:
			move_menu(step, at_seat)
			return
		# Sideways on a vertical list adjusts the focused row instead: a volume
		# bar slides, and anything else simply activates.
		var row := focused_action(at_seat)
		if row in SLIDER_ROWS: nudge_slider(row, SLIDER_STEP * float(step))
		elif row in CHOICE_ROWS: cycle_choice(row, step)
		else: activate_menu(at_seat)
		return
	if vertical: jump_group(step, at_seat)
	else: move_menu(step, at_seat)

func activate_menu(at_seat: int = 0) -> void:
	audio.play("ui_click")
	var items := menu_items(at_seat)
	var index := cursor(at_seat)
	if index >= 0 and index < items.size():
		handle_menu_action(items[index], at_seat)

# CO-OP does not start a run: it opens the screen where two people join, pick a
# survivor each and pick a starting weapon each. Only the last of those starts
# anything.
func open_lobby() -> void:
	coop = true
	lobby.reset(profile.unlocked_guns_or_characters("characters"),
		profile.unlocked_guns_or_characters("guns"))
	state = "lobby"

# Joining is a hold, so it is polled rather than driven off a key event: a tap
# must not sign anybody up.
func poll_lobby(delta: float) -> void:
	if state != "lobby": return
	# Polled per device rather than per seat: which seat somebody lands in is
	# decided by the order the holds finish, not by what they are holding.
	for device in Controls.join_candidates():
		var seat := lobby.tick_join(String(device), delta, Controls.join_held(String(device)))
		if seat >= 0:
			input_device = "pad" if Controls.is_pad(String(device)) else "keyboard"
			audio.play("ui_click")

# The lobby is not a list: each seat steers its own row, and nobody moves on
# until every seat has locked its pick.
func lobby_verb(verb: String, at_seat: int) -> bool:
	if not bool(lobby.joined[at_seat]):
		# An unjoined seat can only back out, and only if it is the last one on
		# the screen -- otherwise Circle would eject the player who did join.
		if verb == "back" and lobby.count() == 0:
			leave_lobby()
			return true
		return false
	match verb:
		"nav_left", "nav_up":
			lobby.move(at_seat, -1)
			audio.play("ui_move")
			return true
		"nav_right", "nav_down":
			lobby.move(at_seat, 1)
			audio.play("ui_move")
			return true
		"confirm":
			if not lobby.locked[at_seat]:
				lobby.locked[at_seat] = true
				audio.play("ui_click")
			advance_lobby()
			return true
		"back":
			back_out_of_lobby(at_seat)
			return true
	return false

# Nobody moves on alone: the stage changes only once both seats have locked,
# and the last stage starts the run rather than advancing.
func advance_lobby() -> void:
	if not lobby.all_locked(): return
	if lobby.last_stage():
		start_run(true)
		return
	lobby.advance()

# Back always undoes the last thing this seat did: its lock, then the stage,
# then its own place on the screen.
func back_out_of_lobby(at_seat: int) -> void:
	if bool(lobby.locked[at_seat]):
		lobby.locked[at_seat] = false
		return
	if lobby.step_back(): return
	lobby.joined[at_seat] = false
	lobby.hold[at_seat] = 0.0
	if lobby.count() == 0: leave_lobby()

func leave_lobby() -> void:
	coop = false
	state = "title"

func start_run(two_player: bool = false) -> void:
	coop = two_player
	if not profile.is_gun_unlocked(selected_gun):
		if not profile.unlock_gun(selected_gun, int(GunCatalog.get_gun(selected_gun).cost)): return
	# Characters are earned now, not bought, so this refuses rather than silently
	# starting a run as somebody the player has not unlocked.
	if not profile.is_character_unlocked(selected_character): return
	session.selected_gun = selected_gun
	session.selected_character = selected_character
	session.danger = danger
	session.coop = coop
	# Empty in solo, so build_survivor falls back to the armory selection.
	var picked_characters: Array[int] = lobby.characters() if coop else ([] as Array[int])
	var picked_guns: Array[int] = lobby.guns() if coop else ([] as Array[int])
	session.seat_characters = picked_characters
	session.seat_guns = picked_guns
	# Which physical device drives which seat, in join order.
	session.seat_devices = lobby.seat_device.duplicate() if coop else []
	session.reset_run()
	# No argument: every survivor keeps the character it was built with, which in
	# co-op is the one that seat picked for itself.
	session.apply_character()
	state = "playing"

func on_run_ended() -> void:
	last_reward = session.round_number * 4 + int(session.kills / 4) + danger * 6
	profile.add_coins(last_reward)
	last_earned = profile.award_all(session.run_summary())
	if not last_earned.is_empty(): audio.play("level_up")
	state = "game_over"

func on_run_won() -> void:
	# Winning pays far better than dying deep, and opens the next rung of the
	# danger ladder.
	last_reward = 120 + danger * 45 + int(session.kills / 4)
	profile.add_coins(last_reward)
	profile.record_victory(danger)
	last_earned = profile.award_all(session.run_summary())
	state = "victory"

func set_danger(value: int) -> void:
	danger = clampi(value, 0, profile.max_danger())

func open_settings() -> void:
	state = "settings_pause" if state == "paused" else "settings"

func leave_settings() -> void:
	state = "paused" if state == "settings_pause" else "title"

# Which settings screen opened the controls list, so backing out of it returns
# where it came from rather than always to the title.
var controls_from := "settings"

func open_controls() -> void:
	controls_from = state
	state = "controls"

# Both seats have to press NEXT WAVE, or one player would drag the other out of
# the shop mid-purchase. The button reads READY for whoever has already pressed.
func leave_shop(at_seat: int = 0) -> void:
	if not session.mark_ready(at_seat): return
	session.begin_round()
	state = "playing"

func handle_menu_action(action: String, at_seat: int = 0) -> void:
	if action.begins_with("buy_"):
		session.buy(int(action.trim_prefix("buy_")), at_seat)
		clamp_focus(at_seat)
		return
	if action.begins_with("sell_"):
		session.sell_weapon(int(action.trim_prefix("sell_")), at_seat)
		clamp_focus(at_seat)
		return
	if action.begins_with("lock_"):
		session.toggle_lock(int(action.trim_prefix("lock_")), at_seat)
		return
	if action.begins_with("combine_"):
		session.combine_weapon(int(action.trim_prefix("combine_")), at_seat)
		clamp_focus(at_seat)
		return
	if action.begins_with("gun_"):
		selected_gun = int(action.trim_prefix("gun_"))
		return
	if action.begins_with("danger_"):
		set_danger(int(action.trim_prefix("danger_")))
		return
	if action.begins_with("pick_"):
		lobby.set_selection(at_seat, int(action.trim_prefix("pick_")))
		return
	if action.begins_with("upgrade_"):
		choose_upgrade(int(action.trim_prefix("upgrade_")), at_seat)
		return
	match action:
		"play": start_run(false)
		"coop": open_lobby()
		"armory": state = "armory"
		"awards": state = "awards"
		"controls": open_controls()
		"character": cycle_character(1)
		"settings": open_settings()
		"sfx", "music": set_slider(action, 0.0 if slider_value(action) > 0.0 else 0.7)
		"rift": toggle_rift_effects()
		# Confirm on a choice row steps it forward; left and right also work.
		"window", "resolution", "quality", "fps": cycle_choice(action, 1)
		"showfps": profile.set_setting("show_fps", not profile.setting("show_fps"))
		"resume": state = "playing"
		# Abandoning a run pays no coins, unlike dying, so it asks first.
		"menu": state = "confirm_quit"
		"quit_run": state = "title"
		"keep_playing": state = "paused"
		"back": leave_back()
		"reroll": session.reroll_shop(at_seat)
		"go": leave_shop(at_seat)
		"quit": get_tree().quit()

# Taking a level-up reward. A level can be gained during the shop, and dropping
# straight back to "playing" from there would resume the wave with the shop
# skipped, so where this lands depends on what the session was doing.
func choose_upgrade(index: int, at_seat: int = 0) -> void:
	session.choose_upgrade(index, at_seat)
	# The overlay stays up while the other player still has a choice in front of
	# them -- in co-op both can level on the same pickup.
	if session.anyone_choosing(): return
	state = "shop" if session.round_phase == "shop" else "playing"

# Selling or merging shortens the rack, and with it the shop's row list, so the
# cursor has to be brought back inside the list it is pointing into.
# The offer the cursor is on, whether it is resting on the card or on its pin
# chip -- so the pin shortcut works from either.
func focused_offer(at_seat: int) -> int:
	var action := focused_action(at_seat)
	if action.begins_with("buy_"): return int(action.trim_prefix("buy_"))
	if action.begins_with("lock_"): return int(action.trim_prefix("lock_"))
	return -1

func clamp_focus(at_seat: int = 0) -> void:
	set_cursor(at_seat, clampi(cursor(at_seat), 0, maxi(0, menu_items(at_seat).size() - 1)))

# Walks only what is unlocked, so the armory cannot settle on somebody the
# player has not earned.
func cycle_character(step: int) -> void:
	var owned: Array = profile.unlocked_guns_or_characters("characters")
	var at := owned.find(selected_character)
	at = 0 if at < 0 else wrapi(at + step, 0, owned.size())
	selected_character = int(owned[at])
	audio.play("ui_move")

func cycle_gun(step: int) -> void:
	selected_gun = wrapi(selected_gun + step, 0, GunCatalog.all().size())
	audio.play("ui_move")

# Every way out of a screen goes through here, so a clicked BACK and a pressed
# Escape cannot disagree about where "back" is. The controls screen was reached
# by both and only the key knew the way out.
func leave_back() -> void:
	if state == "settings" or state == "settings_pause": leave_settings()
	elif state == "controls": state = controls_from
	else: state = "title"

func is_fullscreen() -> bool:
	var mode := get_window().mode
	return mode == Window.MODE_FULLSCREEN or mode == Window.MODE_EXCLUSIVE_FULLSCREEN

# F11 and the settings row are the same switch: windowed <-> borderless.
func toggle_fullscreen() -> void:
	profile.set_choice("window_mode", 0 if is_fullscreen() else 1)
	apply_display()

# The three display settings, as one list each. `step` wraps, so a pad can walk
# a setting in either direction without a separate "back" row.
func cycle_choice(row: String, step: int) -> void:
	audio.play("ui_move")
	match row:
		"window":
			profile.set_choice("window_mode", wrapi(profile.choice("window_mode") + step, 0, DisplaySettings.WINDOW_MODES.size()))
		"resolution":
			profile.set_choice("resolution", wrapi(profile.choice("resolution") + step, 0, DisplaySettings.RESOLUTIONS.size()))
		"quality":
			profile.set_choice("quality", wrapi(profile.choice("quality") + step, 0, DisplaySettings.QUALITY.size()))
		"fps":
			profile.set_choice("fps_cap", wrapi(profile.choice("fps_cap") + step, 0, DisplaySettings.FPS_CAPS.size()))
	apply_display()

# Everything the three settings actually do, in one place, so boot and a change
# take exactly the same path.
func apply_display() -> void:
	DisplaySettings.apply_window(get_window(), profile.choice("window_mode"), profile.choice("resolution"))
	DisplaySettings.apply_fps(profile.choice("fps_cap"))
	var quality := profile.choice("quality")
	session.number_cap = DisplaySettings.numbers_cap(quality)
	session.shake_scale = DisplaySettings.shake_scale(quality)
	Arena.prop_budget = DisplaySettings.prop_count(quality)

func slider_value(action: String) -> float:
	return audio.volume if action == "sfx" else audio.music_volume

func set_slider(action: String, value: float) -> void:
	var level := clampf(value, 0.0, 1.0)
	slider_dirty = true
	if action == "sfx":
		audio.set_volume(level)
		# The blip is how the new volume is actually heard, but at sixty frames
		# a second a sweep would machine-gun it, so it only fires on a real
		# change in level.
		if absf(level - slider_tick) >= 0.05:
			slider_tick = level
			audio.play("ui_move")
		profile.set_level("sfx_volume", level, false)
	else:
		audio.set_music_volume(level)
		profile.set_level("music_volume", level, false)

func nudge_slider(action: String, step: float) -> void:
	set_slider(action, slider_value(action) + step)

# The focused volume row, or "" when the current screen has none focused.
func focused_slider() -> String:
	if not (state in LIST_STATES): return ""
	var row := focused_action()
	return row if row in SLIDER_ROWS else ""

# The move itself rides on the motion event, so the position comes from the
# event rather than the viewport. This is only the safety net: a button released
# outside the window sends no release event, and the drag has to end anyway.
func drag_slider() -> bool:
	if dragging == "": return false
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dragging = ""
		return false
	return true

func drag_to(at: Vector2) -> void:
	if dragging == "": return
	set_slider(dragging, ui.slider_ratio_at(menu_items().find(dragging), at))

# Keyboard and pad sweep: holding a direction slides the bar continuously rather
# than stepping it once per press. move_left/move_right already carry the arrow
# keys, A and D, the stick and the d-pad, and get_axis hands back the stick's
# analog value -- so a gentle push slides gently.
func poll_slider(delta: float) -> bool:
	var row := focused_slider()
	if row == "": return false
	var axis := Input.get_axis("move_left", "move_right")
	if absf(axis) < 0.15: return false
	nudge_slider(row, axis * SLIDER_RATE * delta)
	return true

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
	if button == Gamepad.R1: return "ready"
	if button == Gamepad.SQUARE: return "alt"
	if button == Gamepad.TRIANGLE: return "special"
	if button == JOY_BUTTON_DPAD_UP: return "nav_up"
	if button == JOY_BUTTON_DPAD_DOWN: return "nav_down"
	if button == JOY_BUTTON_DPAD_LEFT: return "nav_left"
	if button == JOY_BUTTON_DPAD_RIGHT: return "nav_right"
	return ""

# The controls screen, as data. The keyboard column is written here because the
# same verb genuinely differs per screen -- `alt` is Q in a fight and L in the
# shop -- which is the whole reason verbs exist. The pad column is *derived* by
# asking pad_verb about every button, so a binding can never be shown here and
# not be true. Rows with an empty verb are the ones that are not verbs at all.
const CONTROL_ROWS := [
	{"label": "Move", "verb": "", "key": "W A S D  /  Arrows", "pad": "Left Stick  /  D-Pad"},
	{"label": "Select, buy, take", "verb": "confirm", "key": "Enter  /  Click"},
	{"label": "Back, cancel", "verb": "back", "key": "Esc"},
	{"label": "Pause the run", "verb": "pause", "key": "Esc"},
	{"label": "Dash", "verb": "alt", "key": "Q"},
	{"label": "Rift nova", "verb": "special", "key": "E"},
	{"label": "Pin an offer (shop)", "verb": "alt", "key": "L"},
	{"label": "Reroll the shop", "verb": "special", "key": "R"},
	{"label": "Leave the shop", "verb": "ready", "key": "Space"},
	{"label": "Buy slot 1-4 (shop)", "verb": "", "key": "1  2  3  4", "pad": "—"},
	{"label": "Fullscreen", "verb": "", "key": "F11  /  Alt+Enter", "pad": "—"},
]

# Every pad button, asked what it means. Returns "" for a verb nothing is bound
# to, which is what keeps the controls screen honest.
func pad_button_for(verb: String) -> String:
	if verb == "": return ""
	for button in range(JOY_BUTTON_MAX):
		if pad_verb(button) == verb: return Gamepad.glyph(button).to_upper()
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
	elif event is InputEventMouseMotion:
		# Only a real movement takes control back, not the jitter a mouse
		# produces sitting still.
		if (event as InputEventMouseMotion).relative.length() >= MOUSE_WAKE:
			input_device = "keyboard"
	elif event is InputEventKey or event is InputEventMouse:
		input_device = "keyboard"

# The left stick walks a menu as well as the d-pad does. Latched, or a single
# push would scroll the whole list inside one frame, and clamped to one axis at
# a time, or a diagonal would move the cursor twice.
func poll_stick(delta: float) -> void:
	if not (state in LIST_STATES or state in ROW_STATES or state == "armory"):
		stick_held.clear()
		return
	# Every pad plugged in, each steering its own seat. Which seat that is comes
	# from seat_for, so in co-op the two sticks cannot drive the same cursor.
	for index in Input.get_connected_joypads():
		if index >= Controls.MAX_PADS: continue
		poll_one_stick(index, delta)

func poll_one_stick(index: int, delta: float) -> void:
	var axis := Vector2(Input.get_joy_axis(index, JOY_AXIS_LEFT_X), Input.get_joy_axis(index, JOY_AXIS_LEFT_Y))
	var pushed := Vector2.ZERO
	if absf(axis.x) >= Gamepad.MENU_DEADZONE and absf(axis.x) >= absf(axis.y): pushed.x = signf(axis.x)
	elif absf(axis.y) >= Gamepad.MENU_DEADZONE: pushed.y = signf(axis.y)
	if pushed == Vector2.ZERO:
		stick_held[index] = Vector2.ZERO
		return
	var was: Vector2 = stick_held.get(index, Vector2.ZERO)
	stick_repeat[index] = float(stick_repeat.get(index, 0.0)) - delta
	if pushed != was:
		stick_held[index] = pushed
		stick_repeat[index] = Gamepad.REPEAT_FIRST
	elif float(stick_repeat[index]) > 0.0:
		return
	else:
		stick_repeat[index] = Gamepad.REPEAT_NEXT
	input_device = "pad"
	var seat := seat_for("pad%d" % index)
	if pushed.y < 0.0: handle_verb("nav_up", seat)
	elif pushed.y > 0.0: handle_verb("nav_down", seat)
	elif pushed.x < 0.0: handle_verb("nav_left", seat)
	else: handle_verb("nav_right", seat)

# Everything the two devices share. Returns whether the verb was consumed, so a
# screen's own letter shortcuts only ever see what is left over.
func handle_verb(verb: String, at_seat: int = 0) -> bool:
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
				session.dash(at_seat)
				return true
			"special":
				session.rift_nova(at_seat)
				return true
		return false
	if state == "lobby": return lobby_verb(verb, at_seat)
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
				move_focus(-1, true, at_seat)
				return true
			"nav_down":
				move_focus(1, true, at_seat)
				return true
			"nav_left":
				move_focus(-1, false, at_seat)
				return true
			"nav_right":
				move_focus(1, false, at_seat)
				return true
			"confirm":
				activate_menu(at_seat)
				return true
	# The shop has three things worth reaching without walking the cursor to a
	# button, so it takes a shoulder as well as the two spare face buttons.
	if state == "shop":
		match verb:
			"alt":
				var offer := focused_offer(at_seat)
				if offer >= 0: session.toggle_lock(offer, at_seat)
				return true
			"special":
				session.reroll_shop(at_seat)
				return true
			"ready":
				leave_shop(at_seat)
				return true
	if verb == "back":
		match state:
			"settings", "settings_pause":
				leave_settings()
				return true
			"paused":
				state = "playing"
				return true
			"confirm_quit":
				state = "paused"
				return true
			"game_over", "victory", "awards":
				state = "title"
				return true
			"controls":
				state = controls_from
				return true
			# The shop and the level-up screen are each a decision the player
			# has to actually make. There is nowhere to back out to.
			"shop", "level_up":
				return true
	if verb == "confirm":
		match state:
			"awards":
				state = "title"
				return true
			"controls":
				state = controls_from
				return true
			"game_over":
				start_run(coop)
				return true
			"victory":
				state = "title"
				return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	# A drag in progress owns the mouse until the button comes up.
	if event is InputEventMouseMotion and dragging != "":
		drag_to((event as InputEventMouseMotion).position)
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (event as InputEventMouseButton).pressed:
		dragging = ""
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and state in MOUSE_STATES:
		# Clicking is the pointer asserting itself, even if it never moved.
		mouse_leads = true
		var clicked := ui.menu_action_at(event.position)
		# A press on a volume row sets it where you clicked and then follows the
		# mouse until the button comes up, so the bar can be swept.
		if clicked in SLIDER_ROWS:
			dragging = clicked
			menu_index = maxi(0, menu_items().find(clicked))
			set_slider(clicked, ui.slider_ratio_at(menu_items().find(clicked), event.position))
			return
		handle_menu_action(clicked)
		return
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		# The event carries which pad it came from, so two controllers land in
		# their own seats rather than both driving player one.
		var pad := event as InputEventJoypadButton
		handle_verb(pad_verb(pad.button_index), seat_for(Controls.device_of(pad)))
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
		leave_shop(seat_for("kb"))
		return
	if handle_verb(key_verb(key.keycode), seat_for("kb")): return
	# What is left is each screen's own letter shortcuts. Arrows, Enter, Space
	# and Escape never reach here -- they are verbs, and work on a pad too.
	if state == "title":
		if key.keycode == KEY_P: handle_menu_action("play")
		elif key.keycode == KEY_A: handle_menu_action("armory")
		elif key.keycode == KEY_S: handle_menu_action("settings")
		elif key.keycode == KEY_Q: handle_menu_action("quit")
	elif state == "awards":
		if key.keycode == KEY_B: state = "title"
	elif state == "controls":
		if key.keycode == KEY_B: state = controls_from
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
		elif key.keycode == KEY_Q: state = "confirm_quit"
	elif state == "shop":
		if key.keycode >= KEY_1 and key.keycode <= KEY_4: session.buy(key.keycode - KEY_1, seat_for("kb"))
		elif key.keycode == KEY_R: session.reroll_shop(seat_for("kb"))
		elif key.keycode == KEY_L:
			var pin := focused_offer(seat_for("kb"))
			if pin >= 0: session.toggle_lock(pin, seat_for("kb"))
	elif state == "level_up":
		if key.keycode >= KEY_1 and key.keycode <= KEY_4: choose_upgrade(key.keycode - KEY_1, seat_for("kb"))
	elif state == "playing":
		if key.keycode == KEY_Q: session.dash(seat_for("kb"))
		elif key.keycode == KEY_E: session.rift_nova(seat_for("kb"))
