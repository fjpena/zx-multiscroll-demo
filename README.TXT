This is an example of a ZX Spectrum multiscroll engine using
Jonathan 'Joffa' Smith's technique, as seen in Cobra. I started
from the engine description shared in [1], then added my own stuff.

You can find the following files:

- demo.asm: main file.
- depack.asm: aplib depack routines, originally created by dwedit and
  optimized by Metalbrain.
- drawsprite.asm: sprite drawing routines. This is a 16x16 sprite drawing
  routine, with mask, that features a sprite cache.
- engine.asm: the scrolling engine itself, all routines that take care of
  displaying the background.
- entities.asm: an entity management engine. Only used for the "player" in
  the demo, but able to manage other entity types (enemies, objects, etc.).
- im2.asm: z80 IM2 handling routines.
- input.asm: Generic Spectrum input routines.
- rambank.asm: 128k Spectrum RAM banking routines.
- *.asm: support files (map, tiles, etc.).

You will need the following tools to build the demo.tzx file:

- Pasmo assembler, from http://pasmo.speccy.org
- Apack compressor, from from http://www.smspower.org/maxim/uploads/SMSSoftware/aplib12.zip?sid=23bcb2a72f8a461be5cad0f46f7c3681,
  renamed to "apack" and run via Wine.
- Buildtzx utility, from https://github.com/fjpena/zx-spectrum/tree/master/buildtzx

[1] - https://sites.google.com/site/kevinphair/home/jonathan-smith---a-tribute/frobush/Cobra/5-thescroller
