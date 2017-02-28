API = require("buttonAPI")
local event = require("event")
local computer = require("computer")
local term = require("term")
local component = require("component")
local gpu = component.gpu

local rs = component.proxy(component.get("b7b"))
local cl = require("colors")
local sd = require("sides")

function API.fillTable()  
  API.setTable("Rot-1", rotg1, 2,17,5,7)
  API.setTable("Gelb-1", gelb1, 2,17,9,11)
  API.setTable("Gruen-1", gruen1, 2,17,13,15)
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

function rotg1()
  API.toggleButton("Rot-1")
  if buttonStatus == true then
    rs.setBundledOutput(sd.south, cl.orange, 0)
    rs.setBundledOutput(sd.south, cl.magenta, 0)
    rs.setBundledOutput(sd.south, cl.white, 255)
  else
    rs.setBundledOutput(sd.south, cl.white, 0)
  end
end

function gelb1()
  API.toggleButton("Gelb-1")
  if buttonStatus == true then
    rs.setBundledOutput(sd.south, cl.white, 0)
    rs.setBundledOutput(sd.south, cl.magenta, 0)
    rs.setBundledOutput(sd.south, cl.orange, 255)
  else
    rs.setBundledOutput(sd.south, cl.orange, 0)
  end
end

function gruen1()
  API.toggleButton("Gruen-1")
  if buttonStatus == true then
    rs.setBundledOutput(sd.south, cl.white, 0)
    rs.setBundledOutput(sd.south, cl.orange, 0)
    rs.setBundledOutput(sd.south, cl.magenta, 255)
  else
    rs.setBundledOutput(sd.south, cl.magenta, 0)
  end
end

function neustartst()
  computer.shutdown(true)
end

term.setCursorBlink(false)
gpu.setResolution(160, 50)
API.clear()
API.fillTable()
API.heading("Signal Steuerung")
API.label(1,50,"Version Alpha 1.0 von Blauerdrache.")

while true do
  getClick()
end