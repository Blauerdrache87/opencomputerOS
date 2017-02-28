API = require("buttonAPI")
local event = require("event")
local computer = require("computer")
local term = require("term")
local component = require("component")
local gpu = component.gpu

local rs = component.proxy(component.get("b75"))
local cl = require("colors")
local sd = require("sides")

function API.fillTable()  
  API.setTable("Licht", lichtst, 2,12,5,7)
  API.setTable("Neustarten", neustartst, 20,34,20,22)
  API.screen()
end

function getClick()
  local _, _, x, y = event.pull(1,touch)
  if x == nil or y == nil then
    local h, w = gpu.getResolution()
    gpu.set(h, w, ".")
    gpu.set(h, w, " ")
  else 
    API.checkxy(x,y)
  end
end

function lichtst()
  API.toggleButton("Licht")
  if buttonStatus == true then
    os.sleep(1)
    rs.setBundledOutput(sd.north, cl.red, 0)
    os.sleep(0.5)
    rs.setBundledOutput(sd.north, cl.white, 255)
  else
    os.sleep(2)
    rs.setBundledOutput(sd.north, cl.white, 0)
    os.sleep(0.5)
    rs.setBundledOutput(sd.north, cl.red, 255)
  end
end

function neustartst()
  computer.shutdown(true)
end

term.setCursorBlink(false)
gpu.setResolution(35, 25)
API.clear()
API.fillTable()
API.heading("Keller Licht Steuerung")
API.label(1,24,"Version 1.0 von Blauerdrache.")

while true do
  getClick()
end