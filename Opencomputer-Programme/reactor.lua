--#requires
 
local fs = require("filesystem")
local term = require("term")
local serialization = require("serialization")
local component = require("component")
local event = require("event")
local component = require("component")
local colors = require("colors")
 
--#variables
local gpu = component.gpu
local config = {}
local reactor = nil
local running = true
local screen = "main"
--#install
 
function install()
  screen = "install"
  term.clear()
  print("Vorraussetzung:")
  print("Tier 2 Bildschirm")
  print("Tier 2 Grafikkarte")
  print("Ist der BigReactor Compunter Port per") 
  print("Kabel mit dem Pc verbunden")
  print("Tastatur fuers installieren noetig,") 
  print("danach per Pad benutzbar")
  print()
  print("Alle vorraussetzungen erfuellt? (j/n)")
  local result = false
  while not result do
    local name, adress, char, code, player = event.pull("key_down")
    if code == 36 then
      result = true
    elseif code == 49 then
      os.exit()
    else
      print("Invalid response")
    end
  end
  --set resolution and continue
  gpu.setResolution(105,25)
  gpu.setForeground(0x000000)
  term.clear()
  gpu.setBackground(0x0000BB)
  term.clear()
  gpu.setBackground(0x808080)
  gpu.fill(20,9,40,6," ")
  term.setCursor(20,9)
  print("Danke fuers Runterladen")
  term.setCursor(20,10)
  print("Reactor Controll")
  term.setCursor(20,11)
  print("Druecke Okay fuer weiter")
  term.setCursor(20,12)
  print("Druecke abbrechen um die") 
    term.setCursor(20,13)
  print("installation abzubrechen")
  gpu.setBackground(0x008000)
  gpu.fill(20,14,20,1," ")
  term.setCursor(29,14)
  print("Okay")
  gpu.setBackground(0x800000)
  gpu.fill(40,14,20,1," ")
  term.setCursor(48,14)
  print("abbrechen")
  local event_running = true
  while event_running do
    local name, address, x, y, button, player = event.pull("touch")
    if x >= 20 and x <= 39 and y == 14 then
      print("ok")
      event_running = false
    elseif x>=40 and x <= 59 and y == 14 then
      os.exit()
    end
  end
  install_pick_reactor()
  set_color_scheme()
  save_config()
  main()
end
 
--#main
 
function main()
  screen = "main"
  gpu.setResolution(105,25)
  read_config()
  reactor = component.proxy(config.reactor)
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
 
--#save_config
 
function save_config()
  local file = io.open("/etc/reactor-steuerung.cfg","w")
  file:write(serialization.serialize(config,false))
  file:close()
end
 
--#read_config
 
function read_config()
  local file = io.open("/etc/reactor-steuerung.cfg","r")
  local c = serialization.unserialize(file:read(fs.size("/etc/reactor-steuerung.cfg")))
  file:close()
  for k,v in pairs(c) do
    config[k] = v
  end
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
 
--#install_pick_reactor
 
function install_pick_reactor()
  gpu.setBackground(0x0000BB)
  term.clear()
  gpu.setBackground(0x808080)
  local reactors = component.list("br_reactor")
  local len = 3
  for k,v in pairs(reactors) do
    if len<#k then
      len = #k
    end
  end
  local s_x = 40-len/2
  local s_y = 13-round(countTable(reactors)/2)
  gpu.fill(s_x-1,s_y-2,len+2,countTable(reactors)+3," ")
  term.setCursor(s_x+9,s_y-2)
  print("select a reactor")
  local i = s_y
  for k,v in pairs(reactors) do
    term.setCursor(s_x,i)
    print(k)
    i=i+1
  end
  local event_running = true
  while event_running do
    local name, address, x, y, button, player = event.pull("touch")
    print(y-s_y)
    if x>=s_x and x <= s_x+len and y>=s_y and y<= s_y+countTable(reactors) then
      event_running = false
      local i = y-s_y
      for k,v in pairs(reactors) do
        if i == 0 then
          config.reactor = k
        end
        i=i-1
      end
    end
  end
end
 
--#draw_main
 
function draw_main()
    gpu.setBackground(config.color_scheme.button)
    gpu.setForeground(0xFFFFFF)
    gpu.fill(1,2,69,3," ")
    term.setCursor(25,3)
    term.write("Enable Auto-Power")
    gpu.setBackground(0x153F3F)
    gpu.fill(70,2,11,3," ")
    term.setCursor(73,3)
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

--#init
if not fs.exists("/etc/reactor-steuerung.cfg") then
  install()
else
  main()
end

event.ignore("touch",listen)
gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
term.clear()