class_name GameUI
extends Node2D

# Immediate-mode drawing. Every clickable thing gets its rectangle from a
# helper below, and menu_action_at hit-tests the same helpers, so a layout
# change never has to be made twice.

const SCREEN := Vector2(1920, 1080)
const MARGIN := 48.0

const SHOP_CARDS := 4
const CARD_SIZE := Vector2(340, 250)
const CARD_TOP := 230.0
const CARD_GAP := 26.0
const BUTTON_SIZE := Vector2(300, 58)
const BUTTON_TOP := 512.0
const SLOT_SIZE := Vector2(250, 62)
const SLOT_TOP := 640.0
const SLOT_GAP := 14.0

const MENU_BUTTON := Vector2(440, 64)
const MENU_TOP := 520.0
const MENU_STEP := 84.0

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

# --- layout ------------------------------------------------------------------

func text_at(position: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func text_width(text: String, size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

func text_centered(centre_x: float, y: float, text: String, size: int, color: Color) -> void:
	text_at(Vector2(centre_x - text_width(text, size) * 0.5, y), text, size, color)

func text_right(right_x: float, y: float, text: String, size: int, color: Color) -> void:
	text_at(Vector2(right_x - text_width(text, size), y), text, size, color)

func row_rect(index: int, count: int, size: Vector2, top: float, gap: float) -> Rect2:
	var total := size.x * count + gap * (count - 1)
	return Rect2(Vector2((SCREEN.x - total) * 0.5 + index * (size.x + gap), top), size)

func card_rect(index: int) -> Rect2:
	return row_rect(index, SHOP_CARDS, CARD_SIZE, CARD_TOP, CARD_GAP)

func slot_rect(index: int) -> Rect2:
	return row_rect(index, GameSession.MAX_WEAPONS, SLOT_SIZE, SLOT_TOP, SLOT_GAP)

func reroll_rect() -> Rect2:
	return Rect2(Vector2(card_rect(0).position.x, BUTTON_TOP), BUTTON_SIZE)

func go_rect() -> Rect2:
	return Rect2(Vector2(card_rect(SHOP_CARDS - 1).end.x - BUTTON_SIZE.x, BUTTON_TOP), BUTTON_SIZE)

func menu_button_rect(index: int) -> Rect2:
	return Rect2(Vector2((SCREEN.x - MENU_BUTTON.x) * 0.5, MENU_TOP + index * MENU_STEP), MENU_BUTTON)

func armory_back_rect() -> Rect2:
	return Rect2(60, 60, 170, 52)

func gun_rect(index: int) -> Rect2:
	return row_rect(index, 3, Vector2(400, 240), 280.0, 40.0)

func menu_action_at(point: Vector2) -> String:
	if game.state == "title":
		var actions := ["play", "armory", "settings", "quit"]
		for i in range(actions.size()):
			if menu_button_rect(i).has_point(point): return actions[i]
	elif game.state == "armory" and armory_back_rect().has_point(point):
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

func fill_screen(color: Color) -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), color)

# --- title and armory --------------------------------------------------------

func draw_title() -> void:
	draw_menu_background()
	text_centered(SCREEN.x * 0.5, 300, "RIFTBOUND", 76, Color("e8efff"))
	text_centered(SCREEN.x * 0.5, 372, "SURVIVORS", 76, Color("ffcf77"))
	text_centered(SCREEN.x * 0.5, 424, "An arcade survival run", 20, Color("aabce1"))
	var buttons := [["PLAY", "play", Color("69f4d4")], ["ARMORY", "armory", Color("bf8cff")], ["SETTINGS", "settings", Color("82b7ff")], ["QUIT GAME", "quit", Color("ff718b")]]
	for i in range(buttons.size()):
		draw_menu_button(menu_button_rect(i), buttons[i][0], buttons[i][1], buttons[i][2])
	text_centered(SCREEN.x * 0.5, 912, "COINS  %d" % game.profile.coins(), 20, Color("ffcf77"))
	text_centered(SCREEN.x * 0.5, 952, "Mouse or keyboard: P  A  S  Q", 15, Color("8ea4cb"))

