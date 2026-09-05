class_name GameUI
extends Node2D

# Immediate-mode drawing: every screen is painted here and mouse hits are
# resolved against the same rectangles in menu_action_at, so a layout change
# only has to be made once if the rect comes from a shared helper.

const SHOP_CARDS := 4
const CARD_SIZE := Vector2(260, 200)
const CARD_TOP := 150.0
const CARD_GAP := 20.0
const SLOT_SIZE := Vector2(190, 52)
const SLOT_TOP := 470.0
const SLOT_GAP := 10.0

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
		# The shop is a full screen with its own header, so the combat HUD
		# under it would just show doubled numbers through the overlay.
		if game.state != "shop": draw_hud()
		if game.state == "level_up": draw_upgrades()
		elif game.state == "shop": draw_shop()
		elif game.state == "paused": draw_pause()
		elif game.state == "settings_pause": draw_settings("PAUSE SETTINGS", "ESC: back to pause")
		elif game.state == "game_over": draw_game_over()

# --- shared helpers ----------------------------------------------------------

func text_at(position: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func text_centered(centre_x: float, y: float, text: String, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text_at(Vector2(centre_x - width * 0.5, y), text, size, color)

func row_rect(index: int, count: int, size: Vector2, top: float, gap: float) -> Rect2:
	var total := size.x * count + gap * (count - 1)
	return Rect2(Vector2((1280.0 - total) * 0.5 + index * (size.x + gap), top), size)

func card_rect(index: int) -> Rect2:
	return row_rect(index, SHOP_CARDS, CARD_SIZE, CARD_TOP, CARD_GAP)

func slot_rect(index: int) -> Rect2:
	return row_rect(index, GameSession.MAX_WEAPONS, SLOT_SIZE, SLOT_TOP, SLOT_GAP)

func reroll_rect() -> Rect2:
	return Rect2(card_rect(0).position.x, 372, 250, 50)

func go_rect() -> Rect2:
	var last := card_rect(SHOP_CARDS - 1)
	return Rect2(last.end.x - 250, 372, 250, 50)

func menu_action_at(point: Vector2) -> String:
	if game.state == "title":
		var actions := ["play", "armory", "settings", "quit"]
		for i in range(actions.size()):
			if Rect2(455, 318 + i * 68, 370, 54).has_point(point): return actions[i]
	elif game.state == "armory" and Rect2(48, 42, 140, 44).has_point(point):
		return "back"
	elif game.state == "shop":
		for i in range(SHOP_CARDS):
			if card_rect(i).has_point(point): return "buy_%d" % i
		for i in range(game.session.weapons.size()):
			if slot_rect(i).has_point(point): return "sell_%d" % i
		if reroll_rect().has_point(point): return "reroll"
		if go_rect().has_point(point): return "go"
	return ""

func draw_panel(rect: Rect2, fill: Color, edge: Color, width: float = 2.0) -> void:
	draw_rect(rect, fill, true)
	draw_rect(rect, edge, false, width)

# --- title and armory --------------------------------------------------------

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
	text_at(Vector2(390,145), "Choose a starting weapon and survivor", 17, Color("aabce1"))
	var guns := GunCatalog.all()
	for i in range(guns.size()):
		var box := Rect2(160 + i * 325, 205, 295, 180)
		var selected := i == game.selected_gun
		draw_panel(box, Color("263452") if selected else Color("151d35"), guns[i].color, 4.0 if selected else 2.0)
		text_at(box.position + Vector2(22,42), "%d  %s" % [i+1, guns[i].name], 17, guns[i].color)
		text_at(box.position + Vector2(22,80), guns[i].description, 15, Color("d1dcf5"))
		var unlocked := game.profile.is_gun_unlocked(i)
		text_at(box.position + Vector2(22,125), "EQUIPPED" if selected and unlocked else ("UNLOCK  %d COINS" % guns[i].cost if not unlocked else "Press %d" % (i+1)), 15, Color("ffcf77"))
	var character := CharacterCatalog.get_character(game.selected_character)
	var character_unlocked := game.profile.is_character_unlocked(game.selected_character)
	draw_panel(Rect2(270,445,740,120), Color("182441"), character.color)
	text_at(Vector2(305,488), "C  %s" % character.name, 22, character.color)
	var perks := ItemCatalog.describe(character)
	text_at(Vector2(305,521), "%s  •  HP %d  •  SPEED %d" % [character.description, character.hp, character.speed], 16, Color("d1dcf5"))
	text_at(Vector2(305,547), perks if perks != "" else "No stat modifiers", 14, Color("9fb3d9"))
	text_at(Vector2(880,547), "READY" if character_unlocked else "UNLOCK  %d COINS" % character.cost, 14, Color("ffcf77"))
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
	draw_panel(shown_rect, Color(color.r, color.g, color.b, 0.16) if hovered else Color("17233e"), color, 3.0 if hovered else 1.5)
	text_centered(shown_rect.get_center().x, shown_rect.get_center().y + 7.0, label, 19, Color("ffffff") if hovered else Color("d6e2fa"))

# --- combat HUD --------------------------------------------------------------

func draw_hud() -> void:
	var s := game.session
	text_at(Vector2(30,39), "RIFTBOUND SURVIVORS", 24, Color("e8efff"))
	var round_status := "CLEAR HOSTILES" if s.round_phase == "cleanup" else ("SHOP" if s.round_phase == "shop" else "FIGHT")
	text_at(Vector2(1050,41), "WAVE %d  %02d" % [s.round_number, int(ceil(s.round_time_left))], 25, Color("ffd166"))
	text_at(Vector2(1050,66), "%s  •  KILLS %d" % [round_status, s.kills], 15, Color("ffcf77") if s.round_phase != "combat" else Color("b6c6e8"))
	text_at(Vector2(30,67), "MATERIALS  %d" % s.materials, 18, Color("8cffd1"))
	# Weapon rack, so the effect of a shop purchase is visible in the fight.
	var x := 250.0
	for weapon in s.weapons:
		var label: String = weapon.display_name()
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16.0
		draw_panel(Rect2(x, 52, width, 22), Color(0.09,0.13,0.24,0.85), weapon.def().color, 1.0)
		text_at(Vector2(x + 8, 68), label, 13, weapon.def().color)
		x += width + 8.0
	text_at(Vector2(840,41), "Q DASH  %s   E NOVA  %s" % ["READY" if s.dash_cooldown <= 0.0 else "%.1fs" % s.dash_cooldown, "READY" if s.nova_cooldown <= 0.0 else "%.1fs" % s.nova_cooldown], 13, Color("b6c6e8"))
	draw_rect(Rect2(35,704,350,10), Color("3a2844"))
	draw_rect(Rect2(35,704,350 * s.player_hp / s.player_max_hp,10), Color("ff5f7a"))
	text_at(Vector2(35,697), "HP %d / %d" % [s.player_hp, s.player_max_hp], 15, Color("f2d8e0"))
	draw_rect(Rect2(465,704,350,10), Color("1f3e4c"))
	draw_rect(Rect2(465,704,350 * float(s.xp) / maxf(1.0, float(s.xp_to_next)),10), Color("60e8d2"))
	text_at(Vector2(465,697), "LEVEL %d  •  XP %d / %d" % [s.level, s.xp, s.xp_to_next], 15, Color("d0fff7"))
	if s.round_number % 5 == 0 and s.round_phase == "combat" and s.round_time_left > s.round_length - 3.0:
		text_centered(640, 122, "BOSS RIFT OPEN", 21, Color("ffcf77"))

# --- shop --------------------------------------------------------------------

func draw_shop() -> void:
	var s := game.session
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280,720)), Color(0.02,0.03,0.08,0.93))
	text_centered(640, 74, "WAVE %d CLEARED" % s.round_number, 30, Color("69f4d4"))
	text_centered(640, 104, "Spend materials, then head back in", 16, Color("aabce1"))
	text_at(Vector2(48, 88), "MATERIALS  %d" % s.materials, 22, Color("8cffd1"))
	for i in range(SHOP_CARDS):
		draw_offer_card(i, s)
	var reroll_cost: int = s.shop.reroll_cost()
	var can_reroll: bool = s.materials >= reroll_cost
	draw_menu_button(reroll_rect(), "REROLL  %d  (R)" % reroll_cost, "reroll", Color("82b7ff") if can_reroll else Color("54617d"))
	draw_menu_button(go_rect(), "NEXT WAVE  (SPACE)", "go", Color("69f4d4"))
	draw_weapon_slots(s)
	draw_owned_items(s)
	draw_stat_strip(s)

