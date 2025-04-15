# YABG (Yet Another Block Game)

<p align="center"><img src="resources/yabg.png"/></p>

## Play instructions:

As of now, the game has no real content, but it will be added once I consider
the engine good-enough. A couple of environment variables can be set for
testing purposes:
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

Keyboard controls:
 W:          Walk up
 A:          Walk left
 S:          Walk down
 D:          Walk right
 , (comma):  Break block
 . (period): Place stone

Gamepad controls:
 Left stick:  Move
 TODO: break, place blocks

In the future I will likely make both placing and breaking use the same button
and depend on the item currently highlighted.

## Dependency installation:
```sh
# Regardless of distro, Zig 0.14 is required, so just install that using zigup
# unless your distro has it in their repo

# Nix:
nix develop # Flake-enabled
nix-shell   # No flake

# Ubuntu/Debian:
libx11-dev libxcursor-dev libxrandr-dev libxinerama-dev libxi-dev libgl-dev

# Alpine:
libx11-dev libxcursor-dev libxrandr-dev libxinerama-dev libxi-dev mesa-gl mesa-dev libc-dev pipewire
```

## Building instructions:
```
git clone https://github.com/mgord9518/yabg
cd yabg

zig build # Or `zig build run`
```
