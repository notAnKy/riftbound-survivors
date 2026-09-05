# Project architecture

The project is now split by responsibility rather than kept in a single script.

- `main.gd`: application state and input routing.
- `scripts/game/game_session.gd`: simulation (player, enemies, bullets, XP, abilities).
- `scripts/ui/game_ui.gd`: menus, HUD, upgrade overlay, and other presentation UI.
- `scripts/audio/audio_sfx.gd`: runtime-generated sound effects.
- `scripts/data/gun_catalog.gd`: weapon definitions.
- `scripts/data/character_catalog.gd`: playable-character definitions.
- `scripts/data/upgrade_catalog.gd`: rarity-weighted upgrade rolls.
- `scripts/save/profile_manager.gd`: persistent coins and unlocks.
- `assets/sprites/`: the four sprites the game actually loads, cut from the Kenney pack in `assets/kenney/`.

Next additions belong in focused modules: enemy definitions in `scripts/data`, new mechanics in `scripts/game`, and screens/widgets in `scripts/ui`.
