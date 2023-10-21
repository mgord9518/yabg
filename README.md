# YABG (Yet Another Block Game)

<p align="center"><img src="resources/yabg.png"/></p>

A fun project to give an excuse to slightly neglect my other projects.
I originally wrote it in Go with Ebitengine, but I wanted to learn something
new, so Zig and Raylib it is. I don't have any plans to post the original Go
code, but I'd be willing if it were requested for some reason. It was written
HORRIBLY, and the Zig version already has some of the harder parts already
ported over, so I see little reason.

The idea is as follows: a top-down, Minecraft-esque building and exploration 
game with either partial or fully turn-based combat, 2-layer world interaction
(only "floor" and "wall" type tiles), exploration both below and above the base
layer, such as hell and floating islands, computer-based automation (think
Minecraft's Computercraft mod), simple RPG-like progression and plenty of mini
boss fights. I like the idea of making it a pretty hard game, and might take
some inspiration from Terrafirmacraft's semi-realistic crafting, such as
knapping and casting. To make it all a bit more unique, I decided to use
dozenal (aka duodecimal or base 12) numbering. In the future I'll add an option
to switch to decimal or hex, but currently it doesn't even have a basic settings
menu

If the game actually turns out to be half decent, I'll probably end up charging
a small fee ($5-$10?) on stores such as Steam, MS Store, phone app stores, etc.
The code will ALWAYS be completely open source, however, and I'll have portable
downloads for Linux and Windows (and macOS if I can get the means to test it)
here free to use.

## Play instructions:

There are currently releases for Linux and Windows (x86_64) that can simply be
downloaded and ran. As of now, the game has no real content, but it will be
added once I consider the engine good-enough. A couple of enviornment variables
can be set for testing purposes:
```
SCALE_FACTOR  # Must be set to an integer, this will change the scaling of the
              # game (default=6)

PLAYER_SPEED  # Changes the speed of the player per tick. Each game tick is
              # 1/30th of a second, so if you want to move one pixel per tick,
			  # the speed would be set to 2 (default)

WINDOW_WIDTH  # Must be set to an integer, sets the window width in pixels
WINDOW_HEIGHT # Same as WINDOW_WIDTH but for height

DEBUG_MODE    # Start the game in debug mode (F3 menu)
```

PC controls:
 WASD:        Move
 Left click:  Break block
 Right click: Place stone

Gamepad controls:
 Left stick:  Move
 TODO: break, place blocks

In the future I will likely make both placing and breaking use the same button
and depend on the item currently highlighted.

## Dependencies:
```sh
# Regardless of distro, the latest version of Zig is required. This should be
# obtained through the AUR, Snap or the official tarball. Zig is still in
# heavy development and even slightly older versions that might be found in a
# standard repository likely won't be able to build YABG

# Ubuntu/Debian:
libx11-dev libxcursor-dev libxrandr-dev libxinerama-dev libxi-dev libgl-dev

# Alpine:
libx11-dev libxcursor-dev libxrandr-dev libxinerama-dev libxi-dev mesa-gl mesa-dev libc-dev pipewire
```

## Building instructions:
```
git clone --recurse-submodules https://github.com/mgord9518/yabg
cd yabg

zig build # Or `zig build run`
```

Short-term goals:
 - [X] Tile loading
 - [X] Chunk loading
 - [X] Chunk generation
 - [ ] Entity loading
 - [X] Collision
 - [ ] Complete animations
 - [ ] Controls config loading
 - [X] F3 debug menu

Future goals:
 - [ ] Entity generation
 - [ ] Combat
 - [ ] Music
 - [ ] Inventory
 - [ ] Crafting
 - [ ] Multiplayer
 - [ ] Settings menu
