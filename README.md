# Riftbound Survivors

An original Godot 4 arena-survival prototype where sci-fi drones, fantasy rifts, and undead hordes collide.

## Run it

1. Install/open **Godot 4.x**.
2. Import `project.godot` from this folder.
3. Press **F6** or the play button.

## Controls

- **WASD** or arrow keys: move
- Weapons fire automatically at the nearest enemy.
- **1**-**4**: choose a level-up evolution, or buy that slot in the shop.
- **R**: reroll the shop. **Space**: start the next wave.
- **Q**: Rift Dash (short cooldown).
- **E**: Rift Nova, a shockwave that damages and throws back everything around you.
- **Escape**: pause; press **S** from the title screen or pause menu for settings.
- **F11** or **Alt+Enter**: toggle fullscreen — or click the Fullscreen row in Settings.
- Menus take the **arrow keys and Enter**, or the mouse.
- **Space**: start another run after dying.

## The loop

Each wave is a timed fight. Clear it and the **shop** opens: spend the materials
you picked up on weapons and passive items, reroll the board if you dislike it,
sell anything you have outgrown, then head back in. Materials are both the shop
currency and your XP, so every pickup counts twice.

You can carry **six weapons at once**, each firing on its own cooldown at its
own target. Buy three of the same weapon at the same tier and they **merge into
the next tier up**.

## Armaments

Plasma Pistol, Rune Wand, Void Shotgun, Splinter SMG, Arc Rifle, Rift Lance and
Scrap Cannon, each in four tiers. Sixteen passive items feed a stat sheet
covering damage, attack speed, crit, armor, dodge, speed, lifesteal, range,
harvesting and luck.

## Current prototype

The arena runs on Godot physics: the player and every enemy are collision bodies, so a crowd spreads out under its own pressure and the arena walls actually stop you. The prototype includes timed rounds, intermissions, boss rounds every five rounds, escalating enemy power, auto-fire, XP drops, rarity-based level-up selections, character/gun unlocks, and a persistent coin profile. Characters and enemies use CC0 sprites from Kenney's Topdown Shooter pack (see `assets/ATTRIBUTION.md`); the arena, HUD, effects, and menus are all drawn in code.

## Enemies

- **Husk**: the baseline shambler.
- **Runner**: fast, weaves as it closes.
- **Gunner**: holds its range and shoots back.
- **Brute**: slow, heavy, hits hard.
- **Marauder**: quick and durable, from round 6.
- **Warden**: weaving elite, from round 8.
- **Riftlord**: the boss that opens every fifth round.

## Staying alive

Enemies sometimes drop a **bandage**, and you heal a little every twenty kills
regardless. Materials fly to you from a wide radius, so you rarely have to walk
onto a drop; the Pickup Range stat widens it further.

## Round flow

Each round has a timer. Enemy health, speed, and spawn pressure increase by round. When the timer ends, defeat remaining enemies; then a short intermission begins before the next round. Rounds 5, 10, 15, and so on start with a boss.

Coins are saved automatically in Godot's `user://riftbound_profile.json` profile. They unlock the Rune Wand, Void Shotgun, Arcane Warden, and Iron Revenant from the title screen.
