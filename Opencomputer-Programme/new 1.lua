--#requires
 
local fs = require("filesystem")
local term = require("term")
local serialization = require("serialization")
local component = require("component")
local event = require("event")
local colors = require("colors")
 
--#variables
local gpu = component.gpu
local config = {}
local reactor = nil
local running = true
local screen = "main"

 
--#main
 
function main()
  set_color_scheme()
  screen = "main"
  gpu.setResolution(160,50)
  event.listen("touch",listen)
  while running do
    gpu.setBackground(config.color_scheme.background)
    term.clear()
    draw_menubar()
    draw_main()
    os.sleep(.05)
  end
end
 
--#draw_menubar
 
function draw_menubar()
  term.setCursor(1,1)
  gpu.setBackground(config.color_scheme.menubar.background)
  gpu.setForeground(config.color_scheme.menubar.foreground)
  term.clearLine()
  term.setCursor(1,1)
  term.write("Status: ")
  if reactor.getActive() then
    gpu.setForeground(config.color_scheme.success)
    term.write("Online ")
  else
    gpu.setForeground(config.color_scheme.error)
    term.write("Offline ")
  end
  gpu.setForeground(config.color_scheme.menubar.foreground)
  term.write(" Fluessigkeit Temperatur: ")
  gpu.setForeground(config.color_scheme.info)
  term.write(round(reactor.getFuelTemperature()).."C ")
  gpu.setForeground(config.color_scheme.menubar.foreground)
  term.write(" Gehaeuse Temperatur: ")
  gpu.setForeground(config.color_scheme.info)
  term.write(round(reactor.getCasingTemperature()).."C ")
  term.setCursor(97,1)
  gpu.setForeground(config.color_scheme.menubar.foreground)
  term.write("[")
  gpu.setForeground(config.color_scheme.error)
  term.write("Beenden")
  gpu.setForeground(config.color_scheme.menubar.foreground)
  term.write("]")
end
 
 
--#set_color_scheme
 
function set_color_scheme()
  config.color_scheme = {}
  config.color_scheme.background = 0x0000BB
  config.color_scheme.button = 0x606060
  config.color_scheme.button_disabled = 0xC0C0C0
  config.color_scheme.foreground = 0x000000
  config.color_scheme.progressBar = {}
  config.color_scheme.progressBar.background = 0x000000
  config.color_scheme.progressBar.foreground = 0xFFFFFF
  config.color_scheme.menubar={}
  config.color_scheme.menubar.background = 0x000000
  config.color_scheme.menubar.foreground = 0xFFFFFF
  config.color_scheme.success = 0x008000
  config.color_scheme.error = 0x800000
  config.color_scheme.info = 0x808000
  config.auto_power = {}
  config.auto_power.enabled = false
  config.auto_power.start_percent = 15
  config.auto_power.stop_percent = 80
end
 
 
--#draw_main
 
function draw_main()
    --#gpu.setBackground(config.color_scheme.button)
    --#gpu.setForeground(0xFFFFFF)
    --#gpu.fill(1,2,69,3," ")
    --#term.setCursor(25,3)
    --#term.write("")
    gpu.setBackground(0x088A08)
    gpu.fill(2,3,9,3," ")
    term.setCursor(4,4)
    term.write("Power")
  gpu.setForeground(0xFFFFFF)
  gpu.setBackground(config.color_scheme.button)
  gpu.fill(1,8,20,3," ")
  gpu.fill(1,14,20,3," ")
  gpu.fill(1,20,20,3," ")
  term.setCursor(2,9)
  term.write("Abfall Level")
  term.setCursor(2,15)
  term.write("Fuel zulauf Level")
  term.setCursor(2,21)
  term.write("Reaktor Fuel Level")
  drawProgressBar(21,8,65,3,reactor.getWasteAmount()/10^3)
  drawProgressBar(21,14,65,3,reactor.getFuelAmount()/reactor.getFuelAmountMax())
  drawProgressBar(21,20,65,3,reactor.getFuelReactivity()/10^3)
end
 

 
--#drawProgressBar
 
function drawProgressBar(x,y,w,h,percent)
  gpu.setBackground(config.color_scheme.progressBar.background)
  gpu.fill(x,y,w,h," ")
  gpu.setBackground(config.color_scheme.progressBar.foreground)
  gpu.fill(x,y,w*percent,h," ")
end
 
--#listen
 
function listen(name,address,x,y,button,player)
  if x >= 98 and x <= 104 and y == 1 then
    running = false
  end
if screen =="main" then
  if x >= 4 and x <= 8 and y == 4 then
    reactor.setActive(not reactor.getActive())
  end
end
end
 
--#countTable
 
function countTable(table)
local result = 0
  for k,v in pairs(table) do
    result = result+1
  end
return result
end
 
--#round
 
function round(num,idp)
  local mult = 10^(idp or 0)
  return math.floor(num*mult+0.5)/mult
end


event.ignore("touch",listen)
gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
term.clear()