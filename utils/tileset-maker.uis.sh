#!/bin/bash

>&2 echo "******************** ts-ui-all"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/engines/default/data/gfx/ \
	--name ts-ui-all --max-w 4096 --max-h 4096 --padding IMAGE:1 \
	--mount game/engines/default/ \
	--add-dir-recurs /data/gfx/achievement-ui \
	--add-dir-recurs /data/gfx/dark-ui \
	--add-dir-recurs /data/gfx/invisible-ui \
	--add-dir-recurs /data/gfx/metal-ui \
	--add-dir-recurs /data/gfx/parchment-ui \
	--add-dir-recurs /data/gfx/simple-ui \
	--add-dir-recurs /data/gfx/stone-ui \
	--add-dir-recurs /data/gfx/tombstone-ui \
	--add-dir-recurs /data/gfx/ui

>&2 echo "******************** ts-ui-tome"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-ui-tome --max-w 4096 --max-h 4096 --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/dark-ui/ \
	--add-dir-recurs /data/gfx/deathbox-ui/ \
	--add-dir-recurs /data/gfx/metal-ui/ \
	--add-dir-recurs /data/gfx/quest-escort-ui/ \
	--add-dir-recurs /data/gfx/quest-fail-ui/ \
	--add-dir-recurs /data/gfx/quest-idchallenge-ui/ \
	--add-dir-recurs /data/gfx/quest-main-ui/ \
	--add-dir-recurs /data/gfx/quest-ui/ \
	--add-dir-recurs /data/gfx/quest-win-ui/ \
	--add-dir-recurs /data/gfx/ui/ \
	--exclude "_backglow"
