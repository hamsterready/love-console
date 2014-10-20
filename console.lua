local console = {
	_VERSION     = 'love-console v0.1.0',
	_DESCRIPTION = 'Simple love2d console overlay',
	_URL         = 'https://github.com/hamsterready/love-console',
	_LICENSE     = [[
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
	-- hm, should it be stored in console or as module locals?
	-- need to read more http://kiki.to/blog/2014/03/31/rule-2-return-a-local-table/
	
	_KEY_TOGGLE = "`",--"f2",--
	_KEY_SUBMIT = "return",
	_KEY_CLEAR = "escape",
	_KEY_DELETE = "backspace",

	visible = false, 
	delta = 0, 
	logs = {}, 
	linesPerConsole = 0, 
	fontSize = 20, 
	font = nil, 
	firstLine = 0, 
	lastLine = 0, 
	input = "",
	ps = "> ",
	mode = "none", --Options are "none", "wrap", "scissors" or "bind"
	msg = 'Welcome user!\nType "help" for an index of available commands.',

	-- This table has as its keys the names of commands as
	-- strings, which the user must type to run the command.  The
	-- values are themselves tables with two properties:
	--
	-- 1. 'description' A string of information to show via the
	-- help command.
	--
	-- 2. 'implementation' A function implementing the command.
	--
	-- See the function defineCommand() for examples of adding
	-- entries to this table.
	commands = {} 
}
--Dinamyc polygons used to draw the arrows
local up = function (x, y, w)
	w = w * .7
	local h = w * .7
	return {
		x, y + h;
		x + w, y + h;
		x + w/2, y
	}
end

local down = function (x, y, w)
	w = w * .7
	local h = w * .7
	return {
		x, y;
		x + w, y;
		x + w/2, y + h
	}
end
--When you use wrap or bind, the total number of lines depends 
--on the number of lines used by each entry.
local totalLines = function ()
	if console.mode == "wrap" or console.mode == "bind" then
		local a, b = 1, 1
		local width = console.w - console.margin * 2
		for i,t in ipairs(console.logs) do
			b = a
			local _,u = console.font:getWrap(t.msg, width)
			a = a + u
		end
		return a
	else
		return #console.logs
	end
end

local function toboolean(v)
	return (type(v) == "string" and v == "true") or (type(v) == "string" and v == "1") or (type(v) == "number" and v ~= 0) or (type(v) == "boolean" and v)
end

-- http://lua-users.org/wiki/StringTrim trim2
local function trim(s)
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
		if f == '"' and l ~= '"' then
			merging = true
			buf = v
		else
			if merging then
				buf = buf .. " " .. v
				if l == '"' then
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

function console.load(font, keyRepeat, inputCallback, mode)

	if mode == "none" or mode == "wrap" or mode == "scissors" or mode == "bind" then
		console.mode = mode
	end

	love.keyboard.setKeyRepeat(keyRepeat or false)

	console.font		= font or love.graphics.newFont(console.fontSize)
	console.fontSize	= font and font:getHeight() or console.fontSize
	console.margin		= console.fontSize
	console.lineHeight	= console.fontSize * 1.3
	
	console.font:setLineHeight(1.3)

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

function console.setMsg(message)
	console.msg = message
end

function console.resize( w, h )
	console.w, console.h = w, h / 3
	console.linesPerConsole = math.floor((console.h - console.margin * 2) / console.lineHeight)
	console.lastLine = console.firstLine + console.linesPerConsole
end

function console.textInput(t)
	if t ~= console._KEY_TOGGLE and console.visible then
		console.input = console.input .. t
	end
end

function console.keypressed(key) 
	if key ~= console._KEY_TOGGLE and console.visible then
		if key == console._KEY_SUBMIT then
			console.inputCallback(console.input)
			console.input = ""
		elseif key == console._KEY_CLEAR then
			console.input = ""
		elseif key == console._KEY_DELETE then
			console.input = string.sub(console.input, 0, #console.input - 1)
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
	love.graphics.push()
	local r, g, b, a = love.graphics.getColor()
	local font = love.graphics.getFont()
	local blend = love.graphics.getBlendMode()
	local cr, cg, cb, ca = love.graphics.getColorMask()
	local sx, sy, sw, sh = love.graphics.getScissor()
	local canvas = love.graphics.getCanvas()
	
	--set everything to default
	love.graphics.origin()
	love.graphics.setBlendMode("alpha")
	love.graphics.setColorMask(true,true,true,true)
	love.graphics.setCanvas()
	
	if console.mode == "scissors" or console.mode == "bind" then
		love.graphics.setScissor(console.x, console.y, console.w, console.h + console.lineHeight)
	else
		love.graphics.setScissor()
	end

	-- draw console
	local color = console.colors.background
	love.graphics.setColor(color.r, color.g, color.b, color.a)
	love.graphics.rectangle("fill", console.x, console.y, console.w, console.h)
	color = console.colors.input
	love.graphics.setColor(color.r, color.g, color.b, color.a)
	love.graphics.rectangle("fill", console.x, console.h, console.w, console.lineHeight)
	color = console.colors.default
	love.graphics.setColor(color.r, color.g, color.b, color.a)
	love.graphics.setFont(console.font)
	love.graphics.print(console.ps .. " " .. console.input, console.x + console.margin, console.y + console.h + (console.lineHeight - console.fontSize) / 2 -1 )

	if console.firstLine > 0 then
		love.graphics.polygon("fill", up(console.x + console.w - console.margin, console.y + console.margin, console.margin))
	end

	if console.lastLine < #console.logs then
		love.graphics.polygon("fill", down(console.x + console.w - console.margin, console.y +console.h - console.margin * 2, console.margin))
	end
	
	--Wrap and Bind are more complex than the normal mode so they are separated
	if console.mode == "wrap" or console.mode == "bind" then
		local x, width = console.x + console.margin, console.w - console.margin * 2
		local k, j = 1,1
		local lines = totalLines()
		love.graphics.setScissor(x, console.y, width, (console.linesPerConsole + 1) * console.lineHeight)
		for i, t in ipairs(console.logs) do
			local _,u = console.font:getWrap(t.msg, width)
			j = k + u
			if j > console.firstLine and k <= console.lastLine then
				local color = console.colors[t.level]
				love.graphics.setColor(color.r, color.g, color.b, color.a)
				
				local y = console.y + (k - console.firstLine)*console.lineHeight
				
				love.graphics.printf(t.msg, x, y, width)
			end
			k = j
		end
	else
		--This is the normal section
		for i, t in ipairs(console.logs) do
			if i > console.firstLine and i <= console.lastLine then
				local color = console.colors[t.level]
				love.graphics.setColor(color.r, color.g, color.b, color.a)
				love.graphics.print(t.msg, console.x + console.margin, console.y + (i - console.firstLine)*console.lineHeight)
			end
		end
	end
	-- rollback
	love.graphics.setCanvas(canvas)
	love.graphics.pop()
	love.graphics.setFont(font)
	love.graphics.setColor(r, g, b, a)
	love.graphics.setBlendMode(blend)
	love.graphics.setColorMask(cr, cg, cb, ca)
	love.graphics.setScissor(sx, sy, sw, sh)
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
		console.firstLine = math.max(1 - console.linesPerConsole, console.firstLine - 1)
		consumed = true
	end

	if button == "wd" then
		console.firstLine = math.min(totalLines() - 1, console.firstLine + 1)
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
--THIS IS A REALLY DANGEROUS FUNCTION, REMOVE IT IF YOU DONT NEED IT
console.defineCommand(
	"lua",
	"Lets you run lua code from the terminal",
	function(args)
		local t = {}
		for k,v in pairs(args) do
			local ok,err = pcall(loadstring(v))
			if ok then
				if err then
					console.d(err)
				end
			else
				console.e(err)
			end
		end
	end,
	true
)

console.defineCommand(
	"msg",
	"Shows/sets the intro message.",
	function(args)
		if args[1] then
			console.msg = args[1]
			console.i("Message updated.")
		else
			console.i(console.msg)
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
			-- I'm not sure what's going on causing this to need to run twice sometimes - but I haven't broken it since.
			console.commands[name].implementation(merge_quoted(args))
		else
			console.e('Command "' .. name .. '" not supported, type help for help.')
		end
	end
end

-- http://stackoverflow.com/questions/1426954
local function string_split(self, pat)
	pat = pat or '%s+'
	local st, g = 1, self:gmatch("()("..pat..")")
	local function getter(segs, seps, sep, cap1, ...)
		st = sep and seps + #sep
		return self:sub(segs, (seps or 0) - 1), cap1 or sep, ...
	end
	return function() if st then return getter(st, g()) end end
end

function a(str, level)
	for str in string_split(str, "\n") do
		table.insert(console.logs, #console.logs + 1, {level = level, msg = string.format("%07.02f [".. level .. "] %s", console.delta, str)})
		console.lastLine = totalLines()
		console.firstLine = console.lastLine - console.linesPerConsole
	end
end

-- auto-initialize so that console.load() is optional
console.load()
console.i(console.msg)

return console
