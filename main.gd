class_name GameController
extends Node2D

@onready var session: GameSession = $GameSession
@onready var audio: AudioSfx = $AudioSfx
@onready var ui: GameUI = $GameUI

var state := "title"
var selected_gun := 0
var selected_character := 0
var sound_enabled := true
var rift_effects_enabled := true
var profile := ProfileManager.new()
var menu_hover := ""

func _ready() -> void:
	profile.load_profile()
	session.level_up_requested.connect(func() -> void: state = "level_up")
	session.run_ended.connect(on_run_ended)
	session.rift_effects_enabled = rift_effects_enabled

func _process(delta: float) -> void:
	if state == "playing":
		session.tick(delta)
	if state == "title" or state == "armory":
		menu_hover = ui.menu_action_at(get_viewport().get_mouse_position())
	ui.queue_redraw()

func start_run() -> void:
	if not profile.is_gun_unlocked(selected_gun):
		if not profile.unlock_gun(selected_gun, int(GunCatalog.get_gun(selected_gun).cost)): return
	if not profile.is_character_unlocked(selected_character):
		if not profile.unlock_character(selected_character, int(CharacterCatalog.get_character(selected_character).cost)): return
	session.selected_gun = selected_gun
	session.reset_run()
	session.apply_character(selected_character)
	state = "playing"

func on_run_ended() -> void:
	profile.add_coins(session.round_number * 4 + int(session.kills / 4))
	state = "game_over"

func open_settings() -> void:
	state = "settings_pause" if state == "paused" else "settings"

func handle_menu_action(action: String) -> void:
	match action:
		"play": start_run()
		"armory": state = "armory"
		"settings": state = "settings"
		"back": state = "title"
		"quit": get_tree().quit()

func toggle_sound() -> void:
	sound_enabled = not sound_enabled
	audio.enabled = sound_enabled

func toggle_rift_effects() -> void:
	rift_effects_enabled = not rift_effects_enabled
	session.rift_effects_enabled = rift_effects_enabled

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and (state == "title" or state == "armory"):
		handle_menu_action(ui.menu_action_at(event.position))
		return
	if not (event is InputEventKey and event.pressed and not event.echo): return
	if state == "title":
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_P: handle_menu_action("play")
		elif event.keycode == KEY_A: handle_menu_action("armory")
		elif event.keycode == KEY_S: handle_menu_action("settings")
		elif event.keycode == KEY_Q: handle_menu_action("quit")
	elif state == "armory":
		if event.keycode >= KEY_1 and event.keycode <= KEY_3: selected_gun = event.keycode - KEY_1
		elif event.keycode == KEY_C: selected_character = (selected_character + 1) % CharacterCatalog.all().size()
		elif event.keycode == KEY_ESCAPE or event.keycode == KEY_B: state = "title"
	elif state == "settings" or state == "settings_pause":
		if event.keycode == KEY_S: toggle_sound()
		elif event.keycode == KEY_V: toggle_rift_effects()
		elif event.keycode == KEY_ESCAPE: state = "paused" if state == "settings_pause" else "title"
	elif state == "paused":
		if event.keycode == KEY_ESCAPE: state = "playing"
		elif event.keycode == KEY_S: open_settings()
		elif event.keycode == KEY_Q: state = "title"
	elif state == "level_up":
		if event.keycode >= KEY_1 and event.keycode <= KEY_3:
			session.choose_upgrade(event.keycode - KEY_1)
			state = "playing"
	elif state == "game_over":
		if event.keycode == KEY_SPACE: start_run()
		elif event.keycode == KEY_ESCAPE: state = "title"
	elif state == "playing":
		if event.keycode == KEY_ESCAPE: state = "paused"
		elif event.keycode == KEY_Q: session.dash()
		elif event.keycode == KEY_E: session.rift_nova()
