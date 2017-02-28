-- A small program to easily look over, and modify files.

-- CONTROLS:
-- [W] and [S] to move up and down the list.
-- [CTRL+W] to exit the explorer.
-- [CTRL+E] to change the CWD to the selected directory
-- [CTRL+Del] to delete the file/folder
-- [CTRL+C] to prepare a file/folder for copying.
-- [CTRL+V] to copy/move a prepared file/folder. (Requires the cursor to be over a directory)
-- [C] to collapse/uncollapse a folder (Collapsed folders have a "~~" at the end of them)
-- [D] to create a folder
-- [F] to create a file
-- [E] to open the edit program on the currently selected file
-- [F3] to rename a file/folder

-- COLOURS(At least.. For 8-bit colours):
-- Orange = Currently selected
-- Purple = Current working directory
-- Green  = Prepared to be copied/moved

-- POSSIBLE FETURES:
-- A bit more colour for Tier 3/2 screens.
-- Clean up the code a bit. More optimisation.
-- Show the size of each file. (This one would take a decent amount of work if I wanted the text to be in line)
-- That one must-need feature for this certain obscure reason that I'm satanic for not putting in.

-- BUGS:
-- ... At some point change "pallet" to "palette"
-- I haven't ran into anymore bugs than the ones I've fixed.
 
-- Imports
local fs       = require("filesystem")
local gpu      = require("component").gpu
local term     = require("term")
local shell    = require("shell")
local keyboard = require("keyboard")
local event    = require("event")
local debug    = require("serialization")

-- Screen resolution
local w,h = gpu.getResolution()

local root     = {} -- The root directory 
local startY   = 2  -- The Y position to start the item list
local maxY     = h  -- The Y position to end the item list
local toSkip   = 0  -- How many items to skip over when populating the item list
local redrawSelected = false -- True if printList should only redraw the lines for the selected item(optimisation reasons).

-- The different modes printList uses
local printMode_None    = 0 -- Normal mode, redraws the list one-by-one
local printMode_CopyTop = 1 -- Optimisation. Copies all but the first item in the list, and redraws the copy 1 y-axis higher
local printMode_CopyBot = 2 -- Optimisation. Copies all but the last item in the list, and redraws the copy 1 y-axist lower
local printMode         = printMode_None

