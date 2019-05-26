all: demo.tzx

clean:
	rm *.tzx
	rm *.bin
	rm *.sym

demo.tzx: demo.asm engine.asm entities.asm drawsprite.asm input.asm im2.asm depack.asm rambank.asm sprites.bin levels.bin marco.pck
	pasmo demo.asm demo.bin demo.sym
	export PACKER=/usr/local/bin/apack; buildtzx -l 1 -i template.txt -o demo.tzx -n DEMO

sprites.bin: sprites.asm gommy.asm 
	pasmo sprites.asm sprites.bin

marco.pck: marco.scr
	apack marco.scr marco.pck

levels.bin: levels.asm mapa01.pck
	pasmo levels.asm levels.bin

mapa01.pck: mapa01.asm
	pasmo mapa01.asm mapa01.bin
	apack mapa01.bin mapa01.pck
