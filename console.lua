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

	visible = false, 
	keyCode = "`", 
	delta = 0, 
	logs = {}, 
	linesPerConsole = 0, 
	fontSize = 20, 
	font = nil, 
	firstLine = 0, 
	lastLine = 0, 
        input = "",
        ps = "> ",

        -- This table has as its keys the names of commands as
        -- strings, which the user must type to run the command.  The
        -- values are themselves tables with two properties:
        --
        -- 1. 'description' A string of information to show via the
        -- /help command.
        --
        -- 2. 'implementation' A function implementing the command.
        --
        -- See the function defineCommand() for examples of adding
        -- entries to this table.
        commands = {} }

function console.load( keyCode, fontSize, keyRepeat, inputCallback )
  love.keyboard.setKeyRepeat(keyRepeat or false)

	console.keyCode = keyCode or console.keyCode
	console.fontSize = fontSize or console.fontSize
	console.margin = console.fontSize
	console.font = love.graphics.newFont(console.fontSize)
	console.lineHeight = console.fontSize * 1.4
	console.x, console.y = 0, 0
	console.colors = {}
	console.colors["I"] = {r = 251, g = 241, b = 213, a = 255}
	console.colors["D"] = {r = 235, g = 197, b =  50, a = 255}
	console.colors["E"] = {r = 222, g =  69, b =  61, a = 255}

	console.inputCallback = inputCallback or console.defaultInputCallback

	console.resize(love.graphics.getWidth(), love.graphics.getHeight())
end

function console.resize( w, h )
	console.w, console.h = w, h / 5
	console.linesPerConsole = math.floor((console.h - console.margin * 2) / console.lineHeight)
end

function console.textInput(t)
	console.input = console.input .. t
end

function console.keypressed(key) 
	if key ~= "`" and console.visible then
		if key == "return" then
			console.inputCallback(console.input)
			console.input = ""
		elseif key == "escape" then
			console.input = ""
		elseif key == "backspace" then
			console.input = string.sub(console.input, 0, #console.input - 1)
		end
		return true
	elseif key == "`" then
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
	love.graphics.setColor(23,55,86, 190)
	love.graphics.rectangle("fill", console.x, console.y, console.w, console.h)
	love.graphics.setColor(23,55,86, 255)
	love.graphics.rectangle("fill", console.x, console.h, console.w, console.lineHeight)
	love.graphics.setColor(215,213,174, 255)
	love.graphics.setFont(console.font)
	love.graphics.print(console.ps .. " " .. console.input, console.x + console.margin, console.h + (console.lineHeight - console.fontSize) / 2 -1 )

	if console.firstLine > 0 then
		love.graphics.print("^", love.graphics.getWidth() - console.margin, console.margin)
	end

	if console.lastLine < #console.logs then
		love.graphics.print("v", love.graphics.getWidth() - console.margin, console.h - console.margin * 2)
	end

	for i, t in pairs(console.logs) do
		if i > console.firstLine and i <= console.lastLine then
			local color = console.colors[t.level]
			love.graphics.setColor(color.r, color.g, color.b, color.a)
			love.graphics.print(t.msg, console.margin, (i - console.firstLine)*console.lineHeight)
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

  local consumed = false

  if button == "wu" then
  	console.firstLine = math.max(1 - console.linesPerConsole, console.firstLine - 1)
 		consumed = true
  end

  if button == "wd" then
  	console.firstLine = math.min(#console.logs - 1, console.firstLine + 1)
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

function console.defineCommand(name, description, implementation)
    console.commands[name] = {
        ["description"] = description,
        ["implementation"] = implementation,
    }
end

-- private stuff

console.defineCommand(
    "/help",
    "Shows information on all commands.",
    function ()
        console.i("Available commands are:")
        for name,data in pairs(console.commands) do
            console.i(string.format("  %s - %s", name, data.description))
        end
    end
)

console.defineCommand(
    "/quit",
    "Quits your application.",
    function () love.event.quit() end
)

console.defineCommand(
    "/clear",
    "Clears the console.",
    function ()
        console.firstLine = 0
        console.lastLine = 0
        console.logs = {}
    end
)

function console.defaultInputCallback(name)
    if console.commands[name] ~= nil then
        console.commands[name].implementation()
    else
        console.e("Command \"" .. name .. "\" not supported, type /help for help.")
    end
end

function a(str, level)
	table.insert(console.logs, #console.logs + 1, {level = level, msg = string.format("%07.02f [".. level .. "] %s", console.delta, str)})
	console.lastLine = #console.logs
	console.firstLine = console.lastLine - console.linesPerConsole
end

-- auto-initialize so that console.load() is optional
console.load()
console.i("Welcome to love-console v0.1.0")
console.i("Use console.i(text) to append info msg to the console")
console.d("Use console.d(text) to append debug msg to the console")
console.e("Use console.e(text) to append error msg to the console")


return console