func draw_offer_card(index: int, s: GameSession) -> void:
	var rect := card_rect(index)
	var offer: Dictionary = s.shop.offers[index] if index < s.shop.offers.size() else {}
	if offer.is_empty():
		draw_panel(rect, Color(0.06,0.08,0.15,0.7), Color("2b3550"), 1.5)
		text_centered(rect.get_center().x, rect.get_center().y, "SOLD", 20, Color("54617d"))
		return
	var affordable: bool = s.materials >= int(offer.price)
	var hovered := game.menu_hover == "buy_%d" % index
	var edge: Color = offer.color if affordable else Color("54617d")
	draw_panel(rect, Color(0.12,0.16,0.28,0.95) if hovered else Color("151d35"), edge, 3.0 if hovered else 2.0)
	text_at(rect.position + Vector2(16, 32), "WEAPON" if offer.kind == "weapon" else "ITEM", 12, Color("8ea4cb"))
	text_at(rect.position + Vector2(16, 62), String(offer.name), 18, edge)
	draw_wrapped(rect.position + Vector2(16, 92), String(offer.text), 14, Color("c8d3ed"), rect.size.x - 32.0)
	if offer.kind == "weapon":
		var def: Dictionary = WeaponCatalog.get_weapon(String(offer.id))
		var dps: float = WeaponCatalog.damage_at(String(offer.id), int(offer.tier)) * float(def.shots) / WeaponCatalog.cooldown_at(String(offer.id), int(offer.tier))
		text_at(rect.position + Vector2(16, 152), "%.0f dps  •  %d range" % [dps, int(def.range)], 13, Color("9fb3d9"))
	text_at(rect.position + Vector2(16, 180), "%d MATERIALS" % int(offer.price), 16, Color("8cffd1") if affordable else Color("ff718b"))
	text_at(rect.position + Vector2(rect.size.x - 34, 180), "(%d)" % (index + 1), 14, Color("ffe09b"))

