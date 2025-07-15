# YABG (Yet Another Block Game)

<p align="center"><img src="docs/yabg.png"/></p>

## Play instructions:

As of now, the game has no real content, just a procedurally-generated world
that you can walk around, break and place tiles. I've been working on a
large refactor of the engine, and once I deem it "good-nuff", I will work
on adding stuff to do

The following environment variables are currently supported:
```
SCALE_FACTOR <uint> # Scaling factor, changes the size of game pixels relative
                    # to the system's native resolution (default=4)

WINDOW_WIDTH  <uint> # Sets the window width in pixels
WINDOW_HEIGHT <uint> # Sets the window height in pixels

DEBUG_MODE <bool> # Start the game in debug mode (F3 menu)
```

### Controls
```
Keyboard controls:
 w:          Walk up
 a:          Walk left
 s:          Walk down
 d:          Walk right
 . (period): Break tile
 / (slash):  Place tile

 ← (left):  Select previous item in hotbar
 → (right): Select next item in hotbar
 1-6:       Jump to hotbar item

Gamepad controls:
 Left stick:  Move
 TODO: break, place blocks
```

In the future I will likely make both placing and breaking use the same button
and depend on the item currently highlighted.

## Dependency installation:
```sh
# Zig 0.14 is required, so just install that using zigup or your OS's package
# manager (probably isn't present if you don't use a rolling release)

# Nix:
nix develop     # Flake-enabled
nix-shell ./nix # No flake

# Ubuntu/Debian:
sudo apt install libx11-dev libxcursor-dev libxrandr-dev libxinerama-dev libxi-dev libgl-dev libxkbcommon-dev libegl-dev libwayland-dev
```

## Building instructions:
```sh
git clone https://github.com/mgord9518/yabg
cd yabg

zig build # Or `zig build run`
```
