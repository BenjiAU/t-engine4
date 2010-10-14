-- ToME - Tales of Middle-Earth
-- Copyright (C) 2009, 2010 Nicolas Casalini
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-- Nicolas Casalini "DarkGod"
-- darkgod@te4.org

setStatusAll{no_teleport=true}

defineTile('.', "FLOOR")
defineTile('X', "HARDWALL")
defineTile('!', "DOOR_VAULT")
defineTile('D', "DOOR")
defineTile('^', "FLOOR", nil, nil, {random_filter={add_levels=4}})
defineTile('S', "FLOOR", {random_filter={add_levels=4}}, {random_filter={name="degenerated skeleton warrior", add_levels=4}})
defineTile('A', "FLOOR", {random_filter={type="armor", ego_chance=25}}, nil)
defineTile('G', "FLOOR", nil, {random_filter={name="armoured skeleton warrior", add_levels=4}})
rotates = {"default", "90", "180", "270", "flipx", "flipy"}

return {
[[.........]],
[[...X^X...]],
[[..XX!XX..]],
[[.XXX^XXX.]],
[[.XSD.DSX.]],
[[.XXXGXXX.]],
[[.XSD.DAX.]],
[[.XXX^XXX.]],
[[..XX!XX..]],
[[...X^X...]],
[[.........]],
}
