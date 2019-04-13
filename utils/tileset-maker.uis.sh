#!/bin/bash

cd game/engines/default/data/gfx
rm -f ts-ui-*
lua ../../../../../utils/tileset-maker-precise.lua ts-ui-metal /data/gfx/ `find metal-ui/ -name '*png'`
lua ../../../../../utils/tileset-maker-precise.lua ts-ui-dark /data/gfx/ `find dark-ui/ -name '*png'`

cd -
cd game/modules/tome/data/gfx
rm -f ts-ui-*
# lua ../../../../../utils/tileset-maker-precise.lua ts-ui-tome /data/gfx/ `find ui/ -name '*png'`
lua ../../../../../utils/tileset-maker-precise.lua ts-ui-darktome /data/gfx/ `find dark-ui/ -name '*png'`
