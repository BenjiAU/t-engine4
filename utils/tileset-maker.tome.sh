#!/bin/bash


./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-terrain --min-w 4096 --min-h 4096 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/terrain/

./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-npc --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/npc/

./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-object --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/object/

./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-trap --min-w 1024 --min-h 512 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/trap/

./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-talents-effects --min-w 4096 --min-h 2048 --max-w 4096 --max-h 4096 --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/talents/ \
	--add-dir-recurs /data/gfx/effects/

./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-dwarf_female --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/dwarf_female/

./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-dwarf_male --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/dwarf_male/

./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-elf_female --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/elf_female/

./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-elf_male --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/elf_male/

./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-ghoul --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/ghoul/

./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-halfling_female --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/halfling_female/

./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-halfling_male --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/halfling_male/

./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-human_female --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/human_female/

./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-human_male --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/human_male/

./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-ogre_female --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/ogre_female/

./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-ogre_male --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/ogre_male/

./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-orc_male --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/orc_male/

./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-runic_golem --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/runic_golem/

./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-skeleton --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/skeleton/

./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-yeek --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/yeek/

