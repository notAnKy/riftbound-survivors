class_name GameUI
extends Node2D

var game: GameController
var font: Font

func _ready() -> void:
	game = get_parent() as GameController
	font = ThemeDB.fallback_font

func _draw() -> void:
	if game == null: return
	if game.state == "title": draw_title()
	elif game.state == "armory": draw_armory()
	elif game.state == "settings": draw_settings("SETTINGS", "ESC: back to title")
	else:
		draw_hud()
		if game.state == "level_up": draw_upgrades()
		elif game.state == "paused": draw_pause()
		elif game.state == "settings_pause": draw_settings("PAUSE SETTINGS", "ESC: back to pause")
		elif game.state == "game_over": draw_game_over()

func text_at(position: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func menu_action_at(point: Vector2) -> String:
	if game.state == "title":
		var actions := ["play", "armory", "settings", "quit"]
		for i in range(actions.size()):
			if Rect2(455, 318 + i * 68, 370, 54).has_point(point): return actions[i]
	elif game.state == "armory" and Rect2(48, 42, 140, 44).has_point(point):
		return "back"
	return ""

func draw_title() -> void:
	draw_menu_background()
	text_at(Vector2(421,154), "RIFTBOUND", 55, Color("e8efff"))
	text_at(Vector2(425,205), "SURVIVORS", 55, Color("ffcf77"))
	text_at(Vector2(482,245), "An arcade survival run", 18, Color("aabce1"))
	var buttons := [["PLAY", "play", Color("69f4d4")], ["ARMORY", "armory", Color("bf8cff")], ["SETTINGS", "settings", Color("82b7ff")], ["QUIT GAME", "quit", Color("ff718b")]]
	for i in range(buttons.size()):
		draw_menu_button(Rect2(455, 318 + i * 68, 370, 54), buttons[i][0], buttons[i][1], buttons[i][2])
	text_at(Vector2(530,623), "COINS  %d" % game.profile.coins(), 18, Color("ffcf77"))
	text_at(Vector2(460,660), "Mouse or keyboard: P  A  S  Q", 14, Color("8ea4cb"))

func draw_armory() -> void:
	draw_menu_background()
	draw_menu_button(Rect2(48,42,140,44), "BACK", "back", Color("aabce1"))
	text_at(Vector2(510,104), "ARMORY", 42, Color("e8efff"))
	text_at(Vector2(390,145), "Choose a weapon and survivor for your next run", 17, Color("aabce1"))
	var guns := GunCatalog.all()
	for i in range(guns.size()):
		var box := Rect2(160 + i * 325, 205, 295, 180)
		var selected := i == game.selected_gun
		draw_rect(box, Color("263452") if selected else Color("151d35"), true)
		draw_rect(box, guns[i].color, false, 4.0 if selected else 2.0)
		text_at(box.position + Vector2(22,42), "%d  %s" % [i+1, guns[i].name], 17, guns[i].color)
		text_at(box.position + Vector2(22,80), guns[i].description, 15, Color("d1dcf5"))
		var unlocked := game.profile.is_gun_unlocked(i)
		text_at(box.position + Vector2(22,125), "EQUIPPED" if selected and unlocked else ("UNLOCK  %d COINS" % guns[i].cost if not unlocked else "Press %d" % (i+1)), 15, Color("ffcf77"))
	var character := CharacterCatalog.get_character(game.selected_character)
	var character_unlocked := game.profile.is_character_unlocked(game.selected_character)
	draw_rect(Rect2(270,445,740,120), Color("182441"), true)
	draw_rect(Rect2(270,445,740,120), character.color, false, 2.0)
	text_at(Vector2(305,488), "C  %s" % character.name, 22, character.color)
	text_at(Vector2(305,523), "%s  •  HP %d  •  SPEED %d" % [character.description,character.hp,character.speed], 16, Color("d1dcf5"))
	text_at(Vector2(305,550), "READY" if character_unlocked else "UNLOCK  %d COINS" % character.cost, 14, Color("ffcf77"))
	text_at(Vector2(445,630), "Press PLAY from the main menu to begin", 17, Color("aabce1"))

func draw_menu_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280,720)), Color("0b1020"))
	for i in range(38):
		var star := Vector2(float((i * 97) % 1280), float((i * 53) % 720))
		draw_circle(star, 1.0 + float(i % 3), Color(0.35,0.70,1.0,0.22))
	draw_arc(Vector2(640,170), 100.0, 0.2, TAU - 0.2, 24, Color(0.62,0.42,1.0,0.25), 8.0)
	draw_arc(Vector2(640,170), 72.0, 0.0, TAU, 20, Color(0.27,0.88,0.94,0.16), 4.0)

