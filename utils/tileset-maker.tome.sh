#!/bin/bash

>&2 echo "******************** ts-gfx-terrain"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-terrain --min-w 4096 --min-h 4096 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/terrain/

echo
>&2 echo "******************** ts-gfx-npc"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-npc --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/npc/

echo
>&2 echo "******************** ts-gfx-object"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-object --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/object/

echo
>&2 echo "******************** ts-gfx-trap"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-trap --min-w 1024 --min-h 512 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/trap/

echo
>&2 echo "******************** ts-gfx-talents-effects"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-talents-effects --min-w 4096 --min-h 2048 --max-w 4096 --max-h 4096 --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/talents/ \
	--add-dir-recurs /data/gfx/effects/

echo
>&2 echo "******************** ts-gfx-racedoll-dwarf_female"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-dwarf_female --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/dwarf_female/

echo
>&2 echo "******************** ts-gfx-racedoll-dwarf_male"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-dwarf_male --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/dwarf_male/

echo
>&2 echo "******************** ts-gfx-racedoll-elf_female"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-elf_female --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/elf_female/

echo
>&2 echo "******************** ts-gfx-racedoll-elf_male"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-elf_male --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/elf_male/

echo
>&2 echo "******************** ts-gfx-racedoll-ghoul"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-ghoul --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/ghoul/

echo
>&2 echo "******************** ts-gfx-racedoll-halfling_female"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-halfling_female --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/halfling_female/

echo
>&2 echo "******************** ts-gfx-racedoll-halfling_male"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-halfling_male --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/halfling_male/

echo
>&2 echo "******************** ts-gfx-racedoll-human_female"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-human_female --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/human_female/

echo
>&2 echo "******************** ts-gfx-racedoll-human_male"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-human_male --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/human_male/

echo
>&2 echo "******************** ts-gfx-racedoll-ogre_female"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-ogre_female --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/ogre_female/

echo
>&2 echo "******************** ts-gfx-racedoll-ogre_male"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-ogre_male --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/ogre_male/

echo
>&2 echo "******************** ts-gfx-racedoll-orc_male"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-orc_male --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/orc_male/

echo
>&2 echo "******************** ts-gfx-racedoll-runic_golem"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-runic_golem --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/runic_golem/

echo
>&2 echo "******************** ts-gfx-racedoll-skeleton"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-skeleton --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/skeleton/

echo
>&2 echo "******************** ts-gfx-racedoll-yeek"
\time -f '%E' ./t-engine --utility spritesheet-generator --write-to game/modules/tome/data/gfx/ \
	--name ts-gfx-racedoll-yeek --min-w 2048 --min-h 2048 --max-w 4096 --max-h 4096 --trim --padding IMAGE:1 \
	--mount game/modules/tome/ \
	--add-dir-recurs /data/gfx/shockbolt/player/yeek/

