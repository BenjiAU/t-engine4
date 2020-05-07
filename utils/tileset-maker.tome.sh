#!/bin/bash


>&2 echo "******************** ts-gfx-terrain"
time ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-terrain --min-w 4096 --min-h 4096 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/terrain/

>&2 echo "******************** ts-gfx-npc"
time ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-npc --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/npc/

>&2 echo "******************** ts-gfx-object"
time ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-object --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/object/

>&2 echo "******************** ts-gfx-trap"
time ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-trap --min-w 1024 --min-h 512 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/trap/

>&2 echo "******************** ts-gfx-talents-effects"
time ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-talents-effects --min-w 4096 --min-h 2048 --max-w 4096 --max-h 4096 --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/talents/ \
	--add-dir-recurs /data/gfx/effects/

>&2 echo "******************** ts-gfx-racedoll-dwarf_female"
time ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-dwarf_female --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/dwarf_female/

>&2 echo "******************** ts-gfx-racedoll-dwarf_male"
time ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-dwarf_male --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/dwarf_male/

>&2 echo "******************** ts-gfx-racedoll-elf_female"
time ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-elf_female --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/elf_female/

>&2 echo "******************** ts-gfx-racedoll-elf_male"
time ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-elf_male --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/elf_male/

>&2 echo "******************** ts-gfx-racedoll-ghoul"
time ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-ghoul --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/ghoul/

>&2 echo "******************** ts-gfx-racedoll-halfling_female"
time ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-halfling_female --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/halfling_female/

>&2 echo "******************** ts-gfx-racedoll-halfling_male"
time ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-halfling_male --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/halfling_male/

>&2 echo "******************** ts-gfx-racedoll-human_female"
time ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-human_female --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/human_female/

>&2 echo "******************** ts-gfx-racedoll-human_male"
time ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-human_male --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/human_male/

>&2 echo "******************** ts-gfx-racedoll-ogre_female"
time ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-ogre_female --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/ogre_female/

>&2 echo "******************** ts-gfx-racedoll-ogre_male"
time ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-ogre_male --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/ogre_male/

>&2 echo "******************** ts-gfx-racedoll-orc_male"
time ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-orc_male --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/orc_male/

>&2 echo "******************** ts-gfx-racedoll-runic_golem"
time ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-runic_golem --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/runic_golem/

>&2 echo "******************** ts-gfx-racedoll-skeleton"
time ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-skeleton --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/skeleton/

>&2 echo "******************** ts-gfx-racedoll-yeek"
time ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-yeek --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/yeek/

