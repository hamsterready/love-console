local console = require 'console'

function love.load()
  -- Step 1: load console, parameters are optional, defaults enumerated below
  --  key to open/close console == `
  --  font size == 20
  --  nil == function called when user press return, see console.lua and defaultInputCallback function
  --  false = no key repeat by default, pressing (and not releasing backspace) will act in a strange way
  -- it is fine not to run console.load() 
  -- console.load("`", 20, false, nil)
end

function love.update( dt )
  -- Step 2: make sure that you update console with dt
  console.update(dt)

  -- Use it console.i(msg), console.d(msg), console.e(msg)
  -- if somethingHappend then
  --   console.i("Something ...")
  -- end
end

function love.draw()
  drawGrid()

  -- Step 3: draw console, probably it is best to call console.draw() as a last instruction in the love.draw function
  console.draw()
end

function love.keypressed(key)
  -- Step 4: let console consume keys so that it can open, close (default `) and consume user input
  if console.keypressed(key) then
    return
  end

  if key == "escape" then
    love.event.quit()
  end
end

function love.resize( w, h )
  -- Step 5: if you application allows to resize window then call console.resize on love.resize
  console.resize(w, h)
end


function love.mousepressed(x, y, button)
  -- Step 6: when console is open mouse scroll is supported to scroll the text
  if console.mousepressed(x, y, button) then
    return 
  end

end


function drawGrid( )
  for i =0, math.floor(1920/100) do
    for j=0, math.floor(1080/100) do
      if (i + j) % 2 == 0 then
        love.graphics.setColor(255, 255, 255, 200)
      else
        love.graphics.setColor(255, 255, 255, 220)
      end 
      love.graphics.rectangle("fill", i*100, j*100, 100, 100)
    end
  end
end
