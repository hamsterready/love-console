local console = {
	_LICENSE = [[
		The MIT License (MIT)

		Copyright (c) 2014 Maciej Lopacinski

		Permission is hereby granted, free of charge, to any person obtaining a copy
		of this software and associated documentation files (the "Software"), to deal
		in the Software without restriction, including without limitation the rights
		to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
		copies of the Software, and to permit persons to whom the Software is
		furnished to do so, subject to the following conditions:

		The above copyright notice and this permission notice shall be included in all
		copies or substantial portions of the Software.

		THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
		IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
		FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
		AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
		LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
		OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
		SOFTWARE.
	]],
	_VERSION = 'love-console v0.1.0',
	_DESCRIPTION = 'Simple love2d console overlay',
	_URL = 'https://github.com/hamsterready/love-console',
	_KEY_TOGGLE = "`",
	_KEY_SUBMIT = "return",
	_KEY_CLEAR = "escape",
	_KEY_DELETE = "backspace",
	_KEY_UP = "up",
	_KEY_DOWN = "down",
	_KEY_PAGEDOWN = "pagedown",
	_KEY_PAGEUP = "pageup",

	visible = false,
	delta = 0,
	logs = {},
	history = {},
	historyPosition = 0,
	linesPerConsole = 0,
	fontSize = 20,
	font = nil,
	firstLine = 0,
	lastLine = 0,
	input = "",
	ps = "> ",
	motd = "Greetings, traveler!\nType \"help\" for an index of available commands.",

	-- This table has as its keys the names of commands as
	-- strings, which the user must type to run the command. The
	-- values are themselves tables with two properties:
	--
	-- 1. 'description' A string of information to show via the
	-- /help command.
	--
	-- 2. 'implementation' A function implementing the command.
	--
	-- See the function defineCommand() for examples of adding
	-- entries to this table.
	commands = {}
}

local function toboolean(v)
	return (type(v) == "string" and v == "true") or (type(v) == "string" and v == "1") or (type(v) == "number" and v ~= 0) or (type(v) == "boolean" and v)
end

-- http://lua-users.org/wiki/StringTrim trim2
local function trim(s)
	s = s or ""
	return s:match "^%s*(.-)%s*$"
end

-- http://wiki.interfaceware.com/534.html
local function string_split(s, d)
	local t = {}
	local i = 0
	local f
	local match = '(.-)' .. d .. '()'
	
	if string.find(s, d) == nil then
		return {s}
	end
	
	for sub, j in string.gmatch(s, match) do
		i = i + 1
		t[i] = sub
		f = j
	end
	
	if i ~= 0 then
		t[i+1] = string.sub(s, f)
	end
	
	return t
end

local function merge_quoted(t)
	local ret = {}
	local merging = false
	local buf = ""
	for k, v in ipairs(t) do
		local f, l = v:sub(1,1), v:sub(v:len())
		if f == "\"" and l ~= "\"" then
			merging = true
			buf = v
		else
			if merging then
				buf = buf .. " " .. v
				if l == "\"" then
					merging = false
					table.insert(ret, buf:sub(2,-2))
				end
			else
				if f == "\"" and l == f then
					table.insert(ret, v:sub(2, -2))
				else
					table.insert(ret, v)
				end
			end
		end
	end
	return ret
end

function console.load(font, keyRepeat, inputCallback)
	love.keyboard.setKeyRepeat(keyRepeat or false)

	console.font		= font or love.graphics.newFont(console.fontSize)
	console.fontSize	= font and font:getHeight() or console.fontSize
	console.margin		= console.fontSize
	console.lineSpacing	= 1.25
	console.lineHeight	= console.fontSize * console.lineSpacing
	console.x, console.y = 0, 0

	console.colors = {}
	console.colors["I"] = {r = 251, g = 241, b = 213, a = 255}
	console.colors["D"] = {r = 235, g = 197, b =  50, a = 255}
	console.colors["E"] = {r = 222, g =  69, b =  61, a = 255}
	
	console.colors["background"] = 	{r = 23, g = 55, b = 86, a = 190}
	console.colors["input"]      = 	{r = 23, g = 55, b = 86, a = 255}
	console.colors["default"]    = 	{r = 215, g = 213, b = 174, a = 255}

	console.inputCallback = inputCallback or console.defaultInputCallback

	console.resize(love.graphics.getWidth(), love.graphics.getHeight())
