#!/bin/bash

>&2 echo "******************** ts-gfx-all"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/engines/default/modules/boot/data/gfx/ \
	--name ts-gfx-all --trim --max-w 4096 --max-h 4096 --padding IMAGE:1 \
	--mount game/engines/default/modules/boot/ \
	--add-dir-recurs /data/gfx/player \
	--add-dir-recurs /data/gfx/npc \
	--add-dir-recurs /data/gfx/terrain
