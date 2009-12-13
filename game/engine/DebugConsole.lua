require "engine.class"
require "engine.Dialog"

module(..., package.seeall, class.inherit(engine.Dialog))

-- Globals to all instances of the console
scroll = 0
history = {}
line = ""
com_sel = 0
commands = {}

function _M:init()
	engine.Dialog.init(self, "Lua Console", core.display.size())
	self:keyCommands{
		_RETURN = function()
			self.commands[#self.commands+1] = self.line
			table.insert(self.history, 1, self.line)
			if self.line:match("^=") then self.line = "return "..self.line:sub(2) end
			local f, err = loadstring(self.line)
			if err then
				table.insert(self.history, 1, err)
			else
				local res = {pcall(f)}
				for i, v in ipairs(res) do
					if i > 1 then
						table.insert(self.history, 1, (i-1).." :=: "..tostring(v))
					end
				end
			end
			self.line = ""
			self.changed = true
		end,
		_UP = function()
			self.com_sel = util.bound(self.com_sel + 1, 1, #self.commands)
			if self.commands[self.com_sel] then
				self.line = self.commands[self.com_sel]
			end
		end,
		_DOWN = function()
			self.com_sel = util.bound(self.com_sel - 1, 1, #self.commands)
			if self.commands[self.com_sel] then
				self.line = self.commands[self.com_sel]
			end
		end,
		_ESCAPE = function()
			game:unregisterDialog(self)
		end,
		_BACKSPACE = function()
			self.line = self.line:sub(1, self.line:len() - 1)
		end,
		__TEXTINPUT = function(c)
			self.line = self.line .. c
			self.changed = true
		end,
	}
end

function _M:drawDialog(s, w, h)
	local i, dh = 1, 0
	while dh < self.h do
		if not self.history[self.scroll + i] then break end
		s:drawString(self.font, self.history[self.scroll + i], 0, self.ih - (i + 1) * self.font:lineSkip(), 255, 255, 255)
		i = i + 1
		dh = dh + self.font:lineSkip()
	end

	s:drawString(self.font, self.line, 0, self.ih - self.font:lineSkip(), 255, 255, 255)
end
