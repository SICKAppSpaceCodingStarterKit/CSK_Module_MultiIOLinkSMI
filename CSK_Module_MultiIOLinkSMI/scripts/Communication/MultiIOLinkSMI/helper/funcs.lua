---@diagnostic disable: undefined-global, redundant-parameter, missing-parameter
--*****************************************************************
-- Inside of this script, you will find helper functions
--*****************************************************************

--**************************************************************************
--**********************Start Global Scope *********************************
--**************************************************************************

local nameOfModule = 'CSK_MultiIOLinkSMI'

local funcs = {}
-- Providing standard JSON functions
local json = require('Communication/MultiIOLinkSMI/helper/Json')
-- Default parameters for instances of module
funcs.defaultParameters = require('Communication/MultiIOLinkSMI/MultiIOLinkSMI_Parameters')

--**************************************************************************
--********************** End Global Scope **********************************
--**************************************************************************
--**********************Start Function Scope *******************************
--**************************************************************************

local function copy(origTable, seen)
  if type(origTable) ~= 'table' then return origTable end
  if seen and seen[origTable] then return seen[origTable] end
  local s = seen or {}
  local res = setmetatable({}, getmetatable(origTable))
  s[origTable] = res
  for k, v in pairs(origTable) do res[copy(k, s)] = copy(v, s) end
  return res
end
funcs.copy = copy

local function getTableSize(someTable)
  if not someTable then
    return 0
  end
  local size = 0
  for _,_ in pairs(someTable) do
    size = size + 1
  end
  return size
end
funcs.getTableSize = getTableSize


local function createDynamicTableContent(tableType, inputTable, selectedID)
  local content = {}
  for id, dataPointInfo in ipairs(inputTable) do
    local singleRowContent = {}
    for parameter, value in pairs(dataPointInfo) do
      local contentValue = value
      if parameter == 'Datatype' then
        contentValue = ''
        for datatypeParameter, datatypeParameterValue in pairs(value) do
          if datatypeParameter ~= 'type' and datatypeParameter ~= 'RecordItem' then
            contentValue = contentValue .. datatypeParameter .. ' = ' .. tostring(datatypeParameterValue) .. '; \n'
          end
        end
        singleRowContent[tableType..'type'] = value.type
      end
      singleRowContent[tableType..parameter] = contentValue
    end
    singleRowContent[tableType.. 'ID'] = id
    singleRowContent.selected = selectedID == id
    table.insert(content, singleRowContent)
  end
  return json.encode(content)
end
funcs.createDynamicTableContent = createDynamicTableContent

--- Function to create a list with numbers
---@param size int Size of the list
---@return string list List of numbers
local function createStringListBySize(size)
  local list = "["
  if size >= 1 then
    list = list .. '"' .. tostring(1) .. '"'
  end
  if size >= 2 then
    for i=2, size do
      list = list .. ', ' .. '"' .. tostring(i) .. '"'
    end
  end
  list = list .. "]"
  return list
end
funcs.createStringListBySize = createStringListBySize

local function checkIfKeyListFormArray(keyList)
  local success, _ = pcall(
    table.sort,
    keyList,
    function(left,right)
      return tonumber(left) < tonumber(right)
    end
  )
  if not success then
    return false, keyList
  end
  local i = 0
  for _, key in ipairs(keyList) do
    if tonumber(key) and tonumber(key)-i == 1 then
      i = i + 1
    else
      return false, keyList
    end
  end
  if i ~= #keyList then
    return false, keyList
  end
  return true, keyList
end

-- Function to convert a table into a Container object
---@param data auto[] Lua Table to convert to Container
---@return Container cont Created Container
local function convertTable2Container(data)
  local cont = Container.create()
  for key, val in pairs(data) do
    local valType = nil
    local val2add = val
    if type(val) == 'table' then
      val2add = convertTable2Container(val)
      valType = 'OBJECT'
    end
    if type(val) == 'string' then valType = 'STRING' end
    cont:add(key, val2add, valType)
  end
  return cont
end
funcs.convertTable2Container = convertTable2Container

--- Function to convert a Container into a table
---@param cont Container Container to convert to Lua table
---@return auto[] data Created Lua table
local function convertContainer2Table(cont)
  local arrayInside, keyList = checkIfKeyListFormArray(cont:list())
  local tab = {}
  for _, key in ipairs(keyList) do
    local tempVal = cont:get(key, cont:getType(key))
    local keyToAdd = key
    if arrayInside then
      keyToAdd = tonumber(key)
    end
    if cont:getType(key) == 'OBJECT' then
      if Object.getType(tempVal) == 'Container' then
        tab[keyToAdd] = convertContainer2Table(tempVal)
      else
        tab[keyToAdd] = tempVal
      end
    else
      tab[keyToAdd] = tempVal
    end
  end
  return tab
end
funcs.convertContainer2Table = convertContainer2Table

--- Function to unpack data out binary
---@param fmt string Format to use to unpack binary data
---@param data binary Binary data
---@param bitPosition int Position of bit within byte if fmt is 'bit'
---@return auto data Unpacked data
local function unpack(fmt, data, bitPosition)
  if fmt == 'bit' then
    local byteData = string.unpack('B', data)
    local status = byteData >> bitPosition & 1
    return status
  else
    local suc = string.unpack(fmt, data)
    if suc then
      return suc
    else
      return false
    end
  end
end
funcs.unpack = unpack

--- Function to compare table content. Optionally will fill missing values within content table with values of defaultTable
---@param content auto Data to check
---@param defaultTable auto Reference data
---@return auto[] content Update of data
local function checkParameters(content, defaultTable)
  for key, value in pairs(defaultTable) do
    if type(value) == 'table' then
      if content[key] == nil then
        _G.logger:info(nameOfModule .. ": Created missing parameters table '" .. tostring(key) .. "'")
        content[key] = {}
      end
      content[key] = checkParameters(content[key], defaultTable[key])
    elseif content[key] == nil then
      _G.logger:info(nameOfModule .. ": Missing parameter '" .. tostring(key) .. "'. Adding default value '" .. tostring(defaultTable[key]) .. "'")
      content[key] = defaultTable[key]
      if key == 'cameraNo' then
        _G.logger:warning(nameOfModule .. ": '" .. tostring(key) .. "' is a major parameter! Default value might not work and needs to be edited!")
      end
    end
  end
  return content
end
funcs.checkParameters = checkParameters

return funcs

--**************************************************************************
--**********************End Function Scope *********************************
--**************************************************************************