func draw_menu_button(rect: Rect2, label: String, action: String, color: Color) -> void:
	var hovered := game.menu_hover == action
	var pulse := (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
	var shown_rect := rect.grow(4.0 + pulse * 2.0) if hovered else rect
	draw_rect(shown_rect, Color(color.r, color.g, color.b, 0.16) if hovered else Color("17233e"), true)
	draw_rect(shown_rect, color, false, 3.0 if hovered else 1.5)
	var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	text_at(Vector2(shown_rect.get_center().x - label_width / 2.0, shown_rect.get_center().y + 7.0), label, 19, Color("ffffff") if hovered else Color("d6e2fa"))

func draw_hud() -> void:
	var s := game.session
	text_at(Vector2(30,39), "RIFTBOUND SURVIVORS", 24, Color("e8efff"))
	text_at(Vector2(30,67), "WASD / ARROWS  •  Survive the multiverse", 16, Color("94a3c7"))
	var round_status := "CLEAR HOSTILES" if s.round_phase == "cleanup" else ("NEXT ROUND" if s.round_phase == "intermission" else "FIGHT")
	var displayed_time := int(ceil(s.intermission_left if s.round_phase == "intermission" else s.round_time_left))
	text_at(Vector2(1050,41), "ROUND %d  %02d" % [s.round_number, displayed_time], 25, Color("ffd166"))
	text_at(Vector2(1050,66), "%s  •  KILLS %d" % [round_status, s.kills], 15, Color("ffcf77") if s.round_phase != "combat" else Color("b6c6e8"))
	var gun := GunCatalog.get_gun(s.selected_gun)
	text_at(Vector2(840,41), gun.name, 16, gun.color)
	text_at(Vector2(840,65), "Q DASH  %s   E NOVA  %s" % ["READY" if s.dash_cooldown <= 0.0 else "%.1fs" % s.dash_cooldown, "READY" if s.nova_cooldown <= 0.0 else "%.1fs" % s.nova_cooldown], 13, Color("b6c6e8"))
	draw_rect(Rect2(35,704,350,10), Color("3a2844"))
	draw_rect(Rect2(35,704,350 * s.player_hp / s.player_max_hp,10), Color("ff5f7a"))
	text_at(Vector2(35,697), "HP %d / %d" % [s.player_hp,s.player_max_hp], 15, Color("f2d8e0"))
	draw_rect(Rect2(465,704,350,10), Color("1f3e4c"))
	draw_rect(Rect2(465,704,350 * float(s.xp) / s.xp_to_next,10), Color("60e8d2"))
	text_at(Vector2(465,697), "LEVEL %d  •  XP %d / %d" % [s.level,s.xp,s.xp_to_next], 15, Color("d0fff7"))
	if s.round_phase == "intermission":
		draw_rect(Rect2(410,300,460,105), Color(0.04,0.06,0.14,0.90), true)
		draw_rect(Rect2(410,300,460,105), Color("69f4d4"), false, 2.0)
		text_at(Vector2(520,342), "ROUND CLEAR", 28, Color("69f4d4"))
		text_at(Vector2(493,378), "Next rift opens in %d" % int(ceil(s.intermission_left)), 18, Color("dbe8ff"))
	elif s.round_number % 5 == 0 and s.round_time_left > s.round_length - 3.0:
		text_at(Vector2(520,122), "BOSS RIFT OPEN", 21, Color("ffcf77"))

func draw_upgrades() -> void:
	draw_rect(Rect2(Vector2.ZERO,Vector2(1280,720)), Color(0.02,0.03,0.08,0.82))
	text_at(Vector2(453,172), "RIFT EVOLUTION", 36, Color("ffe09b"))
	text_at(Vector2(476,205), "Choose one upgrade", 18, Color("c8d3ed"))
	for i in range(game.session.upgrades.size()):
		var box := Rect2(190 + i * 310,270,270,210)
		draw_rect(box, Color("202b4a"), true)
		draw_rect(box, [Color("6df7e4"),Color("ae7cff"),Color("ffd166")][i], false, 3.0)
		text_at(box.position + Vector2(22,52), "%d" % (i+1), 25, Color("ffe09b"))
		text_at(box.position + Vector2(22,82), game.session.upgrades[i].rarity, 13, Color("ffcf77") if game.session.upgrades[i].rarity == "LEGENDARY" else (Color("82b7ff") if game.session.upgrades[i].rarity == "RARE" else Color("b7c5d9")))
		text_at(box.position + Vector2(22,110), game.session.upgrades[i].title, 19, Color("f1f5ff"))
		text_at(box.position + Vector2(22,145), game.session.upgrades[i].detail, 16, Color("a9bbde"))
		text_at(box.position + Vector2(22,180), "Press %d" % (i+1), 15, Color("ffe09b"))

func draw_pause() -> void:
	draw_rect(Rect2(Vector2.ZERO,Vector2(1280,720)), Color(0.02,0.03,0.08,0.76))
	text_at(Vector2(537,290), "PAUSED", 42, Color("eaf1ff"))
	text_at(Vector2(495,345), "ESC  •  Continue", 19, Color("ffe09b"))
	text_at(Vector2(500,380), "S  •  Settings", 19, Color("b6c6e8"))
	text_at(Vector2(500,415), "Q  •  Main Menu", 19, Color("b6c6e8"))

func draw_settings(title: String, footer: String) -> void:
	draw_rect(Rect2(Vector2.ZERO,Vector2(1280,720)), Color("0b1020"))
	text_at(Vector2(490,170), title, 40, Color("eaf1ff"))
	var panel := Rect2(365,225,550,240)
	draw_rect(panel, Color("182441"), true)
	draw_rect(panel, Color("607cab"), false, 2.0)
	text_at(Vector2(410,290), "S    Sound Effects", 22, Color("e9f0ff"))
	text_at(Vector2(775,290), "ON" if game.sound_enabled else "OFF", 22, Color("69f4d4") if game.sound_enabled else Color("ff718b"))
	text_at(Vector2(410,360), "V    Rift Effects", 22, Color("e9f0ff"))
	text_at(Vector2(775,360), "ON" if game.rift_effects_enabled else "OFF", 22, Color("69f4d4") if game.rift_effects_enabled else Color("ff718b"))
	text_at(Vector2(485,535), footer, 16, Color("aabce1"))

func draw_game_over() -> void:
	draw_rect(Rect2(Vector2.ZERO,Vector2(1280,720)), Color(0.03,0.01,0.07,0.78))
	var s := game.session
	text_at(Vector2(467,310), "THE RIFT CONSUMES YOU", 31, Color("ff7590"))
	text_at(Vector2(528,350), "Time survived: %02d:%02d  •  Kills: %d" % [int(s.run_time)/60,int(s.run_time)%60,s.kills], 18, Color("d2d9ed"))
	text_at(Vector2(500,390), "Round %d reached  •  +%d coins earned" % [s.round_number, s.round_number * 4 + int(s.kills / 4)], 18, Color("ffcf77"))
	text_at(Vector2(500,430), "SPACE: retry   •   ESC: main menu", 19, Color("ffe09b"))
