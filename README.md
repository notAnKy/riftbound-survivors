# Riftbound Survivors

An original Godot 4 arena-survival prototype where sci-fi drones, fantasy rifts, and undead hordes collide.

## Run it

1. Install/open **Godot 4.x**.
2. Import `project.godot` from this folder.
3. Press **F6** or the play button.

## Controls

- **WASD** or arrow keys: move
- Weapons fire automatically at the nearest enemy.
- **1**, **2**, or **3**: choose a level-up evolution.
- **Q**: Rift Dash (short cooldown).
- **E**: Rift Nova (area damage, longer cooldown).
- **Escape**: pause; press **S** from the title screen or pause menu for settings.
- **Space**: start another run after dying.

## Armaments

- **Plasma Blaster**: rapid energy bolts.
- **Rune Wand**: powerful piercing magic bolts.
- **Void Shotgun**: five-projectile close-range blast.

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

## Round flow

Each round has a timer. Enemy health, speed, and spawn pressure increase by round. When the timer ends, defeat remaining enemies; then a short intermission begins before the next round. Rounds 5, 10, 15, and so on start with a boss.

Coins are saved automatically in Godot's `user://riftbound_profile.json` profile. They unlock the Rune Wand, Void Shotgun, Arcane Warden, and Iron Revenant from the title screen.