-- Item list settings
local selected       = 1   -- The index of the currently selected item in the item list.
local selectedItem   = {}  -- A reference to the currently selected item.
local dirSettings    = {}  -- A cache to store settings of directories (such as if they're collapsed or not.) This is used to remember settings between item list refreshes
local savedItem      = nil -- A reference to the item that has been "saved". Used for copying/moving

-- Save modes
local saveMode_none  = 0
local saveMode_copy  = 1
local saveMode_move  = 2
local saveMode       = saveMode_none  -- What the savedItem is being used for
local modes = {[saveMode_none]="NONE", [saveMode_copy]="COPY", [saveMode_move]="MOVE"}

-- General variables
local running    = true
local itemList   = {} -- Contains all of the items to draw on screen.

-- Statuses
local status_rename         = "ENTER NAME: "
local status_errorRename    = "UNABLE TO RENAME ITEM"
local status_errorDelete    = "UNABLE TO DELETE ITEM"
local status_errorCopy      = "UNABLE TO COPY ITEM"
local status_errorNewDir    = "UNABLE TO MAKE DIRECTORY"
local status_errorNewFile   = "UNABLE TO MAKE FILE"
local status_errorMove      = "UNABLE TO MOVE ITEM"
local status_errorNotDir    = "PLEASE SELECT A DIR"
local status_errorNotFile   = "PLEASE SELECT A FILE"
local status_errorNoItem    = "PLEASE SELECT ITEM TO COPY/MOVE"
local status_normal         = "Exit:{CTRL+W} Copy:{CTRL+C} Cut:{CTRL+X} Paste:{CTRL+V} Make CWD:{CTRL+E} Remove:{CTRL+Del} (Un)collapse:{C} Rename:{F3} Folder:{D} File:{F} Edit:{E}"
local status                = status_normal

local version = "Jaster File Explorer v1.1"

-- All of the colours for the program
local colours = 
{
  bars          = 0,
  text_normal   = 0,
  text_highlight= 0,
  item_cwd      = 0,
  item_highlight= 0,
  item_saved    = 0,

  usePallet     = false
}

-- Setup all of the colours used
if (gpu.getDepth() == 1) then
  colours.bars             = 1
  colours.text_normal      = 1
  colours.text_highlight   = 0
  colours.item_cwd         = 1
  colours.item_highlight   = 1
  colours.item_saved       = 1
elseif (gpu.getDepth() == 8) then
  colours.bars             = 0x00264D
  colours.text_normal      = 0xFFFFFF
  colours.text_highlight   = 0xFFFFFF
  colours.item_cwd         = 0x660066
  colours.item_highlight   = 0x803300
  colours.item_saved       = 0x004400
else
  local col = require("colors")
  colours.usePallet = true

  colours.bars             = col.blue
  colours.text_normal      = col.white
  colours.text_highlight   = col.white
  colours.item_cwd         = col.magenta
  colours.item_highlight   = col.red
  colours.item_saved       = col.green
end

-- Adds a directory to the list
local function addDirectory(parent, dir)
  local dirEntry = 
  {
    name      = dir.."/",
    isDir     = true,
    collapsed = false,
    children  = {},
    tabCount  = 0,
    parent    = parent
  }

  if (dirSettings[dirEntry.name] == nil) then
    dirSettings[dirEntry.name] = {collapsed = false}
  end

  for entry in fs.list(dir) do
    entry = fs.concat(dir, entry)

    if (fs.isDirectory(entry)) then
      addDirectory(dirEntry, entry)
    else
      table.insert(dirEntry.children, {name=entry, isDir=false, tabCount = 0, parent = dirEntry})
    end
  end

  if (parent ~= nil) then 
    table.insert(parent.children, dirEntry) 
  else
    root = dirEntry
  end
end

-- Populates the item list to contain the correct items to use.
local function populateList(dir, tabCount, skipCount)
  if (skipCount == toSkip) then
    dir.tabCount = tabCount
    table.insert(itemList, dir)
  else
    skipCount = skipCount + 1  
  end
  tabCount = tabCount + 1

  -- Get cached settings
  local cache = dirSettings[dir.name]
  if (cache ~= nil) then
    dir.collapsed = cache.collapsed
  end

  if (dir.collapsed) then return skipCount end

  for i, item in ipairs(dir.children) do
    if (#itemList >= maxY-startY) then break end

    if (item.isDir) then
      skipCount = populateList(item, tabCount, skipCount)
    else
      if (skipCount == toSkip) then
        item.tabCount = tabCount
        table.insert(itemList, item)
      else
        skipCount = skipCount + 1
      end
    end
  end

  return skipCount
end

-- Prints the item list. Sets redrawSelected to false.
local function printList()
  term.setCursor(1, startY)
  local cwd = shell.getWorkingDirectory()
  local draw = true

  -- Just so the root directory gets highlighted
  if (cwd == "/") then cwd = "//" end

  -- CopyTop and CopyBot modes
  -- Copying pixels that have already been drawn makes thing SO MUCH faster <3
  -- Not sure if it still draws a ton of power though
  if (printMode == printMode_CopyTop) then
    gpu.copy(1, startY+1, w, h-(startY+1), 0, -1)
  elseif (printMode == printMode_CopyBot) then
    gpu.copy(1, startY, w, h-(startY+1), 0, 1)
  end

  for i, item in ipairs(itemList) do
    local extraText = ""
    if (item.collapsed and item.isDir) then extraText = " ~~" end

    -- If we're redrawing only the selected item, then redraw the selected item, the one before it, and the one after it.
    -- This is to cover all the possible lines that need to be redrawn
    if (redrawSelected) then
      draw = (i == selected or i == selected-1 or i==selected+1)

      -- Clear the lines we're redrawing if we're not using the normal print mode
      -- This is because the copy modes sometimes mess up, and it leaves text from previous items in the wrong place.
      if (draw and printMode ~= printMode_None) then
        term.setCursor(1, startY + (i - 1))
        term.clearLine()
      end
    end

    if (i == selected) then
      gpu.setBackground(colours.item_highlight, colours.usePallet)
      gpu.setForeground(colours.text_highlight, colours.usePallet)
      selectedItem = item
    elseif (item.name == cwd) then
      gpu.setBackground(colours.item_cwd, colours.usePallet)
      gpu.setForeground(colours.text_highlight, colours.usePallet)
    elseif (savedItem == item) then
      gpu.setBackground(colours.item_saved, colours.usePallet)
      gpu.setForeground(colours.text_highlight, colours.usePallet)
    end
      
    -- We want to make sure that the mode is always drawn.
    if (savedItem == item) then
      extraText = extraText.." ["..modes[saveMode].."]"
    end

    if (draw) then
      term.setCursor(1, startY + (i - 1))
      local tabs = string.rep("  ", item.tabCount)

      print(tabs..item.name..extraText)
    end

    draw = true
    gpu.setBackground(0x000000)
    gpu.setForeground(colours.text_normal, colours.usePallet)
  end

  redrawSelected = false
  printMode      = printMode_None
end

-- Draws the gray bars to make it look pretty
local function drawBars()
  local old = gpu.getBackground()
  gpu.setBackground(colours.bars, colours.usePallet)
  
  gpu.fill(1,    1,    w, 1,    " ")  -- Top bar
  gpu.fill(1,    maxY, w, 1,    " ")  -- Bottom bar
  --gpu.fill(barX, 1,    1, maxY, " ")  -- Middle bar

  gpu.setForeground(colours.text_highlight, colours.usePallet)
  gpu.set(1,          1,     "FILES")
  gpu.set(w-#version, 1,     version)
  gpu.set(1,          maxY,  status)

  gpu.setBackground(old)
end

-- Repopulates the entire list
local function repopulate()
  itemList = {}
  populateList(root, 0, 0)
end

-- Refreshes the list
local function refresh(newRoot)
  if newRoot then
    savedItem = nil
    addDirectory(nil, "/")
  end

  status = status_normal
  repopulate()

  term.clear()
  printList()
  drawBars()
end

local function fullRefresh()
  toSkip = 0
  selected = 1
  refresh(true)
end

-- Saves/unsaves the selected item
local function saveItem(mode)
  if (selectedItem == savedItem and saveMode == mode) then
    savedItem = nil
    saveMode  = saveMode_none
  else
    savedItem = selectedItem
    saveMode  = mode
  end

  term.clear()
  printList()
  drawBars()
end

-- Gets user input
-- NOTE: Does not refresh the screen after input is entered.
local function getInput(prompt)
  status = prompt
  drawBars()

  term.setCursor(#prompt, h)
  term.setCursorBlink(true)
  local input = require("text").trim(term.read())
  term.setCursorBlink(false)

  return input
end

-- If the name already exists, put "(1)" at the end of it.
-- If THAT exists, "(2)", and so on.
local function fixName(name)
  local i = 0
  local old = name

  while true do
    if (fs.exists(name)) then
      i = i + 1
      name = old.."("..i..")"
    else
      break
    end
  end

  return name
end

-- Sorts the children of the given directory into alphabetical order
local function _sortDirectory(a, b) return a.name < b.name end
local function sortDirectory(dir)
  table.sort(dir.children, _sortDirectory)
end

-- Removes an item from it's parent
-- This function is used to avoid having to refresh the root
local function removeFromParent(dir)
  if (dir ~= nil and dir.parent ~= nil) then
    for i, child in ipairs(dir.parent.children) do
      if (child.name == dir.name) then
        table.remove(dir.parent.children, i)
        break
      end
    end
  end
end

-- Sets the parent for an item
-- This function is used to avoid having to refresh the root
local function setParent(item, parent)
  removeFromParent(item)
  item.parent = parent
  table.insert(parent.children, item)
  sortDirectory(parent)
end

-- Save the previous fore and background
local old_fore, old_fore_palette = gpu.getForeground()
local old_back, old_back_palette = gpu.getBackground()

-- Clear the screen, refresh the list, and set the cursor into the right place
refresh(true)
--print(debug.serialize(root))

while running do
  local _ = event.pull(0.25)

  -- Handle the CTRL commands
  if (keyboard.isControlDown()) then
    if (keyboard.isKeyDown(keyboard.keys.w)) then
      break
    elseif (keyboard.isKeyDown(keyboard.keys.e) and selectedItem.isDir) then
      shell.setWorkingDirectory(selectedItem.name)
      refresh(false)
    elseif (keyboard.isKeyDown(keyboard.keys.delete)) then
      -- If the item is saved, unsave it first
      if (selectedItem == savedItem) then saveItem(saveMode) end

      local didIt, error = fs.remove(selectedItem.name)

      if (not didIt) then
        status = status_errorDelete        
        drawBars()
      else
        selected = selected - 1
        removeFromParent(selectedItem) -- I remove it from the things directly, to save A LOT of time. Rather than having to refresh the root(On a Tier 3 computer, can take up to 4 seconds with only OpenOS installed).
        refresh(false)
      end
    elseif (keyboard.isKeyDown(keyboard.keys.c)) then
      saveItem(saveMode_copy)
    elseif (keyboard.isKeyDown(keyboard.keys.x)) then
      saveItem(saveMode_move)
    elseif (keyboard.isKeyDown(keyboard.keys.v)) then
      if (selectedItem.isDir and savedItem ~= nil) then
        -- First, decide which function should be used.
        local toUse   = nil
        local message = nil
        if (saveMode == saveMode_copy) then
          toUse   = fs.copy
          message = status_errorCopy
        elseif (saveMode == saveMode_move) then
          toUse   = fs.rename
          message = status_errorMove
        end

        -- Then use the function, and report back any errors
        if (toUse ~= nil) then
          local name = fixName(fs.concat(selectedItem.name, fs.name(savedItem.name)))
          local didIt, msg = toUse(savedItem.name, name)

          if (not didIt) then
            status = message
            drawBars()
          else
            -- If it worked, add the new item thing the to parent. Also unsave it           

            if (fs.isDirectory(name)) then
              addDirectory(selectedItem, name)
            else
              table.insert(selectedItem.children, {name=name, isDir=false, tabCount=0, parent=selectedItem})
            end

            -- And remove the original if it no longer exists.
            if (not fs.exists(savedItem.name)) then removeFromParent(savedItem) end

            saveItem(saveMode)
            saveItem(saveMode)
            sortDirectory(selectedItem)
            refresh(false)
          end
        else
          status = status_errorNoItem
          drawBars()
        end
      else
        if (selectedItem.isDir) then
          status = status_errorNoItem
        else
          status = status_errorNotDir
        end

        drawBars()
      end
    end
  end

  -- Move down in the list
  if (keyboard.isKeyDown(keyboard.keys.s)) then
    -- If we're on the last displayed item
    if (selected == #itemList) then
      -- Skip the next item when repopulating
      toSkip = toSkip + 1
      repopulate()

      redrawSelected = true

      -- If the list ended up being smaller than before
      -- Then unskip the last item, and repopulate again, before refreshing.
      -- This effectively stops the user from scrolling down past the list.
      if (selected > #itemList) then
        toSkip   = toSkip - 1
        repopulate()
        selected = #itemList
        printList()
      else -- Otherwise, refresh.
        printMode = printMode_CopyTop -- Optimisation, prevents a whole screen-redraw.
        printList()
      end
    else -- Otherwise, just print the next item
      selected = selected + 1
      redrawSelected = true
      printList()
    end

    -- reset the status
    if (status ~= status_normal) then 
      status = status_normal 
      drawBars()
    end
  end

  -- Rename the thing
  if (keyboard.isKeyDown(keyboard.keys.f3)) then
    local name = getInput("[RNM]"..status_rename)

    -- Create the new path
    local path = fs.concat(fs.path(selectedItem.name), name)

    -- And attempt a rename
    local result, error = fs.rename(selectedItem.name, path)    
    if (not result) then
      status = status_errorRename -- This never actually gets seen, because "refresh" resets the status.
      refresh(false)
    else
      if (selectedItem.isDir) then
        removeFromParent(selectedItem)
        addDirectory(selectedItem.parent, path)
      else
        selectedItem.name = path
      end      

      sortDirectory(selectedItem.parent)
      refresh(false)
    end
  end

  -- Go up in the list
  if (keyboard.isKeyDown(keyboard.keys.w)) then
    if (selected-1 == 0) then -- If we're on the first item, then either scroll up if we've skipped past some, or just don't do anything.
      if (toSkip ~= 0) then
        toSkip = toSkip - 1

        -- Optimise the drawing
        redrawSelected = true
        printMode = printMode_CopyBot

        -- Repopulate, and redraw the list
        repopulate()
        printList()
      end
    else -- Otherwise, just go up an item.
      selected = selected - 1
      redrawSelected = true
      printList()
    end

    if (status ~= status_normal) then
      status = status_normal
      drawBars()
    end
  end

  if (keyboard.isKeyDown(keyboard.keys.e)) then
    if (not selectedItem.isDir) then
      require("os").execute("edit \""..selectedItem.name.."\"")
      refresh(false)
    else
      status = status_errorNotFile
      drawBars()
    end
  end

  if (keyboard.isKeyDown(keyboard.keys.d)) then
    if (selectedItem.isDir) then
      local name = getInput("[DIR]"..status_rename)

      name = fs.concat(selectedItem.name, name)
      local didIt, msg = fs.makeDirectory(name)
      if (not didIt) then
        status = status_errorNewDir
        refresh(false)
      else
        addDirectory(selectedItem, name)
        sortDirectory(selectedItem)
        refresh(false)
      end
    else
      status = status_errorNotDir
      drawBars()
    end
  end

  if (keyboard.isKeyDown(keyboard.keys.f)) then
    if (selectedItem.isDir) then
      local name = getInput("[FIL]"..status_rename)
      name = fs.concat(selectedItem.name, name)

      local _     = fs.open(name, "w")
      local didIt = (_ ~= nil)

      _:close()
      if (didIt) then
        table.insert(selectedItem.children, {name=name, isDir=false, tabCount=0, parent=selectedItem})
        sortDirectory(selectedItem)
        refresh(false)
      else
        status = status_errorNewFile
        drawBars()
      end
    else
      status = status_errorNotDir
      drawBars()
    end
  end
  
  -- (un)Collapses the directory currently selected
  if (keyboard.isKeyDown(keyboard.keys.c) and not keyboard.isControlDown()) then
    if (selectedItem.isDir) then
      selectedItem.collapsed = not selectedItem.collapsed
      dirSettings[selectedItem.name].collapsed = selectedItem.collapsed
      refresh(false)
    end
  end

  --status = "Selected = "..selected.."| toSkip = "..toSkip.." | #ItemList = "..#itemList.." | CWD = "..shell.getWorkingDirectory()
  --drawBars()
end

gpu.setBackground(old_back, old_back_palette)
gpu.setForeground(old_fore, old_fore_palette)
term.clear()