end

function console.newHotkeys(toggle, submit, clear, delete)
	console._KEY_TOGGLE = toggle or console._KEY_TOGGLE
	console._KEY_SUBMIT = submit or console._KEY_SUBMIT
	console._KEY_CLEAR = clear or console._KEY_CLEAR
	console._KEY_DELETE = delete or console._KEY_DELETE
end

function console.setMotd(message)
	console.motd = message
end

function console.resize( w, h )
	console.w, console.h = w, h / 3
	console.y = console.lineHeight - console.lineHeight * console.lineSpacing

	console.linesPerConsole = math.floor((console.h - console.margin * 2) / console.lineHeight)

	console.h = math.floor(console.linesPerConsole * console.lineHeight + console.margin * 2)

	console.firstLine = console.lastLine - console.linesPerConsole
	console.lastLine = console.firstLine + console.linesPerConsole
end

function console.textinput(t)
	if t ~= console._KEY_TOGGLE and console.visible then
		console.input = console.input .. t
	end
end

function console.keypressed(key)
	local function push_history(input)
		local trimmed = trim(console.input)
		local valid = trimmed ~= ""
		if valid then
			table.insert(console.history, trimmed)
			console.historyPosition = #console.history
		end
		console.input = ""
		return valid
	end
	if key ~= console._KEY_TOGGLE and console.visible then
		if key == console._KEY_SUBMIT then
			local msg = console.input
			if push_history() then
				console.inputCallback(msg)
			end
		elseif key == console._KEY_CLEAR then
			console.input = ""
		elseif key == console._KEY_DELETE then
			console.input = string.sub(console.input, 0, #console.input - 1)
		end

		-- history traversal
		if #console.history > 0 then
			if key == console._KEY_UP then
				console.historyPosition = math.min(math.max(console.historyPosition - 1, 1), #console.history)
				console.input = console.history[console.historyPosition]
			elseif key == console._KEY_DOWN then
				local pushing = console.historyPosition + 1 == #console.history + 1
				console.historyPosition = math.min(console.historyPosition + 1, #console.history)
				console.input = console.history[console.historyPosition]
				if pushing then
					console.input = ""
				end
			end
		end
		
		if key == console._KEY_PAGEUP then
			console.firstLine = math.max(0, console.firstLine - console.linesPerConsole)
			console.lastLine = console.firstLine + console.linesPerConsole
		elseif key == console._KEY_PAGEDOWN then
			console.firstLine = math.min(console.firstLine + console.linesPerConsole, #console.logs - console.linesPerConsole)
			console.lastLine = console.firstLine + console.linesPerConsole
		end

		return true
	elseif key == console._KEY_TOGGLE then
		console.visible = not console.visible
		return true
	end
	return false
end

function console.update( dt )
	console.delta = console.delta + dt
end

function console.draw()
	if not console.visible then
		return
	end

	-- backup
	local r, g, b, a = love.graphics.getColor()
	local font = love.graphics.getFont()

	-- draw console
	local color = console.colors.background
	love.graphics.setColor(color.r, color.g, color.b, color.a)
	love.graphics.rectangle("fill", console.x, console.y, console.w, console.h)
	color = console.colors.input
	love.graphics.setColor(color.r, color.g, color.b, color.a)
	love.graphics.rectangle("fill", console.x, console.y + console.h, console.w, console.lineHeight)
	color = console.colors.default
	love.graphics.setColor(color.r, color.g, color.b, color.a)
	love.graphics.setFont(console.font)
	love.graphics.print(console.ps .. " " .. console.input, console.x + console.margin, console.y + console.h + (console.lineHeight - console.fontSize) / 2 -1 )

	if console.firstLine > 0 then
		love.graphics.print("^", console.x + console.w - console.margin, console.y + console.margin)
	end

	if console.lastLine < #console.logs then
		love.graphics.print("v", console.x + console.w - console.margin, console.y + console.h - console.margin * 2)
	end

	for i, t in pairs(console.logs) do
		if i > console.firstLine and i <= console.lastLine then
			local color = console.colors[t.level]
			love.graphics.setColor(color.r, color.g, color.b, color.a)
			love.graphics.print(t.msg, console.x + console.margin, console.y + (i - console.firstLine)*console.lineHeight)
		end
	end

	-- rollback
	love.graphics.setFont(font)
	love.graphics.setColor(r, g, b, a)
end

function console.mousepressed( x, y, button )
	if not console.visible then
		return false
	end
	
	if not (x >= console.x and x <= (console.x + console.w)) then
		return false
	end
	
	if not (y >= console.y and y <= (console.y + console.h + console.lineHeight)) then
		return false
	end

	local consumed = false

	if button == "wu" then
		console.firstLine = math.max(0, console.firstLine - 1)
		consumed = true
	end

	if button == "wd" then
		console.firstLine = math.min(#console.logs - console.linesPerConsole, console.firstLine + 1)
		consumed = true
	end
	console.lastLine = console.firstLine + console.linesPerConsole

	return consumed
end

function console.d(str)
	a(str, 'D')
end

function console.i(str)
	a(str, 'I')
end

function console.e(str)
	a(str, 'E')
end

function console.defineCommand(name, description, implementation, hidden)
	console.commands[name] = {
		description = description,
		implementation = implementation,
		hidden = hidden or false
	}
end

-- private stuff

console.defineCommand(
	"help",
	"Shows information on all commands.",
	function ()
		console.i("Available commands are:")
		for name,data in pairs(console.commands) do
			if not data.hidden then
				console.i(string.format("  %s - %s", name, data.description))
			end
		end
	end
)

console.defineCommand(
	"quit",
	"Quits your application.",
	function () love.event.quit() end
)

console.defineCommand(
	"clear",
	"Clears the console.",
	function ()
		console.firstLine = 0
		console.lastLine = 0
		console.logs = {}
	end
)

console.defineCommand(
	"sv_cheats",
	"~It is a mystery~",
	function(enable)
		local change = toboolean(dopefish)
		dopefish = toboolean(enable)
		change = dopefish ~= change
		if not change then
			console.e("No change")
			return
		end
		if dopefish then
			console.e("The rain in spain stays mainly in the plain.")
		else
			console.i("How now brown cow.")
		end
	end,
	true
)

console.defineCommand(
	"motd",
	"Shows/sets the intro message.",
	function(motd)
		if motd then
			console.motd = motd
			console.i("Motd updated.")
		else
			console.i(console.motd)
		end
	end
)

function console.defaultInputCallback(input)
	local commands = string_split(input, ";")

	for _, line in ipairs(commands) do
		local args = merge_quoted(string_split(trim(line), " "))
		local name = args[1]
		table.remove(args, 1)
		if console.commands[name] ~= nil then
			local status, error = pcall(function()
				-- I'm not sure what's going on causing this to need to run twice sometimes - but I haven't broken it since.
				console.commands[name].implementation(unpack(merge_quoted(args)))
			end)
			if not status then
				console.e(error)
			end
		else
			console.e("Command \"" .. name .. "\" not supported, type help for help.")
		end
	end
end

function a(str, level)
	for _, str in ipairs(string_split(str, "\n")) do
		table.insert(console.logs, #console.logs + 1, {level = level, msg = string.format("%07.02f [".. level .. "] %s", console.delta, str)})
		console.lastLine = #console.logs
		console.firstLine = console.lastLine - console.linesPerConsole
		print(console.logs[console.lastLine].msg)
	end
end

-- auto-initialize so that console.load() is optional
console.load()
console.i(console.motd)

return console
