# Evercore
A fork of [Smalleste](https://github.com/CelesteClassic/smalleste) with additional features for mod developers.

## Features

- Large / scrolling level support
- Level table system and mapdata string loading
- Moving solid / semisolid object system
- Prebuilt horizontal springs and jumpthroughs
- Object draw layering
- Support for multiple berries per level
- Tons of free tokens
- Lots of free sprite space
- Backwards compatible with vanilla levels

## Info

[If you need help getting started, consider joining the Celeste Classic Discord and hopping over to #mod-dev!](https://discord.com/invite/9Dm3NCS)

## Level Table

Evercore uses a completely reworked level system: Rather than simply loading rooms using coordinates, Evercore pulls from a table of level strings, each containing the coordinates, size, and name of the level.
The level table is constructed using the following format:

`[id]="[x],[y],[w],[h],[title]",`

The four coordinate variables are stored in **room units**: 16\*16 chunks of the PICO-8 map. For more precise room sizing and placement decimal numbers are supported.
The `[id]=` can be omitted and PICO-8 will automatically assign the string to the lowest positive unoccupied index (except zero).
These values are unpacked into the lvl_ variables when load_level() is called.

## Mapdata Table

To load a level from a mapdata string, also known as **hex loading**, first you'll need to open the cart with the level you're trying to copy and run the `get_mapdata()` function, using the map position and size of the level. This will generate a **mapdata string** and copy it into your clipboard.
Then, open the cart you're trying to load the level in and add a new **level string** to the `levels` table. Set it's coordinates to (0,0) and use the same size as the level you're trying to load. It's okay if this overlaps with other levels, as that section of the map will be temporarily overwritten (and restored upon leaving the level).
Finally, paste the mapdata string into the `mapdata` table at the same index as the level string you added to the levels table.

The default Evercore cart hex loads Summit if you want to see a better example on how to set this up.

## Layers

Evercore uses a layer system to draw its objects. Layers can be assigned to any object as a number variable - typically in the object's init function, but it can be changed at any time. As a general rule, objects on higher numbered layers are drawn later, resulting in them appearing on top of other objects.

- Objects on layers 2+ will be drawn above the player.
- The player is drawn on layer 1 - drawing other objects on this layer will result in undefined behavior.
- Objects on layer 0 will be drawn below the player, but above the terrain - this is the default layer.
- Objects on negative layers will be drawn below the terrain.

## Documentation

#### Functions

* vector(x, y) - Returns a table with the format {x=[x], y=[y]}
* rectangle(x, y, w, h) - Returns a table with the format {x=[x], y=[y], w=[w], h=[h]}

* load_level(id) - Load a level from the string stored at index [id] of the levels table
* next_level() - Load a level from the string stored at index [lvl_id + 1] of the levels table

* get_mapdata(x, y, w, h) - Grab a mapdata string at **tile coordinates** [x], [y] with a **tile size** of [w], [h]

* move_camera(obj) - Attempt to move the camera towards object [obj]

* init_object(type, x, y, tile)- Creates a new object of type [type] at postition [x], [y], with sprite [tile]
* obj.init_smoke(ox, oy) - Spawns a smoke object at [obj] with an offset of [ox], [oy]
  
#### Globals

* levels - A table containing the coordinates of every level that can be loaded
* mapdata - A table containing mapdata strings to be loaded by the indexed level
* music_switches - A table containing music ids to play upon loading the indexed level

* lvl_id - The table index of the currently loaded level

* lvl_x - The X position of the currently loaded level, in tiles
* lvl_y - The Y position of the currently loaded level, in tiles
* lvl_w - The width of the currently loaded level, in tiles
* lvl_h - The height of the currently loaded level, in tiles

* lvl_pw - The width of the currently loaded level, in pixels
* lvl_ph - The height of the currently loaded level, in pixels

* lvl_title - The title of the currently loaded level, will be nil if not set in the level string

* cam_x - The x position of the center of the camera
* cam_y - The y position of the center of the camera

* cam_spdx - The current x velocity of the camera
* cam_spdy - The current y velocity of the camera

* cam_gain - How quickly the camera should center on the player

* ui_timer - Tracks how many frames the level title should display on screen.

* time_ticking - Whether the speedrun timer is running. The flag object sets this to false when touched. Berries will not be counted if grabbed while this false
* collected - The unique ID of every berry the player has collected. Objects with the "is_fruit" type variable set to true will not initialize if their id is contained here
* fruit_count - How many berries the player has collected
  
#### Object Variables

* type - The object type table to use as a base

* collideable - Whether other objects can collide with this object
* collides - Whether this object collides with solids and semisolids
* solid_obj - Whether this object is marked as a **solid** and will push and carry objects that collide with it
* semisolid_obj - Whether this object is marked as a **semisolid** and will carry objects on top of it

* spr - The current sprite of the object
* flip - A vector containing booleans. Used to determine if the object's sprite should be flipped in the set directions

* x - The object's current X position
* y - The object's current Y position
* spd - A vector containing decimal numbers. Stores the object's current speed
* rem - A vector containing decimal numbers. Stores the remainder of the player's postion

* hitbox - A rectangle containing integers. Used to calculate the position and size of the object's hitbox

* id - A unique identifier generated for every object based on their position.

* layer - Which layer to draw the object on

#### Object Type Variables

* is_fruit - Whether the object should check if its ID is stored in the `collected` table before being initialized.