RIFTBOUND SURVIVORS  -  playtest build
======================================

Run RiftboundSurvivors.exe. Nothing to install, no dependencies.

Windows will probably warn you
------------------------------
The first launch may show "Windows protected your PC" (SmartScreen). That is
because the file is not code-signed, not because anything is wrong with it.
Click "More info" then "Run anyway".

Controls
--------
Everything is listed in-game under Settings > Controls, for whichever device
you are holding. The short version:

  WASD / arrows     move (that is the only thing you control)
  Left Shift        Rift Dash
  E                 Rift Nova - damages and throws back everything near you
  1-4               pick a level-up reward, or buy that shop slot
  L                 pin the shop offer you are on (it survives rerolls)
  R                 reroll the shop
  Space             start the next wave
  Escape            pause
  F11 / Alt+Enter   fullscreen
  Mouse             works everywhere; menus also take arrows + Enter

Controller works everywhere too, and the on-screen prompts switch to it the
moment you pick one up. On a PlayStation pad: Cross selects, Circle goes back,
Square dashes (and pins in the shop), Triangle casts the nova (and rerolls),
R1 starts the next wave, Options pauses.

Co-op
-----
CO-OP on the title screen opens a join screen. Hold Space or Cross to join --
whoever holds it first is player one. Any two devices work: two controllers, or
a controller and the keyboard. Each player picks their own survivor and starting
weapon, and gets their own half of the shop and level-up screens. The arena is
shared. You only lose when both of you are down; if one survives the wave, the
other comes back for the next one.

Settings
--------
Window mode, resolution, quality, and a frame-rate cap. **If it stutters, try
Quality: Low** -- it cuts the things that pile up with the crowd. Show FPS puts
a counter in the top-left corner.

How it works
------------
Weapons fire themselves at whatever is nearest. You only move. Each wave is a
timed fight; clear it and the shop opens, which is where the run actually gets
built. A run is 20 waves, with a boss every fifth. Winning unlocks the next
danger level (there are 6).

Weapons belong to classes (KINETIC, ARCANE, BRUTAL, SWIFT, VOID). Holding two
or more of a class pays an escalating bonus - most of them cost you something
too.

Two of the same weapon at the same tier can be merged into one of the next tier
up, using the COMBINE button on the weapon slot in the shop. This does not
happen by itself: two barrels firing now, or one weapon that hits much harder,
is a real choice. A full rack refuses a purchase rather than merging for you --
combine a pair to free the slot.

Characters are earned, not bought. Each locked one is behind an achievement,
and the armory tells you which.

What would help most
--------------------
1. Which wave you died on, and what killed you.
2. Do the enemies feel too FAST? They were made faster and fewer on purpose,
   and that is the change most likely to feel unfair rather than hard.
3. Are the bosses on waves 5, 10 and 15 real fights now? They fire in a plus
   and star pattern - is that readable, or just noise?
4. Did you ever feel unkillable? Standing still in a crowd should kill you.
5. If it stutters: turn on Show FPS and say what the number is, and whether
   Quality: Low changes it. Those are two different problems.
6. Anything that looked or sounded wrong.

Your progress (coins, unlocks, settings, volumes) is saved to
  %APPDATA%\Godot\app_userdata\Riftbound Survivors\
Delete that folder to start completely fresh.

Made with Godot 4.7. Every image in the game was drawn for it and is original.
The sound effects and music are CC0, and the two fonts are under the SIL Open
Font License - see assets/ATTRIBUTION.md in the source repository.