func draw_armory() -> void:
	draw_menu_background()
	draw_menu_button(armory_back_rect(), "BACK", "back", Color("aabce1"))
	text_centered(SCREEN.x * 0.5, 150, "ARMORY", 48, Color("e8efff"))
	text_centered(SCREEN.x * 0.5, 196, "Choose a starting weapon and survivor", 18, Color("aabce1"))
	var guns := GunCatalog.all()
	for i in range(guns.size()):
		var box := gun_rect(i)
		var selected := i == game.selected_gun
		draw_panel(box, Color("263452") if selected else Color("151d35"), guns[i].color, 4.0 if selected else 2.0)
		text_at(box.position + Vector2(26,52), "%d  %s" % [i+1, guns[i].name], 20, guns[i].color)
		text_at(box.position + Vector2(26,96), guns[i].description, 16, Color("d1dcf5"))
		var unlocked := game.profile.is_gun_unlocked(i)
		text_at(box.position + Vector2(26,158), "EQUIPPED" if selected and unlocked else ("UNLOCK  %d COINS" % guns[i].cost if not unlocked else "Press %d" % (i+1)), 16, Color("ffcf77"))
	var character := CharacterCatalog.get_character(game.selected_character)
	var panel := Rect2((SCREEN.x - 1000.0) * 0.5, 580, 1000, 150)
	draw_panel(panel, Color("182441"), character.color)
	text_at(panel.position + Vector2(40, 52), "C  %s" % character.name, 24, character.color)
	text_at(panel.position + Vector2(40, 90), "%s  •  HP %d  •  SPEED %d" % [character.description, character.hp, character.speed], 17, Color("d1dcf5"))
	var perks := ItemCatalog.describe(character)
	text_at(panel.position + Vector2(40, 122), perks if perks != "" else "No stat modifiers", 15, Color("9fb3d9"))
	text_right(panel.end.x - 40, panel.position.y + 122, "READY" if game.profile.is_character_unlocked(game.selected_character) else "UNLOCK  %d COINS" % character.cost, 15, Color("ffcf77"))
	text_centered(SCREEN.x * 0.5, 810, "Press PLAY from the main menu to begin", 18, Color("aabce1"))

func draw_menu_background() -> void:
	fill_screen(Color("0b1020"))
	for i in range(60):
		var star := Vector2(float((i * 197) % int(SCREEN.x)), float((i * 131) % int(SCREEN.y)))
		draw_circle(star, 1.0 + float(i % 3), Color(0.35,0.70,1.0,0.22))
	draw_arc(Vector2(SCREEN.x * 0.5, 300), 150.0, 0.2, TAU - 0.2, 32, Color(0.62,0.42,1.0,0.25), 10.0)
	draw_arc(Vector2(SCREEN.x * 0.5, 300), 108.0, 0.0, TAU, 28, Color(0.27,0.88,0.94,0.16), 5.0)