func draw_weapon_slots(s: GameSession) -> void:
	text_at(Vector2(row_rect(0, GameSession.MAX_WEAPONS, SLOT_SIZE, SLOT_TOP, SLOT_GAP).position.x, SLOT_TOP - 12), "WEAPONS  %d / %d  —  click to sell" % [s.weapons.size(), GameSession.MAX_WEAPONS], 14, Color("8ea4cb"))
	for i in range(GameSession.MAX_WEAPONS):
		var rect := slot_rect(i)
		if i >= s.weapons.size():
			draw_panel(rect, Color(0.06,0.08,0.15,0.6), Color("2b3550"), 1.0)
			text_centered(rect.get_center().x, rect.get_center().y + 5, "EMPTY", 13, Color("46526e"))
			continue
		var weapon: Weapon = s.weapons[i]
		var hovered := game.menu_hover == "sell_%d" % i
		draw_panel(rect, Color(0.14,0.10,0.14,0.95) if hovered else Color("1a2440"), weapon.def().color, 2.0 if hovered else 1.5)
		text_at(rect.position + Vector2(12, 22), weapon.display_name(), 14, weapon.def().color)
		var note := "sell +%d" % weapon.sell_value() if hovered and s.weapons.size() > 1 else "%.0f dmg" % WeaponCatalog.damage_at(weapon.id, weapon.tier)
		text_at(rect.position + Vector2(12, 42), note, 12, Color("ff9aa8") if hovered else Color("9fb3d9"))

func draw_owned_items(s: GameSession) -> void:
	var top := SLOT_TOP + SLOT_SIZE.y + 26.0
	var left := slot_rect(0).position.x
	text_at(Vector2(left, top), "ITEMS", 14, Color("8ea4cb"))
	if s.items.is_empty():
		text_at(Vector2(left + 66, top), "none yet", 14, Color("54617d"))
		return
	var names: Array[String] = []
	for id in s.items:
		names.append(String(ItemCatalog.get_item(id).name))
	draw_wrapped(Vector2(left + 66, top), "  •  ".join(names), 14, Color("c8d3ed"), 1150.0)

func draw_stat_strip(s: GameSession) -> void:
	var shown := ["damage", "attack_speed", "crit_chance", "armor", "dodge", "speed", "lifesteal", "harvesting"]
	var left := slot_rect(0).position.x
	var y := 690.0
	var parts: Array[String] = []
	for stat in shown:
		var amount: float = s.stats.get_stat(stat)
		if is_zero_approx(amount): continue
		parts.append("%s %s" % [Stats.LABELS[stat], s.stats.format(stat)])
	text_at(Vector2(left, y), "HP %d/%d" % [s.player_hp, s.player_max_hp], 14, Color("f2d8e0"))
	if not parts.is_empty():
		text_at(Vector2(left + 120, y), "  •  ".join(parts), 14, Color("9fb3d9"))

