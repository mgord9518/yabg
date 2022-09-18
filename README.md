# YABG (Yet Another Block Game)

<p align="center"><img src="resources/yabg.avif"/></p>

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

Dependencies:
```
zig
```

Building and running:
```
git clone --recurse-submodules https://github.com/mgord9518/yabg
cd yabg

zig build # Or `zig build run`
```

Goals to get it up to feature parity:
 - [ ] Tile loading (partially complete)
 - [ ] Chunk loading (partially complete)
 - [ ] Chunk generation
 - [ ] Entity loading
 - [ ] Collision
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