func draw_menu_button(rect: Rect2, label: String, action: String, color: Color) -> void:
	var hovered := game.menu_hover == action
	var pulse := (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
	var shown_rect := rect.grow(4.0 + pulse * 2.0) if hovered else rect
	draw_panel(shown_rect, Color(color.r, color.g, color.b, 0.16) if hovered else Color("17233e"), color, 3.0 if hovered else 1.5)
	text_centered(shown_rect.get_center().x, shown_rect.get_center().y + 8.0, label, 21, Color("ffffff") if hovered else Color("d6e2fa"))

# --- combat HUD --------------------------------------------------------------

func draw_hud() -> void:
	var s := game.session
	var right := SCREEN.x - MARGIN
	text_at(Vector2(MARGIN, 48), "RIFTBOUND SURVIVORS", 26, Color("e8efff"))
	text_at(Vector2(MARGIN, 84), "MATERIALS  %d" % s.materials, 20, Color("8cffd1"))
	# Weapon rack, so the effect of a shop purchase is visible in the fight.
	var x := MARGIN + 300.0
	for weapon in s.weapons:
		var label: String = weapon.display_name()
		var width := text_width(label, 14) + 18.0
		draw_panel(Rect2(x, 64, width, 26), Color(0.09,0.13,0.24,0.85), weapon.def().color, 1.0)
		text_at(Vector2(x + 9, 83), label, 14, weapon.def().color)
		x += width + 9.0
	var round_status := "CLEAR HOSTILES" if s.round_phase == "cleanup" else ("SHOP" if s.round_phase == "shop" else "FIGHT")
	text_right(right, 50, "WAVE %d  %02d" % [s.round_number, int(ceil(s.round_time_left))], 28, Color("ffd166"))
	text_right(right, 80, "%s  •  KILLS %d" % [round_status, s.kills], 16, Color("ffcf77") if s.round_phase != "combat" else Color("b6c6e8"))
	text_right(right, 106, "Q DASH %s    E NOVA %s" % ["READY" if s.dash_cooldown <= 0.0 else "%.1fs" % s.dash_cooldown, "READY" if s.nova_cooldown <= 0.0 else "%.1fs" % s.nova_cooldown], 15, Color("b6c6e8"))
	var bar_y := SCREEN.y - 34.0
	draw_rect(Rect2(MARGIN, bar_y, 520, 14), Color("3a2844"))
	draw_rect(Rect2(MARGIN, bar_y, 520 * s.player_hp / s.player_max_hp, 14), Color("ff5f7a"))
	text_at(Vector2(MARGIN, bar_y - 10), "HP %d / %d" % [s.player_hp, s.player_max_hp], 16, Color("f2d8e0"))
	draw_rect(Rect2(right - 520, bar_y, 520, 14), Color("1f3e4c"))
	draw_rect(Rect2(right - 520, bar_y, 520 * float(s.xp) / maxf(1.0, float(s.xp_to_next)), 14), Color("60e8d2"))
	text_at(Vector2(right - 520, bar_y - 10), "LEVEL %d  •  XP %d / %d" % [s.level, s.xp, s.xp_to_next], 16, Color("d0fff7"))
	if s.round_number % 5 == 0 and s.round_phase == "combat" and s.round_time_left > s.round_length - 3.0:
		text_centered(SCREEN.x * 0.5, 170, "BOSS RIFT OPEN", 24, Color("ffcf77"))

# --- shop --------------------------------------------------------------------

func draw_shop() -> void:
	var s := game.session
	fill_screen(Color(0.02,0.03,0.08,0.94))
	text_centered(SCREEN.x * 0.5, 120, "WAVE %d CLEARED" % s.round_number, 36, Color("69f4d4"))
	text_centered(SCREEN.x * 0.5, 158, "Spend materials, then head back in", 18, Color("aabce1"))
	text_at(Vector2(MARGIN, 130), "MATERIALS  %d" % s.materials, 26, Color("8cffd1"))
	for i in range(SHOP_CARDS):
		draw_offer_card(i, s)
	var reroll_cost: int = s.shop.reroll_cost()
	draw_menu_button(reroll_rect(), "REROLL  %d  (R)" % reroll_cost, "reroll", Color("82b7ff") if s.materials >= reroll_cost else Color("54617d"))
	draw_menu_button(go_rect(), "NEXT WAVE  (SPACE)", "go", Color("69f4d4"))
	draw_weapon_slots(s)
	draw_owned_items(s)
	draw_stat_strip(s)

func draw_offer_card(index: int, s: GameSession) -> void:
	var rect := card_rect(index)
	var offer: Dictionary = s.shop.offers[index] if index < s.shop.offers.size() else {}
	if offer.is_empty():
		draw_panel(rect, Color(0.06,0.08,0.15,0.7), Color("2b3550"), 1.5)
		text_centered(rect.get_center().x, rect.get_center().y, "SOLD", 22, Color("54617d"))
		return
	var affordable: bool = s.materials >= int(offer.price)
	var hovered := game.menu_hover == "buy_%d" % index
	var edge: Color = offer.color if affordable else Color("54617d")
	draw_panel(rect, Color(0.12,0.16,0.28,0.95) if hovered else Color("151d35"), edge, 3.0 if hovered else 2.0)
	text_at(rect.position + Vector2(20, 38), "WEAPON" if offer.kind == "weapon" else "ITEM", 13, Color("8ea4cb"))
	text_at(rect.position + Vector2(20, 74), String(offer.name), 21, edge)
	draw_wrapped(rect.position + Vector2(20, 112), String(offer.text), 15, Color("c8d3ed"), rect.size.x - 40.0)
	if offer.kind == "weapon":
		var def: Dictionary = WeaponCatalog.get_weapon(String(offer.id))
		var dps: float = WeaponCatalog.damage_at(String(offer.id), int(offer.tier)) * float(def.shots) / WeaponCatalog.cooldown_at(String(offer.id), int(offer.tier))
		text_at(rect.position + Vector2(20, 192), "%.0f dps  •  %d range" % [dps, int(def.range)], 14, Color("9fb3d9"))
	text_at(rect.position + Vector2(20, 226), "%d MATERIALS" % int(offer.price), 18, Color("8cffd1") if affordable else Color("ff718b"))
	text_right(rect.end.x - 18, rect.position.y + 226, "(%d)" % (index + 1), 15, Color("ffe09b"))

func draw_weapon_slots(s: GameSession) -> void:
	text_at(Vector2(slot_rect(0).position.x, SLOT_TOP - 14), "WEAPONS  %d / %d  —  click to sell" % [s.weapons.size(), GameSession.MAX_WEAPONS], 15, Color("8ea4cb"))
	for i in range(GameSession.MAX_WEAPONS):
		var rect := slot_rect(i)
		if i >= s.weapons.size():
			draw_panel(rect, Color(0.06,0.08,0.15,0.6), Color("2b3550"), 1.0)
			text_centered(rect.get_center().x, rect.get_center().y + 6, "EMPTY", 14, Color("46526e"))
			continue
		var weapon: Weapon = s.weapons[i]
		var hovered := game.menu_hover == "sell_%d" % i
		draw_panel(rect, Color(0.14,0.10,0.14,0.95) if hovered else Color("1a2440"), weapon.def().color, 2.0 if hovered else 1.5)
		text_at(rect.position + Vector2(14, 26), weapon.display_name(), 15, weapon.def().color)
		var note := "sell +%d" % weapon.sell_value() if hovered and s.weapons.size() > 1 else "%.0f dmg" % WeaponCatalog.damage_at(weapon.id, weapon.tier)
		text_at(rect.position + Vector2(14, 50), note, 13, Color("ff9aa8") if hovered else Color("9fb3d9"))

func draw_owned_items(s: GameSession) -> void:
	var top := SLOT_TOP + SLOT_SIZE.y + 40.0
	var left := slot_rect(0).position.x
	text_at(Vector2(left, top), "ITEMS", 15, Color("8ea4cb"))
	if s.items.is_empty():
		text_at(Vector2(left + 78, top), "none yet", 15, Color("54617d"))
		return
	var names: Array[String] = []
	for id in s.items:
		names.append(String(ItemCatalog.get_item(id).name))
	draw_wrapped(Vector2(left + 78, top), "  •  ".join(names), 15, Color("c8d3ed"), SCREEN.x - left * 2.0 - 78.0)

func draw_stat_strip(s: GameSession) -> void:
	var left := slot_rect(0).position.x
	var y := SCREEN.y - 60.0
	var parts: Array[String] = []
	for stat in ["damage", "attack_speed", "crit_chance", "armor", "dodge", "speed", "lifesteal", "harvesting", "pickup_radius"]:
		if is_zero_approx(s.stats.get_stat(stat)): continue
		parts.append("%s %s" % [Stats.LABELS[stat], s.stats.format(stat)])
	text_at(Vector2(left, y), "HP %d/%d" % [s.player_hp, s.player_max_hp], 15, Color("f2d8e0"))
	if not parts.is_empty():
		draw_wrapped(Vector2(left + 140, y), "  •  ".join(parts), 15, Color("9fb3d9"), SCREEN.x - left * 2.0 - 140.0)

# Wraps on spaces against a pixel width, since draw_string has no wrapping.
func draw_wrapped(at: Vector2, text: String, size: int, color: Color, width: float) -> void:
	var line := ""
	var y := at.y
	for word in text.split(" "):
		var candidate: String = word if line == "" else line + " " + word
		if text_width(candidate, size) > width and line != "":
			text_at(Vector2(at.x, y), line, size, color)
			y += size + 6
			line = word
		else:
			line = candidate
	if line != "": text_at(Vector2(at.x, y), line, size, color)

# --- overlays ----------------------------------------------------------------

func draw_upgrades() -> void:
	fill_screen(Color(0.02,0.03,0.08,0.82))
	text_centered(SCREEN.x * 0.5, 300, "RIFT EVOLUTION", 42, Color("ffe09b"))
	text_centered(SCREEN.x * 0.5, 340, "Choose one upgrade", 20, Color("c8d3ed"))
	var choices: Array[Dictionary] = game.session.upgrades
	var rarity_colors := {"COMMON": Color("b7c5d9"), "RARE": Color("82b7ff"), "LEGENDARY": Color("ffcf77")}
	for i in range(choices.size()):
		var rect := row_rect(i, choices.size(), CARD_SIZE, 400.0, CARD_GAP)
		var edge: Color = rarity_colors[choices[i].rarity]
		draw_panel(rect, Color("202b4a"), edge, 3.0)
		text_at(rect.position + Vector2(24, 52), "%d" % (i + 1), 28, Color("ffe09b"))
		text_at(rect.position + Vector2(24, 88), String(choices[i].rarity), 14, edge)
		text_at(rect.position + Vector2(24, 124), String(choices[i].title), 21, Color("f1f5ff"))
		draw_wrapped(rect.position + Vector2(24, 162), UpgradeCatalog.describe(choices[i]), 16, Color("a9bbde"), rect.size.x - 48.0)
		text_at(rect.position + Vector2(24, 228), "Press %d" % (i + 1), 15, Color("ffe09b"))

func draw_pause() -> void:
	fill_screen(Color(0.02,0.03,0.08,0.76))
	text_centered(SCREEN.x * 0.5, 430, "PAUSED", 48, Color("eaf1ff"))
	text_centered(SCREEN.x * 0.5, 500, "ESC  •  Continue", 21, Color("ffe09b"))
	text_centered(SCREEN.x * 0.5, 540, "S  •  Settings", 21, Color("b6c6e8"))
	text_centered(SCREEN.x * 0.5, 580, "Q  •  Main Menu", 21, Color("b6c6e8"))

func draw_settings(title: String, footer: String) -> void:
	fill_screen(Color("0b1020"))
	text_centered(SCREEN.x * 0.5, 300, title, 44, Color("eaf1ff"))
	var panel := Rect2((SCREEN.x - 700.0) * 0.5, 380, 700, 320)
	draw_panel(panel, Color("182441"), Color("607cab"))
	text_at(panel.position + Vector2(60, 84), "S    Sound Effects", 24, Color("e9f0ff"))
	text_right(panel.end.x - 60, panel.position.y + 84, "ON" if game.sound_enabled else "OFF", 24, Color("69f4d4") if game.sound_enabled else Color("ff718b"))
	text_at(panel.position + Vector2(60, 164), "V    Rift Effects", 24, Color("e9f0ff"))
	text_right(panel.end.x - 60, panel.position.y + 164, "ON" if game.rift_effects_enabled else "OFF", 24, Color("69f4d4") if game.rift_effects_enabled else Color("ff718b"))
	text_at(panel.position + Vector2(60, 244), "F11  Fullscreen", 24, Color("e9f0ff"))
	text_right(panel.end.x - 60, panel.position.y + 244, "ON" if game.is_fullscreen() else "OFF", 24, Color("69f4d4") if game.is_fullscreen() else Color("ff718b"))
	text_centered(SCREEN.x * 0.5, 700, footer, 17, Color("aabce1"))

func draw_game_over() -> void:
	fill_screen(Color(0.03,0.01,0.07,0.78))
	var s := game.session
	text_centered(SCREEN.x * 0.5, 440, "THE RIFT CONSUMES YOU", 36, Color("ff7590"))
	text_centered(SCREEN.x * 0.5, 492, "Time survived: %02d:%02d  •  Kills: %d" % [int(s.run_time)/60, int(s.run_time)%60, s.kills], 20, Color("d2d9ed"))
	text_centered(SCREEN.x * 0.5, 532, "Wave %d reached  •  +%d coins earned" % [s.round_number, s.round_number * 4 + int(s.kills / 4)], 20, Color("ffcf77"))
	text_centered(SCREEN.x * 0.5, 580, "SPACE: retry   •   ESC: main menu", 21, Color("ffe09b"))
