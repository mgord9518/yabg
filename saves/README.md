Saves directory for development testing, this will move to somewhere standard
such as `~/.local/share` on Linux when the game becomes playable

The chunk tileset will be a compressed bytestream, 0 representing a null tile
(air), and every other tile will be assigned a numerical value from 0-255.
Multiple tilesets will be able to load into one chunk to allow for easy modding
and extensions of the vanilla game. Chunks will also have a JSON-formatted
meta section depecting entities and their metadata, stored items in chests, etc
