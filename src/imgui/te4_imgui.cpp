/*
    TE4 - T-Engine 4
    Copyright (C) 2009 - 2018 Nicolas Casalini

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    Nicolas Casalini "DarkGod"
    darkgod@te4.org
*/
#include "imgui/te4_imgui.hpp"

// Thanks to darkgnostic, avoids me having to write it myself ;)
namespace ImGui {
	enum ImKeyModifiers {
		KeyModNone = 0, KeyModAlt = 1, KeyModCtrl = 2 , KeyModShift = 4
	};

	inline ImKeyModifiers operator|(ImKeyModifiers a, ImKeyModifiers b) {
		return static_cast<ImKeyModifiers>(static_cast<int>(a) | static_cast<int>(b));
	}

	bool HotkeyEntered(ImKeyModifiers modifiers /* Alt, Shift, Ctrl, Meta */, int key) {
		int flag = 0;
		auto io = &ImGui::GetIO();
		flag += (io->KeyCtrl ? KeyModCtrl : 0);
		flag += (io->KeyShift ? KeyModShift : 0);
		flag += (io->KeyAlt ? KeyModAlt : 0);

		bool key_down = ImGui::IsKeyPressed(key);
		bool mod_ok = (modifiers == flag);
		if (key_down && mod_ok) {
			return true;
		}
		return false;
	}
}

bool igHotkeyEntered(int mods, int key) {
	return ImGui::HotkeyEntered(static_cast<ImGui::ImKeyModifiers>(mods), key);
}

void te4_imgui_forcelink() {}