# Wraps on spaces against a pixel width, since draw_string has no wrapping.
func draw_wrapped(at: Vector2, text: String, size: int, color: Color, width: float) -> void:
	var line := ""
	var y := at.y
	for word in text.split(" "):
		var candidate: String = word if line == "" else line + " " + word
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			text_at(Vector2(at.x, y), line, size, color)
			y += size + 5
			line = word
		else:
			line = candidate
	if line != "": text_at(Vector2(at.x, y), line, size, color)

# --- overlays ----------------------------------------------------------------

func draw_upgrades() -> void:
	draw_rect(Rect2(Vector2.ZERO,Vector2(1280,720)), Color(0.02,0.03,0.08,0.82))
	text_centered(640, 172, "RIFT EVOLUTION", 36, Color("ffe09b"))
	text_centered(640, 205, "Choose one upgrade", 18, Color("c8d3ed"))
	var choices: Array[Dictionary] = game.session.upgrades
	var rarity_colors := {"COMMON": Color("b7c5d9"), "RARE": Color("82b7ff"), "LEGENDARY": Color("ffcf77")}
	for i in range(choices.size()):
		var rect := row_rect(i, choices.size(), Vector2(260, 200), 260.0, 20.0)
		var edge: Color = rarity_colors[choices[i].rarity]
		draw_panel(rect, Color("202b4a"), edge, 3.0)
		text_at(rect.position + Vector2(20, 44), "%d" % (i + 1), 24, Color("ffe09b"))
		text_at(rect.position + Vector2(20, 74), String(choices[i].rarity), 13, edge)
		text_at(rect.position + Vector2(20, 104), String(choices[i].title), 18, Color("f1f5ff"))
		draw_wrapped(rect.position + Vector2(20, 134), UpgradeCatalog.describe(choices[i]), 15, Color("a9bbde"), rect.size.x - 40.0)
		text_at(rect.position + Vector2(20, 182), "Press %d" % (i + 1), 14, Color("ffe09b"))

func draw_pause() -> void:
	draw_rect(Rect2(Vector2.ZERO,Vector2(1280,720)), Color(0.02,0.03,0.08,0.76))
	text_centered(640, 290, "PAUSED", 42, Color("eaf1ff"))
	text_centered(640, 345, "ESC  •  Continue", 19, Color("ffe09b"))
	text_centered(640, 380, "S  •  Settings", 19, Color("b6c6e8"))
	text_centered(640, 415, "Q  •  Main Menu", 19, Color("b6c6e8"))

func draw_settings(title: String, footer: String) -> void:
	draw_rect(Rect2(Vector2.ZERO,Vector2(1280,720)), Color("0b1020"))
	text_centered(640, 170, title, 40, Color("eaf1ff"))
	draw_panel(Rect2(365,225,550,240), Color("182441"), Color("607cab"))
	text_at(Vector2(410,290), "S    Sound Effects", 22, Color("e9f0ff"))
	text_at(Vector2(775,290), "ON" if game.sound_enabled else "OFF", 22, Color("69f4d4") if game.sound_enabled else Color("ff718b"))
	text_at(Vector2(410,360), "V    Rift Effects", 22, Color("e9f0ff"))
	text_at(Vector2(775,360), "ON" if game.rift_effects_enabled else "OFF", 22, Color("69f4d4") if game.rift_effects_enabled else Color("ff718b"))
	text_centered(640, 535, footer, 16, Color("aabce1"))

func draw_game_over() -> void:
	draw_rect(Rect2(Vector2.ZERO,Vector2(1280,720)), Color(0.03,0.01,0.07,0.78))
	var s := game.session
	text_centered(640, 310, "THE RIFT CONSUMES YOU", 31, Color("ff7590"))
	text_centered(640, 350, "Time survived: %02d:%02d  •  Kills: %d" % [int(s.run_time)/60, int(s.run_time)%60, s.kills], 18, Color("d2d9ed"))
	text_centered(640, 390, "Wave %d reached  •  +%d coins earned" % [s.round_number, s.round_number * 4 + int(s.kills / 4)], 18, Color("ffcf77"))
	text_centered(640, 430, "SPACE: retry   •   ESC: main menu", 19, Color("ffe09b"))
